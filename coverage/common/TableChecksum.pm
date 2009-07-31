---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TableChecksum.pm   89.7   86.4   83.7   83.3    n/a  100.0   87.8
Total                          89.7   86.4   83.7   83.3    n/a  100.0   87.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableChecksum.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:31 2009
Finish:       Fri Jul 31 18:53:31 2009

/home/daniel/dev/maatkit/common/TableChecksum.pm

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
18                                                    # TableChecksum package $Revision: 3186 $
19                                                    # ###########################################################################
20             1                    1             8   use strict;
               1                                  3   
               1                                  6   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
22                                                    
23                                                    package TableChecksum;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1             7   use List::Util qw(max);
               1                                  2   
               1                                 11   
27                                                    
28             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
29                                                    
30                                                    # BXT_XOR is actually faster than ACCUM as long as the user-variable
31                                                    # optimization can be used.  I've never seen a case where it can't be.
32                                                    our %ALGOS = (
33                                                       CHECKSUM => { pref => 0, hash => 0 },
34                                                       BIT_XOR  => { pref => 2, hash => 1 },
35                                                       ACCUM    => { pref => 3, hash => 1 },
36                                                    );
37                                                    
38                                                    sub new {
39             1                    1            32      bless {}, shift;
40                                                    }
41                                                    
42                                                    # Perl implementation of CRC32, ripped off from Digest::Crc32.  The results
43                                                    # ought to match what you get from any standard CRC32 implementation, such as
44                                                    # that inside MySQL.
45                                                    sub crc32 {
46             1                    1             5      my ( $self, $string ) = @_;
47             1                                  3      my $poly = 0xEDB88320;
48             1                                  4      my $crc  = 0xFFFFFFFF;
49             1                                  7      foreach my $char ( split(//, $string) ) {
50            11                                 35         my $comp = ($crc ^ ord($char)) & 0xFF;
51            11                                 34         for ( 1 .. 8 ) {
52            88    100                         378            $comp = $comp & 1 ? $poly ^ ($comp >> 1) : $comp >> 1;
53                                                          }
54            11                                 42         $crc = (($crc >> 8) & 0x00FFFFFF) ^ $comp;
55                                                       }
56             1                                  8      return $crc ^ 0xFFFFFFFF;
57                                                    }
58                                                    
59                                                    # Returns how wide/long, in characters, a CRC function is.
60                                                    sub get_crc_wid {
61    ***      0                    0             0      my ( $self, $dbh, $func ) = @_;
62    ***      0                                  0      my $crc_wid = 16;
63    ***      0      0                           0      if ( uc $func ne 'FNV_64' ) {
64    ***      0                                  0         eval {
65    ***      0                                  0            my ($val) = $dbh->selectrow_array("SELECT $func('a')");
66    ***      0                                  0            $crc_wid = max(16, length($val));
67                                                          };
68                                                       }
69    ***      0                                  0      return $crc_wid;
70                                                    }
71                                                    
72                                                    # Returns a CRC function's MySQL type as a list of (type, length).
73                                                    sub get_crc_type {
74             2                    2            11      my ( $self, $dbh, $func ) = @_;
75             2                                  6      my $type   = '';
76             2                                  6      my $length = 0;
77             2                                  7      my $sql    = "SELECT $func('a')";
78             2                                  6      my $sth    = $dbh->prepare($sql);
79             2                                 10      eval {
80             2                                238         $sth->execute();
81             2                                 36         $type   = $sth->{mysql_type_name}->[0];
82             2                                 13         $length = $sth->{mysql_length}->[0];
83             2                                  9         MKDEBUG && _d($sql, $type, $length);
84    ***      2    100     66                   18         if ( $type eq 'bigint' && $length < 20 ) {
85             1                                  4            $type = 'int';
86                                                          }
87                                                       };
88             2                                 17      $sth->finish;
89             2                                 42      return ($type, $length);
90                                                    }
91                                                    
92                                                    # Options:
93                                                    #   algorithm   Optional: one of CHECKSUM, ACCUM, BIT_XOR
94                                                    #   vp          VersionParser object
95                                                    #   dbh         DB handle
96                                                    #   where       bool: whether user wants a WHERE clause applied
97                                                    #   chunk       bool: whether user wants to checksum in chunks
98                                                    #   replicate   bool: whether user wants to do via replication
99                                                    #   count       bool: whether user wants a row count too
100                                                   sub best_algorithm {
101           12                   12           192      my ( $self, %args ) = @_;
102           12                                 66      my ($alg, $vp, $dbh) = @args{ qw(algorithm vp dbh) };
103           12                                 22      my @choices = sort { $ALGOS{$a}->{pref} <=> $ALGOS{$b}->{pref} } keys %ALGOS;
              36                                156   
104           12    100    100                  141      die "Invalid checksum algorithm $alg"
105                                                         if $alg && !$ALGOS{$alg};
106                                                   
107                                                      # CHECKSUM is eliminated by lots of things...
108           11    100    100                  164      if (
                           100                        
                           100                        
109                                                         $args{where} || $args{chunk}        # CHECKSUM does whole table
110                                                         || $args{replicate}                 # CHECKSUM can't do INSERT.. SELECT
111                                                         || !$vp->version_ge($dbh, '4.1.1')) # CHECKSUM doesn't exist
112                                                      {
113            5                                 12         MKDEBUG && _d('Cannot use CHECKSUM algorithm');
114            5                                 17         @choices = grep { $_ ne 'CHECKSUM' } @choices;
              15                                 59   
115                                                      }
116                                                   
117                                                      # BIT_XOR isn't available till 4.1.1 either
118           11    100                          46      if ( !$vp->version_ge($dbh, '4.1.1') ) {
119            2                                  5         MKDEBUG && _d('Cannot use BIT_XOR algorithm');
120            2                                  9         @choices = grep { $_ ne 'BIT_XOR' } @choices;
               4                                 15   
121                                                      }
122                                                   
123                                                      # Choose the best (fastest) among the remaining choices.
124           11    100    100                   59      if ( $alg && grep { $_ eq $alg } @choices ) {
              20                                 91   
125                                                         # Honor explicit choices.
126            4                                 10         MKDEBUG && _d('User requested', $alg, 'algorithm');
127            4                                 31         return $alg;
128                                                      }
129                                                   
130                                                      # If the user wants a count, prefer something other than CHECKSUM, because it
131                                                      # requires an extra query for the count.
132   ***      7    100     66                   40      if ( $args{count} && grep { $_ ne 'CHECKSUM' } @choices ) {
               3                                 14   
133            1                                  3         MKDEBUG && _d('Not using CHECKSUM algorithm because COUNT desired');
134            1                                  3         @choices = grep { $_ ne 'CHECKSUM' } @choices;
               3                                 12   
135                                                      }
136                                                   
137            7                                 16      MKDEBUG && _d('Algorithms, in order:', @choices);
138            7                                 46      return $choices[0];
139                                                   }
140                                                   
141                                                   sub is_hash_algorithm {
142            3                    3            14      my ( $self, $algorithm ) = @_;
143   ***      3            66                   51      return $ALGOS{$algorithm} && $ALGOS{$algorithm}->{hash};
144                                                   }
145                                                   
146                                                   # Picks a hash function, in order of speed.
147                                                   sub choose_hash_func {
148            3                    3            19      my ( $self, %args ) = @_;
149            3                                 13      my @funcs = qw(CRC32 FNV_64 MD5 SHA1);
150            3    100                          15      if ( $args{func} ) {
151            2                                  9         unshift @funcs, $args{func};
152                                                      }
153            3                                  9      my ($result, $error);
154   ***      3            66                    8      do {
155            4                                 11         my $func;
156            4                                 10         eval {
157            4                                 12            $func = shift(@funcs);
158            4                                 14            my $sql = "SELECT $func('test-string')";
159            4                                  9            MKDEBUG && _d($sql);
160            4                                475            $args{dbh}->do($sql);
161            3                                 14            $result = $func;
162                                                         };
163   ***      4    100     66                   61         if ( $EVAL_ERROR && $EVAL_ERROR =~ m/failed: (.*?) at \S+ line/ ) {
164            1                                  7            $error .= qq{$func cannot be used because "$1"\n};
165            1                                 10            MKDEBUG && _d($func, 'cannot be used because', $1);
166                                                         }
167                                                      } while ( @funcs && !$result );
168                                                   
169   ***      3     50                          11      die $error unless $result;
170            3                                 35      return $result;
171                                                   }
172                                                   
173                                                   # Figure out which slice in a sliced BIT_XOR checksum should have the actual
174                                                   # concat-columns-and-checksum, and which should just get variable references.
175                                                   # Returns the slice.  I'm really not sure if this code is needed.  It always
176                                                   # seems the last slice is the one that works.  But I'd rather be paranoid.
177                                                      # TODO: this function needs a hint to know when a function returns an
178                                                      # integer.  CRC32 is an example.  In these cases no optimization or slicing
179                                                      # is necessary.
180                                                   sub optimize_xor {
181            2                    2            14      my ( $self, %args ) = @_;
182            2                                 11      my ( $dbh, $func ) = @args{qw(dbh func)};
183                                                   
184   ***      2     50                          10      die "$func never needs the BIT_XOR optimization"
185                                                         if $func =~ m/^(?:FNV_64|CRC32)$/i;
186                                                   
187            2                                  6      my $opt_slice = 0;
188            2                                  5      my $unsliced  = uc $dbh->selectall_arrayref("SELECT $func('a')")->[0]->[0];
189            2                                318      my $sliced    = '';
190            2                                  6      my $start     = 1;
191   ***      2     50                          11      my $crc_wid   = length($unsliced) < 16 ? 16 : length($unsliced);
192                                                   
193   ***      2            66                    5      do { # Try different positions till sliced result equals non-sliced.
194            5                                 10         MKDEBUG && _d('Trying slice', $opt_slice);
195            5                                399         $dbh->do('SET @crc := "", @cnt := 0');
196            5                                 38         my $slices = $self->make_xor_slices(
197                                                            query     => "\@crc := $func('a')",
198                                                            crc_wid   => $crc_wid,
199                                                            opt_slice => $opt_slice,
200                                                         );
201                                                   
202            5                                 20         my $sql = "SELECT CONCAT($slices) AS TEST FROM (SELECT NULL) AS x";
203            5                                 12         $sliced = ($dbh->selectrow_array($sql))[0];
204            5    100                        1080         if ( $sliced ne $unsliced ) {
205            3                                  8            MKDEBUG && _d('Slice', $opt_slice, 'does not work');
206            3                                  9            $start += 16;
207            3                                 35            ++$opt_slice;
208                                                         }
209                                                      } while ( $start < $crc_wid && $sliced ne $unsliced );
210                                                   
211   ***      2     50                          11      if ( $sliced eq $unsliced ) {
212            2                                  4         MKDEBUG && _d('Slice', $opt_slice, 'works');
213            2                                 17         return $opt_slice;
214                                                      }
215                                                      else {
216   ***      0                                  0         MKDEBUG && _d('No slice works');
217   ***      0                                  0         return undef;
218                                                      }
219                                                   }
220                                                   
221                                                   # Returns an expression that will do a bitwise XOR over a very wide integer,
222                                                   # such as that returned by SHA1, which is too large to just put into BIT_XOR().
223                                                   # $query is an expression that returns a row's checksum, $crc_wid is the width
224                                                   # of that expression in characters.  If the opt_slice argument is given, use a
225                                                   # variable to avoid calling the $query expression multiple times.  The variable
226                                                   # goes in slice $opt_slice.
227                                                   sub make_xor_slices {
228           13                   13            92      my ( $self, %args ) = @_;
229           13                                 72      my ( $query, $crc_wid, $opt_slice )
230                                                         = @args{qw(query crc_wid opt_slice)};
231                                                   
232                                                      # Create a series of slices with @crc as a placeholder.
233           13                                 32      my @slices;
234                                                      for ( my $start = 1; $start <= $crc_wid; $start += 16 ) {
235           29                                 97         my $len = $crc_wid - $start + 1;
236           29    100                         106         if ( $len > 16 ) {
237           16                                 46            $len = 16;
238                                                         }
239           29                                251         push @slices,
240                                                            "LPAD(CONV(BIT_XOR("
241                                                            . "CAST(CONV(SUBSTRING(\@crc, $start, $len), 16, 10) AS UNSIGNED))"
242                                                            . ", 10, 16), $len, '0')";
243           13                                 33      }
244                                                   
245                                                      # Replace the placeholder with the expression.  If specified, add a
246                                                      # user-variable optimization so the expression goes in only one of the
247                                                      # slices.  This optimization relies on @crc being '' when the query begins.
248   ***     13    100     66                   87      if ( defined $opt_slice && $opt_slice < @slices ) {
249            7                                 63         $slices[$opt_slice] =~ s/\@crc/\@crc := $query/;
250                                                      }
251                                                      else {
252            6                                 20         map { s/\@crc/$query/ } @slices;
              12                                 63   
253                                                      }
254                                                   
255           13                                101      return join(', ', @slices);
256                                                   }
257                                                   
258                                                   # Generates a checksum query for a given table.  Arguments:
259                                                   # *   table      Struct as returned by TableParser::parse()
260                                                   # *   quoter     Quoter()
261                                                   # *   func       SHA1, MD5, etc
262                                                   # *   sep        (Optional) Separator for CONCAT_WS(); default #
263                                                   # *   cols       (Optional) arrayref of columns to checksum
264                                                   # *   trim       (Optional) wrap VARCHAR in TRIM() for 4.x / 5.x compatibility
265                                                   # *   ignorecols (Optional) arrayref of columns to exclude from checksum
266                                                   sub make_row_checksum {
267           20                   20           211      my ( $self, %args ) = @_;
268           20                                107      my ( $table, $quoter, $func )
269                                                         = @args{ qw(table quoter func) };
270                                                   
271           20           100                  134      my $sep = $args{sep} || '#';
272           20                                 65      $sep =~ s/'//g;
273           20           100                   67      $sep ||= '#';
274                                                   
275                                                      # This allows a simpler grep when building %cols below.
276           20                                 53      my %ignorecols = map { $_ => 1 } @{$args{ignorecols}};
               1                                  7   
              20                                 89   
277                                                   
278                                                      # Generate the expression that will turn a row into a checksum.
279                                                      # Choose columns.  Normalize query results: make FLOAT and TIMESTAMP
280                                                      # stringify uniformly.
281           98                                397      my %cols = map { lc($_) => 1 }
              99                                314   
282           11                                 39                 grep { !exists $ignorecols{$_} }
283           20    100                          85                 ($args{cols} ? @{$args{cols}} : @{$table->{cols}});
               9                                 38   
284           98                                343      my @cols =
285                                                         map {
286          228                                676            my $type = $table->{type_for}->{$_};
287           98                                361            my $result = $quoter->quote($_);
288           98    100    100                  855            if ( $type eq 'timestamp' ) {
                    100    100                        
                    100                               
289            6                                 19               $result .= ' + 0';
290                                                            }
291                                                            elsif ( $type =~ m/float|double/ && $args{precision} ) {
292            1                                  6               $result = "ROUND($result, $args{precision})";
293                                                            }
294                                                            elsif ( $type =~ m/varchar/ && $args{trim} ) {
295            1                                  5               $result = "TRIM($result)";
296                                                            }
297           98                                342            $result;
298                                                         }
299                                                         grep {
300           20                                 81            $cols{$_}
301                                                         }
302           20                                 80         @{$table->{cols}};
303                                                   
304           20                                 66      my $query;
305           20    100                          75      if ( uc $func ne 'FNV_64' ) {
306                                                         # Add a bitmap of which nullable columns are NULL.
307           16                                 42         my @nulls = grep { $cols{$_} } @{$table->{null_cols}};
              78                                246   
              16                                 61   
308           16    100                          64         if ( @nulls ) {
309           24                                 89            my $bitmap = "CONCAT("
310            4                                 24               . join(', ', map { 'ISNULL(' . $quoter->quote($_) . ')' } @nulls)
311                                                               . ")";
312            4                                 18            push @cols, $bitmap;
313                                                         }
314                                                   
315           16    100                         114         $query = @cols > 1
316                                                                ? "$func(CONCAT_WS('$sep', " . join(', ', @cols) . '))'
317                                                                : "$func($cols[0])";
318                                                      }
319                                                      else {
320                                                         # As a special case, FNV_64 doesn't need its arguments concatenated, and
321                                                         # doesn't need a bitmap of NULLs.
322            4                                 22         $query = 'FNV_64(' . join(', ', @cols) . ')';
323                                                      }
324                                                   
325           20                                150      return $query;
326                                                   }
327                                                   
328                                                   # Generates a checksum query for a given table.  Arguments:
329                                                   # *   dbname    Database name
330                                                   # *   tblname   Table name
331                                                   # *   table     Struct as returned by TableParser::parse()
332                                                   # *   quoter    Quoter()
333                                                   # *   algorithm Any of @ALGOS
334                                                   # *   func      SHA1, MD5, etc
335                                                   # *   crc_wid   Width of the string returned by func
336                                                   # *   crc_type  Type of func's result
337                                                   # *   opt_slice (Optional) Which slice gets opt_xor (see make_xor_slices()).
338                                                   # *   cols      (Optional) see make_row_checksum()
339                                                   # *   sep       (Optional) see make_row_checksum()
340                                                   # *   replicate (Optional) generate query to REPLACE into this table.
341                                                   # *   trim      (Optional) see make_row_checksum().
342                                                   # *   buffer    (Optional) Adds SQL_BUFFER_RESULT.
343                                                   sub make_checksum_query {
344           12                   12           228      my ( $self, %args ) = @_;
345           12                                 89      my @arg_names = qw(dbname tblname table quoter algorithm
346                                                           func crc_wid crc_type opt_slice);
347           12                                 41      foreach my $arg( @arg_names ) {
348   ***    108     50                         431         die "You must specify argument $arg" unless exists $args{$arg};
349                                                      }
350           12                                 74      my ( $dbname, $tblname, $table, $quoter, $algorithm,
351                                                           $func, $crc_wid, $crc_type, $opt_slice ) = @args{ @arg_names };
352   ***     12    100     66                  105      die "Invalid or missing checksum algorithm"
353                                                         unless $algorithm && $ALGOS{$algorithm};
354                                                   
355           11                                 22      my $result;
356                                                   
357           11    100                          45      if ( $algorithm eq 'CHECKSUM' ) {
358            1                                  5         return "CHECKSUM TABLE " . $quoter->quote($dbname, $tblname);
359                                                      }
360                                                   
361           10                                 61      my $expr = $self->make_row_checksum(%args);
362                                                   
363           10    100                          44      if ( $algorithm eq 'BIT_XOR' ) {
364                                                         # This checksum algorithm concatenates the columns in each row and
365                                                         # checksums them, then slices this checksum up into 16-character chunks.
366                                                         # It then converts them BIGINTs with the CONV() function, and then
367                                                         # groupwise XORs them to produce an order-independent checksum of the
368                                                         # slice over all the rows.  It then converts these back to base 16 and
369                                                         # puts them back together.  The effect is the same as XORing a very wide
370                                                         # (32 characters = 128 bits for MD5, and SHA1 is even larger) unsigned
371                                                         # integer over all the rows.
372                                                         #
373                                                         # As a special case, integer functions do not need to be sliced.  They
374                                                         # can be fed right into BIT_XOR after a cast to UNSIGNED.
375            5    100                          20         if ( $crc_type =~ m/int$/ ) {
376            3                                 11            $result = "LOWER(CONV(BIT_XOR(CAST($expr AS UNSIGNED)), 10, 16)) AS crc ";
377                                                         }
378                                                         else {
379            2                                 15            my $slices = $self->make_xor_slices( query => $expr, %args );
380            2                                 12            $result = "LOWER(CONCAT($slices)) AS crc ";
381                                                         }
382                                                      }
383                                                      else {
384                                                         # Use an accumulator variable.  This query relies on @crc being '', and
385                                                         # @cnt being 0 when it begins.  It checksums each row, appends it to the
386                                                         # running checksum, and checksums the two together.  In this way it acts
387                                                         # as an accumulator for all the rows.  It then prepends a steadily
388                                                         # increasing number to the left, left-padded with zeroes, so each checksum
389                                                         # taken is stringwise greater than the last.  In this way the MAX()
390                                                         # function can be used to return the last checksum calculated.  @cnt is
391                                                         # not used for a row count, it is only used to make MAX() work correctly.
392                                                         #
393                                                         # As a special case, int funcs must be converted to base 16 so it's a
394                                                         # predictable width (it's also a shorter string, but that's not really
395                                                         # important).
396            5    100                          24         if ( $crc_type =~ m/int$/ ) {
397            3                                 24            $result = "RIGHT(MAX("
398                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
399                                                               . "CONV(CAST($func(CONCAT(\@crc, $expr)) AS UNSIGNED), 10, 16))"
400                                                               . "), $crc_wid) AS crc ";
401                                                         }
402                                                         else {
403            2                                 15            $result = "RIGHT(MAX("
404                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
405                                                               . "$func(CONCAT(\@crc, $expr)))"
406                                                               . "), $crc_wid) AS crc ";
407                                                         }
408                                                      }
409           10    100                          36      if ( $args{replicate} ) {
410            2                                 16         $result = "REPLACE /*PROGRESS_COMMENT*/ INTO $args{replicate} "
411                                                            . "(db, tbl, chunk, boundaries, this_cnt, this_crc) "
412                                                            . "SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, $result";
413                                                      }
414                                                      else {
415            8    100                          49         $result = "SELECT "
416                                                            . ($args{buffer} ? 'SQL_BUFFER_RESULT ' : '')
417                                                            . "/*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, $result";
418                                                      }
419           10                                 79      return $result . "FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/";
420                                                   }
421                                                   
422                                                   # Queries the replication table for chunks that differ from the master's data.
423                                                   sub find_replication_differences {
424   ***      0                    0                    my ( $self, $dbh, $table ) = @_;
425                                                   
426   ***      0                                         (my $sql = <<"   EOF") =~ s/\s+/ /gm;
427                                                         SELECT db, tbl, chunk, boundaries,
428                                                            COALESCE(this_cnt-master_cnt, 0) AS cnt_diff,
429                                                            COALESCE(
430                                                               this_crc <> master_crc OR ISNULL(master_crc) <> ISNULL(this_crc),
431                                                               0
432                                                            ) AS crc_diff,
433                                                            this_cnt, master_cnt, this_crc, master_crc
434                                                         FROM $table
435                                                         WHERE master_cnt <> this_cnt OR master_crc <> this_crc
436                                                         OR ISNULL(master_crc) <> ISNULL(this_crc)
437                                                      EOF
438                                                   
439   ***      0                                         MKDEBUG && _d($sql);
440   ***      0                                         my $diffs = $dbh->selectall_arrayref($sql, { Slice => {} });
441   ***      0                                         return @$diffs;
442                                                   }
443                                                   
444                                                   sub _d {
445   ***      0                    0                    my ($package, undef, $line) = caller 0;
446   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
447   ***      0                                              map { defined $_ ? $_ : 'undef' }
448                                                           @_;
449   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
450                                                   }
451                                                   
452                                                   1;
453                                                   
454                                                   # ###########################################################################
455                                                   # End TableChecksum package
456                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
52           100     42     46   $comp & 1 ? :
63    ***      0      0      0   if (uc $func ne 'FNV_64')
84           100      1      1   if ($type eq 'bigint' and $length < 20)
104          100      1     11   if $alg and not $ALGOS{$alg}
108          100      5      6   if ($args{'where'} or $args{'chunk'} or $args{'replicate'} or not $vp->version_ge($dbh, '4.1.1'))
118          100      2      9   if (not $vp->version_ge($dbh, '4.1.1'))
124          100      4      7   if ($alg and grep {$_ eq $alg;} @choices)
132          100      1      6   if ($args{'count'} and grep {$_ ne 'CHECKSUM';} @choices)
150          100      2      1   if ($args{'func'})
163          100      1      3   if ($EVAL_ERROR and $EVAL_ERROR =~ /failed: (.*?) at \S+ line/)
169   ***     50      0      3   unless $result
184   ***     50      0      2   if $func =~ /^(?:FNV_64|CRC32)$/i
191   ***     50      0      2   length $unsliced < 16 ? :
204          100      3      2   if ($sliced ne $unsliced)
211   ***     50      2      0   if ($sliced eq $unsliced) { }
236          100     16     13   if ($len > 16)
248          100      7      6   if (defined $opt_slice and $opt_slice < @slices) { }
283          100     11      9   $args{'cols'} ? :
288          100      6     92   if ($type eq 'timestamp') { }
             100      1     91   elsif ($type =~ /float|double/ and $args{'precision'}) { }
             100      1     90   elsif ($type =~ /varchar/ and $args{'trim'}) { }
305          100     16      4   if (uc $func ne 'FNV_64') { }
308          100      4     12   if (@nulls)
315          100     10      6   @cols > 1 ? :
348   ***     50      0    108   unless exists $args{$arg}
352          100      1     11   unless $algorithm and $ALGOS{$algorithm}
357          100      1     10   if ($algorithm eq 'CHECKSUM')
363          100      5      5   if ($algorithm eq 'BIT_XOR') { }
375          100      3      2   if ($crc_type =~ /int$/) { }
396          100      3      2   if ($crc_type =~ /int$/) { }
409          100      2      8   if ($args{'replicate'}) { }
415          100      2      6   $args{'buffer'} ? :
446   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
84    ***     66      1      0      1   $type eq 'bigint' and $length < 20
104          100      2      9      1   $alg and not $ALGOS{$alg}
124          100      2      5      4   $alg and grep {$_ eq $alg;} @choices
132   ***     66      6      0      1   $args{'count'} and grep {$_ ne 'CHECKSUM';} @choices
143   ***     66      0      1      2   $ALGOS{$algorithm} && $ALGOS{$algorithm}{'hash'}
154   ***     66      0      3      1   @funcs and not $result
163   ***     66      3      0      1   $EVAL_ERROR and $EVAL_ERROR =~ /failed: (.*?) at \S+ line/
193   ***     66      0      2      3   $start < $crc_wid and $sliced ne $unsliced
248   ***     66      6      0      7   defined $opt_slice and $opt_slice < @slices
288          100     90      1      1   $type =~ /float|double/ and $args{'precision'}
             100     82      8      1   $type =~ /varchar/ and $args{'trim'}
352   ***     66      0      1     11   $algorithm and $ALGOS{$algorithm}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
271          100      4     16   $args{'sep'} || '#'
273          100     19      1   $sep ||= '#'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
108          100      1      1      9   $args{'where'} or $args{'chunk'}
             100      2      1      8   $args{'where'} or $args{'chunk'} or $args{'replicate'}
             100      3      2      6   $args{'where'} or $args{'chunk'} or $args{'replicate'} or not $vp->version_ge($dbh, '4.1.1')


Covered Subroutines
-------------------

Subroutine                   Count Location                                            
---------------------------- ----- ----------------------------------------------------
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:20 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:21 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:25 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:26 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:28 
best_algorithm                  12 /home/daniel/dev/maatkit/common/TableChecksum.pm:101
choose_hash_func                 3 /home/daniel/dev/maatkit/common/TableChecksum.pm:148
crc32                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:46 
get_crc_type                     2 /home/daniel/dev/maatkit/common/TableChecksum.pm:74 
is_hash_algorithm                3 /home/daniel/dev/maatkit/common/TableChecksum.pm:142
make_checksum_query             12 /home/daniel/dev/maatkit/common/TableChecksum.pm:344
make_row_checksum               20 /home/daniel/dev/maatkit/common/TableChecksum.pm:267
make_xor_slices                 13 /home/daniel/dev/maatkit/common/TableChecksum.pm:228
new                              1 /home/daniel/dev/maatkit/common/TableChecksum.pm:39 
optimize_xor                     2 /home/daniel/dev/maatkit/common/TableChecksum.pm:181

Uncovered Subroutines
---------------------

Subroutine                   Count Location                                            
---------------------------- ----- ----------------------------------------------------
_d                               0 /home/daniel/dev/maatkit/common/TableChecksum.pm:445
find_replication_differences     0 /home/daniel/dev/maatkit/common/TableChecksum.pm:424
get_crc_wid                      0 /home/daniel/dev/maatkit/common/TableChecksum.pm:61 


