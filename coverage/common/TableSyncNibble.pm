---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncNibble.pm   82.1   66.1   47.4   76.0    n/a  100.0   76.0
Total                          82.1   66.1   47.4   76.0    n/a  100.0   76.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncNibble.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 18:33:05 2009
Finish:       Fri Sep 25 18:33:08 2009

/home/daniel/dev/maatkit/common/TableSyncNibble.pm

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
18                                                    # TableSyncNibble package $Revision: 4748 $
19                                                    # ###########################################################################
20                                                    package TableSyncNibble;
21                                                    # This package implements a moderately complex sync algorithm:
22                                                    # * Prepare to nibble the table (see TableNibbler.pm)
23                                                    # * Fetch the nibble'th next row (say the 500th) from the current row
24                                                    # * Checksum from the current row to the nibble'th as a chunk
25                                                    # * If a nibble differs, make a note to checksum the rows in the nibble (state 1)
26                                                    # * Checksum them (state 2)
27                                                    # * If a row differs, it must be synced
28                                                    # See TableSyncStream for the TableSync interface this conforms to.
29                                                    #
30                                                    # TODO: a variation on this algorithm and benchmark:
31                                                    # * create table __temp(....);
32                                                    # * insert into  __temp(....) select pk_cols, row_checksum limit N;
33                                                    # * select group_checksum(row_checksum) from __temp;
34                                                    # * if they differ, select each row from __temp;
35                                                    # * if rows differ, fetch back and sync as usual.
36                                                    # * truncate and start over.
37                                                    
38             1                    1            10   use strict;
               1                                  2   
               1                                  7   
39             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
40                                                    
41             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
42             1                    1             7   use List::Util qw(max);
               1                                  2   
               1                                 11   
43             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  6   
44                                                    $Data::Dumper::Indent    = 1;
45                                                    $Data::Dumper::Sortkeys  = 1;
46                                                    $Data::Dumper::Quotekeys = 0;
47                                                    
48             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
49                                                    
50                                                    sub new {
51             1                    1            20      my ( $class, %args ) = @_;
52             1                                  6      foreach my $arg ( qw(TableNibbler TableChunker TableParser Quoter) ) {
53    ***      4     50                          18         die "I need a $arg argument" unless defined $args{$arg};
54                                                       }
55             1                                  6      my $self = { %args };
56             1                                 11      return bless $self, $class;
57                                                    }
58                                                    
59                                                    sub name {
60    ***      0                    0             0      return 'Nibble';
61                                                    }
62                                                    
63                                                    # Returns a hash (true) with a chunk_index that can be used to sync
64                                                    # the given tbl_struct.  Else, returns nothing (false) if the table
65                                                    # cannot be synced.  Arguments:
66                                                    #   * tbl_struct    Return value of TableParser::parse()
67                                                    #   * chunk_index   (optional) Index to use for chunking
68                                                    # If chunk_index is given, then it is required so the return value will
69                                                    # only be true if it's the best possible index.  If it's not given, then
70                                                    # the best possible index is returned.  The return value should be passed
71                                                    # back to prepare_to_sync().  -- nibble_index is the same as chunk_index:
72                                                    # both are used to select multiple rows at once in state 0.
73                                                    sub can_sync {
74    ***      0                    0             0      my ( $self, %args ) = @_;
75    ***      0                                  0      foreach my $arg ( qw(tbl_struct) ) {
76    ***      0      0                           0         die "I need a $arg argument" unless defined $args{$arg};
77                                                       }
78                                                    
79                                                       # If there's an index, TableNibbler::generate_asc_stmt() will use it,
80                                                       # so it is an indication that the nibble algorithm will work.
81    ***      0                                  0      my $nibble_index = $self->{TableParser}->find_best_index($args{tbl_struct});
82    ***      0      0                           0      if ( $nibble_index ) {
83    ***      0                                  0         MKDEBUG && _d('Best nibble index:', Dumper($nibble_index));
84    ***      0      0                           0         if ( !$args{tbl_struct}->{keys}->{$nibble_index}->{is_unique} ) {
85    ***      0                                  0            MKDEBUG && _d('Best nibble index is not unique');
86    ***      0                                  0            return;
87                                                          }
88    ***      0      0      0                    0         if ( $args{chunk_index} && $args{chunk_index} ne $nibble_index ) {
89    ***      0                                  0            MKDEBUG && _d('Best nibble index is not requested index',
90                                                                $args{chunk_index});
91    ***      0                                  0            return;
92                                                          }
93                                                       }
94                                                       else {
95    ***      0                                  0         MKDEBUG && _d('No best nibble index returned');
96    ***      0                                  0         return;
97                                                       }
98                                                    
99    ***      0                                  0      MKDEBUG && _d('Can nibble using index', $nibble_index);
100                                                      return (
101   ***      0                                  0         1,
102                                                         chunk_index => $nibble_index,
103                                                         key_cols    => $args{tbl_struct}->{keys}->{$nibble_index}->{cols},
104                                                      );
105                                                   }
106                                                   
107                                                   sub prepare_to_sync {
108            3                    3           173      my ( $self, %args ) = @_;
109            3                                 25      my @required_args = qw(dbh db tbl tbl_struct chunk_index key_cols chunk_size
110                                                                             crc_col ChangeHandler);
111            3                                 15      foreach my $arg ( @required_args ) {
112   ***     27     50                         163         die "I need a $arg argument" unless defined $args{$arg};
113                                                      }
114                                                   
115            3                                 15      $self->{dbh}             = $args{dbh};
116            3                                 15      $self->{crc_col}         = $args{crc_col};
117            3                                 15      $self->{index_hint}      = $args{index_hint};
118            3                                 12      $self->{key_cols}        = $args{key_cols};
119            3                                 43      $self->{chunk_size}      = $self->{TableChunker}->size_to_rows(%args);
120            3                                 15      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
121            3                                 13      $self->{ChangeHandler}   = $args{ChangeHandler};
122                                                   
123            3                                 35      $self->{ChangeHandler}->fetch_back($args{dbh});
124                                                   
125            3                                 35      $self->{sel_stmt} = $self->{TableNibbler}->generate_asc_stmt(
126                                                         %args,
127                                                         index    => $args{chunk_index},  # expects an index arg, not chunk_index
128                                                         asc_only => 1,
129                                                      );
130                                                   
131            3                                 20      $self->{nibble}            = 0;
132            3                                 13      $self->{cached_row}        = undef;
133            3                                 20      $self->{cached_nibble}     = undef;
134            3                                 11      $self->{cached_boundaries} = undef;
135            3                                 14      $self->{state}             = 0;
136                                                   
137            3                                 17      return;
138                                                   }
139                                                   
140                                                   sub uses_checksum {
141   ***      0                    0             0      return 1;
142                                                   }
143                                                   
144                                                   sub set_checksum_queries {
145            1                    1             6      my ( $self, $nibble_sql, $row_sql ) = @_;
146   ***      1     50                           6      die "I need a nibble_sql argument" unless $nibble_sql;
147   ***      1     50                           4      die "I need a row_sql argument" unless $row_sql;
148            1                                  6      $self->{nibble_sql} = $nibble_sql;
149            1                                  6      $self->{row_sql} = $row_sql;
150            1                                  5      return;
151                                                   }
152                                                   
153                                                   sub prepare_sync_cycle {
154   ***      0                    0             0      my ( $self, $host ) = @_;
155   ***      0                                  0      my $sql = 'SET @crc := "", @cnt := 0';
156   ***      0                                  0      MKDEBUG && _d($sql);
157   ***      0                                  0      $host->{dbh}->do($sql);
158   ***      0                                  0      return;
159                                                   }
160                                                   
161                                                   # Returns a SELECT statement that either gets a nibble of rows (state=0) or,
162                                                   # if the last nibble was bad (state=1 or 2), gets the rows in the nibble.
163                                                   # This way we can sync part of the table before moving on to the next part.
164                                                   # Required args: database, table
165                                                   # Optional args: where
166                                                   sub get_sql {
167           12                   12        368747      my ( $self, %args ) = @_;
168           12    100                          75      if ( $self->{state} ) {
169                                                         # Selects the individual rows so that they can be compared.
170            3                                 13         my $q = $self->{Quoter};
171            6                                 29         return 'SELECT /*rows in nibble*/ '
172                                                            . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
173            3                                 17            . join(', ', map { $q->quote($_) } @{$self->key_cols()})
               6                                 28   
174                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
175                                                            . ' FROM ' . $q->quote(@args{qw(database table)})
176                                                            . ' ' . ($self->{index_hint} ? $self->{index_hint} : '')
177                                                            . ' WHERE (' . $self->__get_boundaries(%args) . ')'
178                                                            . ($args{where} ? " AND ($args{where})" : '')
179            3    100                          22            . ' ORDER BY ' . join(', ', map {$q->quote($_) } @{$self->key_cols()});
      ***      3     50                          19   
                    100                               
180                                                      }
181                                                      else {
182                                                         # Selects the rows as a nibble (aka a chunk).
183            9                                 64         my $where = $self->__get_boundaries(%args);
184            8                                130         return $self->{TableChunker}->inject_chunks(
185                                                            database   => $args{database},
186                                                            table      => $args{table},
187                                                            chunks     => [$where],
188                                                            chunk_num  => 0,
189                                                            query      => $self->{nibble_sql},
190                                                            index_hint => $self->{index_hint},
191                                                            where      => [$args{where}],
192                                                         );
193                                                      }
194                                                   }
195                                                   
196                                                   # Returns a WHERE clause for selecting rows in a nibble relative to lower
197                                                   # and upper boundary rows.  Initially neither boundary is defined, so we
198                                                   # get the first upper boundary row and return a clause like:
199                                                   #   WHERE rows < upper_boundary_row1
200                                                   # This selects all "lowest" rows: those before/below the first nibble
201                                                   # boundary.  The upper boundary row is saved (as cached_row) so that on the
202                                                   # next call it becomes the lower boundary and we get the next upper boundary,
203                                                   # resulting in a clause like:
204                                                   #   WHERE rows > cached_row && col < upper_boundary_row2
205                                                   # This process repeats for subsequent calls. Assuming that the source and
206                                                   # destination tables have different data, executing the same query against
207                                                   # them might give back a different boundary row, which is not what we want,
208                                                   # so each boundary needs to be cached until the nibble increases.
209                                                   sub __get_boundaries {
210           12                   12            84      my ( $self, %args ) = @_;
211           12                                 58      my $q = $self->{Quoter};
212           12                                 48      my $s = $self->{sel_stmt};
213           12                                 33      my $lb;   # Lower boundary part of WHERE
214           12                                 33      my $ub;   # Upper boundary part of WHERE
215           12                                 30      my $row;  # Next upper boundary row or cached_row
216                                                   
217           12    100                          72      if ( $self->{cached_boundaries} ) {
218            3                                  8         MKDEBUG && _d('Using cached boundaries');
219            3                                 27         return $self->{cached_boundaries};
220                                                      }
221                                                   
222   ***      9     50     66                   84      if ( $self->{cached_row} && $self->{cached_nibble} == $self->{nibble} ) {
223                                                         # If there's a cached (last) row and the nibble number hasn't increased
224                                                         # then a differing row was found in this nibble.  We re-use its
225                                                         # boundaries so that instead of advancing to the next nibble we'll look
226                                                         # at the row in this nibble (get_sql() will return its SELECT
227                                                         # /*rows in nibble*/ query).
228   ***      0                                  0         MKDEBUG && _d('Using cached row for boundaries');
229   ***      0                                  0         $row = $self->{cached_row};
230                                                      }
231                                                      else {
232            9                                 22         MKDEBUG && _d('Getting next upper boundary row');
233            9                                 33         my $sql;
234            9                                 62         ($sql, $lb) = $self->__make_boundary_sql(%args);  # $lb from outer scope!
235                                                   
236                                                         # Check that $sql will use the index chosen earlier in new().
237                                                         # Only do this for the first nibble.  I assume this will be safe
238                                                         # enough since the WHERE should use the same columns.
239            9    100                          53         if ( $self->{nibble} == 0 ) {
240            4                                 24            my $explain_index = $self->__get_explain_index($sql);
241            4    100    100                   40            if ( ($explain_index || '') ne $s->{index} ) {
242   ***      1     50                          12            die 'Cannot nibble table '.$q->quote($args{database}, $args{table})
243                                                               . " because MySQL chose "
244                                                               . ($explain_index ? "the `$explain_index`" : 'no') . ' index'
245                                                               . " instead of the `$s->{index}` index";
246                                                            }
247                                                         }
248                                                   
249            8                                 21         $row = $self->{dbh}->selectrow_hashref($sql);
250            8                                 57         MKDEBUG && _d($row ? 'Got a row' : "Didn't get a row");
251                                                      }
252                                                   
253            8    100                          39      if ( $row ) {
254                                                         # Add the row to the WHERE clause as the upper boundary.  As such,
255                                                         # the table rows should be <= to this boundary.  (Conversely, for
256                                                         # any lower boundary the table rows should be > the lower boundary.)
257            7                                 24         my $i = 0;
258            7                                 48         $ub   = $s->{boundaries}->{'<='};
259            7                                 94         $ub   =~ s/\?/$q->quote_val($row->{$s->{scols}->[$i++]})/eg;
              21                                150   
260                                                      }
261                                                      else {
262                                                         # This usually happens at the end of the table, after we've nibbled
263                                                         # all the rows.
264            1                                  4         MKDEBUG && _d('No upper boundary');
265            1                                  6         $ub = '1=1';
266                                                      }
267                                                   
268                                                      # If $lb is defined, then this is the 2nd or subsequent nibble and
269                                                      # $ub should be the previous boundary.  Else, this is the first nibble.
270            8    100                          54      my $where = $lb ? "($lb AND $ub)" : $ub;
271                                                   
272            8                                 43      $self->{cached_row}        = $row;
273            8                                 49      $self->{cached_nibble}     = $self->{nibble};
274            8                                 31      $self->{cached_boundaries} = $where;
275                                                   
276            8                                 21      MKDEBUG && _d('WHERE clause:', $where);
277            8                                 67      return $where;
278                                                   }
279                                                   
280                                                   # Returns a SELECT statement for the next upper boundary row and the
281                                                   # lower boundary part of WHERE if this is the 2nd or subsequent nibble.
282                                                   # (The first nibble doesn't have a lower boundary.)  The returned SELECT
283                                                   # is largely responsible for nibbling the table because if the boundaries
284                                                   # are off then the nibble may not advance properly and we'll get stuck
285                                                   # in an infinite loop (issue 96).
286                                                   sub __make_boundary_sql {
287           10                   10        514026      my ( $self, %args ) = @_;
288           10                                 37      my $lb;
289           10                                 44      my $q   = $self->{Quoter};
290           10                                 34      my $s   = $self->{sel_stmt};
291           30                                134      my $sql = "SELECT /*nibble boundary $self->{nibble}*/ "
292   ***     10            50                   63         . join(',', map { $q->quote($_) } @{$s->{cols}})
              10                                 56   
293                                                         . " FROM " . $q->quote($args{database}, $args{table})
294                                                         . ' ' . ($self->{index_hint} || '');
295                                                   
296           10    100                          64      if ( $self->{nibble} ) {
297                                                         # The lower boundaries of the nibble must be defined, based on the last
298                                                         # remembered row.
299            5                                 18         my $tmp = $self->{cached_row};
300            5                                 14         my $i   = 0;
301            5                                 25         $lb     = $s->{boundaries}->{'>'};
302            5                                 37         $lb     =~ s/\?/$q->quote_val($tmp->{$s->{scols}->[$i++]})/eg;
              15                                106   
303            5                                 24         $sql   .= ' WHERE ' . $lb;
304                                                      }
305           10                                 37      $sql .= " ORDER BY " . join(',', map { $q->quote($_) } @{$self->{key_cols}})
              20                                 82   
              10                                 51   
306                                                            . ' LIMIT ' . ($self->{chunk_size} - 1) . ', 1';
307           10                                 27      MKDEBUG && _d('Lower boundary:', $lb);
308           10                                 22      MKDEBUG && _d('Next boundary sql:', $sql);
309           10                                 80      return $sql, $lb;
310                                                   }
311                                                   
312                                                   # Returns just the index value from EXPLAIN for the given query (sql).
313                                                   sub __get_explain_index {
314            4                    4            22      my ( $self, $sql ) = @_;
315   ***      4     50                          18      return unless $sql;
316            4                                 12      my $explain;
317            4                                 14      eval {
318            4                                 73         $explain = $self->{dbh}->selectall_arrayref("EXPLAIN $sql",{Slice => {}});
319                                                      };
320            4    100                          41      if ( $EVAL_ERROR ) {
321            1                                  7         MKDEBUG && _d($EVAL_ERROR);
322            1                                 10         return;
323                                                      }
324            3                                  9      MKDEBUG && _d('EXPLAIN key:', $explain->[0]->{key}); 
325            3                                 28      return $explain->[0]->{key}
326                                                   }
327                                                   
328                                                   sub same_row {
329            4                    4            25      my ( $self, $lr, $rr ) = @_;
330   ***      4    100     33                   31      if ( $self->{state} ) {
      ***            50                               
331            3    100                          31         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
332            1                                  8            $self->{ChangeHandler}->change('UPDATE', $lr, $self->key_cols());
333                                                         }
334                                                      }
335                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
336            1                                  2         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
337            1                                  2         MKDEBUG && _d('Will examine this nibble before moving to next');
338            1                                  6         $self->{state} = 1; # Must examine this nibble row-by-row
339                                                      }
340                                                   }
341                                                   
342                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
343                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
344                                                   # cnt will be 0, but the result set should still come back.
345                                                   sub not_in_right {
346   ***      0                    0             0      my ( $self, $lr ) = @_;
347   ***      0      0                           0      die "Called not_in_right in state 0" unless $self->{state};
348   ***      0                                  0      $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
349                                                   }
350                                                   
351                                                   sub not_in_left {
352            2                    2            10      my ( $self, $rr ) = @_;
353            2    100                          10      die "Called not_in_left in state 0" unless $self->{state};
354            1                                  8      $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
355                                                   }
356                                                   
357                                                   sub done_with_rows {
358            7                    7            34      my ( $self ) = @_;
359            7    100                          49      if ( $self->{state} == 1 ) {
360            1                                  3         $self->{state} = 2;
361            1                                  4         MKDEBUG && _d('Setting state =', $self->{state});
362                                                      }
363                                                      else {
364            6                                 23         $self->{state} = 0;
365            6                                 24         $self->{nibble}++;
366            6                                 28         delete $self->{cached_boundaries};
367            6                                 24         MKDEBUG && _d('Setting state =', $self->{state},
368                                                            ', nibble =', $self->{nibble});
369                                                      }
370                                                   }
371                                                   
372                                                   sub done {
373            2                    2            10      my ( $self ) = @_;
374            2                                  7      MKDEBUG && _d('Done with nibble', $self->{nibble});
375            2                                  5      MKDEBUG && $self->{state} && _d('Nibble differs; must examine rows');
376   ***      2            33                   69      return $self->{state} == 0 && $self->{nibble} && !$self->{cached_row};
      ***                   66                        
377                                                   }
378                                                   
379                                                   sub pending_changes {
380            3                    3            12      my ( $self ) = @_;
381            3    100                          14      if ( $self->{state} ) {
382            2                                205         MKDEBUG && _d('There are pending changes');
383            2                                 15         return 1;
384                                                      }
385                                                      else {
386            1                                  3         MKDEBUG && _d('No pending changes');
387            1                                  6         return 0;
388                                                      }
389                                                   }
390                                                   
391                                                   sub key_cols {
392            9                    9            49      my ( $self ) = @_;
393            9                                 28      my @cols;
394            9    100                          49      if ( $self->{state} == 0 ) {
395            1                                  5         @cols = qw(chunk_num);
396                                                      }
397                                                      else {
398            8                                 31         @cols = @{$self->{key_cols}};
               8                                 53   
399                                                      }
400            9                                 26      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
401            9                                 75      return \@cols;
402                                                   }
403                                                   
404                                                   sub _d {
405   ***      0                    0                    my ($package, undef, $line) = caller 0;
406   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
407   ***      0                                              map { defined $_ ? $_ : 'undef' }
408                                                           @_;
409   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
410                                                   }
411                                                   
412                                                   1;
413                                                   
414                                                   # ###########################################################################
415                                                   # End TableSyncNibble package
416                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
53    ***     50      0      4   unless defined $args{$arg}
76    ***      0      0      0   unless defined $args{$arg}
82    ***      0      0      0   if ($nibble_index) { }
84    ***      0      0      0   if (not $args{'tbl_struct'}{'keys'}{$nibble_index}{'is_unique'})
88    ***      0      0      0   if ($args{'chunk_index'} and $args{'chunk_index'} ne $nibble_index)
112   ***     50      0     27   unless defined $args{$arg}
146   ***     50      0      1   unless $nibble_sql
147   ***     50      0      1   unless $row_sql
168          100      3      9   if ($$self{'state'}) { }
179          100      2      1   $$self{'buffer_in_mysql'} ? :
      ***     50      3      0   $$self{'index_hint'} ? :
             100      2      1   $args{'where'} ? :
217          100      3      9   if ($$self{'cached_boundaries'})
222   ***     50      0      9   if ($$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}) { }
239          100      4      5   if ($$self{'nibble'} == 0)
241          100      1      3   if (($explain_index || '') ne $$s{'index'})
242   ***     50      0      1   $explain_index ? :
253          100      7      1   if ($row) { }
270          100      5      3   $lb ? :
296          100      5      5   if ($$self{'nibble'})
315   ***     50      0      4   unless $sql
320          100      1      3   if ($EVAL_ERROR)
330          100      3      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
331          100      1      2   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
347   ***      0      0      0   unless $$self{'state'}
353          100      1      1   unless $$self{'state'}
359          100      1      6   if ($$self{'state'} == 1) { }
381          100      2      1   if ($$self{'state'}) { }
394          100      1      8   if ($$self{'state'} == 0) { }
406   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
88    ***      0      0      0      0   $args{'chunk_index'} and $args{'chunk_index'} ne $nibble_index
222   ***     66      4      5      0   $$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}
376   ***     33      0      0      2   $$self{'state'} == 0 && $$self{'nibble'}
      ***     66      0      1      1   $$self{'state'} == 0 && $$self{'nibble'} && !$$self{'cached_row'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
241          100      3      1   $explain_index || ''
292   ***     50     10      0   $$self{'index_hint'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
330   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


Covered Subroutines
-------------------

Subroutine           Count Location                                              
-------------------- ----- ------------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:38 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:39 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:41 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:42 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:43 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:48 
__get_boundaries        12 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:210
__get_explain_index      4 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:314
__make_boundary_sql     10 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:287
done                     2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:373
done_with_rows           7 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:358
get_sql                 12 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:167
key_cols                 9 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:392
new                      1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:51 
not_in_left              2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:352
pending_changes          3 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:380
prepare_to_sync          3 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:108
same_row                 4 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:329
set_checksum_queries     1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:145

Uncovered Subroutines
---------------------

Subroutine           Count Location                                              
-------------------- ----- ------------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:405
can_sync                 0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:74 
name                     0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:60 
not_in_right             0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:346
prepare_sync_cycle       0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:154
uses_checksum            0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:141


