---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TableChecksum.pm   89.8   86.4   78.2   83.3    n/a  100.0   86.9
Total                          89.8   86.4   78.2   83.3    n/a  100.0   86.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableChecksum.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:54 2009
Finish:       Sat Aug 29 15:03:55 2009

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
18                                                    # TableChecksum package $Revision: 4508 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  3   
               1                                  7   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
22                                                    
23                                                    package TableChecksum;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
26             1                    1             8   use List::Util qw(max);
               1                                  3   
               1                                 11   
27                                                    
28             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
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
39             1                    1            35      bless {}, shift;
40                                                    }
41                                                    
42                                                    # Perl implementation of CRC32, ripped off from Digest::Crc32.  The results
43                                                    # ought to match what you get from any standard CRC32 implementation, such as
44                                                    # that inside MySQL.
45                                                    sub crc32 {
46             1                    1             5      my ( $self, $string ) = @_;
47             1                                  3      my $poly = 0xEDB88320;
48             1                                  3      my $crc  = 0xFFFFFFFF;
49             1                                  8      foreach my $char ( split(//, $string) ) {
50            11                                 36         my $comp = ($crc ^ ord($char)) & 0xFF;
51            11                                 33         for ( 1 .. 8 ) {
52            88    100                         356            $comp = $comp & 1 ? $poly ^ ($comp >> 1) : $comp >> 1;
53                                                          }
54            11                                 42         $crc = (($crc >> 8) & 0x00FFFFFF) ^ $comp;
55                                                       }
56             1                                  6      return $crc ^ 0xFFFFFFFF;
57                                                    }
58                                                    
59                                                    # Returns how wide/long, in characters, a CRC function is.
60                                                    sub get_crc_wid {
61    ***      0                    0             0      my ( $self, $dbh, $func ) = @_;
62    ***      0                                  0      my $crc_wid = 16;
63    ***      0      0      0                    0      if ( uc $func ne 'FNV_64' && uc $func ne 'FNV1A_64' ) {
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
74             2                    2            12      my ( $self, $dbh, $func ) = @_;
75             2                                  8      my $type   = '';
76             2                                  5      my $length = 0;
77             2                                 10      my $sql    = "SELECT $func('a')";
78             2                                  6      my $sth    = $dbh->prepare($sql);
79             2                                 12      eval {
80             2                                427         $sth->execute();
81             2                                 53         $type   = $sth->{mysql_type_name}->[0];
82             2                                 13         $length = $sth->{mysql_length}->[0];
83             2                                 10         MKDEBUG && _d($sql, $type, $length);
84    ***      2    100     66                   20         if ( $type eq 'bigint' && $length < 20 ) {
85             1                                  3            $type = 'int';
86                                                          }
87                                                       };
88             2                                 32      $sth->finish;
89             2                                  5      MKDEBUG && _d('crc_type:', $type, 'length:', $length);
90             2                                 50      return ($type, $length);
91                                                    }
92                                                    
93                                                    # Options:
94                                                    #   algorithm   Optional: one of CHECKSUM, ACCUM, BIT_XOR
95                                                    #   vp          VersionParser object
96                                                    #   dbh         DB handle
97                                                    #   where       bool: whether user wants a WHERE clause applied
98                                                    #   chunk       bool: whether user wants to checksum in chunks
99                                                    #   replicate   bool: whether user wants to do via replication
100                                                   #   count       bool: whether user wants a row count too
101                                                   sub best_algorithm {
102           12                   12           203      my ( $self, %args ) = @_;
103           12                                 67      my ($alg, $vp, $dbh) = @args{ qw(algorithm vp dbh) };
104           12                                 19      my @choices = sort { $ALGOS{$a}->{pref} <=> $ALGOS{$b}->{pref} } keys %ALGOS;
              36                                159   
105           12    100    100                  130      die "Invalid checksum algorithm $alg"
106                                                         if $alg && !$ALGOS{$alg};
107                                                   
108                                                      # CHECKSUM is eliminated by lots of things...
109           11    100    100                  166      if (
                           100                        
                           100                        
110                                                         $args{where} || $args{chunk}        # CHECKSUM does whole table
111                                                         || $args{replicate}                 # CHECKSUM can't do INSERT.. SELECT
112                                                         || !$vp->version_ge($dbh, '4.1.1')) # CHECKSUM doesn't exist
113                                                      {
114            5                                 11         MKDEBUG && _d('Cannot use CHECKSUM algorithm');
115            5                                 16         @choices = grep { $_ ne 'CHECKSUM' } @choices;
              15                                 59   
116                                                      }
117                                                   
118                                                      # BIT_XOR isn't available till 4.1.1 either
119           11    100                          48      if ( !$vp->version_ge($dbh, '4.1.1') ) {
120            2                                  5         MKDEBUG && _d('Cannot use BIT_XOR algorithm because MySQL < 4.1.1');
121            2                                  8         @choices = grep { $_ ne 'BIT_XOR' } @choices;
               4                                 15   
122                                                      }
123                                                   
124                                                      # Choose the best (fastest) among the remaining choices.
125           11    100    100                   58      if ( $alg && grep { $_ eq $alg } @choices ) {
              20                                 99   
126                                                         # Honor explicit choices.
127            4                                  9         MKDEBUG && _d('User requested', $alg, 'algorithm');
128            4                                 31         return $alg;
129                                                      }
130                                                   
131                                                      # If the user wants a count, prefer something other than CHECKSUM, because it
132                                                      # requires an extra query for the count.
133   ***      7    100     66                   40      if ( $args{count} && grep { $_ ne 'CHECKSUM' } @choices ) {
               3                                 14   
134            1                                  2         MKDEBUG && _d('Not using CHECKSUM algorithm because COUNT desired');
135            1                                  4         @choices = grep { $_ ne 'CHECKSUM' } @choices;
               3                                 12   
136                                                      }
137                                                   
138            7                                 14      MKDEBUG && _d('Algorithms, in order:', @choices);
139            7                                 50      return $choices[0];
140                                                   }
141                                                   
142                                                   sub is_hash_algorithm {
143            3                    3            14      my ( $self, $algorithm ) = @_;
144   ***      3            66                   41      return $ALGOS{$algorithm} && $ALGOS{$algorithm}->{hash};
145                                                   }
146                                                   
147                                                   # Picks a hash function, in order of speed.
148                                                   sub choose_hash_func {
149            3                    3            20      my ( $self, %args ) = @_;
150            3                                 15      my @funcs = qw(CRC32 FNV1A_64 FNV_64 MD5 SHA1);
151            3    100                          14      if ( $args{func} ) {
152            2                                  9         unshift @funcs, $args{func};
153                                                      }
154            3                                  9      my ($result, $error);
155   ***      3            66                    8      do {
156            4                                  9         my $func;
157            4                                  9         eval {
158            4                                 11            $func = shift(@funcs);
159            4                                 17            my $sql = "SELECT $func('test-string')";
160            4                                  9            MKDEBUG && _d($sql);
161            4                                547            $args{dbh}->do($sql);
162            3                                 14            $result = $func;
163                                                         };
164   ***      4    100     66                   67         if ( $EVAL_ERROR && $EVAL_ERROR =~ m/failed: (.*?) at \S+ line/ ) {
165            1                                  8            $error .= qq{$func cannot be used because "$1"\n};
166            1                                  9            MKDEBUG && _d($func, 'cannot be used because', $1);
167                                                         }
168                                                      } while ( @funcs && !$result );
169                                                   
170   ***      3     50                          10      die $error unless $result;
171            3                                  7      MKDEBUG && _d('Chosen hash func:', $result);
172            3                                 37      return $result;
173                                                   }
174                                                   
175                                                   # Figure out which slice in a sliced BIT_XOR checksum should have the actual
176                                                   # concat-columns-and-checksum, and which should just get variable references.
177                                                   # Returns the slice.  I'm really not sure if this code is needed.  It always
178                                                   # seems the last slice is the one that works.  But I'd rather be paranoid.
179                                                      # TODO: this function needs a hint to know when a function returns an
180                                                      # integer.  CRC32 is an example.  In these cases no optimization or slicing
181                                                      # is necessary.
182                                                   sub optimize_xor {
183            2                    2            15      my ( $self, %args ) = @_;
184            2                                 11      my ( $dbh, $func ) = @args{qw(dbh func)};
185                                                   
186   ***      2     50                          10      die "$func never needs the BIT_XOR optimization"
187                                                         if $func =~ m/^(?:FNV1A_64|FNV_64|CRC32)$/i;
188                                                   
189            2                                  5      my $opt_slice = 0;
190            2                                  5      my $unsliced  = uc $dbh->selectall_arrayref("SELECT $func('a')")->[0]->[0];
191            2                                387      my $sliced    = '';
192            2                                  7      my $start     = 1;
193   ***      2     50                          10      my $crc_wid   = length($unsliced) < 16 ? 16 : length($unsliced);
194                                                   
195   ***      2            66                    7      do { # Try different positions till sliced result equals non-sliced.
196            5                                 11         MKDEBUG && _d('Trying slice', $opt_slice);
197            5                                427         $dbh->do('SET @crc := "", @cnt := 0');
198            5                                 39         my $slices = $self->make_xor_slices(
199                                                            query     => "\@crc := $func('a')",
200                                                            crc_wid   => $crc_wid,
201                                                            opt_slice => $opt_slice,
202                                                         );
203                                                   
204            5                                 24         my $sql = "SELECT CONCAT($slices) AS TEST FROM (SELECT NULL) AS x";
205            5                                 12         $sliced = ($dbh->selectrow_array($sql))[0];
206            5    100                        1236         if ( $sliced ne $unsliced ) {
207            3                                  9            MKDEBUG && _d('Slice', $opt_slice, 'does not work');
208            3                                  9            $start += 16;
209            3                                 35            ++$opt_slice;
210                                                         }
211                                                      } while ( $start < $crc_wid && $sliced ne $unsliced );
212                                                   
213   ***      2     50                          11      if ( $sliced eq $unsliced ) {
214            2                                  4         MKDEBUG && _d('Slice', $opt_slice, 'works');
215            2                                 20         return $opt_slice;
216                                                      }
217                                                      else {
218   ***      0                                  0         MKDEBUG && _d('No slice works');
219   ***      0                                  0         return undef;
220                                                      }
221                                                   }
222                                                   
223                                                   # Returns an expression that will do a bitwise XOR over a very wide integer,
224                                                   # such as that returned by SHA1, which is too large to just put into BIT_XOR().
225                                                   # $query is an expression that returns a row's checksum, $crc_wid is the width
226                                                   # of that expression in characters.  If the opt_slice argument is given, use a
227                                                   # variable to avoid calling the $query expression multiple times.  The variable
228                                                   # goes in slice $opt_slice.
229                                                   sub make_xor_slices {
230           13                   13           110      my ( $self, %args ) = @_;
231           13                                 76      my ( $query, $crc_wid, $opt_slice )
232                                                         = @args{qw(query crc_wid opt_slice)};
233                                                   
234                                                      # Create a series of slices with @crc as a placeholder.
235           13                                 34      my @slices;
236                                                      for ( my $start = 1; $start <= $crc_wid; $start += 16 ) {
237           29                                112         my $len = $crc_wid - $start + 1;
238           29    100                         119         if ( $len > 16 ) {
239           16                                 48            $len = 16;
240                                                         }
241           29                                345         push @slices,
242                                                            "LPAD(CONV(BIT_XOR("
243                                                            . "CAST(CONV(SUBSTRING(\@crc, $start, $len), 16, 10) AS UNSIGNED))"
244                                                            . ", 10, 16), $len, '0')";
245           13                                 37      }
246                                                   
247                                                      # Replace the placeholder with the expression.  If specified, add a
248                                                      # user-variable optimization so the expression goes in only one of the
249                                                      # slices.  This optimization relies on @crc being '' when the query begins.
250   ***     13    100     66                  122      if ( defined $opt_slice && $opt_slice < @slices ) {
251            7                                 68         $slices[$opt_slice] =~ s/\@crc/\@crc := $query/;
252                                                      }
253                                                      else {
254            6                                 44         map { s/\@crc/$query/ } @slices;
              12                                 70   
255                                                      }
256                                                   
257           13                                108      return join(', ', @slices);
258                                                   }
259                                                   
260                                                   # Generates a checksum query for a given table.  Arguments:
261                                                   # *   table      Struct as returned by TableParser::parse()
262                                                   # *   quoter     Quoter()
263                                                   # *   func       SHA1, MD5, etc
264                                                   # *   sep        (Optional) Separator for CONCAT_WS(); default #
265                                                   # *   cols       (Optional) arrayref of columns to checksum
266                                                   # *   trim       (Optional) wrap VARCHAR in TRIM() for 4.x / 5.x compatibility
267                                                   # *   ignorecols (Optional) arrayref of columns to exclude from checksum
268                                                   sub make_row_checksum {
269           20                   20           231      my ( $self, %args ) = @_;
270           20                                139      my ( $table, $quoter, $func )
271                                                         = @args{ qw(table quoter func) };
272                                                   
273           20           100                  141      my $sep = $args{sep} || '#';
274           20                                 66      $sep =~ s/'//g;
275           20           100                   73      $sep ||= '#';
276                                                   
277                                                      # This allows a simpler grep when building %cols below.
278           20                                 49      my %ignorecols = map { $_ => 1 } @{$args{ignorecols}};
               1                                  5   
              20                                102   
279                                                   
280                                                      # Generate the expression that will turn a row into a checksum.
281                                                      # Choose columns.  Normalize query results: make FLOAT and TIMESTAMP
282                                                      # stringify uniformly.
283           98                                405      my %cols = map { lc($_) => 1 }
              99                                322   
284           11                                 39                 grep { !exists $ignorecols{$_} }
285           20    100                          87                 ($args{cols} ? @{$args{cols}} : @{$table->{cols}});
               9                                 43   
286           98                                468      my @cols =
287                                                         map {
288          228                                691            my $type = $table->{type_for}->{$_};
289           98                                404            my $result = $quoter->quote($_);
290           98    100    100                  897            if ( $type eq 'timestamp' ) {
                    100    100                        
                    100                               
291            6                                 29               $result .= ' + 0';
292                                                            }
293                                                            elsif ( $type =~ m/float|double/ && $args{precision} ) {
294            1                                  5               $result = "ROUND($result, $args{precision})";
295                                                            }
296                                                            elsif ( $type =~ m/varchar/ && $args{trim} ) {
297            1                                  5               $result = "TRIM($result)";
298                                                            }
299           98                                482            $result;
300                                                         }
301                                                         grep {
302           20                                 91            $cols{$_}
303                                                         }
304           20                                 88         @{$table->{cols}};
305                                                   
306           20                                 74      my $query;
307   ***     20    100     66                  162      if ( uc $func ne 'FNV_64' && uc $func ne 'FNV1A_64' ) {
308                                                         # Add a bitmap of which nullable columns are NULL.
309           16                                 47         my @nulls = grep { $cols{$_} } @{$table->{null_cols}};
              78                                247   
              16                                 67   
310           16    100                          67         if ( @nulls ) {
311           24                                 86            my $bitmap = "CONCAT("
312            4                                 19               . join(', ', map { 'ISNULL(' . $quoter->quote($_) . ')' } @nulls)
313                                                               . ")";
314            4                                 21            push @cols, $bitmap;
315                                                         }
316                                                   
317           16    100                         127         $query = @cols > 1
318                                                                ? "$func(CONCAT_WS('$sep', " . join(', ', @cols) . '))'
319                                                                : "$func($cols[0])";
320                                                      }
321                                                      else {
322                                                         # As a special case, FNV1A_64/FNV_64 doesn't need its arguments
323                                                         # concatenated, and doesn't need a bitmap of NULLs.
324            4                                 13         my $fnv_func = uc $func;
325            4                                 25         $query = "$fnv_func(" . join(', ', @cols) . ')';
326                                                      }
327                                                   
328           20                                168      return $query;
329                                                   }
330                                                   
331                                                   # Generates a checksum query for a given table.  Arguments:
332                                                   # *   dbname    Database name
333                                                   # *   tblname   Table name
334                                                   # *   table     Struct as returned by TableParser::parse()
335                                                   # *   quoter    Quoter()
336                                                   # *   algorithm Any of @ALGOS
337                                                   # *   func      SHA1, MD5, etc
338                                                   # *   crc_wid   Width of the string returned by func
339                                                   # *   crc_type  Type of func's result
340                                                   # *   opt_slice (Optional) Which slice gets opt_xor (see make_xor_slices()).
341                                                   # *   cols      (Optional) see make_row_checksum()
342                                                   # *   sep       (Optional) see make_row_checksum()
343                                                   # *   replicate (Optional) generate query to REPLACE into this table.
344                                                   # *   trim      (Optional) see make_row_checksum().
345                                                   # *   buffer    (Optional) Adds SQL_BUFFER_RESULT.
346                                                   sub make_checksum_query {
347           12                   12           234      my ( $self, %args ) = @_;
348           12                                 96      my @arg_names = qw(dbname tblname table quoter algorithm
349                                                           func crc_wid crc_type opt_slice);
350           12                                 47      foreach my $arg( @arg_names ) {
351   ***    108     50                         448         die "You must specify argument $arg" unless exists $args{$arg};
352                                                      }
353           12                                 74      my ( $dbname, $tblname, $table, $quoter, $algorithm,
354                                                           $func, $crc_wid, $crc_type, $opt_slice ) = @args{ @arg_names };
355   ***     12    100     66                  106      die "Invalid or missing checksum algorithm"
356                                                         unless $algorithm && $ALGOS{$algorithm};
357                                                   
358           11                                 26      my $result;
359                                                   
360           11    100                          46      if ( $algorithm eq 'CHECKSUM' ) {
361            1                                  6         return "CHECKSUM TABLE " . $quoter->quote($dbname, $tblname);
362                                                      }
363                                                   
364           10                                 67      my $expr = $self->make_row_checksum(%args);
365                                                   
366           10    100                          47      if ( $algorithm eq 'BIT_XOR' ) {
367                                                         # This checksum algorithm concatenates the columns in each row and
368                                                         # checksums them, then slices this checksum up into 16-character chunks.
369                                                         # It then converts them BIGINTs with the CONV() function, and then
370                                                         # groupwise XORs them to produce an order-independent checksum of the
371                                                         # slice over all the rows.  It then converts these back to base 16 and
372                                                         # puts them back together.  The effect is the same as XORing a very wide
373                                                         # (32 characters = 128 bits for MD5, and SHA1 is even larger) unsigned
374                                                         # integer over all the rows.
375                                                         #
376                                                         # As a special case, integer functions do not need to be sliced.  They
377                                                         # can be fed right into BIT_XOR after a cast to UNSIGNED.
378            5    100                          20         if ( $crc_type =~ m/int$/ ) {
379            3                                 12            $result = "LOWER(CONV(BIT_XOR(CAST($expr AS UNSIGNED)), 10, 16)) AS crc ";
380                                                         }
381                                                         else {
382            2                                 15            my $slices = $self->make_xor_slices( query => $expr, %args );
383            2                                 11            $result = "LOWER(CONCAT($slices)) AS crc ";
384                                                         }
385                                                      }
386                                                      else {
387                                                         # Use an accumulator variable.  This query relies on @crc being '', and
388                                                         # @cnt being 0 when it begins.  It checksums each row, appends it to the
389                                                         # running checksum, and checksums the two together.  In this way it acts
390                                                         # as an accumulator for all the rows.  It then prepends a steadily
391                                                         # increasing number to the left, left-padded with zeroes, so each checksum
392                                                         # taken is stringwise greater than the last.  In this way the MAX()
393                                                         # function can be used to return the last checksum calculated.  @cnt is
394                                                         # not used for a row count, it is only used to make MAX() work correctly.
395                                                         #
396                                                         # As a special case, int funcs must be converted to base 16 so it's a
397                                                         # predictable width (it's also a shorter string, but that's not really
398                                                         # important).
399            5    100                          38         if ( $crc_type =~ m/int$/ ) {
400            3                                 37            $result = "RIGHT(MAX("
401                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
402                                                               . "CONV(CAST($func(CONCAT(\@crc, $expr)) AS UNSIGNED), 10, 16))"
403                                                               . "), $crc_wid) AS crc ";
404                                                         }
405                                                         else {
406            2                                 21            $result = "RIGHT(MAX("
407                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
408                                                               . "$func(CONCAT(\@crc, $expr)))"
409                                                               . "), $crc_wid) AS crc ";
410                                                         }
411                                                      }
412           10    100                          39      if ( $args{replicate} ) {
413            2                                 16         $result = "REPLACE /*PROGRESS_COMMENT*/ INTO $args{replicate} "
414                                                            . "(db, tbl, chunk, boundaries, this_cnt, this_crc) "
415                                                            . "SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, $result";
416                                                      }
417                                                      else {
418            8    100                          46         $result = "SELECT "
419                                                            . ($args{buffer} ? 'SQL_BUFFER_RESULT ' : '')
420                                                            . "/*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, $result";
421                                                      }
422           10                                 93      return $result . "FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/";
423                                                   }
424                                                   
425                                                   # Queries the replication table for chunks that differ from the master's data.
426                                                   sub find_replication_differences {
427   ***      0                    0                    my ( $self, $dbh, $table ) = @_;
428                                                   
429   ***      0                                         (my $sql = <<"   EOF") =~ s/\s+/ /gm;
430                                                         SELECT db, tbl, chunk, boundaries,
431                                                            COALESCE(this_cnt-master_cnt, 0) AS cnt_diff,
432                                                            COALESCE(
433                                                               this_crc <> master_crc OR ISNULL(master_crc) <> ISNULL(this_crc),
434                                                               0
435                                                            ) AS crc_diff,
436                                                            this_cnt, master_cnt, this_crc, master_crc
437                                                         FROM $table
438                                                         WHERE master_cnt <> this_cnt OR master_crc <> this_crc
439                                                         OR ISNULL(master_crc) <> ISNULL(this_crc)
440                                                      EOF
441                                                   
442   ***      0                                         MKDEBUG && _d($sql);
443   ***      0                                         my $diffs = $dbh->selectall_arrayref($sql, { Slice => {} });
444   ***      0                                         return @$diffs;
445                                                   }
446                                                   
447                                                   sub _d {
448   ***      0                    0                    my ($package, undef, $line) = caller 0;
449   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
450   ***      0                                              map { defined $_ ? $_ : 'undef' }
451                                                           @_;
452   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
453                                                   }
454                                                   
455                                                   1;
456                                                   
457                                                   # ###########################################################################
458                                                   # End TableChecksum package
459                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
52           100     42     46   $comp & 1 ? :
63    ***      0      0      0   if (uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64')
84           100      1      1   if ($type eq 'bigint' and $length < 20)
105          100      1     11   if $alg and not $ALGOS{$alg}
109          100      5      6   if ($args{'where'} or $args{'chunk'} or $args{'replicate'} or not $vp->version_ge($dbh, '4.1.1'))
119          100      2      9   if (not $vp->version_ge($dbh, '4.1.1'))
125          100      4      7   if ($alg and grep {$_ eq $alg;} @choices)
133          100      1      6   if ($args{'count'} and grep {$_ ne 'CHECKSUM';} @choices)
151          100      2      1   if ($args{'func'})
164          100      1      3   if ($EVAL_ERROR and $EVAL_ERROR =~ /failed: (.*?) at \S+ line/)
170   ***     50      0      3   unless $result
186   ***     50      0      2   if $func =~ /^(?:FNV1A_64|FNV_64|CRC32)$/i
193   ***     50      0      2   length $unsliced < 16 ? :
206          100      3      2   if ($sliced ne $unsliced)
213   ***     50      2      0   if ($sliced eq $unsliced) { }
238          100     16     13   if ($len > 16)
250          100      7      6   if (defined $opt_slice and $opt_slice < @slices) { }
285          100     11      9   $args{'cols'} ? :
290          100      6     92   if ($type eq 'timestamp') { }
             100      1     91   elsif ($type =~ /float|double/ and $args{'precision'}) { }
             100      1     90   elsif ($type =~ /varchar/ and $args{'trim'}) { }
307          100     16      4   if (uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64') { }
310          100      4     12   if (@nulls)
317          100     10      6   @cols > 1 ? :
351   ***     50      0    108   unless exists $args{$arg}
355          100      1     11   unless $algorithm and $ALGOS{$algorithm}
360          100      1     10   if ($algorithm eq 'CHECKSUM')
366          100      5      5   if ($algorithm eq 'BIT_XOR') { }
378          100      3      2   if ($crc_type =~ /int$/) { }
399          100      3      2   if ($crc_type =~ /int$/) { }
412          100      2      8   if ($args{'replicate'}) { }
418          100      2      6   $args{'buffer'} ? :
449   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
63    ***      0      0      0      0   uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64'
84    ***     66      1      0      1   $type eq 'bigint' and $length < 20
105          100      2      9      1   $alg and not $ALGOS{$alg}
125          100      2      5      4   $alg and grep {$_ eq $alg;} @choices
133   ***     66      6      0      1   $args{'count'} and grep {$_ ne 'CHECKSUM';} @choices
144   ***     66      0      1      2   $ALGOS{$algorithm} && $ALGOS{$algorithm}{'hash'}
155   ***     66      0      3      1   @funcs and not $result
164   ***     66      3      0      1   $EVAL_ERROR and $EVAL_ERROR =~ /failed: (.*?) at \S+ line/
195   ***     66      0      2      3   $start < $crc_wid and $sliced ne $unsliced
250   ***     66      6      0      7   defined $opt_slice and $opt_slice < @slices
290          100     90      1      1   $type =~ /float|double/ and $args{'precision'}
             100     82      8      1   $type =~ /varchar/ and $args{'trim'}
307   ***     66      4      0     16   uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64'
355   ***     66      0      1     11   $algorithm and $ALGOS{$algorithm}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
273          100      4     16   $args{'sep'} || '#'
275          100     19      1   $sep ||= '#'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
109          100      1      1      9   $args{'where'} or $args{'chunk'}
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
best_algorithm                  12 /home/daniel/dev/maatkit/common/TableChecksum.pm:102
choose_hash_func                 3 /home/daniel/dev/maatkit/common/TableChecksum.pm:149
crc32                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:46 
get_crc_type                     2 /home/daniel/dev/maatkit/common/TableChecksum.pm:74 
is_hash_algorithm                3 /home/daniel/dev/maatkit/common/TableChecksum.pm:143
make_checksum_query             12 /home/daniel/dev/maatkit/common/TableChecksum.pm:347
make_row_checksum               20 /home/daniel/dev/maatkit/common/TableChecksum.pm:269
make_xor_slices                 13 /home/daniel/dev/maatkit/common/TableChecksum.pm:230
new                              1 /home/daniel/dev/maatkit/common/TableChecksum.pm:39 
optimize_xor                     2 /home/daniel/dev/maatkit/common/TableChecksum.pm:183

Uncovered Subroutines
---------------------

Subroutine                   Count Location                                            
---------------------------- ----- ----------------------------------------------------
_d                               0 /home/daniel/dev/maatkit/common/TableChecksum.pm:448
find_replication_differences     0 /home/daniel/dev/maatkit/common/TableChecksum.pm:427
get_crc_wid                      0 /home/daniel/dev/maatkit/common/TableChecksum.pm:61 


