---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncNibble.pm   83.0   67.1   58.8   80.0    0.0    1.2   73.8
TableSyncNibble.t              98.4   50.0   33.3  100.0    n/a   98.8   94.0
Total                          90.3   63.8   56.8   89.1    0.0  100.0   81.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:48:44 2010
Finish:       Thu Jun 24 19:48:44 2010

Run:          TableSyncNibble.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:48:46 2010
Finish:       Thu Jun 24 19:48:50 2010

/home/daniel/dev/maatkit/common/TableSyncNibble.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2010 Baron Schwartz.
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
18                                                    # TableSyncNibble package $Revision: 6511 $
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
29                                                    
30             1                    1             4   use strict;
               1                                  3   
               1                                  4   
31             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
32                                                    
33             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
34             1                    1             7   use List::Util qw(max);
               1                                  2   
               1                                 10   
35             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
36                                                    $Data::Dumper::Indent    = 1;
37                                                    $Data::Dumper::Sortkeys  = 1;
38                                                    $Data::Dumper::Quotekeys = 0;
39                                                    
40    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 12   
41                                                    
42                                                    sub new {
43    ***      1                    1      0      8      my ( $class, %args ) = @_;
44             1                                  5      foreach my $arg ( qw(TableNibbler TableChunker TableParser Quoter) ) {
45    ***      4     50                          20         die "I need a $arg argument" unless defined $args{$arg};
46                                                       }
47             1                                  7      my $self = { %args };
48             1                                 12      return bless $self, $class;
49                                                    }
50                                                    
51                                                    sub name {
52    ***      0                    0      0      0      return 'Nibble';
53                                                    }
54                                                    
55                                                    # Returns a hash (true) with a chunk_index that can be used to sync
56                                                    # the given tbl_struct.  Else, returns nothing (false) if the table
57                                                    # cannot be synced.  Arguments:
58                                                    #   * tbl_struct    Return value of TableParser::parse()
59                                                    #   * chunk_index   (optional) Index to use for chunking
60                                                    # If chunk_index is given, then it is required so the return value will
61                                                    # only be true if it's the best possible index.  If it's not given, then
62                                                    # the best possible index is returned.  The return value should be passed
63                                                    # back to prepare_to_sync().  -- nibble_index is the same as chunk_index:
64                                                    # both are used to select multiple rows at once in state 0.
65                                                    sub can_sync {
66    ***      2                    2      0     40      my ( $self, %args ) = @_;
67             2                                 26      foreach my $arg ( qw(tbl_struct) ) {
68    ***      2     50                          26         die "I need a $arg argument" unless defined $args{$arg};
69                                                       }
70                                                    
71                                                       # If there's an index, TableNibbler::generate_asc_stmt() will use it,
72                                                       # so it is an indication that the nibble algorithm will work.
73             2                                 53      my $nibble_index = $self->{TableParser}->find_best_index($args{tbl_struct});
74    ***      2     50                         232      if ( $nibble_index ) {
75             2                                  8         MKDEBUG && _d('Best nibble index:', Dumper($nibble_index));
76    ***      2     50                          24         if ( !$args{tbl_struct}->{keys}->{$nibble_index}->{is_unique} ) {
77    ***      0                                  0            MKDEBUG && _d('Best nibble index is not unique');
78    ***      0                                  0            return;
79                                                          }
80    ***      2     50     33                   26         if ( $args{chunk_index} && $args{chunk_index} ne $nibble_index ) {
81    ***      0                                  0            MKDEBUG && _d('Best nibble index is not requested index',
82                                                                $args{chunk_index});
83    ***      0                                  0            return;
84                                                          }
85                                                       }
86                                                       else {
87    ***      0                                  0         MKDEBUG && _d('No best nibble index returned');
88    ***      0                                  0         return;
89                                                       }
90                                                    
91                                                       # MySQL may choose to use no index for small tables because it's faster.
92                                                       # However, this will cause __get_boundaries() to die with a "Cannot nibble
93                                                       # table" error.  So we check if the table is small and if it is then we
94                                                       # let MySQL do whatever it wants and let ORDER BY keep us safe.
95             2                                  9      my $small_table = 0;
96    ***      2     50     33                   22      if ( $args{src} && $args{src}->{dbh} ) {
97    ***      0                                  0         my $dbh = $args{src}->{dbh};
98    ***      0                                  0         my $db  = $args{src}->{db};
99    ***      0                                  0         my $tbl = $args{src}->{tbl};
100   ***      0                                  0         my $table_status;
101   ***      0                                  0         eval {
102   ***      0                                  0            my $sql = "SHOW TABLE STATUS FROM `$db` LIKE "
103                                                                    . $self->{Quoter}->literal_like($tbl);
104   ***      0                                  0            MKDEBUG && _d($sql);
105   ***      0                                  0            $table_status = $dbh->selectrow_hashref($sql);
106                                                         };
107   ***      0                                  0         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
108   ***      0      0                           0         if ( $table_status ) {
109   ***      0      0                           0            my $n_rows   = defined $table_status->{Rows} ? $table_status->{Rows}
      ***             0                               
110                                                                         : defined $table_status->{rows} ? $table_status->{rows}
111                                                                         : undef;
112   ***      0      0      0                    0            $small_table = 1 if defined $n_rows && $n_rows <= 100;
113                                                         }
114                                                      }
115            2                                  8      MKDEBUG && _d('Small table:', $small_table);
116                                                   
117            2                                  6      MKDEBUG && _d('Can nibble using index', $nibble_index);
118                                                      return (
119            2                                 60         1,
120                                                         chunk_index => $nibble_index,
121                                                         key_cols    => $args{tbl_struct}->{keys}->{$nibble_index}->{cols},
122                                                         small_table => $small_table,
123                                                      );
124                                                   }
125                                                   
126                                                   sub prepare_to_sync {
127   ***      7                    7      0    239      my ( $self, %args ) = @_;
128            7                                117      my @required_args = qw(dbh db tbl tbl_struct chunk_index key_cols chunk_size
129                                                                             crc_col ChangeHandler);
130            7                                 66      foreach my $arg ( @required_args ) {
131   ***     63     50                         463         die "I need a $arg argument" unless defined $args{$arg};
132                                                      }
133                                                   
134            7                                 48      $self->{dbh}             = $args{dbh};
135            7                                 50      $self->{tbl_struct}      = $args{tbl_struct};
136            7                                159      $self->{crc_col}         = $args{crc_col};
137            7                                 48      $self->{index_hint}      = $args{index_hint};
138            7                                 42      $self->{key_cols}        = $args{key_cols};
139            7                                177      ($self->{chunk_size})    = $self->{TableChunker}->size_to_rows(%args);
140            7                               1188      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
141            7                                 45      $self->{small_table}     = $args{small_table};
142            7                                 64      $self->{ChangeHandler}   = $args{ChangeHandler};
143                                                   
144            7                                110      $self->{ChangeHandler}->fetch_back($args{dbh});
145                                                   
146                                                      # Make sure our chunk col is in the list of comparison columns
147                                                      # used by TableChecksum::make_row_checksum() to create $row_sql.
148                                                      # Normally that sub removes dupes, but the code to make boundary
149                                                      # sql does not, so we do it here.
150            7                                864      my %seen;
151            7                                 35      my @ucols = grep { !$seen{$_}++ } @{$args{cols}}, @{$args{key_cols}};
              29                                221   
               7                                 49   
               7                                 44   
152            7                                 53      $args{cols} = \@ucols;
153                                                   
154            7                                175      $self->{sel_stmt} = $self->{TableNibbler}->generate_asc_stmt(
155                                                         %args,
156                                                         index    => $args{chunk_index}, # expects an index arg, not chunk_index
157                                                         asc_only => 1,
158                                                      );
159                                                   
160            7                              16317      $self->{nibble}            = 0;
161            7                                 55      $self->{cached_row}        = undef;
162            7                                 51      $self->{cached_nibble}     = undef;
163            7                                 44      $self->{cached_boundaries} = undef;
164            7                                 42      $self->{state}             = 0;
165                                                   
166            7                                 82      return;
167                                                   }
168                                                   
169                                                   sub uses_checksum {
170   ***      0                    0      0      0      return 1;
171                                                   }
172                                                   
173                                                   sub set_checksum_queries {
174   ***      4                    4      0   5736      my ( $self, $nibble_sql, $row_sql ) = @_;
175   ***      4     50                          64      die "I need a nibble_sql argument" unless $nibble_sql;
176   ***      4     50                          26      die "I need a row_sql argument" unless $row_sql;
177            4                                 26      $self->{nibble_sql} = $nibble_sql;
178            4                                 24      $self->{row_sql} = $row_sql;
179            4                                 27      return;
180                                                   }
181                                                   
182                                                   sub prepare_sync_cycle {
183   ***      0                    0      0      0      my ( $self, $host ) = @_;
184   ***      0                                  0      my $sql = 'SET @crc := "", @cnt := 0';
185   ***      0                                  0      MKDEBUG && _d($sql);
186   ***      0                                  0      $host->{dbh}->do($sql);
187   ***      0                                  0      return;
188                                                   }
189                                                   
190                                                   # Returns a SELECT statement that either gets a nibble of rows (state=0) or,
191                                                   # if the last nibble was bad (state=1 or 2), gets the rows in the nibble.
192                                                   # This way we can sync part of the table before moving on to the next part.
193                                                   # Required args: database, table
194                                                   # Optional args: where
195                                                   sub get_sql {
196   ***     19                   19      0    275      my ( $self, %args ) = @_;
197           19    100                         172      if ( $self->{state} ) {
198                                                         # Selects the individual rows so that they can be compared.
199            4                                 36         my $q = $self->{Quoter};
200            8                                248         return 'SELECT /*rows in nibble*/ '
201                                                            . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
202                                                            . $self->{row_sql} . " AS $self->{crc_col}"
203                                                            . ' FROM ' . $q->quote(@args{qw(database table)})
204                                                            . ' ' . ($self->{index_hint} ? $self->{index_hint} : '')
205                                                            . ' WHERE (' . $self->__get_boundaries(%args) . ')'
206                                                            . ($args{where} ? " AND ($args{where})" : '')
207            4    100                          90            . ' ORDER BY ' . join(', ', map {$q->quote($_) } @{$self->key_cols()});
               4    100                          37   
                    100                               
208                                                      }
209                                                      else {
210                                                         # Selects the rows as a nibble (aka a chunk).
211           15                                187         my $where = $self->__get_boundaries(%args);
212           14                                361         return $self->{TableChunker}->inject_chunks(
213                                                            database   => $args{database},
214                                                            table      => $args{table},
215                                                            chunks     => [ $where ],
216                                                            chunk_num  => 0,
217                                                            query      => $self->{nibble_sql},
218                                                            index_hint => $self->{index_hint},
219                                                            where      => [ $args{where} ],
220                                                         );
221                                                      }
222                                                   }
223                                                   
224                                                   # Returns a WHERE clause for selecting rows in a nibble relative to lower
225                                                   # and upper boundary rows.  Initially neither boundary is defined, so we
226                                                   # get the first upper boundary row and return a clause like:
227                                                   #   WHERE rows < upper_boundary_row1
228                                                   # This selects all "lowest" rows: those before/below the first nibble
229                                                   # boundary.  The upper boundary row is saved (as cached_row) so that on the
230                                                   # next call it becomes the lower boundary and we get the next upper boundary,
231                                                   # resulting in a clause like:
232                                                   #   WHERE rows > cached_row && col < upper_boundary_row2
233                                                   # This process repeats for subsequent calls. Assuming that the source and
234                                                   # destination tables have different data, executing the same query against
235                                                   # them might give back a different boundary row, which is not what we want,
236                                                   # so each boundary needs to be cached until the nibble increases.
237                                                   sub __get_boundaries {
238           19                   19           515      my ( $self, %args ) = @_;
239           19                                145      my $q = $self->{Quoter};
240           19                                115      my $s = $self->{sel_stmt};
241                                                   
242           19                                 73      my $lb;   # Lower boundary part of WHERE
243           19                                 73      my $ub;   # Upper boundary part of WHERE
244           19                                 69      my $row;  # Next upper boundary row or cached_row
245                                                   
246           19    100                         162      if ( $self->{cached_boundaries} ) {
247            4                                 14         MKDEBUG && _d('Using cached boundaries');
248            4                                 59         return $self->{cached_boundaries};
249                                                      }
250                                                   
251   ***     15     50     66                  220      if ( $self->{cached_row} && $self->{cached_nibble} == $self->{nibble} ) {
252                                                         # If there's a cached (last) row and the nibble number hasn't increased
253                                                         # then a differing row was found in this nibble.  We re-use its
254                                                         # boundaries so that instead of advancing to the next nibble we'll look
255                                                         # at the row in this nibble (get_sql() will return its SELECT
256                                                         # /*rows in nibble*/ query).
257   ***      0                                  0         MKDEBUG && _d('Using cached row for boundaries');
258   ***      0                                  0         $row = $self->{cached_row};
259                                                      }
260                                                      else {
261           15                                 51         MKDEBUG && _d('Getting next upper boundary row');
262           15                                 75         my $sql;
263           15                                147         ($sql, $lb) = $self->__make_boundary_sql(%args);  # $lb from outer scope!
264                                                   
265                                                         # Check that $sql will use the index chosen earlier in new().
266                                                         # Only do this for the first nibble.  I assume this will be safe
267                                                         # enough since the WHERE should use the same columns.
268           15    100    100                  452         if ( $self->{nibble} == 0 && !$self->{small_table} ) {
269            7                                 70            my $explain_index = $self->__get_explain_index($sql);
270            7    100    100                  119            if ( lc($explain_index || '') ne lc($s->{index}) ) {
271   ***      1     50                          13               die 'Cannot nibble table '.$q->quote($args{database}, $args{table})
272                                                                  . " because MySQL chose "
273                                                                  . ($explain_index ? "the `$explain_index`" : 'no') . ' index'
274                                                                  . " instead of the `$s->{index}` index";
275                                                            }
276                                                         }
277                                                   
278           14                                 56         $row = $self->{dbh}->selectrow_hashref($sql);
279           14                                145         MKDEBUG && _d($row ? 'Got a row' : "Didn't get a row");
280                                                      }
281                                                   
282           14    100                         102      if ( $row ) {
283                                                         # Add the row to the WHERE clause as the upper boundary.  As such,
284                                                         # the table rows should be <= to this boundary.  (Conversely, for
285                                                         # any lower boundary the table rows should be > the lower boundary.)
286           11                                 57         my $i = 0;
287           11                                104         $ub   = $s->{boundaries}->{'<='};
288           11           100                  217         $ub   =~ s/\?/$q->quote_val($row->{$s->{scols}->[$i]}, $self->{tbl_struct}->{is_numeric}->{$s->{scols}->[$i++]} || 0)/eg;
              33                               1683   
289                                                      }
290                                                      else {
291                                                         # This usually happens at the end of the table, after we've nibbled
292                                                         # all the rows.
293            3                                 14         MKDEBUG && _d('No upper boundary');
294            3                                 18         $ub = '1=1';
295                                                      }
296                                                   
297                                                      # If $lb is defined, then this is the 2nd or subsequent nibble and
298                                                      # $ub should be the previous boundary.  Else, this is the first nibble.
299                                                      # Do not append option where arg here; it is added by the caller.
300           14    100                         555      my $where = $lb ? "($lb AND $ub)" : $ub;
301                                                   
302           14                                 89      $self->{cached_row}        = $row;
303           14                                125      $self->{cached_nibble}     = $self->{nibble};
304           14                                 93      $self->{cached_boundaries} = $where;
305                                                   
306           14                                 49      MKDEBUG && _d('WHERE clause:', $where);
307           14                                153      return $where;
308                                                   }
309                                                   
310                                                   # Returns a SELECT statement for the next upper boundary row and the
311                                                   # lower boundary part of WHERE if this is the 2nd or subsequent nibble.
312                                                   # (The first nibble doesn't have a lower boundary.)  The returned SELECT
313                                                   # is largely responsible for nibbling the table because if the boundaries
314                                                   # are off then the nibble may not advance properly and we'll get stuck
315                                                   # in an infinite loop (issue 96).
316                                                   sub __make_boundary_sql {
317           16                   16           160      my ( $self, %args ) = @_;
318           16                                 74      my $lb;
319           16                                 92      my $q   = $self->{Quoter};
320           16                                 86      my $s   = $self->{sel_stmt};
321           41                               1512      my $sql = "SELECT /*nibble boundary $self->{nibble}*/ "
322           16    100    100                  139         . join(',', map { $q->quote($_) } @{$s->{cols}})
              16                                134   
323                                                         . " FROM " . $q->quote($args{database}, $args{table})
324                                                         . ' ' . ($self->{index_hint} || '')
325                                                         . ($args{where} ? " WHERE ($args{where})" : "");
326                                                   
327           16    100                         146      if ( $self->{nibble} ) {
328                                                         # The lower boundaries of the nibble must be defined, based on the last
329                                                         # remembered row.
330            7                                 40         my $tmp = $self->{cached_row};
331            7                                 33         my $i   = 0;
332            7                                 57         $lb     = $s->{boundaries}->{'>'};
333            7           100                   92         $lb     =~ s/\?/$q->quote_val($tmp->{$s->{scols}->[$i]}, $self->{tbl_struct}->{is_numeric}->{$s->{scols}->[$i++]} || 0)/eg;
              21                                997   
334            7    100                         351         $sql   .= $args{where} ? " AND $lb" : " WHERE $lb";
335                                                      }
336           16                                 84      $sql .= " ORDER BY " . join(',', map { $q->quote($_) } @{$self->{key_cols}})
              31                                854   
              16                                119   
337                                                            . ' LIMIT ' . ($self->{chunk_size} - 1) . ', 1';
338           16                                867      MKDEBUG && _d('Lower boundary:', $lb);
339           16                                 55      MKDEBUG && _d('Next boundary sql:', $sql);
340           16                                209      return $sql, $lb;
341                                                   }
342                                                   
343                                                   # Returns just the index value from EXPLAIN for the given query (sql).
344                                                   sub __get_explain_index {
345            9                    9            88      my ( $self, $sql ) = @_;
346   ***      9     50                          65      return unless $sql;
347            9                                 33      my $explain;
348            9                                 49      eval {
349            9                                211         $explain = $self->{dbh}->selectall_arrayref("EXPLAIN $sql",{Slice => {}});
350                                                      };
351            9    100                         152      if ( $EVAL_ERROR ) {
352            2                                 16         MKDEBUG && _d($EVAL_ERROR);
353            2                                 32         return;
354                                                      }
355            7                                 28      MKDEBUG && _d('EXPLAIN key:', $explain->[0]->{key}); 
356            7                                121      return $explain->[0]->{key};
357                                                   }
358                                                   
359                                                   sub same_row {
360   ***      4                    4      0     45      my ( $self, %args ) = @_;
361            4                                 36      my ($lr, $rr) = @args{qw(lr rr)};
362   ***      4    100     33                   41      if ( $self->{state} ) {
      ***            50                               
363            3    100                          47         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
364            1                                 10            $self->{ChangeHandler}->change('UPDATE', $lr, $self->key_cols());
365                                                         }
366                                                      }
367                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
368            1                                  4         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
369            1                                  5         MKDEBUG && _d('Will examine this nibble before moving to next');
370            1                                 10         $self->{state} = 1; # Must examine this nibble row-by-row
371                                                      }
372                                                   }
373                                                   
374                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
375                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
376                                                   # cnt will be 0, but the result set should still come back.
377                                                   sub not_in_right {
378   ***      0                    0      0      0      my ( $self, %args ) = @_;
379   ***      0      0                           0      die "Called not_in_right in state 0" unless $self->{state};
380   ***      0                                  0      $self->{ChangeHandler}->change('INSERT', $args{lr}, $self->key_cols());
381                                                   }
382                                                   
383                                                   sub not_in_left {
384   ***      2                    2      0     24      my ( $self, %args ) = @_;
385            2    100                          15      die "Called not_in_left in state 0" unless $self->{state};
386            1                                 11      $self->{ChangeHandler}->change('DELETE', $args{rr}, $self->key_cols());
387                                                   }
388                                                   
389                                                   sub done_with_rows {
390   ***      9                    9      0     68      my ( $self ) = @_;
391            9    100                          90      if ( $self->{state} == 1 ) {
392            1                                  6         $self->{state} = 2;
393            1                                  5         MKDEBUG && _d('Setting state =', $self->{state});
394                                                      }
395                                                      else {
396            8                                 47         $self->{state} = 0;
397            8                                 45         $self->{nibble}++;
398            8                                 51         delete $self->{cached_boundaries};
399            8                                 50         MKDEBUG && _d('Setting state =', $self->{state},
400                                                            ', nibble =', $self->{nibble});
401                                                      }
402                                                   }
403                                                   
404                                                   sub done {
405   ***      2                    2      0     14      my ( $self ) = @_;
406            2                                  7      MKDEBUG && _d('Done with nibble', $self->{nibble});
407            2                                  7      MKDEBUG && $self->{state} && _d('Nibble differs; must examine rows');
408   ***      2            33                   77      return $self->{state} == 0 && $self->{nibble} && !$self->{cached_row};
      ***                   66                        
409                                                   }
410                                                   
411                                                   sub pending_changes {
412   ***      3                    3      0     20      my ( $self ) = @_;
413            3    100                          25      if ( $self->{state} ) {
414            2                                  7         MKDEBUG && _d('There are pending changes');
415            2                                 19         return 1;
416                                                      }
417                                                      else {
418            1                                  5         MKDEBUG && _d('No pending changes');
419            1                                 10         return 0;
420                                                      }
421                                                   }
422                                                   
423                                                   sub key_cols {
424   ***      7                    7      0     47      my ( $self ) = @_;
425            7                                 32      my @cols;
426            7    100                          58      if ( $self->{state} == 0 ) {
427            1                                  6         @cols = qw(chunk_num);
428                                                      }
429                                                      else {
430            6                                 27         @cols = @{$self->{key_cols}};
               6                                 62   
431                                                      }
432            7                                 28      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
433            7                                 87      return \@cols;
434                                                   }
435                                                   
436                                                   sub _d {
437   ***      0                    0                    my ($package, undef, $line) = caller 0;
438   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
439   ***      0                                              map { defined $_ ? $_ : 'undef' }
440                                                           @_;
441   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
442                                                   }
443                                                   
444                                                   1;
445                                                   
446                                                   # ###########################################################################
447                                                   # End TableSyncNibble package
448                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0      4   unless defined $args{$arg}
68    ***     50      0      2   unless defined $args{$arg}
74    ***     50      2      0   if ($nibble_index) { }
76    ***     50      0      2   if (not $args{'tbl_struct'}{'keys'}{$nibble_index}{'is_unique'})
80    ***     50      0      2   if ($args{'chunk_index'} and $args{'chunk_index'} ne $nibble_index)
96    ***     50      0      2   if ($args{'src'} and $args{'src'}{'dbh'})
108   ***      0      0      0   if ($table_status)
109   ***      0      0      0   defined $$table_status{'rows'} ? :
      ***      0      0      0   defined $$table_status{'Rows'} ? :
112   ***      0      0      0   if defined $n_rows and $n_rows <= 100
131   ***     50      0     63   unless defined $args{$arg}
175   ***     50      0      4   unless $nibble_sql
176   ***     50      0      4   unless $row_sql
197          100      4     15   if ($$self{'state'}) { }
207          100      2      2   $$self{'buffer_in_mysql'} ? :
             100      3      1   $$self{'index_hint'} ? :
             100      1      3   $args{'where'} ? :
246          100      4     15   if ($$self{'cached_boundaries'})
251   ***     50      0     15   if ($$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}) { }
268          100      7      8   if ($$self{'nibble'} == 0 and not $$self{'small_table'})
270          100      1      6   if (lc($explain_index || '') ne lc $$s{'index'})
271   ***     50      0      1   $explain_index ? :
282          100     11      3   if ($row) { }
300          100      7      7   $lb ? :
322          100      4     12   $args{'where'} ? :
327          100      7      9   if ($$self{'nibble'})
334          100      2      5   $args{'where'} ? :
346   ***     50      0      9   unless $sql
351          100      2      7   if ($EVAL_ERROR)
362          100      3      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
363          100      1      2   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
379   ***      0      0      0   unless $$self{'state'}
385          100      1      1   unless $$self{'state'}
391          100      1      8   if ($$self{'state'} == 1) { }
413          100      2      1   if ($$self{'state'}) { }
426          100      1      6   if ($$self{'state'} == 0) { }
438   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
80    ***     33      2      0      0   $args{'chunk_index'} and $args{'chunk_index'} ne $nibble_index
96    ***     33      2      0      0   $args{'src'} and $args{'src'}{'dbh'}
112   ***      0      0      0      0   defined $n_rows and $n_rows <= 100
251   ***     66      8      7      0   $$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}
268          100      7      1      7   $$self{'nibble'} == 0 and not $$self{'small_table'}
408   ***     33      0      0      2   $$self{'state'} == 0 && $$self{'nibble'}
      ***     66      0      1      1   $$self{'state'} == 0 && $$self{'nibble'} && !$$self{'cached_row'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
40    ***     50      0      1   $ENV{'MKDEBUG'} || 0
270          100      6      1   $explain_index || ''
288          100     26      7   $$self{'tbl_struct'}{'is_numeric'}{$$s{'scols'}[$i++]} || 0
322          100     12      4   $$self{'index_hint'} || ''
333          100     16      5   $$self{'tbl_struct'}{'is_numeric'}{$$s{'scols'}[$i++]} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
362   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                              
-------------------- ----- --- ------------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:30 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:31 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:33 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:34 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:35 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:40 
__get_boundaries        19     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:238
__get_explain_index      9     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:345
__make_boundary_sql     16     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:317
can_sync                 2   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:66 
done                     2   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:405
done_with_rows           9   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:390
get_sql                 19   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:196
key_cols                 7   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:424
new                      1   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:43 
not_in_left              2   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:384
pending_changes          3   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:412
prepare_to_sync          7   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:127
same_row                 4   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:360
set_checksum_queries     4   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:174

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                              
-------------------- ----- --- ------------------------------------------------------
_d                       0     /home/daniel/dev/maatkit/common/TableSyncNibble.pm:437
name                     0   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:52 
not_in_right             0   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:378
prepare_sync_cycle       0   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:183
uses_checksum            0   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:170


TableSyncNibble.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More;
               1                                  4   
               1                                  9   
13                                                    
14             1                    1            15   use DSNParser;
               1                                  3   
               1                                 12   
15             1                    1            13   use Sandbox;
               1                                  3   
               1                                 10   
16             1                    1            12   use TableSyncNibble;
               1                                  3   
               1                                 13   
17             1                    1            11   use Quoter;
               1                                  3   
               1                                 10   
18             1                    1             9   use ChangeHandler;
               1                                  2   
               1                                 11   
19             1                    1            15   use TableChecksum;
               1                                  2   
               1                                 12   
20             1                    1            17   use TableChunker;
               1                                  4   
               1                                 12   
21             1                    1            13   use TableNibbler;
               1                                  2   
               1                                 10   
22             1                    1            28   use TableParser;
               1                                  2   
               1                                 13   
23             1                    1            10   use MySQLDump;
               1                                  2   
               1                                 11   
24             1                    1            10   use VersionParser;
               1                                  5   
               1                                 10   
25             1                    1            10   use MasterSlave;
               1                                  3   
               1                                 14   
26             1                    1            11   use TableSyncer;
               1                                  3   
               1                                 11   
27             1                    1            10   use MaatkitTest;
               1                                  7   
               1                                 36   
28                                                    
29             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
30             1                                237   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
31             1                                 52   my $dbh = $sb->get_dbh_for('master');
32                                                    
33    ***      1     50                         373   if ( !$dbh ) {
34    ***      0                                  0      plan skip_all => 'Cannot connect to sandbox master';
35                                                    }
36                                                    else {
37             1                                  9      plan tests => 36;
38                                                    }
39                                                    
40             1                                280   my $mysql = $sb->_use_for('master');
41                                                    
42             1                                 29   my $q  = new Quoter();
43             1                                 28   my $ms = new MasterSlave();
44             1                                 32   my $tp = new TableParser(Quoter=>$q);
45             1                                 47   my $du = new MySQLDump();
46             1                                 28   my $vp = new VersionParser();
47                                                    
48             1                                 26   my $nibbler = new TableNibbler(
49                                                       TableParser => $tp,
50                                                       Quoter      => $q,
51                                                    );
52             1                                 50   my $checksum = new TableChecksum(
53                                                       Quoter        => $q,
54                                                       VersionParser => $vp,
55                                                    );
56             1                                 44   my $chunker = new TableChunker(
57                                                       MySQLDump => $du,
58                                                       Quoter    => $q
59                                                    );
60             1                                 45   my $t = new TableSyncNibble(
61                                                       TableNibbler  => $nibbler,
62                                                       TableParser   => $tp,
63                                                       TableChunker  => $chunker,
64                                                       Quoter        => $q,
65                                                       VersionParser => $vp,
66                                                    );
67                                                    
68             1                                  3   my @rows;
69                                                    my $ch = new ChangeHandler(
70                                                       Quoter    => $q,
71                                                       right_db  => 'test',
72                                                       right_tbl => 'test1',
73                                                       left_db   => 'test',
74                                                       left_tbl  => 'test1',
75                                                       replace   => 0,
76             1                    2            15      actions   => [ sub { push @rows, $_[0] }, ],
               2                                784   
77                                                       queue     => 0,
78                                                    );
79                                                    
80             1                                211   my $syncer = new TableSyncer(
81                                                       MasterSlave   => $ms,
82                                                       TableChecksum => $checksum,
83                                                       Quoter        => $q,
84                                                       VersionParser => $vp
85                                                    );
86                                                    
87             1                                 56   $sb->create_dbs($dbh, ['test']);
88             1                             519213   diag(`$mysql < $trunk/common/t/samples/before-TableSyncNibble.sql`);
89             1                                 33   my $ddl        = $du->get_create_table($dbh, $q, 'test', 'test1');
90             1                                325   my $tbl_struct = $tp->parse($ddl);
91             1                               1210   my $src = {
92                                                       db  => 'test',
93                                                       tbl => 'test1',
94                                                       dbh => $dbh,
95                                                    };
96             1                                  9   my $dst = {
97                                                       db  => 'test',
98                                                       tbl => 'test1',
99                                                       dbh => $dbh,
100                                                   };
101            1                                 47   my %args       = (
102                                                      src           => $src,
103                                                      dst           => $dst,
104                                                      dbh           => $dbh,
105                                                      db            => 'test',
106                                                      tbl           => 'test1',
107                                                      tbl_struct    => $tbl_struct,
108                                                      cols          => $tbl_struct->{cols},
109                                                      chunk_size    => 1,
110                                                      chunk_index   => 'PRIMARY',
111                                                      key_cols      => $tbl_struct->{keys}->{PRIMARY}->{cols},
112                                                      crc_col       => '__crc',
113                                                      index_hint    => 'USE INDEX (`PRIMARY`)',
114                                                      ChangeHandler => $ch,
115                                                   );
116                                                   
117            1                                 33   $t->prepare_to_sync(%args);
118                                                   # Test with FNV_64 just to make sure there are no errors
119            1                                  7   eval { $dbh->do('select fnv_64(1)') };
               1                                 19   
120   ***      1     50                          26   SKIP: {
121            1                                  9      skip 'No FNV_64 function installed', 1 if $EVAL_ERROR;
122                                                   
123   ***      0                                  0      $t->set_checksum_queries(
124                                                         $syncer->make_checksum_queries(%args, function => 'FNV_64')
125                                                      );
126   ***      0                                  0      is(
127                                                         $t->get_sql(
128                                                            database => 'test',
129                                                            table    => 'test1',
130                                                         ),
131                                                         q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS }
132                                                         . q{cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(FNV_64(`a`, `b`, `c`) AS UNSIGNED)), }
133                                                         . q{10, 16)), 0) AS crc FROM `test`.`test1` USE INDEX (`PRIMARY`) WHERE (((`a` < '1') OR (`a` = '1' }
134                                                         . q{AND `b` <= 'en')))},
135                                                         'First nibble SQL with FNV_64',
136                                                      );
137                                                   }
138                                                   
139                                                   $t->set_checksum_queries(
140            1                                807      $syncer->make_checksum_queries(%args, function => 'SHA1')
141                                                   );
142   ***      1     50                          15   is(
143                                                      $t->get_sql(
144                                                         database => 'test',
145                                                         table    => 'test1',
146                                                      ),
147                                                      ($sandbox_version gt '4.0' ?
148                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
149                                                      . q{COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, }
150                                                      . q{10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(}
151                                                      . q{SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
152                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS('#', `a`, }
153                                                      . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc FROM }
154                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE (((`a` < '1') OR (`a` = '1' AND `b` <= 'en')))} :
155                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
156                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
157                                                      . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', `a`, `b`, `c`)))))), 40), 0) AS crc FROM }
158                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE (((`a` < '1') OR (`a` = '1' AND `b` <= 'en')))}
159                                                      ),
160                                                      'First nibble SQL',
161                                                   );
162                                                   
163   ***      1     50                          15   is(
164                                                      $t->get_sql(
165                                                         database => 'test',
166                                                         table    => 'test1',
167                                                      ),
168                                                      ($sandbox_version gt '4.0' ?
169                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
170                                                      . q{COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, }
171                                                      . q{10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(}
172                                                      . q{SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
173                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS('#', `a`, }
174                                                      . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc FROM }
175                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE (((`a` < '1') OR (`a` = '1' AND `b` <= 'en')))} :
176                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
177                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
178                                                      . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', `a`, `b`, `c`)))))), 40), 0) AS crc FROM }
179                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE (((`a` < '1') OR (`a` = '1' AND `b` <= 'en')))}
180                                                      ),
181                                                      'First nibble SQL, again',
182                                                   );
183                                                   
184            1                                 10   $t->{nibble} = 1;
185            1                                  7   delete $t->{cached_boundaries};
186                                                   
187   ***      1     50                          11   is(
188                                                      $t->get_sql(
189                                                         database => 'test',
190                                                         table    => 'test1',
191                                                      ),
192                                                      ($sandbox_version gt '4.0' ?
193                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
194                                                      . q{COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, }
195                                                      . q{10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(}
196                                                      . q{SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
197                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS('#', `a`, }
198                                                      . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc FROM }
199                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE ((((`a` > '1') OR (`a` = '1' AND `b` > 'en')) AND }
200                                                      . q{((`a` < '2') OR (`a` = '2' AND `b` <= 'ca'))))} :
201                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
202                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
203                                                      . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', `a`, `b`, `c`)))))), 40), 0) AS crc FROM }
204                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE ((((`a` > '1') OR (`a` = '1' AND `b` > 'en')) AND }
205                                                      . q{((`a` < '2') OR (`a` = '2' AND `b` <= 'ca'))))}
206                                                      ),
207                                                      'Second nibble SQL',
208                                                   );
209                                                   
210                                                   # Bump the nibble boundaries ahead until we run off the end of the table.
211            1                                 25   $t->done_with_rows();
212            1                                 10   $t->get_sql(
213                                                         database => 'test',
214                                                         table    => 'test1',
215                                                      );
216            1                                337   $t->done_with_rows();
217            1                                 10   $t->get_sql(
218                                                         database => 'test',
219                                                         table    => 'test1',
220                                                      );
221            1                                351   $t->done_with_rows();
222            1                                 10   $t->get_sql(
223                                                         database => 'test',
224                                                         table    => 'test1',
225                                                      );
226                                                   
227   ***      1     50                         332   is(
228                                                      $t->get_sql(
229                                                         database => 'test',
230                                                         table    => 'test1',
231                                                      ),
232                                                      ($sandbox_version gt '4.0' ?
233                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
234                                                      . q{COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, }
235                                                      . q{10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(}
236                                                      . q{SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), }
237                                                      . q{LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS('#', `a`, }
238                                                      . q{`b`, `c`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc FROM }
239                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE ((((`a` > '4') OR (`a` = '4' AND `b` > 'bz')) AND }
240                                                      . q{1=1))} :
241                                                      q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
242                                                      . q{COALESCE(RIGHT(MAX(@crc := CONCAT(LPAD(@cnt := @cnt + 1, 16, '0'), }
243                                                      . q{SHA1(CONCAT(@crc, SHA1(CONCAT_WS('#', `a`, `b`, `c`)))))), 40), 0) AS crc FROM }
244                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE ((((`a` > '4') OR (`a` = '4' AND `b` > 'bz')) AND }
245                                                      . q{1=1))}
246                                                      ),
247                                                      'End-of-table nibble SQL',
248                                                   );
249                                                   
250            1                                 15   $t->done_with_rows();
251            1                                 16   ok($t->done(), 'Now done');
252                                                   
253                                                   # Throw away and start anew, because it's off the end of the table
254            1                                  8   $t->{nibble} = 0;
255            1                                  5   delete $t->{cached_boundaries};
256            1                                  6   delete $t->{cached_nibble};
257            1                                  7   delete $t->{cached_row};
258                                                   
259            1                                 15   is_deeply($t->key_cols(), [qw(chunk_num)], 'Key cols in state 0');
260            1                                 27   $t->get_sql(
261                                                         database => 'test',
262                                                         table    => 'test1',
263                                                      );
264            1                                323   $t->done_with_rows();
265                                                   
266            1                                  8   is($t->done(), '', 'Not done, because not reached end-of-table');
267                                                   
268                                                   throws_ok(
269            1                    1            38      sub { $t->not_in_left() },
270            1                                 73      qr/in state 0/,
271                                                      'not_in_(side) illegal in state 0',
272                                                   );
273                                                   
274                                                   # Now "find some bad chunks," as it were.
275                                                   
276                                                   # "find a bad row"
277            1                                 46   $t->same_row(
278                                                      lr => { chunk_num => 0, cnt => 0, crc => 'abc' },
279                                                      rr => { chunk_num => 0, cnt => 1, crc => 'abc' },
280                                                   );
281            1                                 11   ok($t->pending_changes(), 'Pending changes found');
282            1                                 12   is($t->{state}, 1, 'Working inside nibble');
283            1                                 10   $t->done_with_rows();
284            1                                 16   is($t->{state}, 2, 'Now in state to fetch individual rows');
285            1                                 10   ok($t->pending_changes(), 'Pending changes not done yet');
286            1                                 13   is($t->get_sql(database => 'test', table => 'test1'),
287                                                      q{SELECT /*rows in nibble*/ `a`, `b`, `c`, SHA1(CONCAT_WS('#', `a`, `b`, `c`)) AS __crc FROM }
288                                                      . q{`test`.`test1` USE INDEX (`PRIMARY`) WHERE ((((`a` > '1') OR (`a` = '1' AND `b` > 'en')) }
289                                                      . q{AND ((`a` < '2') OR (`a` = '2' AND `b` <= 'ca'))))}
290                                                      . q{ ORDER BY `a`, `b`},
291                                                      'SQL now working inside nibble'
292                                                   );
293            1                                 20   ok($t->{state}, 'Still working inside nibble');
294            1                                 12   is(scalar(@rows), 0, 'No bad row triggered');
295                                                   
296            1                                 18   $t->not_in_left(rr => {a => 1, b => 'en'});
297                                                   
298            1                                 50   is_deeply(\@rows,
299                                                      ["DELETE FROM `test`.`test1` WHERE `a`='1' AND `b`='en' LIMIT 1"],
300                                                      'Working inside nibble, got a bad row',
301                                                   );
302                                                   
303                                                   # Shouldn't cause anything to happen
304            1                                 35   $t->same_row(
305                                                      lr => {a => 1, b => 'en', __crc => 'foo'},
306                                                      rr => {a => 1, b => 'en', __crc => 'foo'} );
307                                                   
308            1                                 14   is_deeply(\@rows,
309                                                      ["DELETE FROM `test`.`test1` WHERE `a`='1' AND `b`='en' LIMIT 1"],
310                                                      'No more rows added',
311                                                   );
312                                                   
313            1                                 29   $t->same_row(
314                                                      lr => {a => 1, b => 'en', __crc => 'foo'},
315                                                      rr => {a => 1, b => 'en', __crc => 'bar'} );
316                                                   
317            1                                 49   is_deeply(\@rows,
318                                                      [
319                                                         "DELETE FROM `test`.`test1` WHERE `a`='1' AND `b`='en' LIMIT 1",
320                                                         "UPDATE `test`.`test1` SET `c`='a' WHERE `a`='1' AND `b`='en' LIMIT 1",
321                                                      ],
322                                                      'Row added to update differing row',
323                                                   );
324                                                   
325            1                                 21   $t->done_with_rows();
326            1                                 11   is($t->{state}, 0, 'Now not working inside nibble');
327            1                                 11   is($t->pending_changes(), 0, 'No pending changes');
328                                                   
329                                                   # Now test that SQL_BUFFER_RESULT is in the queries OK
330            1                                 21   $t->prepare_to_sync(%args, buffer_in_mysql=>1);
331            1                                  9   $t->{state} = 1;
332            1                                 12   like(
333                                                      $t->get_sql(
334                                                         database => 'test',
335                                                         table    => 'test1',
336                                                         buffer_in_mysql => 1,
337                                                      ),
338                                                      qr/SELECT ..rows in nibble.. SQL_BUFFER_RESULT/,
339                                                      'Buffering in first nibble',
340                                                   );
341                                                   
342                                                   # "find a bad row"
343            1                                 35   $t->same_row(
344                                                      lr => { chunk_num => 0, cnt => 0, __crc => 'abc' },
345                                                      rr => { chunk_num => 0, cnt => 1, __crc => 'abc' },
346                                                   );
347                                                   
348            1                                 15   like(
349                                                      $t->get_sql(
350                                                         database => 'test',
351                                                         table    => 'test1',
352                                                         buffer_in_mysql => 1,
353                                                      ),
354                                                      qr/SELECT ..rows in nibble.. SQL_BUFFER_RESULT/,
355                                                      'Buffering in next nibble',
356                                                   );
357                                                   
358                                                   # #########################################################################
359                                                   # Issue 96: mk-table-sync: Nibbler infinite loop
360                                                   # #########################################################################
361            1                                 37   $sb->load_file('master', 'common/t/samples/issue_96.sql');
362            1                             827729   $tbl_struct = $tp->parse($du->get_create_table($dbh, $q, 'issue_96', 't'));
363            1                               1559   $t->prepare_to_sync(
364                                                      ChangeHandler  => $ch,
365                                                      cols           => $tbl_struct->{cols},
366                                                      dbh            => $dbh,
367                                                      db             => 'issue_96',
368                                                      tbl            => 't',
369                                                      tbl_struct     => $tbl_struct,
370                                                      chunk_size     => 2,
371                                                      chunk_index    => 'package_id',
372                                                      crc_col        => '__crc_col',
373                                                      index_hint     => 'FORCE INDEX(`package_id`)',
374                                                      key_cols       => $tbl_struct->{keys}->{package_id}->{cols},
375                                                   );
376                                                   
377                                                   # Test that we die if MySQL isn't using the chosen index (package_id)
378                                                   # for the boundary sql.
379                                                   
380            1                                 12   my $sql = "SELECT /*nibble boundary 0*/ `package_id`,`location`,`from_city` FROM `issue_96`.`t` FORCE INDEX(`package_id`) ORDER BY `package_id`,`location` LIMIT 1, 1";
381            1                                 19   is(
382                                                      $t->__get_explain_index($sql),
383                                                      'package_id',
384                                                      '__get_explain_index()'
385                                                   );
386                                                   
387            1                             472076   diag(`/tmp/12345/use -e 'ALTER TABLE issue_96.t DROP INDEX package_id'`);
388                                                   
389            1                                 42   is(
390                                                      $t->__get_explain_index($sql),
391                                                      undef,
392                                                      '__get_explain_index() for nonexistent index'
393                                                   );
394                                                   
395            1                                 16   my %args2 = ( database=>'issue_96', table=>'t' );
396            1                                  4   eval {
397            1                                 22      $t->get_sql(database=>'issue_96', tbl=>'t', %args2);
398                                                   };
399            1                                 72   like(
400                                                      $EVAL_ERROR,
401                                                      qr/^Cannot nibble table `issue_96`.`t` because MySQL chose no index instead of the `package_id` index/,
402                                                      "Die if MySQL doesn't choose our index (issue 96)"
403                                                   );
404                                                   
405                                                   # Restore the index, get the first sql boundary and check that it
406                                                   # has the proper ORDER BY clause which makes MySQL use the index.
407            1                             642809   diag(`/tmp/12345/use -e 'ALTER TABLE issue_96.t ADD UNIQUE INDEX package_id (package_id,location);'`);
408            1                                 17   eval {
409            1                                 42      ($sql,undef) = $t->__make_boundary_sql(%args2);
410                                                   };
411            1                                 24   is(
412                                                      $sql,
413                                                      "SELECT /*nibble boundary 0*/ `package_id`,`location`,`from_city` FROM `issue_96`.`t` FORCE INDEX(`package_id`) ORDER BY `package_id`,`location` LIMIT 1, 1",
414                                                      'Boundary SQL has ORDER BY key columns'
415                                                   );
416                                                   
417                                                   # If small_table is true, the index check should be skipped.
418            1                             108862   diag(`/tmp/12345/use -e 'create table issue_96.t3 (i int, unique index (i))'`);
419            1                              19500   diag(`/tmp/12345/use -e 'insert into issue_96.t3 values (1)'`);
420            1                                 43   $tbl_struct = $tp->parse($du->get_create_table($dbh, $q, 'issue_96', 't3'));
421            1                               1302   $t->prepare_to_sync(
422                                                      ChangeHandler  => $ch,
423                                                      cols           => $tbl_struct->{cols},
424                                                      dbh            => $dbh,
425                                                      db             => 'issue_96',
426                                                      tbl            => 't3',
427                                                      tbl_struct     => $tbl_struct,
428                                                      chunk_size     => 2,
429                                                      chunk_index    => 'i',
430                                                      crc_col        => '__crc_col',
431                                                      index_hint     => 'FORCE INDEX(`i`)',
432                                                      key_cols       => $tbl_struct->{keys}->{i}->{cols},
433                                                      small_table    => 1,
434                                                   );
435            1                                  5   eval {
436            1                                 12      $t->get_sql(database=>'issue_96', table=>'t3');
437                                                   };
438            1                                350   is(
439                                                      $EVAL_ERROR,
440                                                      '',
441                                                      "Skips index check when small table (issue 634)"
442                                                   );
443                                                   
444            1                                  7   my ($can_sync, %plugin_args);
445   ***      1     50                          10   SKIP: {
446            1                                 10      skip "Not tested on MySQL $sandbox_version", 5
447                                                         unless $sandbox_version gt '4.0';
448                                                   
449                                                   # #############################################################################
450                                                   # Issue 560: mk-table-sync generates impossible WHERE
451                                                   # Issue 996: might not chunk inside of mk-table-checksum's boundaries
452                                                   # #############################################################################
453                                                   # Due to issue 996 this test has changed.  Now it *should* use the replicate
454                                                   # boundary provided via the where arg and nibble just inside this boundary.
455                                                   # If it does, then it will prevent the impossible WHERE of issue 560.
456                                                   
457                                                   # The buddy_list table has 500 rows, so when it's chunk into 100 rows this is
458                                                   # chunk 2:
459            1                                  5   my $where = '`player_id` >= 201 AND `player_id` < 301';
460                                                   
461            1                                 21   $sb->load_file('master', 'mk-table-sync/t/samples/issue_560.sql');
462            1                             590666   $tbl_struct = $tp->parse($du->get_create_table($dbh, $q, 'issue_560', 'buddy_list'));
463            1                               1417   (undef, %plugin_args) = $t->can_sync(tbl_struct => $tbl_struct);
464            1                                 23   $t->prepare_to_sync(
465                                                      ChangeHandler  => $ch,
466                                                      cols           => $tbl_struct->{cols},
467                                                      dbh            => $dbh,
468                                                      db             => 'issue_560',
469                                                      tbl            => 'buddy_list',
470                                                      tbl_struct     => $tbl_struct,
471                                                      chunk_size     => 100,
472                                                      crc_col        => '__crc_col',
473                                                      %plugin_args,
474                                                      replicate      => 'issue_560.checksum',
475                                                      where          => $where,  # not used in sub but normally passed so we
476                                                                                 # do the same to simulate a real run
477                                                   );
478                                                   
479                                                   # Must call this else $row_sql will have values from previous test.
480            1                                 28   $t->set_checksum_queries(
481                                                      $syncer->make_checksum_queries(
482                                                         src        => $src,
483                                                         dst        => $dst,
484                                                         tbl_struct => $tbl_struct,
485                                                      )
486                                                   );
487                                                   
488            1                                 13   is(
489                                                      $t->get_sql(
490                                                         where    => $where,
491                                                         database => 'issue_560',
492                                                         table    => 'buddy_list', 
493                                                      ),
494                                                      "SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list`  WHERE (((`player_id` < '300') OR (`player_id` = '300' AND `buddy_id` <= '2085'))) AND (($where))",
495                                                      'Nibble with chunk boundary (chunk sql)'
496                                                   );
497                                                   
498            1                                 10   $t->{state} = 2;
499            1                                 12   is(
500                                                      $t->get_sql(
501                                                         where    => $where,
502                                                         database => 'issue_560',
503                                                         table    => 'buddy_list', 
504                                                      ),
505                                                      "SELECT /*rows in nibble*/ `player_id`, `buddy_id`, CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS __crc_col FROM `issue_560`.`buddy_list`  WHERE (((`player_id` < '300') OR (`player_id` = '300' AND `buddy_id` <= '2085'))) AND ($where) ORDER BY `player_id`, `buddy_id`",
506                                                      'Nibble with chunk boundary (row sql)'
507                                                   );
508                                                   
509            1                                 11   $t->{state} = 0;
510            1                                 14   $t->done_with_rows();
511            1                                 11   is(
512                                                      $t->get_sql(
513                                                         where    => $where,
514                                                         database => 'issue_560',
515                                                         table    => 'buddy_list', 
516                                                      ),
517                                                      "SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list`  WHERE ((((`player_id` > '300') OR (`player_id` = '300' AND `buddy_id` > '2085')) AND 1=1)) AND (($where))",
518                                                      "Next sub-nibble",
519                                                   );
520                                                   
521                                                   # Just like the previous tests but this time the chunk size is 50 so we
522                                                   # should nibble two chunks within the larger range ($where).
523            1                                 24   $t->prepare_to_sync(
524                                                      ChangeHandler  => $ch,
525                                                      cols           => $tbl_struct->{cols},
526                                                      dbh            => $dbh,
527                                                      db             => 'issue_560',
528                                                      tbl            => 'buddy_list',
529                                                      tbl_struct     => $tbl_struct,
530                                                      chunk_size     => 50,              # 2 sub-nibbles
531                                                      crc_col        => '__crc_col',
532                                                      %plugin_args,
533                                                      replicate      => 'issue_560.checksum',
534                                                      where          => $where,  # not used in sub but normally passed so we
535                                                                                 # do the same to simulate a real run
536                                                   );
537                                                   
538                                                   # Must call this else $row_sql will have values from previous test.
539            1                                 15   $t->set_checksum_queries(
540                                                      $syncer->make_checksum_queries(
541                                                         src        => $src,
542                                                         dst        => $dst,
543                                                         tbl_struct => $tbl_struct,
544                                                      )
545                                                   );
546                                                   
547            1                                 10   is(
548                                                      $t->get_sql(
549                                                         where    => $where,
550                                                         database => 'issue_560',
551                                                         table    => 'buddy_list', 
552                                                      ),
553                                                      "SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list`  WHERE (((`player_id` < '250') OR (`player_id` = '250' AND `buddy_id` <= '809'))) AND ((`player_id` >= 201 AND `player_id` < 301))",
554                                                      "Sub-nibble 1"
555                                                   );
556                                                   
557            1                                 14   $t->done_with_rows();
558            1                                 13   is(
559                                                      $t->get_sql(
560                                                         where    => $where,
561                                                         database => 'issue_560',
562                                                         table    => 'buddy_list', 
563                                                      ),
564                                                      "SELECT /*issue_560.buddy_list:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `player_id`, `buddy_id`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_560`.`buddy_list`  WHERE ((((`player_id` > '250') OR (`player_id` = '250' AND `buddy_id` > '809')) AND ((`player_id` < '300') OR (`player_id` = '300' AND `buddy_id` <= '2085')))) AND ((`player_id` >= 201 AND `player_id` < 301))",
565                                                      "Sub-nibble 2"
566                                                   );
567                                                   }
568                                                   
569                                                   # #############################################################################
570                                                   # Issue 804: mk-table-sync: can't nibble because index name isn't lower case?
571                                                   # #############################################################################
572            1                                 25   $sb->load_file('master', 'common/t/samples/issue_804.sql');
573            1                             354831   $tbl_struct = $tp->parse($du->get_create_table($dbh, $q, 'issue_804', 't'));
574            1                               1464   ($can_sync, %plugin_args) = $t->can_sync(tbl_struct => $tbl_struct);
575            1                                 22   is(
576                                                      $can_sync,
577                                                      1,
578                                                      'Can sync issue_804 table'
579                                                   );
580            1                                 28   is_deeply(
581                                                      \%plugin_args,
582                                                      {
583                                                         chunk_index => 'purchases_accountid_purchaseid',
584                                                         key_cols    => [qw(accountid purchaseid)],
585                                                         small_table => 0,
586                                                      },
587                                                      'Plugin args for issue_804 table'
588                                                   );
589                                                   
590            1                                 44   $t->prepare_to_sync(
591                                                      ChangeHandler  => $ch,
592                                                      cols           => $tbl_struct->{cols},
593                                                      dbh            => $dbh,
594                                                      db             => 'issue_804',
595                                                      tbl            => 't',
596                                                      tbl_struct     => $tbl_struct,
597                                                      chunk_size     => 50,
598                                                      chunk_index    => $plugin_args{chunk_index},
599                                                      crc_col        => '__crc_col',
600                                                      index_hint     => 'FORCE INDEX(`'.$plugin_args{chunk_index}.'`)',
601                                                      key_cols       => $tbl_struct->{keys}->{$plugin_args{chunk_index}}->{cols},
602                                                   );
603                                                   
604                                                   # Must call this else $row_sql will have values from previous test.
605            1                                 29   $t->set_checksum_queries(
606                                                      $syncer->make_checksum_queries(
607                                                         src        => $src,
608                                                         dst        => $dst,
609                                                         tbl_struct => $tbl_struct,
610                                                      )
611                                                   );
612                                                   
613                                                   # Before fixing issue 804, the code would die during this call, saying:
614                                                   # Cannot nibble table `issue_804`.`t` because MySQL chose the
615                                                   # `purchases_accountId_purchaseId` index instead of the
616                                                   # `purchases_accountid_purchaseid` index at TableSyncNibble.pm line 284.
617            1                                 10   $sql = $t->get_sql(database=>'issue_804', table=>'t');
618   ***      1     50                         368   is(
619                                                      $sql,
620                                                      ($sandbox_version gt '4.0' ?
621                                                      "SELECT /*issue_804.t:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `accountid`, `purchaseid`)) AS UNSIGNED)), 10, 16)), 0) AS crc FROM `issue_804`.`t` FORCE INDEX(`purchases_accountid_purchaseid`) WHERE (((`accountid` < '49') OR (`accountid` = '49' AND `purchaseid` <= '50')))" :
622                                                      "SELECT /*issue_804.t:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(RIGHT(MAX(\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), MD5(CONCAT(\@crc, MD5(CONCAT_WS('#', `accountid`, `purchaseid`)))))), 32), 0) AS crc FROM `issue_804`.`t` FORCE INDEX(`purchases_accountid_purchaseid`) WHERE (((`accountid` < '49') OR (`accountid` = '49' AND `purchaseid` <= '50')))"
623                                                      ),
624                                                      'SQL nibble for issue_804 table'
625                                                   );
626                                                   
627                                                   # #############################################################################
628                                                   # Done.
629                                                   # #############################################################################
630            1                                 19   $sb->wipe_clean($dbh);
631            1                                  9   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
33    ***     50      0      1   if (not $dbh) { }
120   ***     50      1      0   if $EVAL_ERROR
142   ***     50      1      0   $sandbox_version gt '4.0' ? :
163   ***     50      1      0   $sandbox_version gt '4.0' ? :
187   ***     50      1      0   $sandbox_version gt '4.0' ? :
227   ***     50      1      0   $sandbox_version gt '4.0' ? :
445   ***     50      0      1   unless $sandbox_version gt '4.0'
618   ***     50      1      0   $sandbox_version gt '4.0' ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location             
---------- ----- ---------------------
BEGIN          1 TableSyncNibble.t:10 
BEGIN          1 TableSyncNibble.t:11 
BEGIN          1 TableSyncNibble.t:12 
BEGIN          1 TableSyncNibble.t:14 
BEGIN          1 TableSyncNibble.t:15 
BEGIN          1 TableSyncNibble.t:16 
BEGIN          1 TableSyncNibble.t:17 
BEGIN          1 TableSyncNibble.t:18 
BEGIN          1 TableSyncNibble.t:19 
BEGIN          1 TableSyncNibble.t:20 
BEGIN          1 TableSyncNibble.t:21 
BEGIN          1 TableSyncNibble.t:22 
BEGIN          1 TableSyncNibble.t:23 
BEGIN          1 TableSyncNibble.t:24 
BEGIN          1 TableSyncNibble.t:25 
BEGIN          1 TableSyncNibble.t:26 
BEGIN          1 TableSyncNibble.t:27 
BEGIN          1 TableSyncNibble.t:4  
BEGIN          1 TableSyncNibble.t:9  
__ANON__       1 TableSyncNibble.t:269
__ANON__       2 TableSyncNibble.t:76 


