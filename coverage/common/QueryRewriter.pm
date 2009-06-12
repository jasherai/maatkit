---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryRewriter.pm   91.5   87.5   53.3   93.8    n/a  100.0   88.0
Total                          91.5   87.5   53.3   93.8    n/a  100.0   88.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRewriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:51 2009
Finish:       Wed Jun 10 17:20:51 2009

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
18                                                    # QueryRewriter package $Revision: 3383 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  5   
               1                                  7   
21             1                    1           109   use warnings FATAL => 'all';
               1                                  3   
               1                                  9   
22                                                    
23                                                    package QueryRewriter;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
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
52             1                    1            11      my ( $class, %args ) = @_;
53             1                                  4      my $self = { %args };
54             1                                 11      return bless $self, $class;
55                                                    }
56                                                    
57                                                    # Strips comments out of queries.
58                                                    sub strip_comments {
59             5                    5            26      my ( $self, $query ) = @_;
60             5                                 38      $query =~ s/$olc_re//go;
61             5                                 24      $query =~ s/$mlc_re//go;
62             5                                 31      return $query;
63                                                    }
64                                                    
65                                                    # Shortens long queries by normalizing stuff out of them.  $length is used only
66                                                    # for IN() lists.
67                                                    sub shorten {
68            13                   13            62      my ( $self, $query, $length ) = @_;
69                                                       # Shorten multi-value insert/replace, all the way up to on duplicate key
70                                                       # update if it exists.
71            13                                163      $query =~ s{
72                                                          \A(
73                                                             (?:INSERT|REPLACE)
74                                                             (?:\s+LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)?
75                                                             (?:\s\w+)*\s+\S+\s+VALUES\s*\(.*?\)
76                                                          )
77                                                          \s*,\s*\(.*?(ON\s+DUPLICATE|\Z)}
78                                                          {$1 /*... omitted ...*/$2}xsi;
79                                                    
80                                                       # Shortcut!  Find out if there's an IN() list with values.
81            13    100                         113      return $query unless $query =~ m/IN\s*\(\s*(?!select)/i;
82                                                    
83                                                       # Shorten long IN() lists of literals.  But only if the string is longer than
84                                                       # the $length limit.  Assumption: values don't contain commas or closing
85                                                       # parens inside them.  Assumption: all values are the same length.
86    ***      3    100     66                   33      if ( $length && length($query) > $length ) {
87             2                                 20         my ($left, $mid, $right) = $query =~ m{
88                                                             (\A.*?\bIN\s*\()     # Everything up to the opening of IN list
89                                                             ([^\)]+)             # Contents of the list
90                                                             (\).*\Z)             # The rest of the query
91                                                          }xsi;
92    ***      2     50                          10         if ( $left ) {
93                                                             # Compute how many to keep and try to get rid of the middle of the
94                                                             # list until it's short enough.
95             2                                  7            my $targ = $length - length($left) - length($right);
96             2                                 12            my @vals = split(/,/, $mid);
97             2                                  7            my @left = shift @vals;
98             2                                  6            my @right;
99             2                                  5            my $len  = length($left[0]);
100   ***      2            33                   24            while ( @vals && $len < $targ / 2 ) {
101   ***      0                                  0               $len += length($vals[0]) + 1;
102   ***      0                                  0               push @left, shift @vals;
103                                                            }
104   ***      2            33                   35            while ( @vals && $len < $targ ) {
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
115            3                                 16      return $query;
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
126           35                   35          1196      my ( $self, $query ) = @_;
127                                                   
128                                                      # First, we start with a bunch of special cases that we can optimize because
129                                                      # they are special behavior or because they are really big and we want to
130                                                      # throw them away as early as possible.
131           35    100                         207      $query =~ m#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `# # mysqldump query
132                                                         && return 'mysqldump';
133                                                      # Matches queries like REPLACE /*foo.bar:3/3*/ INTO checksum.checksum
134           34    100                         629      $query =~ m#/\*\w+\.\w+:[0-9]/[0-9]\*/#     # mk-table-checksum, etc query
135                                                         && return 'maatkit';
136                                                      # Administrator commands appear to be a comment, so return them as-is
137           33    100                         126      $query =~ m/\A# administrator command: /
138                                                         && return $query;
139                                                      # Special-case for stored procedures.
140           32    100                         180      $query =~ m/\A\s*(call\s+\S+)\(/i
141                                                         && return lc($1); # Warning! $1 used, be careful.
142                                                      # mysqldump's INSERT statements will have long values() lists, don't waste
143                                                      # time on them... they also tend to segfault Perl on some machines when you
144                                                      # get to the "# Collapse IN() and VALUES() lists" regex below!
145           31    100                         579      if ( my ($beginning) = $query =~ m/\A((?:INSERT|REPLACE)(?: IGNORE)? INTO .+? VALUES \(.*?\)),\(/i ) {
146            3                                 12         $query = $beginning; # Shorten multi-value INSERT statements ASAP
147                                                      }
148                                                   
149           31                                388      $query =~ s/$olc_re//go;
150           31                                100      $query =~ s/$mlc_re//go;
151           31    100                         153      $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
152                                                         && return $query;
153                                                   
154           30                                 93      $query =~ s/\\["']//g;                # quoted strings
155           30                                 84      $query =~ s/".*?"/?/sg;               # quoted strings
156           30                                100      $query =~ s/'.*?'/?/sg;               # quoted strings
157                                                      # This regex is extremely broad in its definition of what looks like a
158                                                      # number.  That is for speed.
159           30                                134      $query =~ s/[0-9+-][0-9a-f.xb+-]*/?/g;# Anything vaguely resembling numbers
160           30                                110      $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
161           30                                 90      $query =~ s/\A\s+//;                  # Chop off leading whitespace
162           30                                 91      chomp $query;                         # Kill trailing whitespace
163           30                                108      $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
164           30                                100      $query = lc $query;
165           30                                 91      $query =~ s/\bnull\b/?/g;             # Get rid of NULLs
166           30                                276      $query =~ s{                          # Collapse IN and VALUES lists
167                                                                  \b(in|values?)(?:[\s,]*\([\s?,]*\))+
168                                                                 }
169                                                                 {$1(?+)}gx;
170           30                                142      $query =~ s{                          # Collapse UNION
171                                                                  \b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+
172                                                                 }
173                                                                 {$1 /*repeat$2*/}xg;
174           30                                100      $query =~ s/\blimit \?(?:, ?\?| offset \?)?/limit ?/; # LIMIT
175                                                      # The following are disabled because of speed issues.  Should we try to
176                                                      # normalize whitespace between and around operators?  My gut feeling is no.
177                                                      # $query =~ s/ , | ,|, /,/g;    # Normalize commas
178                                                      # $query =~ s/ = | =|= /=/g;       # Normalize equals
179                                                      # $query =~ s# [,=+*/-] ?|[,=+*/-] #+#g;    # Normalize operators
180           30                                189      return $query;
181                                                   }
182                                                   
183                                                   # This is kind of like fingerprinting, but it super-fingerprints to something
184                                                   # that shows the query type and the tables/objects it accesses.
185                                                   sub distill {
186           30                   30           169      my ( $self, $query, %args ) = @_;
187   ***     30            33                  296      my $qp = $args{qp} || $self->{QueryParser};
188   ***     30     50                         108      die "I need a qp argument" unless $qp;
189                                                   
190                                                      # Special cases.
191           30    100                         170      $query =~ m/\A\s*call\s+(\S+)\(/i
192                                                         && return "CALL $1"; # Warning! $1 used, be careful.
193           29    100                         121      $query =~ m/\A# administrator/
194                                                         && return "ADMIN";
195           28    100                         129      $query =~ m/\A\s*use\s+/
196                                                         && return "USE";
197                                                   
198                                                      # First, get the query type -- just extract all the verbs and collapse them
199                                                      # together.
200           27                                682      my @verbs = $query =~ m/\b($verbs)\b/gio;
201           27                                 89      @verbs    = do {
202           27                                 81         my $last = '';
203           27                                 95         grep { my $pass = $_ ne $last; $last = $_; $pass } map { uc } @verbs;
              37                                114   
              37                                 94   
              37                                149   
              37                                140   
204                                                      };
205           27                                104      my $verbs = join(q{ }, @verbs);
206           27                                 84      $verbs =~ s/( UNION SELECT)+/ UNION/g;
207                                                   
208                                                      # "Fingerprint" the tables.
209           31                                102      my @tables = map {
210           27                                134         $_ =~ s/`//g;
211           31                                181         $_ =~ s/(_?)[0-9]+/$1?/g;
212           31                                126         $_;
213                                                      } $qp->get_tables($query);
214                                                   
215                                                      # Collapse the table list
216           27                                 77      @tables = do {
217           27                                 78         my $last = '';
218           27                                 79         grep { my $pass = $_ ne $last; $last = $_; $pass } @tables;
              31                                 88   
              31                                 80   
              31                                116   
219                                                      };
220                                                   
221           27                                102      $query = join(q{ }, $verbs, @tables);
222           27                                163      return $query;
223                                                   }
224                                                   
225                                                   sub convert_to_select {
226           23                   23           119      my ( $self, $query ) = @_;
227           23    100                          89      return unless $query;
228            7                                 38      $query =~ s{
               8                                 38   
229                                                                    \A.*?
230                                                                    update\s+(.*?)
231                                                                    \s+set\b(.*?)
232                                                                    (?:\s*where\b(.*?))?
233                                                                    (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
234                                                                    \Z
235                                                                 }
236                                                                 {__update_to_select($1, $2, $3, $4)}exsi
237            2                                  9         || $query =~ s{
238                                                                       \A.*?
239                                                                       (?:insert|replace)\s+
240                                                                       .*?\binto\b(.*?)\(([^\)]+)\)\s*
241                                                                       values?\s*(\(.*?\))\s*
242                                                                       (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
243                                                                       \Z
244                                                                    }
245                                                                    {__insert_to_select($1, $2, $3)}exsi
246           22    100    100                  560         || $query =~ s{
247                                                                       \A.*?
248                                                                       delete\s+(.*?)
249                                                                       \bfrom\b(.*)
250                                                                       \Z
251                                                                    }
252                                                                    {__delete_to_select($1, $2)}exsi;
253           22                                297      $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
254           22                                124      $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
255           22                                152      return $query;
256                                                   }
257                                                   
258                                                   sub convert_select_list {
259            2                    2             9      my ( $self, $query ) = @_;
260            2    100                          15      $query =~ s{
               2                                 16   
261                                                                  \A\s*select(.*?)\bfrom\b
262                                                                 }
263                                                                 {$1 =~ m/\*/ ? "select 1 from" : "select isnull(coalesce($1)) from"}exi;
264            2                                 13      return $query;
265                                                   }
266                                                   
267                                                   sub __delete_to_select {
268            2                    2            13      my ( $delete, $join ) = @_;
269            2    100                          13      if ( $join =~ m/\bjoin\b/ ) {
270            1                                  7         return "select 1 from $join";
271                                                      }
272            1                                  8      return "select * from $join";
273                                                   }
274                                                   
275                                                   sub __insert_to_select {
276            8                    8            59      my ( $tbl, $cols, $vals ) = @_;
277            8                                 20      MKDEBUG && _d('Args:', @_);
278            8                                 46      my @cols = split(/,/, $cols);
279            8                                 20      MKDEBUG && _d('Cols:', @cols);
280            8                                 60      $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
281            8                                189      my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
282            8                                 35      MKDEBUG && _d('Vals:', @vals);
283   ***      8     50                          34      if ( @cols == @vals ) {
284           23                                170         return "select * from $tbl where "
285            8                                 63            . join(' and ', map { "$cols[$_]=$vals[$_]" } (0..$#cols));
286                                                      }
287                                                      else {
288   ***      0                                  0         return "select * from $tbl limit 1";
289                                                      }
290                                                   }
291                                                   
292                                                   sub __update_to_select {
293            7                    7            54      my ( $from, $set, $where, $limit ) = @_;
294            7    100                          92      return "select $set from $from "
                    100                               
295                                                         . ( $where ? "where $where" : '' )
296                                                         . ( $limit ? " $limit "      : '' );
297                                                   }
298                                                   
299                                                   sub wrap_in_derived {
300            3                    3            14      my ( $self, $query ) = @_;
301            3    100                          14      return unless $query;
302            2    100                          20      return $query =~ m/\A\s*select/i
303                                                         ? "select 1 from ($query) as x limit 1"
304                                                         : $query;
305                                                   }
306                                                   
307                                                   sub _d {
308   ***      0                    0                    my ($package, undef, $line) = caller 0;
309   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
310   ***      0                                              map { defined $_ ? $_ : 'undef' }
311                                                           @_;
312   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
313                                                   }
314                                                   
315                                                   1;
316                                                   
317                                                   # ###########################################################################
318                                                   # End QueryRewriter package
319                                                   # ###########################################################################


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
188   ***     50      0     30   unless $qp
191          100      1     29   if $query =~ /\A\s*call\s+(\S+)\(/i
193          100      1     28   if $query =~ /\A# administrator/
195          100      1     27   if $query =~ /\A\s*use\s+/
227          100      1     22   unless $query
246          100      7     15   unless $query =~ s/
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
260          100      1      1   $1 =~ /\*/ ? :
269          100      1      1   if ($join =~ /\bjoin\b/)
283   ***     50      8      0   if (@cols == @vals) { }
294          100      4      3   $where ? :
             100      1      6   $limit ? :
301          100      1      2   unless $query
302          100      1      1   $query =~ /\A\s*select/i ? :
309   ***      0      0      0   defined $_ ? :


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
187   ***     33      0     30      0   $args{'qp'} || $$self{'QueryParser'}
246          100      7      8      7   $query =~ s/
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
__delete_to_select      2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:268
__insert_to_select      8 /home/daniel/dev/maatkit/common/QueryRewriter.pm:276
__update_to_select      7 /home/daniel/dev/maatkit/common/QueryRewriter.pm:293
convert_select_list     2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:259
convert_to_select      23 /home/daniel/dev/maatkit/common/QueryRewriter.pm:226
distill                30 /home/daniel/dev/maatkit/common/QueryRewriter.pm:186
fingerprint            35 /home/daniel/dev/maatkit/common/QueryRewriter.pm:126
new                     1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:52 
shorten                13 /home/daniel/dev/maatkit/common/QueryRewriter.pm:68 
strip_comments          5 /home/daniel/dev/maatkit/common/QueryRewriter.pm:59 
wrap_in_derived         3 /home/daniel/dev/maatkit/common/QueryRewriter.pm:300

Uncovered Subroutines
---------------------

Subroutine          Count Location                                            
------------------- ----- ----------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/QueryRewriter.pm:308


