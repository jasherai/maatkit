---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TableChecksum.pm   90.3   84.3   78.2   83.3    n/a  100.0   86.8
Total                          90.3   84.3   78.2   83.3    n/a  100.0   86.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableChecksum.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 21:18:17 2009
Finish:       Fri Sep 25 21:18:18 2009

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
18                                                    # TableChecksum package $Revision: 4757 $
19                                                    # ###########################################################################
20                                                    package TableChecksum;
21                                                    
22             1                    1             8   use strict;
               1                                  3   
               1                                  6   
23             1                    1           107   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25             1                    1             7   use List::Util qw(max);
               1                                  2   
               1                                 11   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
28                                                    
29                                                    # BXT_XOR is actually faster than ACCUM as long as the user-variable
30                                                    # optimization can be used.  I've never seen a case where it can't be.
31                                                    our %ALGOS = (
32                                                       CHECKSUM => { pref => 0, hash => 0 },
33                                                       BIT_XOR  => { pref => 2, hash => 1 },
34                                                       ACCUM    => { pref => 3, hash => 1 },
35                                                    );
36                                                    
37                                                    sub new {
38             1                    1            17      my ( $class, %args ) = @_;
39             1                                  5      foreach my $arg ( qw(Quoter VersionParser) ) {
40    ***      2     50                          11         die "I need a $arg argument" unless defined $args{$arg};
41                                                       }
42             1                                  6      my $self = { %args };
43             1                                 11      return bless $self, $class;
44                                                    }
45                                                    
46                                                    # Perl implementation of CRC32, ripped off from Digest::Crc32.  The results
47                                                    # ought to match what you get from any standard CRC32 implementation, such as
48                                                    # that inside MySQL.
49                                                    sub crc32 {
50             1                    1             5      my ( $self, $string ) = @_;
51             1                                  3      my $poly = 0xEDB88320;
52             1                                  3      my $crc  = 0xFFFFFFFF;
53             1                                  8      foreach my $char ( split(//, $string) ) {
54            11                                 35         my $comp = ($crc ^ ord($char)) & 0xFF;
55            11                                 34         for ( 1 .. 8 ) {
56            88    100                         351            $comp = $comp & 1 ? $poly ^ ($comp >> 1) : $comp >> 1;
57                                                          }
58            11                                 42         $crc = (($crc >> 8) & 0x00FFFFFF) ^ $comp;
59                                                       }
60             1                                  7      return $crc ^ 0xFFFFFFFF;
61                                                    }
62                                                    
63                                                    # Returns how wide/long, in characters, a CRC function is.
64                                                    sub get_crc_wid {
65    ***      0                    0             0      my ( $self, $dbh, $func ) = @_;
66    ***      0                                  0      my $crc_wid = 16;
67    ***      0      0      0                    0      if ( uc $func ne 'FNV_64' && uc $func ne 'FNV1A_64' ) {
68    ***      0                                  0         eval {
69    ***      0                                  0            my ($val) = $dbh->selectrow_array("SELECT $func('a')");
70    ***      0                                  0            $crc_wid = max(16, length($val));
71                                                          };
72                                                       }
73    ***      0                                  0      return $crc_wid;
74                                                    }
75                                                    
76                                                    # Returns a CRC function's MySQL type as a list of (type, length).
77                                                    sub get_crc_type {
78             2                    2            11      my ( $self, $dbh, $func ) = @_;
79             2                                  7      my $type   = '';
80             2                                  6      my $length = 0;
81             2                                  9      my $sql    = "SELECT $func('a')";
82             2                                  7      my $sth    = $dbh->prepare($sql);
83             2                                 12      eval {
84             2                                473         $sth->execute();
85             2                                 43         $type   = $sth->{mysql_type_name}->[0];
86             2                                 13         $length = $sth->{mysql_length}->[0];
87             2                                  9         MKDEBUG && _d($sql, $type, $length);
88    ***      2    100     66                   21         if ( $type eq 'bigint' && $length < 20 ) {
89             1                                  3            $type = 'int';
90                                                          }
91                                                       };
92             2                                 18      $sth->finish;
93             2                                  6      MKDEBUG && _d('crc_type:', $type, 'length:', $length);
94             2                                 47      return ($type, $length);
95                                                    }
96                                                    
97                                                    # Arguments:
98                                                    #   algorithm   (optional) One of CHECKSUM, ACCUM, BIT_XOR
99                                                    #   dbh         DB handle
100                                                   #   where       bool: whether user wants a WHERE clause applied
101                                                   #   chunk       bool: whether user wants to checksum in chunks
102                                                   #   replicate   bool: whether user wants to do via replication
103                                                   #   count       bool: whether user wants a row count too
104                                                   sub best_algorithm {
105           12                   12           173      my ( $self, %args ) = @_;
106           12                                 57      my ( $alg, $dbh ) = @args{ qw(algorithm dbh) };
107           12                                 43      my $vp = $self->{VersionParser};
108           12                                 21      my @choices = sort { $ALGOS{$a}->{pref} <=> $ALGOS{$b}->{pref} } keys %ALGOS;
              36                                158   
109           12    100    100                  120      die "Invalid checksum algorithm $alg"
110                                                         if $alg && !$ALGOS{$alg};
111                                                   
112                                                      # CHECKSUM is eliminated by lots of things...
113           11    100    100                  145      if (
                           100                        
                           100                        
114                                                         $args{where} || $args{chunk}        # CHECKSUM does whole table
115                                                         || $args{replicate}                 # CHECKSUM can't do INSERT.. SELECT
116                                                         || !$vp->version_ge($dbh, '4.1.1')) # CHECKSUM doesn't exist
117                                                      {
118            5                                 13         MKDEBUG && _d('Cannot use CHECKSUM algorithm');
119            5                                 15         @choices = grep { $_ ne 'CHECKSUM' } @choices;
              15                                 57   
120                                                      }
121                                                   
122                                                      # BIT_XOR isn't available till 4.1.1 either
123           11    100                          45      if ( !$vp->version_ge($dbh, '4.1.1') ) {
124            2                                  5         MKDEBUG && _d('Cannot use BIT_XOR algorithm because MySQL < 4.1.1');
125            2                                  6         @choices = grep { $_ ne 'BIT_XOR' } @choices;
               4                                 15   
126                                                      }
127                                                   
128                                                      # Choose the best (fastest) among the remaining choices.
129           11    100    100                   55      if ( $alg && grep { $_ eq $alg } @choices ) {
              20                                 93   
130                                                         # Honor explicit choices.
131            4                                  8         MKDEBUG && _d('User requested', $alg, 'algorithm');
132            4                                 28         return $alg;
133                                                      }
134                                                   
135                                                      # If the user wants a count, prefer something other than CHECKSUM, because it
136                                                      # requires an extra query for the count.
137   ***      7    100     66                   56      if ( $args{count} && grep { $_ ne 'CHECKSUM' } @choices ) {
               3                                 13   
138            1                                  3         MKDEBUG && _d('Not using CHECKSUM algorithm because COUNT desired');
139            1                                  4         @choices = grep { $_ ne 'CHECKSUM' } @choices;
               3                                 12   
140                                                      }
141                                                   
142            7                                 18      MKDEBUG && _d('Algorithms, in order:', @choices);
143            7                                 44      return $choices[0];
144                                                   }
145                                                   
146                                                   sub is_hash_algorithm {
147            3                    3            15      my ( $self, $algorithm ) = @_;
148   ***      3            66                   40      return $ALGOS{$algorithm} && $ALGOS{$algorithm}->{hash};
149                                                   }
150                                                   
151                                                   # Picks a hash function, in order of speed.
152                                                   # Arguments:
153                                                   #   * dbh
154                                                   #   * function  (optional) Preferred function: SHA1, MD5, etc.
155                                                   sub choose_hash_func {
156            3                    3            19      my ( $self, %args ) = @_;
157            3                                 17      my @funcs = qw(CRC32 FNV1A_64 FNV_64 MD5 SHA1);
158            3    100                          13      if ( $args{function} ) {
159            2                                  9         unshift @funcs, $args{function};
160                                                      }
161            3                                  8      my ($result, $error);
162   ***      3            66                    8      do {
163            4                                 10         my $func;
164            4                                 10         eval {
165            4                                 12            $func = shift(@funcs);
166            4                                 15            my $sql = "SELECT $func('test-string')";
167            4                                  8            MKDEBUG && _d($sql);
168            4                                594            $args{dbh}->do($sql);
169            3                                 13            $result = $func;
170                                                         };
171   ***      4    100     66                   65         if ( $EVAL_ERROR && $EVAL_ERROR =~ m/failed: (.*?) at \S+ line/ ) {
172            1                                  8            $error .= qq{$func cannot be used because "$1"\n};
173            1                                  9            MKDEBUG && _d($func, 'cannot be used because', $1);
174                                                         }
175                                                      } while ( @funcs && !$result );
176                                                   
177   ***      3     50                          13      die $error unless $result;
178            3                                  6      MKDEBUG && _d('Chosen hash func:', $result);
179            3                                 36      return $result;
180                                                   }
181                                                   
182                                                   # Figure out which slice in a sliced BIT_XOR checksum should have the actual
183                                                   # concat-columns-and-checksum, and which should just get variable references.
184                                                   # Returns the slice.  I'm really not sure if this code is needed.  It always
185                                                   # seems the last slice is the one that works.  But I'd rather be paranoid.
186                                                      # TODO: this function needs a hint to know when a function returns an
187                                                      # integer.  CRC32 is an example.  In these cases no optimization or slicing
188                                                      # is necessary.
189                                                   sub optimize_xor {
190            2                    2            14      my ( $self, %args ) = @_;
191            2                                 11      my ($dbh, $func) = @args{qw(dbh function)};
192                                                   
193   ***      2     50                          10      die "$func never needs the BIT_XOR optimization"
194                                                         if $func =~ m/^(?:FNV1A_64|FNV_64|CRC32)$/i;
195                                                   
196            2                                  6      my $opt_slice = 0;
197            2                                  5      my $unsliced  = uc $dbh->selectall_arrayref("SELECT $func('a')")->[0]->[0];
198            2                               5691      my $sliced    = '';
199            2                                  7      my $start     = 1;
200   ***      2     50                          15      my $crc_wid   = length($unsliced) < 16 ? 16 : length($unsliced);
201                                                   
202   ***      2            66                    7      do { # Try different positions till sliced result equals non-sliced.
203            5                                 10         MKDEBUG && _d('Trying slice', $opt_slice);
204            5                                626         $dbh->do('SET @crc := "", @cnt := 0');
205            5                                 42         my $slices = $self->make_xor_slices(
206                                                            query     => "\@crc := $func('a')",
207                                                            crc_wid   => $crc_wid,
208                                                            opt_slice => $opt_slice,
209                                                         );
210                                                   
211            5                                 21         my $sql = "SELECT CONCAT($slices) AS TEST FROM (SELECT NULL) AS x";
212            5                                 12         $sliced = ($dbh->selectrow_array($sql))[0];
213            5    100                        1340         if ( $sliced ne $unsliced ) {
214            3                                  9            MKDEBUG && _d('Slice', $opt_slice, 'does not work');
215            3                                  8            $start += 16;
216            3                                 37            ++$opt_slice;
217                                                         }
218                                                      } while ( $start < $crc_wid && $sliced ne $unsliced );
219                                                   
220   ***      2     50                          10      if ( $sliced eq $unsliced ) {
221            2                                  6         MKDEBUG && _d('Slice', $opt_slice, 'works');
222            2                                 20         return $opt_slice;
223                                                      }
224                                                      else {
225   ***      0                                  0         MKDEBUG && _d('No slice works');
226   ***      0                                  0         return undef;
227                                                      }
228                                                   }
229                                                   
230                                                   # Returns an expression that will do a bitwise XOR over a very wide integer,
231                                                   # such as that returned by SHA1, which is too large to just put into BIT_XOR().
232                                                   # $query is an expression that returns a row's checksum, $crc_wid is the width
233                                                   # of that expression in characters.  If the opt_slice argument is given, use a
234                                                   # variable to avoid calling the $query expression multiple times.  The variable
235                                                   # goes in slice $opt_slice.
236                                                   # Arguments:
237                                                   #   * query
238                                                   #   * crc_wid
239                                                   #   * opt_slice  (optional)
240                                                   sub make_xor_slices {
241           13                   13           105      my ( $self, %args ) = @_;
242           13                                 60      foreach my $arg ( qw(query crc_wid) ) {
243   ***     26     50                         168         die "I need a $arg argument" unless defined $args{$arg};
244                                                      }
245           13                                 71      my ( $query, $crc_wid, $opt_slice ) = @args{qw(query crc_wid opt_slice)};
246                                                   
247                                                      # Create a series of slices with @crc as a placeholder.
248           13                                 32      my @slices;
249                                                      for ( my $start = 1; $start <= $crc_wid; $start += 16 ) {
250           29                                 99         my $len = $crc_wid - $start + 1;
251           29    100                         106         if ( $len > 16 ) {
252           16                                 46            $len = 16;
253                                                         }
254           29                                253         push @slices,
255                                                            "LPAD(CONV(BIT_XOR("
256                                                            . "CAST(CONV(SUBSTRING(\@crc, $start, $len), 16, 10) AS UNSIGNED))"
257                                                            . ", 10, 16), $len, '0')";
258           13                                 39      }
259                                                   
260                                                      # Replace the placeholder with the expression.  If specified, add a
261                                                      # user-variable optimization so the expression goes in only one of the
262                                                      # slices.  This optimization relies on @crc being '' when the query begins.
263   ***     13    100     66                   93      if ( defined $opt_slice && $opt_slice < @slices ) {
264            7                                 74         $slices[$opt_slice] =~ s/\@crc/\@crc := $query/;
265                                                      }
266                                                      else {
267            6                                 20         map { s/\@crc/$query/ } @slices;
              12                                 65   
268                                                      }
269                                                   
270           13                                114      return join(', ', @slices);
271                                                   }
272                                                   
273                                                   # Generates a checksum query for a given table.  Arguments:
274                                                   # *   tbl_struct  Struct as returned by TableParser::parse()
275                                                   # *   function    SHA1, MD5, etc
276                                                   # *   sep         (optional) Separator for CONCAT_WS(); default #
277                                                   # *   cols        (optional) arrayref of columns to checksum
278                                                   # *   trim        (optional) wrap VARCHAR in TRIM() for 4.x / 5.x compatibility
279                                                   # *   ignorecols  (optional) arrayref of columns to exclude from checksum
280                                                   sub make_row_checksum {
281           20                   20           258      my ( $self, %args ) = @_;
282           20                                114      my ( $tbl_struct, $func ) = @args{ qw(tbl_struct function) };
283           20                                 67      my $q = $self->{Quoter};
284                                                   
285           20           100                  178      my $sep = $args{sep} || '#';
286           20                                 70      $sep =~ s/'//g;
287           20           100                   69      $sep ||= '#';
288                                                   
289                                                      # This allows a simpler grep when building %cols below.
290           20                                 60      my %ignorecols = map { $_ => 1 } @{$args{ignorecols}};
               1                                  6   
              20                                 96   
291                                                   
292                                                      # Generate the expression that will turn a row into a checksum.
293                                                      # Choose columns.  Normalize query results: make FLOAT and TIMESTAMP
294                                                      # stringify uniformly.
295           98                                452      my %cols = map { lc($_) => 1 }
              99                                319   
296           11                                 42                 grep { !exists $ignorecols{$_} }
297           20    100                          89                 ($args{cols} ? @{$args{cols}} : @{$tbl_struct->{cols}});
               9                                 43   
298           98                                369      my @cols =
299                                                         map {
300          228                                691            my $type = $tbl_struct->{type_for}->{$_};
301           98                                362            my $result = $q->quote($_);
302           98    100    100                  871            if ( $type eq 'timestamp' ) {
                    100    100                        
                    100                               
303            6                                 19               $result .= ' + 0';
304                                                            }
305                                                            elsif ( $type =~ m/float|double/ && $args{float_precision} ) {
306            1                                  7               $result = "ROUND($result, $args{float_precision})";
307                                                            }
308                                                            elsif ( $type =~ m/varchar/ && $args{trim} ) {
309            1                                  6               $result = "TRIM($result)";
310                                                            }
311           98                                373            $result;
312                                                         }
313                                                         grep {
314           20                                 89            $cols{$_}
315                                                         }
316           20                                 83         @{$tbl_struct->{cols}};
317                                                   
318           20                                 70      my $query;
319   ***     20    100     66                  156      if ( uc $func ne 'FNV_64' && uc $func ne 'FNV1A_64' ) {
320                                                         # Add a bitmap of which nullable columns are NULL.
321           16                                 44         my @nulls = grep { $cols{$_} } @{$tbl_struct->{null_cols}};
              78                                251   
              16                                 79   
322           16    100                          67         if ( @nulls ) {
323           24                                 92            my $bitmap = "CONCAT("
324            4                                 14               . join(', ', map { 'ISNULL(' . $q->quote($_) . ')' } @nulls)
325                                                               . ")";
326            4                                 19            push @cols, $bitmap;
327                                                         }
328                                                   
329           16    100                         122         $query = @cols > 1
330                                                                ? "$func(CONCAT_WS('$sep', " . join(', ', @cols) . '))'
331                                                                : "$func($cols[0])";
332                                                      }
333                                                      else {
334                                                         # As a special case, FNV1A_64/FNV_64 doesn't need its arguments
335                                                         # concatenated, and doesn't need a bitmap of NULLs.
336            4                                 14         my $fnv_func = uc $func;
337            4                                 24         $query = "$fnv_func(" . join(', ', @cols) . ')';
338                                                      }
339                                                   
340           20                                200      return $query;
341                                                   }
342                                                   
343                                                   # Generates a checksum query for a given table.  Arguments:
344                                                   # *   db          Database name
345                                                   # *   tbl         Table name
346                                                   # *   tbl_struct  Struct as returned by TableParser::parse()
347                                                   # *   algorithm   Any of @ALGOS
348                                                   # *   function    SHA1, MD5, etc
349                                                   # *   crc_wid     Width of the string returned by function
350                                                   # *   crc_type    Type of function's result
351                                                   # *   opt_slice   (optional) Which slice gets opt_xor (see make_xor_slices()).
352                                                   # *   cols        (optional) see make_row_checksum()
353                                                   # *   sep         (optional) see make_row_checksum()
354                                                   # *   replicate   (optional) generate query to REPLACE into this table.
355                                                   # *   trim        (optional) see make_row_checksum().
356                                                   # *   buffer      (optional) Adds SQL_BUFFER_RESULT.
357                                                   sub make_checksum_query {
358           12                   12           230      my ( $self, %args ) = @_;
359           12                                 84      my @required_args = qw(db tbl tbl_struct algorithm function crc_wid crc_type);
360           12                                 57      foreach my $arg( @required_args ) {
361   ***     84     50                         350         die "I need a $arg argument" unless $args{$arg};
362                                                      }
363           12                                 83      my ( $db, $tbl, $tbl_struct, $algorithm,
364                                                           $func, $crc_wid, $crc_type) = @args{@required_args};
365           12                                 44      my $q = $self->{Quoter};
366           12                                 29      my $result;
367                                                   
368   ***     12    100     66                  109      die "Invalid or missing checksum algorithm"
369                                                         unless $algorithm && $ALGOS{$algorithm};
370                                                   
371           11    100                          45      if ( $algorithm eq 'CHECKSUM' ) {
372            1                                  5         return "CHECKSUM TABLE " . $q->quote($db, $tbl);
373                                                      }
374                                                   
375           10                                 78      my $expr = $self->make_row_checksum(%args);
376                                                   
377           10    100                          48      if ( $algorithm eq 'BIT_XOR' ) {
378                                                         # This checksum algorithm concatenates the columns in each row and
379                                                         # checksums them, then slices this checksum up into 16-character chunks.
380                                                         # It then converts them BIGINTs with the CONV() function, and then
381                                                         # groupwise XORs them to produce an order-independent checksum of the
382                                                         # slice over all the rows.  It then converts these back to base 16 and
383                                                         # puts them back together.  The effect is the same as XORing a very wide
384                                                         # (32 characters = 128 bits for MD5, and SHA1 is even larger) unsigned
385                                                         # integer over all the rows.
386                                                         #
387                                                         # As a special case, integer functions do not need to be sliced.  They
388                                                         # can be fed right into BIT_XOR after a cast to UNSIGNED.
389            5    100                          22         if ( $crc_type =~ m/int$/ ) {
390            3                                 12            $result = "LOWER(CONV(BIT_XOR(CAST($expr AS UNSIGNED)), 10, 16)) AS crc ";
391                                                         }
392                                                         else {
393            2                                 14            my $slices = $self->make_xor_slices( query => $expr, %args );
394            2                                 11            $result = "LOWER(CONCAT($slices)) AS crc ";
395                                                         }
396                                                      }
397                                                      else {
398                                                         # Use an accumulator variable.  This query relies on @crc being '', and
399                                                         # @cnt being 0 when it begins.  It checksums each row, appends it to the
400                                                         # running checksum, and checksums the two together.  In this way it acts
401                                                         # as an accumulator for all the rows.  It then prepends a steadily
402                                                         # increasing number to the left, left-padded with zeroes, so each checksum
403                                                         # taken is stringwise greater than the last.  In this way the MAX()
404                                                         # function can be used to return the last checksum calculated.  @cnt is
405                                                         # not used for a row count, it is only used to make MAX() work correctly.
406                                                         #
407                                                         # As a special case, int funcs must be converted to base 16 so it's a
408                                                         # predictable width (it's also a shorter string, but that's not really
409                                                         # important).
410            5    100                          28         if ( $crc_type =~ m/int$/ ) {
411            3                                 27            $result = "RIGHT(MAX("
412                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
413                                                               . "CONV(CAST($func(CONCAT(\@crc, $expr)) AS UNSIGNED), 10, 16))"
414                                                               . "), $crc_wid) AS crc ";
415                                                         }
416                                                         else {
417            2                                 14            $result = "RIGHT(MAX("
418                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
419                                                               . "$func(CONCAT(\@crc, $expr)))"
420                                                               . "), $crc_wid) AS crc ";
421                                                         }
422                                                      }
423           10    100                          56      if ( $args{replicate} ) {
424            2                                 23         $result = "REPLACE /*PROGRESS_COMMENT*/ INTO $args{replicate} "
425                                                            . "(db, tbl, chunk, boundaries, this_cnt, this_crc) "
426                                                            . "SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, $result";
427                                                      }
428                                                      else {
429            8    100                          50         $result = "SELECT "
430                                                            . ($args{buffer} ? 'SQL_BUFFER_RESULT ' : '')
431                                                            . "/*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, $result";
432                                                      }
433           10                                 90      return $result . "FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/";
434                                                   }
435                                                   
436                                                   # Queries the replication table for chunks that differ from the master's data.
437                                                   sub find_replication_differences {
438   ***      0                    0                    my ( $self, $dbh, $table ) = @_;
439                                                   
440   ***      0                                         (my $sql = <<"   EOF") =~ s/\s+/ /gm;
441                                                         SELECT db, tbl, chunk, boundaries,
442                                                            COALESCE(this_cnt-master_cnt, 0) AS cnt_diff,
443                                                            COALESCE(
444                                                               this_crc <> master_crc OR ISNULL(master_crc) <> ISNULL(this_crc),
445                                                               0
446                                                            ) AS crc_diff,
447                                                            this_cnt, master_cnt, this_crc, master_crc
448                                                         FROM $table
449                                                         WHERE master_cnt <> this_cnt OR master_crc <> this_crc
450                                                         OR ISNULL(master_crc) <> ISNULL(this_crc)
451                                                      EOF
452                                                   
453   ***      0                                         MKDEBUG && _d($sql);
454   ***      0                                         my $diffs = $dbh->selectall_arrayref($sql, { Slice => {} });
455   ***      0                                         return @$diffs;
456                                                   }
457                                                   
458                                                   sub _d {
459   ***      0                    0                    my ($package, undef, $line) = caller 0;
460   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
461   ***      0                                              map { defined $_ ? $_ : 'undef' }
462                                                           @_;
463   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
464                                                   }
465                                                   
466                                                   1;
467                                                   
468                                                   # ###########################################################################
469                                                   # End TableChecksum package
470                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
40    ***     50      0      2   unless defined $args{$arg}
56           100     42     46   $comp & 1 ? :
67    ***      0      0      0   if (uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64')
88           100      1      1   if ($type eq 'bigint' and $length < 20)
109          100      1     11   if $alg and not $ALGOS{$alg}
113          100      5      6   if ($args{'where'} or $args{'chunk'} or $args{'replicate'} or not $vp->version_ge($dbh, '4.1.1'))
123          100      2      9   if (not $vp->version_ge($dbh, '4.1.1'))
129          100      4      7   if ($alg and grep {$_ eq $alg;} @choices)
137          100      1      6   if ($args{'count'} and grep {$_ ne 'CHECKSUM';} @choices)
158          100      2      1   if ($args{'function'})
171          100      1      3   if ($EVAL_ERROR and $EVAL_ERROR =~ /failed: (.*?) at \S+ line/)
177   ***     50      0      3   unless $result
193   ***     50      0      2   if $func =~ /^(?:FNV1A_64|FNV_64|CRC32)$/i
200   ***     50      0      2   length $unsliced < 16 ? :
213          100      3      2   if ($sliced ne $unsliced)
220   ***     50      2      0   if ($sliced eq $unsliced) { }
243   ***     50      0     26   unless defined $args{$arg}
251          100     16     13   if ($len > 16)
263          100      7      6   if (defined $opt_slice and $opt_slice < @slices) { }
297          100     11      9   $args{'cols'} ? :
302          100      6     92   if ($type eq 'timestamp') { }
             100      1     91   elsif ($type =~ /float|double/ and $args{'float_precision'}) { }
             100      1     90   elsif ($type =~ /varchar/ and $args{'trim'}) { }
319          100     16      4   if (uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64') { }
322          100      4     12   if (@nulls)
329          100     10      6   @cols > 1 ? :
361   ***     50      0     84   unless $args{$arg}
368          100      1     11   unless $algorithm and $ALGOS{$algorithm}
371          100      1     10   if ($algorithm eq 'CHECKSUM')
377          100      5      5   if ($algorithm eq 'BIT_XOR') { }
389          100      3      2   if ($crc_type =~ /int$/) { }
410          100      3      2   if ($crc_type =~ /int$/) { }
423          100      2      8   if ($args{'replicate'}) { }
429          100      2      6   $args{'buffer'} ? :
460   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
67    ***      0      0      0      0   uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64'
88    ***     66      1      0      1   $type eq 'bigint' and $length < 20
109          100      2      9      1   $alg and not $ALGOS{$alg}
129          100      2      5      4   $alg and grep {$_ eq $alg;} @choices
137   ***     66      6      0      1   $args{'count'} and grep {$_ ne 'CHECKSUM';} @choices
148   ***     66      0      1      2   $ALGOS{$algorithm} && $ALGOS{$algorithm}{'hash'}
162   ***     66      0      3      1   @funcs and not $result
171   ***     66      3      0      1   $EVAL_ERROR and $EVAL_ERROR =~ /failed: (.*?) at \S+ line/
202   ***     66      0      2      3   $start < $crc_wid and $sliced ne $unsliced
263   ***     66      6      0      7   defined $opt_slice and $opt_slice < @slices
302          100     90      1      1   $type =~ /float|double/ and $args{'float_precision'}
             100     82      8      1   $type =~ /varchar/ and $args{'trim'}
319   ***     66      4      0     16   uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64'
368   ***     66      0      1     11   $algorithm and $ALGOS{$algorithm}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
285          100      4     16   $args{'sep'} || '#'
287          100     19      1   $sep ||= '#'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
113          100      1      1      9   $args{'where'} or $args{'chunk'}
             100      2      1      8   $args{'where'} or $args{'chunk'} or $args{'replicate'}
             100      3      2      6   $args{'where'} or $args{'chunk'} or $args{'replicate'} or not $vp->version_ge($dbh, '4.1.1')


Covered Subroutines
-------------------

Subroutine                   Count Location                                            
---------------------------- ----- ----------------------------------------------------
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:22 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:23 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:24 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:25 
BEGIN                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:27 
best_algorithm                  12 /home/daniel/dev/maatkit/common/TableChecksum.pm:105
choose_hash_func                 3 /home/daniel/dev/maatkit/common/TableChecksum.pm:156
crc32                            1 /home/daniel/dev/maatkit/common/TableChecksum.pm:50 
get_crc_type                     2 /home/daniel/dev/maatkit/common/TableChecksum.pm:78 
is_hash_algorithm                3 /home/daniel/dev/maatkit/common/TableChecksum.pm:147
make_checksum_query             12 /home/daniel/dev/maatkit/common/TableChecksum.pm:358
make_row_checksum               20 /home/daniel/dev/maatkit/common/TableChecksum.pm:281
make_xor_slices                 13 /home/daniel/dev/maatkit/common/TableChecksum.pm:241
new                              1 /home/daniel/dev/maatkit/common/TableChecksum.pm:38 
optimize_xor                     2 /home/daniel/dev/maatkit/common/TableChecksum.pm:190

Uncovered Subroutines
---------------------

Subroutine                   Count Location                                            
---------------------------- ----- ----------------------------------------------------
_d                               0 /home/daniel/dev/maatkit/common/TableChecksum.pm:459
find_replication_differences     0 /home/daniel/dev/maatkit/common/TableChecksum.pm:438
get_crc_wid                      0 /home/daniel/dev/maatkit/common/TableChecksum.pm:65 


