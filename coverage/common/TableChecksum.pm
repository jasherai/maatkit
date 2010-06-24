---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TableChecksum.pm   90.8   85.9   77.2   83.3    0.0   17.8   84.6
TableChecksum.t               100.0   50.0   33.3  100.0    n/a   82.2   97.0
Total                          93.9   84.1   75.0   90.9    0.0  100.0   87.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:48:52 2010
Finish:       Thu Jun 24 19:48:52 2010

Run:          TableChecksum.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:48:54 2010
Finish:       Thu Jun 24 19:48:54 2010

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
18                                                    # TableChecksum package $Revision: 6511 $
19                                                    # ###########################################################################
20                                                    package TableChecksum;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                 15   
25             1                    1             6   use List::Util qw(max);
               1                                  4   
               1                                 11   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  6   
               1                                 20   
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
38    ***      1                    1      0      7      my ( $class, %args ) = @_;
39             1                                  5      foreach my $arg ( qw(Quoter VersionParser) ) {
40    ***      2     50                          13         die "I need a $arg argument" unless defined $args{$arg};
41                                                       }
42             1                                  5      my $self = { %args };
43             1                                 11      return bless $self, $class;
44                                                    }
45                                                    
46                                                    # Perl implementation of CRC32, ripped off from Digest::Crc32.  The results
47                                                    # ought to match what you get from any standard CRC32 implementation, such as
48                                                    # that inside MySQL.
49                                                    sub crc32 {
50    ***      1                    1      0      5      my ( $self, $string ) = @_;
51             1                                  3      my $poly = 0xEDB88320;
52             1                                  4      my $crc  = 0xFFFFFFFF;
53             1                                  6      foreach my $char ( split(//, $string) ) {
54            11                                 36         my $comp = ($crc ^ ord($char)) & 0xFF;
55            11                                 34         for ( 1 .. 8 ) {
56            88    100                         370            $comp = $comp & 1 ? $poly ^ ($comp >> 1) : $comp >> 1;
57                                                          }
58            11                                 44         $crc = (($crc >> 8) & 0x00FFFFFF) ^ $comp;
59                                                       }
60             1                                  7      return $crc ^ 0xFFFFFFFF;
61                                                    }
62                                                    
63                                                    # Returns how wide/long, in characters, a CRC function is.
64                                                    sub get_crc_wid {
65    ***      0                    0      0      0      my ( $self, $dbh, $func ) = @_;
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
78    ***      2                    2      0     10      my ( $self, $dbh, $func ) = @_;
79             2                                  6      my $type   = '';
80             2                                  7      my $length = 0;
81             2                                  9      my $sql    = "SELECT $func('a')";
82             2                                  5      my $sth    = $dbh->prepare($sql);
83             2                                 11      eval {
84             2                                264         $sth->execute();
85             2                                 38         $type   = $sth->{mysql_type_name}->[0];
86             2                                 13         $length = $sth->{mysql_length}->[0];
87             2                                  9         MKDEBUG && _d($sql, $type, $length);
88    ***      2    100     66                   19         if ( $type eq 'bigint' && $length < 20 ) {
89             1                                  3            $type = 'int';
90                                                          }
91                                                       };
92             2                                 26      $sth->finish;
93             2                                  6      MKDEBUG && _d('crc_type:', $type, 'length:', $length);
94             2                                 51      return ($type, $length);
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
105   ***     12                   12      0     80      my ( $self, %args ) = @_;
106           12                                 90      my ( $alg, $dbh ) = @args{ qw(algorithm dbh) };
107           12                                 43      my $vp = $self->{VersionParser};
108           12                                 22      my @choices = sort { $ALGOS{$a}->{pref} <=> $ALGOS{$b}->{pref} } keys %ALGOS;
              36                                161   
109           12    100    100                  135      die "Invalid checksum algorithm $alg"
110                                                         if $alg && !$ALGOS{$alg};
111                                                   
112                                                      # CHECKSUM is eliminated by lots of things...
113           11    100    100                  170      if (
                           100                        
                           100                        
114                                                         $args{where} || $args{chunk}        # CHECKSUM does whole table
115                                                         || $args{replicate}                 # CHECKSUM can't do INSERT.. SELECT
116                                                         || !$vp->version_ge($dbh, '4.1.1')) # CHECKSUM doesn't exist
117                                                      {
118            5                                 85         MKDEBUG && _d('Cannot use CHECKSUM algorithm');
119            5                                 19         @choices = grep { $_ ne 'CHECKSUM' } @choices;
              15                                 57   
120                                                      }
121                                                   
122                                                      # BIT_XOR isn't available till 4.1.1 either
123           11    100                         301      if ( !$vp->version_ge($dbh, '4.1.1') ) {
124            2                                 69         MKDEBUG && _d('Cannot use BIT_XOR algorithm because MySQL < 4.1.1');
125            2                                  6         @choices = grep { $_ ne 'BIT_XOR' } @choices;
               4                                 16   
126                                                      }
127                                                   
128                                                      # Choose the best (fastest) among the remaining choices.
129           11    100    100                  385      if ( $alg && grep { $_ eq $alg } @choices ) {
              20                                 97   
130                                                         # Honor explicit choices.
131            4                                  9         MKDEBUG && _d('User requested', $alg, 'algorithm');
132            4                                 28         return $alg;
133                                                      }
134                                                   
135                                                      # If the user wants a count, prefer something other than CHECKSUM, because it
136                                                      # requires an extra query for the count.
137   ***      7    100     66                   53      if ( $args{count} && grep { $_ ne 'CHECKSUM' } @choices ) {
               3                                 15   
138            1                                  3         MKDEBUG && _d('Not using CHECKSUM algorithm because COUNT desired');
139            1                                  4         @choices = grep { $_ ne 'CHECKSUM' } @choices;
               3                                 12   
140                                                      }
141                                                   
142            7                                 16      MKDEBUG && _d('Algorithms, in order:', @choices);
143            7                                 48      return $choices[0];
144                                                   }
145                                                   
146                                                   sub is_hash_algorithm {
147   ***      3                    3      0     13      my ( $self, $algorithm ) = @_;
148   ***      3            66                   38      return $ALGOS{$algorithm} && $ALGOS{$algorithm}->{hash};
149                                                   }
150                                                   
151                                                   # Picks a hash function, in order of speed.
152                                                   # Arguments:
153                                                   #   * dbh
154                                                   #   * function  (optional) Preferred function: SHA1, MD5, etc.
155                                                   sub choose_hash_func {
156   ***      3                    3      0     18      my ( $self, %args ) = @_;
157            3                                 17      my @funcs = qw(CRC32 FNV1A_64 FNV_64 MD5 SHA1);
158            3    100                          14      if ( $args{function} ) {
159            2                                  8         unshift @funcs, $args{function};
160                                                      }
161            3                                  9      my ($result, $error);
162   ***      3            66                    8      do {
163            4                                 10         my $func;
164            4                                 11         eval {
165            4                                 12            $func = shift(@funcs);
166            4                                 16            my $sql = "SELECT $func('test-string')";
167            4                                  9            MKDEBUG && _d($sql);
168            4                                425            $args{dbh}->do($sql);
169            3                                 12            $result = $func;
170                                                         };
171   ***      4    100     66                   59         if ( $EVAL_ERROR && $EVAL_ERROR =~ m/failed: (.*?) at \S+ line/ ) {
172            1                                  7            $error .= qq{$func cannot be used because "$1"\n};
173            1                                  9            MKDEBUG && _d($func, 'cannot be used because', $1);
174                                                         }
175                                                      } while ( @funcs && !$result );
176                                                   
177   ***      3     50                          12      die $error unless $result;
178            3                                  7      MKDEBUG && _d('Chosen hash func:', $result);
179            3                                 28      return $result;
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
190   ***      2                    2      0     12      my ( $self, %args ) = @_;
191            2                                 11      my ($dbh, $func) = @args{qw(dbh function)};
192                                                   
193   ***      2     50                          13      die "$func never needs the BIT_XOR optimization"
194                                                         if $func =~ m/^(?:FNV1A_64|FNV_64|CRC32)$/i;
195                                                   
196            2                                  6      my $opt_slice = 0;
197            2                                  6      my $unsliced  = uc $dbh->selectall_arrayref("SELECT $func('a')")->[0]->[0];
198            2                                314      my $sliced    = '';
199            2                                  7      my $start     = 1;
200   ***      2     50                          12      my $crc_wid   = length($unsliced) < 16 ? 16 : length($unsliced);
201                                                   
202   ***      2            66                    5      do { # Try different positions till sliced result equals non-sliced.
203            5                                 11         MKDEBUG && _d('Trying slice', $opt_slice);
204            5                                339         $dbh->do('SET @crc := "", @cnt := 0');
205            5                                 36         my $slices = $self->make_xor_slices(
206                                                            query     => "\@crc := $func('a')",
207                                                            crc_wid   => $crc_wid,
208                                                            opt_slice => $opt_slice,
209                                                         );
210                                                   
211            5                                 20         my $sql = "SELECT CONCAT($slices) AS TEST FROM (SELECT NULL) AS x";
212            5                                 10         $sliced = ($dbh->selectrow_array($sql))[0];
213            5    100                        1119         if ( $sliced ne $unsliced ) {
214            3                                  6            MKDEBUG && _d('Slice', $opt_slice, 'does not work');
215            3                                  9            $start += 16;
216            3                                 38            ++$opt_slice;
217                                                         }
218                                                      } while ( $start < $crc_wid && $sliced ne $unsliced );
219                                                   
220   ***      2     50                          10      if ( $sliced eq $unsliced ) {
221            2                                  5         MKDEBUG && _d('Slice', $opt_slice, 'works');
222            2                                 16         return $opt_slice;
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
241   ***     13                   13      0     94      my ( $self, %args ) = @_;
242           13                                 57      foreach my $arg ( qw(query crc_wid) ) {
243   ***     26     50                         130         die "I need a $arg argument" unless defined $args{$arg};
244                                                      }
245           13                                 66      my ( $query, $crc_wid, $opt_slice ) = @args{qw(query crc_wid opt_slice)};
246                                                   
247                                                      # Create a series of slices with @crc as a placeholder.
248           13                                 31      my @slices;
249                                                      for ( my $start = 1; $start <= $crc_wid; $start += 16 ) {
250           29                                 99         my $len = $crc_wid - $start + 1;
251           29    100                         103         if ( $len > 16 ) {
252           16                                 47            $len = 16;
253                                                         }
254           29                                246         push @slices,
255                                                            "LPAD(CONV(BIT_XOR("
256                                                            . "CAST(CONV(SUBSTRING(\@crc, $start, $len), 16, 10) AS UNSIGNED))"
257                                                            . ", 10, 16), $len, '0')";
258           13                                 35      }
259                                                   
260                                                      # Replace the placeholder with the expression.  If specified, add a
261                                                      # user-variable optimization so the expression goes in only one of the
262                                                      # slices.  This optimization relies on @crc being '' when the query begins.
263   ***     13    100     66                   88      if ( defined $opt_slice && $opt_slice < @slices ) {
264            7                                 60         $slices[$opt_slice] =~ s/\@crc/\@crc := $query/;
265                                                      }
266                                                      else {
267            6                                 19         map { s/\@crc/$query/ } @slices;
              12                                 68   
268                                                      }
269                                                   
270           13                                 99      return join(', ', @slices);
271                                                   }
272                                                   
273                                                   # Generates a checksum query for a given table.  Arguments:
274                                                   # *   tbl_struct  Struct as returned by TableParser::parse()
275                                                   # *   function    SHA1, MD5, etc
276                                                   # *   sep         (optional) Separator for CONCAT_WS(); default #
277                                                   # *   cols        (optional) arrayref of columns to checksum
278                                                   # *   trim        (optional) wrap VARCHAR cols in TRIM() for v4/v5 compatibility
279                                                   # *   ignorecols  (optional) arrayref of columns to exclude from checksum
280                                                   sub make_row_checksum {
281   ***     20                   20      0    166      my ( $self, %args ) = @_;
282           20                                100      my ( $tbl_struct, $func ) = @args{ qw(tbl_struct function) };
283           20                                 63      my $q = $self->{Quoter};
284                                                   
285           20           100                  139      my $sep = $args{sep} || '#';
286           20                                 70      $sep =~ s/'//g;
287           20           100                   72      $sep ||= '#';
288                                                   
289                                                      # This allows a simpler grep when building %cols below.
290           20                                 54      my %ignorecols = map { $_ => 1 } @{$args{ignorecols}};
               1                                  5   
              20                                 91   
291                                                   
292                                                      # Generate the expression that will turn a row into a checksum.
293                                                      # Choose columns.  Normalize query results: make FLOAT and TIMESTAMP
294                                                      # stringify uniformly.
295           98                                392      my %cols = map { lc($_) => 1 }
              99                                315   
296           11                                 38                 grep { !exists $ignorecols{$_} }
297           20    100                          88                 ($args{cols} ? @{$args{cols}} : @{$tbl_struct->{cols}});
               9                                 40   
298           20                                 72      my %seen;
299           98                                364      my @cols =
300                                                         map {
301          228    100                        1253            my $type = $tbl_struct->{type_for}->{$_};
302           98                                390            my $result = $q->quote($_);
303           98    100    100                 2905            if ( $type eq 'timestamp' ) {
                    100    100                        
                    100                               
304            6                                 18               $result .= ' + 0';
305                                                            }
306                                                            elsif ( $args{float_precision} && $type =~ m/float|double/ ) {
307            1                                  6               $result = "ROUND($result, $args{float_precision})";
308                                                            }
309                                                            elsif ( $args{trim} && $type =~ m/varchar/ ) {
310            1                                  5               $result = "TRIM($result)";
311                                                            }
312           98                                342            $result;
313                                                         }
314                                                         grep {
315           20                                 85            $cols{$_} && !$seen{$_}++
316                                                         }
317           20                                 60         @{$tbl_struct->{cols}};
318                                                   
319                                                      # Prepend columns to query, resulting in "col1, col2, FUNC(..col1, col2...)",
320                                                      # unless caller says not to.  The only caller that says not to is
321                                                      # make_checksum_query() which uses this row checksum as part of a larger
322                                                      # checksum.  Other callers, like TableSyncer::make_checksum_queries() call
323                                                      # this sub directly and want the actual columns.
324           20                                 66      my $query;
325           20    100                          87      if ( !$args{no_cols} ) {
326           51                                125         $query = join(', ',
327                                                                     map { 
328           10                                 30                        my $col = $_;
329           51    100                         272                        if ( $col =~ m/\+ 0/ ) {
                    100                               
330                                                                           # Alias col name back to itself else its name becomes
331                                                                           # "col + 0" instead of just "col".
332            3                                 16                           my ($real_col) = /^(\S+)/;
333            3                                 12                           $col .= " AS $real_col";
334                                                                        }
335                                                                        elsif ( $col =~ m/TRIM/ ) {
336            1                                  8                           my ($real_col) = m/TRIM\(([^\)]+)\)/;
337            1                                  4                           $col .= " AS $real_col";
338                                                                        }
339           51                                161                        $col;
340                                                                     } @cols)
341                                                                . ', ';
342                                                      }
343                                                   
344   ***     20    100     66                  156      if ( uc $func ne 'FNV_64' && uc $func ne 'FNV1A_64' ) {
345                                                         # Add a bitmap of which nullable columns are NULL.
346           16                                 44         my @nulls = grep { $cols{$_} } @{$tbl_struct->{null_cols}};
              78                                247   
              16                                 64   
347           16    100                          65         if ( @nulls ) {
348           24                                507            my $bitmap = "CONCAT("
349            4                                 14               . join(', ', map { 'ISNULL(' . $q->quote($_) . ')' } @nulls)
350                                                               . ")";
351            4                                116            push @cols, $bitmap;
352                                                         }
353                                                   
354           16    100                         109         $query .= @cols > 1
355                                                                 ? "$func(CONCAT_WS('$sep', " . join(', ', @cols) . '))'
356                                                                 : "$func($cols[0])";
357                                                      }
358                                                      else {
359                                                         # As a special case, FNV1A_64/FNV_64 doesn't need its arguments
360                                                         # concatenated, and doesn't need a bitmap of NULLs.
361            4                                 13         my $fnv_func = uc $func;
362            4                                 23         $query .= "$fnv_func(" . join(', ', @cols) . ')';
363                                                      }
364                                                   
365           20                                153      return $query;
366                                                   }
367                                                   
368                                                   # Generates a checksum query for a given table.  Arguments:
369                                                   # *   db          Database name
370                                                   # *   tbl         Table name
371                                                   # *   tbl_struct  Struct as returned by TableParser::parse()
372                                                   # *   algorithm   Any of @ALGOS
373                                                   # *   function    (optional) SHA1, MD5, etc
374                                                   # *   crc_wid     Width of the string returned by function
375                                                   # *   crc_type    Type of function's result
376                                                   # *   opt_slice   (optional) Which slice gets opt_xor (see make_xor_slices()).
377                                                   # *   cols        (optional) see make_row_checksum()
378                                                   # *   sep         (optional) see make_row_checksum()
379                                                   # *   replicate   (optional) generate query to REPLACE into this table.
380                                                   # *   trim        (optional) see make_row_checksum().
381                                                   # *   buffer      (optional) Adds SQL_BUFFER_RESULT.
382                                                   sub make_checksum_query {
383   ***     12                   12      0    140      my ( $self, %args ) = @_;
384           12                                 83      my @required_args = qw(db tbl tbl_struct algorithm crc_wid crc_type);
385           12                                 41      foreach my $arg( @required_args ) {
386   ***     72     50                         299         die "I need a $arg argument" unless $args{$arg};
387                                                      }
388           12                                 65      my ( $db, $tbl, $tbl_struct, $algorithm,
389                                                           $crc_wid, $crc_type) = @args{@required_args};
390           12                                 34      my $func = $args{function};
391           12                                 38      my $q = $self->{Quoter};
392           12                                 29      my $result;
393                                                   
394   ***     12    100     66                  107      die "Invalid or missing checksum algorithm"
395                                                         unless $algorithm && $ALGOS{$algorithm};
396                                                   
397           11    100                          42      if ( $algorithm eq 'CHECKSUM' ) {
398            1                                  7         return "CHECKSUM TABLE " . $q->quote($db, $tbl);
399                                                      }
400                                                   
401           10                                 63      my $expr = $self->make_row_checksum(%args, no_cols=>1);
402                                                   
403           10    100                          59      if ( $algorithm eq 'BIT_XOR' ) {
404                                                         # This checksum algorithm concatenates the columns in each row and
405                                                         # checksums them, then slices this checksum up into 16-character chunks.
406                                                         # It then converts them BIGINTs with the CONV() function, and then
407                                                         # groupwise XORs them to produce an order-independent checksum of the
408                                                         # slice over all the rows.  It then converts these back to base 16 and
409                                                         # puts them back together.  The effect is the same as XORing a very wide
410                                                         # (32 characters = 128 bits for MD5, and SHA1 is even larger) unsigned
411                                                         # integer over all the rows.
412                                                         #
413                                                         # As a special case, integer functions do not need to be sliced.  They
414                                                         # can be fed right into BIT_XOR after a cast to UNSIGNED.
415            5    100                          22         if ( $crc_type =~ m/int$/ ) {
416            3                                 12            $result = "COALESCE(LOWER(CONV(BIT_XOR(CAST($expr AS UNSIGNED)), 10, 16)), 0) AS crc ";
417                                                         }
418                                                         else {
419            2                                 14            my $slices = $self->make_xor_slices( query => $expr, %args );
420            2                                 10            $result = "COALESCE(LOWER(CONCAT($slices)), 0) AS crc ";
421                                                         }
422                                                      }
423                                                      else {
424                                                         # Use an accumulator variable.  This query relies on @crc being '', and
425                                                         # @cnt being 0 when it begins.  It checksums each row, appends it to the
426                                                         # running checksum, and checksums the two together.  In this way it acts
427                                                         # as an accumulator for all the rows.  It then prepends a steadily
428                                                         # increasing number to the left, left-padded with zeroes, so each checksum
429                                                         # taken is stringwise greater than the last.  In this way the MAX()
430                                                         # function can be used to return the last checksum calculated.  @cnt is
431                                                         # not used for a row count, it is only used to make MAX() work correctly.
432                                                         #
433                                                         # As a special case, int funcs must be converted to base 16 so it's a
434                                                         # predictable width (it's also a shorter string, but that's not really
435                                                         # important).
436                                                         #
437                                                         # On MySQL 4.0 and older, crc is NULL/undef if no rows are selected.
438                                                         # We COALESCE to avoid having to check that crc is defined; see
439                                                         # http://code.google.com/p/maatkit/issues/detail?id=672
440            5    100                          30         if ( $crc_type =~ m/int$/ ) {
441            3                                 24            $result = "COALESCE(RIGHT(MAX("
442                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
443                                                               . "CONV(CAST($func(CONCAT(\@crc, $expr)) AS UNSIGNED), 10, 16))"
444                                                               . "), $crc_wid), 0) AS crc ";
445                                                         }
446                                                         else {
447            2                                 15            $result = "COALESCE(RIGHT(MAX("
448                                                               . "\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), "
449                                                               . "$func(CONCAT(\@crc, $expr)))"
450                                                               . "), $crc_wid), 0) AS crc ";
451                                                         }
452                                                      }
453           10    100                          39      if ( $args{replicate} ) {
454            2                                 14         $result = "REPLACE /*PROGRESS_COMMENT*/ INTO $args{replicate} "
455                                                            . "(db, tbl, chunk, boundaries, this_cnt, this_crc) "
456                                                            . "SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, $result";
457                                                      }
458                                                      else {
459            8    100                          51         $result = "SELECT "
460                                                            . ($args{buffer} ? 'SQL_BUFFER_RESULT ' : '')
461                                                            . "/*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, $result";
462                                                      }
463           10                                 85      return $result . "FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/";
464                                                   }
465                                                   
466                                                   # Queries the replication table for chunks that differ from the master's data.
467                                                   sub find_replication_differences {
468   ***      0                    0      0             my ( $self, $dbh, $table ) = @_;
469                                                   
470   ***      0                                         (my $sql = <<"   EOF") =~ s/\s+/ /gm;
471                                                         SELECT db, tbl, chunk, boundaries,
472                                                            COALESCE(this_cnt-master_cnt, 0) AS cnt_diff,
473                                                            COALESCE(
474                                                               this_crc <> master_crc OR ISNULL(master_crc) <> ISNULL(this_crc),
475                                                               0
476                                                            ) AS crc_diff,
477                                                            this_cnt, master_cnt, this_crc, master_crc
478                                                         FROM $table
479                                                         WHERE master_cnt <> this_cnt OR master_crc <> this_crc
480                                                         OR ISNULL(master_crc) <> ISNULL(this_crc)
481                                                      EOF
482                                                   
483   ***      0                                         MKDEBUG && _d($sql);
484   ***      0                                         my $diffs = $dbh->selectall_arrayref($sql, { Slice => {} });
485   ***      0                                         return @$diffs;
486                                                   }
487                                                   
488                                                   sub _d {
489   ***      0                    0                    my ($package, undef, $line) = caller 0;
490   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
491   ***      0                                              map { defined $_ ? $_ : 'undef' }
492                                                           @_;
493   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
494                                                   }
495                                                   
496                                                   1;
497                                                   
498                                                   # ###########################################################################
499                                                   # End TableChecksum package
500                                                   # ###########################################################################


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
301          100     98    130   if $cols{$_}
303          100      6     92   if ($type eq 'timestamp') { }
             100      1     91   elsif ($args{'float_precision'} and $type =~ /float|double/) { }
             100      1     90   elsif ($args{'trim'} and $type =~ /varchar/) { }
325          100     10     10   if (not $args{'no_cols'})
329          100      3     48   if ($col =~ /\+ 0/) { }
             100      1     47   elsif ($col =~ /TRIM/) { }
344          100     16      4   if (uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64') { }
347          100      4     12   if (@nulls)
354          100     10      6   @cols > 1 ? :
386   ***     50      0     72   unless $args{$arg}
394          100      1     11   unless $algorithm and $ALGOS{$algorithm}
397          100      1     10   if ($algorithm eq 'CHECKSUM')
403          100      5      5   if ($algorithm eq 'BIT_XOR') { }
415          100      3      2   if ($crc_type =~ /int$/) { }
440          100      3      2   if ($crc_type =~ /int$/) { }
453          100      2      8   if ($args{'replicate'}) { }
459          100      2      6   $args{'buffer'} ? :
490   ***      0      0      0   defined $_ ? :


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
303          100     90      1      1   $args{'float_precision'} and $type =~ /float|double/
             100     79     11      1   $args{'trim'} and $type =~ /varchar/
344   ***     66      4      0     16   uc $func ne 'FNV_64' and uc $func ne 'FNV1A_64'
394   ***     66      0      1     11   $algorithm and $ALGOS{$algorithm}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0
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

Subroutine                   Count Pod Location                                            
---------------------------- ----- --- ----------------------------------------------------
BEGIN                            1     /home/daniel/dev/maatkit/common/TableChecksum.pm:22 
BEGIN                            1     /home/daniel/dev/maatkit/common/TableChecksum.pm:23 
BEGIN                            1     /home/daniel/dev/maatkit/common/TableChecksum.pm:24 
BEGIN                            1     /home/daniel/dev/maatkit/common/TableChecksum.pm:25 
BEGIN                            1     /home/daniel/dev/maatkit/common/TableChecksum.pm:27 
best_algorithm                  12   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:105
choose_hash_func                 3   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:156
crc32                            1   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:50 
get_crc_type                     2   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:78 
is_hash_algorithm                3   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:147
make_checksum_query             12   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:383
make_row_checksum               20   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:281
make_xor_slices                 13   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:241
new                              1   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:38 
optimize_xor                     2   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:190

Uncovered Subroutines
---------------------

Subroutine                   Count Pod Location                                            
---------------------------- ----- --- ----------------------------------------------------
_d                               0     /home/daniel/dev/maatkit/common/TableChecksum.pm:489
find_replication_differences     0   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:468
get_crc_wid                      0   0 /home/daniel/dev/maatkit/common/TableChecksum.pm:65 


TableChecksum.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            31      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 51;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            10   use TableChecksum;
               1                                  2   
               1                                 10   
15             1                    1            12   use VersionParser;
               1                                  3   
               1                                 10   
16             1                    1            14   use TableParser;
               1                                  3   
               1                                 12   
17             1                    1            11   use Quoter;
               1                                  3   
               1                                  9   
18             1                    1            10   use MySQLDump;
               1                                  3   
               1                                 11   
19             1                    1            10   use DSNParser;
               1                                  3   
               1                                 70   
20             1                    1            13   use Sandbox;
               1                                  3   
               1                                 10   
21             1                    1            12   use MaatkitTest;
               1                                  6   
               1                                 39   
22                                                    
23             1                                 15   my $dp = new DSNParser(opts=>$dsn_opts);
24             1                                254   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
25    ***      1     50                          62   my $dbh = $sb->get_dbh_for('master')
26                                                       or BAIL_OUT('Cannot connect to sandbox master');
27             1                                393   $sb->create_dbs($dbh, ['test']);
28                                                    
29             1                                565   my $q  = new Quoter();
30             1                                 34   my $tp = new TableParser(Quoter => $q);
31             1                                 51   my $vp = new VersionParser();
32             1                                 27   my $du = new MySQLDump();
33             1                                 34   my $c  = new TableChecksum(Quoter=>$q, VersionParser=>$vp);
34                                                    
35             1                                  3   my $t;
36                                                    
37             1                                  6   my %args = map { $_ => undef }
               8                                 37   
38                                                       qw(db tbl tbl_struct algorithm function crc_wid crc_type opt_slice);
39                                                    
40                                                    throws_ok (
41             1                    1            21      sub { $c->best_algorithm( %args, algorithm => 'foo', ) },
42             1                                 28      qr/Invalid checksum algorithm/,
43                                                       'Algorithm=foo',
44                                                    );
45                                                    
46                                                    # Inject the VersionParser with some bogus versions.  Later I'll just pass the
47                                                    # string version number instead of a real DBH, so the version parsing will
48                                                    # return the value I want.
49             1                                 17   foreach my $ver( qw(4.0.0 4.1.1) ) {
50             2                                 35      $vp->{$ver} = $vp->parse($ver);
51                                                    }
52                                                    
53                                                    is (
54             1                                 24      $c->best_algorithm(
55                                                          algorithm => 'CHECKSUM',
56                                                          dbh       => '4.1.1',
57                                                       ),
58                                                       'CHECKSUM',
59                                                       'Prefers CHECKSUM',
60                                                    );
61                                                    
62             1                                  6   is (
63                                                       $c->best_algorithm(
64                                                          dbh       => '4.1.1',
65                                                       ),
66                                                       'CHECKSUM',
67                                                       'Default is CHECKSUM',
68                                                    );
69                                                    
70             1                                  8   is (
71                                                       $c->best_algorithm(
72                                                          algorithm => 'CHECKSUM',
73                                                          dbh       => '4.1.1',
74                                                          where     => 1,
75                                                       ),
76                                                       'BIT_XOR',
77                                                       'CHECKSUM eliminated by where',
78                                                    );
79                                                    
80             1                                  7   is (
81                                                       $c->best_algorithm(
82                                                          algorithm => 'CHECKSUM',
83                                                          dbh       => '4.1.1',
84                                                          chunk     => 1,
85                                                       ),
86                                                       'BIT_XOR',
87                                                       'CHECKSUM eliminated by chunk',
88                                                    );
89                                                    
90             1                                  8   is (
91                                                       $c->best_algorithm(
92                                                          algorithm => 'CHECKSUM',
93                                                          dbh       => '4.1.1',
94                                                          replicate => 1,
95                                                       ),
96                                                       'BIT_XOR',
97                                                       'CHECKSUM eliminated by replicate',
98                                                    );
99                                                    
100            1                                  9   is (
101                                                      $c->best_algorithm(
102                                                         dbh       => '4.1.1',
103                                                         count     => 1,
104                                                      ),
105                                                      'BIT_XOR',
106                                                      'Default CHECKSUM eliminated by count',
107                                                   );
108                                                   
109            1                                  6   is (
110                                                      $c->best_algorithm(
111                                                         algorithm => 'CHECKSUM',
112                                                         dbh       => '4.1.1',
113                                                         count     => 1,
114                                                      ),
115                                                      'CHECKSUM',
116                                                      'Explicit CHECKSUM not eliminated by count',
117                                                   );
118                                                   
119            1                                  6   is (
120                                                      $c->best_algorithm(
121                                                         algorithm => 'CHECKSUM',
122                                                         dbh       => '4.0.0',
123                                                      ),
124                                                      'ACCUM',
125                                                      'CHECKSUM and BIT_XOR eliminated by version',
126                                                   );
127                                                   
128            1                                  6   is (
129                                                      $c->best_algorithm(
130                                                         algorithm => 'BIT_XOR',
131                                                         dbh       => '4.1.1',
132                                                      ),
133                                                      'BIT_XOR',
134                                                      'BIT_XOR as requested',
135                                                   );
136                                                   
137            1                                  7   is (
138                                                      $c->best_algorithm(
139                                                         algorithm => 'BIT_XOR',
140                                                         dbh       => '4.0.0',
141                                                      ),
142                                                      'ACCUM',
143                                                      'BIT_XOR eliminated by version',
144                                                   );
145                                                   
146            1                                  6   is (
147                                                      $c->best_algorithm(
148                                                         algorithm => 'ACCUM',
149                                                         dbh       => '4.1.1',
150                                                      ),
151                                                      'ACCUM',
152                                                      'ACCUM as requested',
153                                                   );
154                                                   
155            1                                  7   ok($c->is_hash_algorithm('ACCUM'), 'ACCUM is hash');
156            1                                  5   ok($c->is_hash_algorithm('BIT_XOR'), 'BIT_XOR is hash');
157            1                                  7   ok(!$c->is_hash_algorithm('CHECKSUM'), 'CHECKSUM is not hash');
158                                                   
159            1                                  7   is (
160                                                      $c->make_xor_slices(
161                                                         query   => 'FOO',
162                                                         crc_wid => 1,
163                                                      ),
164                                                      "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 1), 16, 10) "
165                                                         . "AS UNSIGNED)), 10, 16), 1, '0')",
166                                                      'FOO XOR slices 1 wide',
167                                                   );
168                                                   
169            1                                  6   is (
170                                                      $c->make_xor_slices(
171                                                         query   => 'FOO',
172                                                         crc_wid => 16,
173                                                      ),
174                                                      "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 16), 16, 10) "
175                                                         . "AS UNSIGNED)), 10, 16), 16, '0')",
176                                                      'FOO XOR slices 16 wide',
177                                                   );
178                                                   
179            1                                  7   is (
180                                                      $c->make_xor_slices(
181                                                         query   => 'FOO',
182                                                         crc_wid => 17,
183                                                      ),
184                                                      "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 16), 16, 10) "
185                                                         . "AS UNSIGNED)), 10, 16), 16, '0'), "
186                                                         . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 17, 1), 16, 10) "
187                                                         . "AS UNSIGNED)), 10, 16), 1, '0')",
188                                                      'FOO XOR slices 17 wide',
189                                                   );
190                                                   
191            1                                  7   is (
192                                                      $c->make_xor_slices(
193                                                         query   => 'FOO',
194                                                         crc_wid => 32,
195                                                      ),
196                                                      "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 1, 16), 16, 10) "
197                                                         . "AS UNSIGNED)), 10, 16), 16, '0'), "
198                                                         . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(FOO, 17, 16), 16, 10) "
199                                                         . "AS UNSIGNED)), 10, 16), 16, '0')",
200                                                      'FOO XOR slices 32 wide',
201                                                   );
202                                                   
203            1                                  7   is (
204                                                      $c->make_xor_slices(
205                                                         query     => 'FOO',
206                                                         crc_wid   => 32,
207                                                         opt_slice => 0,
208                                                      ),
209                                                      "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc := FOO, 1, 16), 16, 10) "
210                                                         . "AS UNSIGNED)), 10, 16), 16, '0'), "
211                                                         . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 17, 16), 16, 10) "
212                                                         . "AS UNSIGNED)), 10, 16), 16, '0')",
213                                                      'XOR slice optimized in slice 0',
214                                                   );
215                                                   
216            1                                  6   is (
217                                                      $c->make_xor_slices(
218                                                         query     => 'FOO',
219                                                         crc_wid   => 32,
220                                                         opt_slice => 1,
221                                                      ),
222                                                      "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 1, 16), 16, 10) "
223                                                         . "AS UNSIGNED)), 10, 16), 16, '0'), "
224                                                         . "LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc := FOO, 17, 16), 16, 10) "
225                                                         . "AS UNSIGNED)), 10, 16), 16, '0')",
226                                                      'XOR slice optimized in slice 1',
227                                                   );
228                                                   
229            1                                 10   $t = $tp->parse(load_file('common/t/samples/sakila.film.sql'));
230                                                   
231            1                               1483   is (
232                                                      $c->make_row_checksum(
233                                                         function  => 'SHA1',
234                                                         tbl_struct => $t,
235                                                      ),
236                                                        q{`film_id`, `title`, `description`, `release_year`, `language_id`, `original_language_id`, `rental_duration`, `rental_rate`, `length`, `replacement_cost`, `rating`, `special_features`, `last_update` + 0 AS `last_update`, }
237                                                      . q{SHA1(CONCAT_WS('#', }
238                                                      . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
239                                                      . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
240                                                      . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0, }
241                                                      . q{CONCAT(ISNULL(`description`), ISNULL(`release_year`), }
242                                                      . q{ISNULL(`original_language_id`), ISNULL(`length`), }
243                                                      . q{ISNULL(`rating`), ISNULL(`special_features`))))},
244                                                      'SHA1 query for sakila.film',
245                                                   );
246                                                   
247            1                                  6   is (
248                                                      $c->make_row_checksum(
249                                                         function      => 'FNV_64',
250                                                         tbl_struct => $t,
251                                                      ),
252                                                        q{`film_id`, `title`, `description`, `release_year`, `language_id`, `original_language_id`, `rental_duration`, `rental_rate`, `length`, `replacement_cost`, `rating`, `special_features`, `last_update` + 0 AS `last_update`, }
253                                                      . q{FNV_64(}
254                                                      . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
255                                                      . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
256                                                      . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0)},
257                                                      'FNV_64 query for sakila.film',
258                                                   );
259                                                   
260            1                                  8   is (
261                                                      $c->make_row_checksum(
262                                                         function      => 'SHA1',
263                                                         tbl_struct => $t,
264                                                         cols      => [qw(film_id)],
265                                                      ),
266                                                      q{`film_id`, SHA1(`film_id`)},
267                                                      'SHA1 query for sakila.film with only one column',
268                                                   );
269                                                   
270            1                                  8   is (
271                                                      $c->make_row_checksum(
272                                                         function      => 'SHA1',
273                                                         tbl_struct => $t,
274                                                         cols      => [qw(FILM_ID)],
275                                                      ),
276                                                      q{`film_id`, SHA1(`film_id`)},
277                                                      'Column names are case-insensitive',
278                                                   );
279                                                   
280            1                                 11   is (
281                                                      $c->make_row_checksum(
282                                                         function      => 'SHA1',
283                                                         tbl_struct => $t,
284                                                         cols      => [qw(film_id title)],
285                                                         sep       => '%',
286                                                      ),
287                                                      q{`film_id`, `title`, SHA1(CONCAT_WS('%', `film_id`, `title`))},
288                                                      'Separator',
289                                                   );
290                                                   
291            1                                  9   is (
292                                                      $c->make_row_checksum(
293                                                         function      => 'SHA1',
294                                                         tbl_struct => $t,
295                                                         cols      => [qw(film_id title)],
296                                                         sep       => "'%'",
297                                                      ),
298                                                      q{`film_id`, `title`, SHA1(CONCAT_WS('%', `film_id`, `title`))},
299                                                      'Bad separator',
300                                                   );
301                                                   
302            1                                  9   is (
303                                                      $c->make_row_checksum(
304                                                         function      => 'SHA1',
305                                                         tbl_struct => $t,
306                                                         cols      => [qw(film_id title)],
307                                                         sep       => "'''",
308                                                      ),
309                                                      q{`film_id`, `title`, SHA1(CONCAT_WS('#', `film_id`, `title`))},
310                                                      'Really bad separator',
311                                                   );
312                                                   
313            1                                  9   $t = $tp->parse(load_file('common/t/samples/sakila.rental.float.sql'));
314            1                                333   is (
315                                                      $c->make_row_checksum(
316                                                         function      => 'SHA1',
317                                                         tbl_struct => $t,
318                                                      ),
319                                                      q{`rental_id`, `foo`, SHA1(CONCAT_WS('#', `rental_id`, `foo`))},
320                                                      'FLOAT column is like any other',
321                                                   );
322                                                   
323            1                                  6   is (
324                                                      $c->make_row_checksum(
325                                                         function      => 'SHA1',
326                                                         tbl_struct => $t,
327                                                         float_precision => 5,
328                                                      ),
329                                                      q{`rental_id`, ROUND(`foo`, 5), SHA1(CONCAT_WS('#', `rental_id`, ROUND(`foo`, 5)))},
330                                                      'FLOAT column is rounded to 5 places',
331                                                   );
332                                                   
333            1                                  6   $t = $tp->parse(load_file('common/t/samples/sakila.film.sql'));
334                                                   
335            1                               1376   like(
336                                                      $c->make_row_checksum(
337                                                         function   => 'SHA1',
338                                                         tbl_struct => $t,
339                                                         trim       => 1,
340                                                      ),
341                                                      qr{TRIM\(`title`\)},
342                                                      'VARCHAR column is trimmed',
343                                                   );
344                                                   
345            1                                 18   is (
346                                                      $c->make_checksum_query(
347                                                         %args,
348                                                         db        => 'sakila',
349                                                         tbl       => 'film',
350                                                         tbl_struct => $t,
351                                                         algorithm => 'CHECKSUM',
352                                                         function      => 'SHA1',
353                                                         crc_wid   => 40,
354                                                         crc_type  => 'varchar',
355                                                      ),
356                                                      'CHECKSUM TABLE `sakila`.`film`',
357                                                      'Sakila.film CHECKSUM',
358                                                   );
359                                                   
360                                                   throws_ok (
361            1                    1            20      sub { $c->make_checksum_query(
362                                                               %args,
363                                                               db        => 'sakila',
364                                                               tbl       => 'film',
365                                                               tbl_struct => $t,
366                                                               algorithm => 'BIT_XOR',
367                                                               crc_wid   => 40,
368                                                               cols      => [qw(film_id)],
369                                                               crc_type  => 'varchar',
370                                                               function  => 'SHA1',
371                                                               algorithm => 'CHECKSUM TABLE',
372                                                            )
373                                                      },
374            1                                 16      qr/missing checksum algorithm/,
375                                                      'Complains about bad algorithm',
376                                                   );
377                                                   
378            1                                 17   is (
379                                                      $c->make_checksum_query(
380                                                         %args,
381                                                         db         => 'sakila',
382                                                         tbl        => 'film',
383                                                         tbl_struct => $t,
384                                                         algorithm  => 'BIT_XOR',
385                                                         function   => 'SHA1',
386                                                         crc_wid    => 40,
387                                                         cols       => [qw(film_id)],
388                                                         crc_type   => 'varchar',
389                                                      ),
390                                                      q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
391                                                      . q{COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 1, }
392                                                      . q{16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
393                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 17, 16), 16, }
394                                                      . q{10) AS UNSIGNED)), 10, 16), 16, '0'), }
395                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 33, 8), 16, }
396                                                      . q{10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc }
397                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
398                                                      'Sakila.film SHA1 BIT_XOR',
399                                                   );
400                                                   
401            1                                 12   is (
402                                                      $c->make_checksum_query(
403                                                         %args,
404                                                         db         => 'sakila',
405                                                         tbl        => 'film',
406                                                         tbl_struct => $t,
407                                                         algorithm  => 'BIT_XOR',
408                                                         function   => 'FNV_64',
409                                                         crc_wid    => 99,
410                                                         cols       => [qw(film_id)],
411                                                         crc_type   => 'bigint',
412                                                      ),
413                                                      q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
414                                                      . q{COALESCE(LOWER(CONV(BIT_XOR(CAST(FNV_64(`film_id`) AS UNSIGNED)), 10, 16)), 0) AS crc }
415                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
416                                                      'Sakila.film FNV_64 BIT_XOR',
417                                                   );
418                                                   
419            1                                 12   is (
420                                                      $c->make_checksum_query(
421                                                         %args,
422                                                         db         => 'sakila',
423                                                         tbl        => 'film',
424                                                         tbl_struct => $t,
425                                                         algorithm  => 'BIT_XOR',
426                                                         function   => 'FNV_64',
427                                                         crc_wid    => 99,
428                                                         cols       => [qw(film_id)],
429                                                         buffer     => 1,
430                                                         crc_type   => 'bigint',
431                                                      ),
432                                                      q{SELECT SQL_BUFFER_RESULT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
433                                                      . q{COALESCE(LOWER(CONV(BIT_XOR(CAST(FNV_64(`film_id`) AS UNSIGNED)), 10, 16)), 0) AS crc }
434                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
435                                                      'Sakila.film FNV_64 BIT_XOR',
436                                                   );
437                                                   
438            1                                 13   is (
439                                                      $c->make_checksum_query(
440                                                         %args,
441                                                         db         => 'sakila',
442                                                         tbl        => 'film',
443                                                         tbl_struct => $t,
444                                                         algorithm  => 'BIT_XOR',
445                                                         function   => 'CRC32',
446                                                         crc_wid    => 99,
447                                                         cols       => [qw(film_id)],
448                                                         buffer     => 1,
449                                                         crc_type   => 'int',
450                                                      ),
451                                                      q{SELECT SQL_BUFFER_RESULT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
452                                                      . q{COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(`film_id`) AS UNSIGNED)), 10, 16)), 0) AS crc }
453                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
454                                                      'Sakila.film CRC32 BIT_XOR',
455                                                   );
456                                                   
457            1                                 12   is (
458                                                      $c->make_checksum_query(
459                                                         %args,
460                                                         db         => 'sakila',
461                                                         tbl        => 'film',
462                                                         tbl_struct => $t,
463                                                         algorithm  => 'BIT_XOR',
464                                                         function   => 'SHA1',
465                                                         crc_wid    => 40,
466                                                         cols       => [qw(film_id)],
467                                                         replicate  => 'test.checksum',
468                                                         crc_type   => 'varchar',
469                                                      ),
470                                                      q{REPLACE /*PROGRESS_COMMENT*/ INTO test.checksum }
471                                                      . q{(db, tbl, chunk, boundaries, this_cnt, this_crc) }
472                                                      . q{SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, }
473                                                      . q{COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 1, }
474                                                      . q{16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
475                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 17, 16), 16, }
476                                                      . q{10) AS UNSIGNED)), 10, 16), 16, '0'), }
477                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(SHA1(`film_id`), 33, 8), 16, }
478                                                      . q{10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc }
479                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
480                                                      'Sakila.film SHA1 BIT_XOR with replication',
481                                                   );
482                                                   
483            1                                 11   is (
484                                                      $c->make_checksum_query(
485                                                         %args,
486                                                         db         => 'sakila',
487                                                         tbl        => 'film',
488                                                         tbl_struct => $t,
489                                                         algorithm  => 'ACCUM',
490                                                         function   => 'SHA1',
491                                                         crc_wid    => 40,
492                                                         crc_type   => 'varchar',
493                                                      ),
494                                                      q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
495                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
496                                                      . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', }
497                                                      . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
498                                                      . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
499                                                      . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0, }
500                                                      . q{CONCAT(ISNULL(`description`), ISNULL(`release_year`), }
501                                                      . q{ISNULL(`original_language_id`), ISNULL(`length`), }
502                                                      . q{ISNULL(`rating`), ISNULL(`special_features`)))))))), 40), 0) AS crc }
503                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
504                                                      'Sakila.film SHA1 ACCUM',
505                                                   );
506                                                   
507            1                                 11   is (
508                                                      $c->make_checksum_query(
509                                                         %args,
510                                                         db         => 'sakila',
511                                                         tbl        => 'film',
512                                                         tbl_struct => $t,
513                                                         algorithm  => 'ACCUM',
514                                                         function   => 'FNV_64',
515                                                         crc_wid    => 16,
516                                                         crc_type   => 'bigint',
517                                                      ),
518                                                      q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
519                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
520                                                      . q{CONV(CAST(FNV_64(CONCAT(@crc, FNV_64(}
521                                                      . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
522                                                      . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
523                                                      . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0}
524                                                      . q{))) AS UNSIGNED), 10, 16))), 16), 0) AS crc }
525                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
526                                                      'Sakila.film FNV_64 ACCUM',
527                                                   );
528                                                   
529            1                                 11   is (
530                                                      $c->make_checksum_query(
531                                                         %args,
532                                                         db         => 'sakila',
533                                                         tbl        => 'film',
534                                                         tbl_struct => $t,
535                                                         algorithm  => 'ACCUM',
536                                                         function   => 'CRC32',
537                                                         crc_wid    => 16,
538                                                         crc_type   => 'int',
539                                                         cols       => [qw(film_id)],
540                                                      ),
541                                                      q{SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, }
542                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
543                                                      . q{CONV(CAST(CRC32(CONCAT(@crc, CRC32(`film_id`}
544                                                      . q{))) AS UNSIGNED), 10, 16))), 16), 0) AS crc }
545                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
546                                                      'Sakila.film CRC32 ACCUM',
547                                                   );
548                                                   
549            1                                 11   is (
550                                                      $c->make_checksum_query(
551                                                         %args,
552                                                         db         => 'sakila',
553                                                         tbl        => 'film',
554                                                         tbl_struct => $t,
555                                                         algorithm  => 'ACCUM',
556                                                         function   => 'SHA1',
557                                                         crc_wid    => 40,
558                                                         replicate  => 'test.checksum',
559                                                         crc_type   => 'varchar',
560                                                      ),
561                                                      q{REPLACE /*PROGRESS_COMMENT*/ INTO test.checksum }
562                                                      . q{(db, tbl, chunk, boundaries, this_cnt, this_crc) }
563                                                      . q{SELECT ?, ?, /*CHUNK_NUM*/ ?, COUNT(*) AS cnt, }
564                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
565                                                      . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', }
566                                                      . q{`film_id`, `title`, `description`, `release_year`, `language_id`, }
567                                                      . q{`original_language_id`, `rental_duration`, `rental_rate`, `length`, }
568                                                      . q{`replacement_cost`, `rating`, `special_features`, `last_update` + 0, }
569                                                      . q{CONCAT(ISNULL(`description`), ISNULL(`release_year`), }
570                                                      . q{ISNULL(`original_language_id`), ISNULL(`length`), }
571                                                      . q{ISNULL(`rating`), ISNULL(`special_features`)))))))), 40), 0) AS crc }
572                                                      . q{FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/},
573                                                      'Sakila.film SHA1 ACCUM with replication',
574                                                   );
575                                                   
576            1                                  8   is ( $c->crc32('hello world'), 222957957, 'CRC32 of hello world');
577                                                   
578                                                   # #############################################################################
579                                                   # Sandbox tests.
580                                                   # #############################################################################
581            1                                  6   like(
582                                                      $c->choose_hash_func(
583                                                         dbh => $dbh,
584                                                      ),
585                                                      qr/CRC32|FNV_64|MD5/,
586                                                      'CRC32, FNV_64 or MD5 is default',
587                                                   );
588                                                   
589            1                                 10   like(
590                                                      $c->choose_hash_func(
591                                                         dbh      => $dbh,
592                                                         function => 'SHA99',
593                                                      ),
594                                                      qr/CRC32|FNV_64|MD5/,
595                                                      'SHA99 does not exist so I get CRC32 or friends',
596                                                   );
597                                                   
598            1                                 10   is(
599                                                      $c->choose_hash_func(
600                                                         dbh      => $dbh,
601                                                         function => 'MD5',
602                                                      ),
603                                                      'MD5',
604                                                      'MD5 requested and MD5 granted',
605                                                   );
606                                                   
607            1                                  8   is(
608                                                      $c->optimize_xor(
609                                                         dbh      => $dbh,
610                                                         function => 'SHA1',
611                                                      ),
612                                                      '2',
613                                                      'SHA1 slice is 2',
614                                                   );
615                                                   
616            1                                  7   is(
617                                                      $c->optimize_xor(
618                                                         dbh      => $dbh,
619                                                         function => 'MD5',
620                                                      ),
621                                                      '1',
622                                                      'MD5 slice is 1',
623                                                   );
624                                                   
625            1                                  9   is_deeply(
626                                                      [$c->get_crc_type($dbh, 'CRC32')],
627                                                      [qw(int 10)],
628                                                      'Type and length of CRC32'
629                                                   );
630                                                   
631            1                                 12   is_deeply(
632                                                      [$c->get_crc_type($dbh, 'MD5')],
633                                                      [qw(varchar 32)],
634                                                      'Type and length of MD5'
635                                                   );
636                                                   
637                                                   # #############################################################################
638                                                   # Issue 94: Enhance mk-table-checksum, add a --ignorecols option
639                                                   # #############################################################################
640            1                                 15   $sb->load_file('master', 'common/t/samples/issue_94.sql');
641            1                              75725   $t= $tp->parse( $du->get_create_table($dbh, $q, 'test', 'issue_94') );
642            1                                947   my $query = $c->make_checksum_query(
643                                                      db         => 'test',
644                                                      tbl        => 'issue_47',
645                                                      tbl_struct => $t,
646                                                      algorithm  => 'ACCUM',
647                                                      function   => 'CRC32',
648                                                      crc_wid    => 16,
649                                                      crc_type   => 'int',
650                                                      opt_slice  => undef,
651                                                      cols       => undef,
652                                                      sep        => '#',
653                                                      replicate  => undef,
654                                                      precision  => undef,
655                                                      trim       => undef,
656                                                      ignorecols => ['c'],
657                                                   );
658            1                                 11   is($query,
659                                                      'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, \'0\'), CONV(CAST(CRC32(CONCAT(@crc, CRC32(CONCAT_WS(\'#\', `a`, `b`)))) AS UNSIGNED), 10, 16))), 16), 0) AS crc FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/',
660                                                      'Ignores specified columns');
661                                                   
662            1                                 14   $sb->wipe_clean($dbh);
663            1                                  5   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
25    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location           
---------- ----- -------------------
BEGIN          1 TableChecksum.t:10 
BEGIN          1 TableChecksum.t:11 
BEGIN          1 TableChecksum.t:12 
BEGIN          1 TableChecksum.t:14 
BEGIN          1 TableChecksum.t:15 
BEGIN          1 TableChecksum.t:16 
BEGIN          1 TableChecksum.t:17 
BEGIN          1 TableChecksum.t:18 
BEGIN          1 TableChecksum.t:19 
BEGIN          1 TableChecksum.t:20 
BEGIN          1 TableChecksum.t:21 
BEGIN          1 TableChecksum.t:4  
BEGIN          1 TableChecksum.t:9  
__ANON__       1 TableChecksum.t:361
__ANON__       1 TableChecksum.t:41 


