---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncNibble.pm   81.9   66.1   47.4   76.0    n/a  100.0   75.9
Total                          81.9   66.1   47.4   76.0    n/a  100.0   75.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncNibble.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Sep 24 23:37:28 2009
Finish:       Thu Sep 24 23:37:31 2009

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
18                                                    # TableSyncNibble package $Revision: 4743 $
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
               1                                  8   
39             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
40                                                    
41             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
42             1                    1             7   use List::Util qw(max);
               1                                  3   
               1                                 10   
43             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  5   
44                                                    $Data::Dumper::Indent    = 1;
45                                                    $Data::Dumper::Sortkeys  = 1;
46                                                    $Data::Dumper::Quotekeys = 0;
47                                                    
48             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  9   
49                                                    
50                                                    sub new {
51             1                    1            18      my ( $class, %args ) = @_;
52             1                                  5      foreach my $arg ( qw(TableNibbler TableChunker TableParser Quoter) ) {
53    ***      4     50                          19         die "I need a $arg argument" unless defined $args{$arg};
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
108            3                    3           149      my ( $self, %args ) = @_;
109            3                                 26      my @required_args = qw(dbh db tbl tbl_struct chunk_index key_cols chunk_size
110                                                                             crc_col ChangeHandler);
111            3                                 16      foreach my $arg ( @required_args ) {
112   ***     27     50                         159         die "I need a $arg argument" unless defined $args{$arg};
113                                                      }
114                                                   
115            3                                 15      $self->{dbh}             = $args{dbh};
116            3                                 15      $self->{crc_col}         = $args{crc_col};
117            3                                 16      $self->{index_hint}      = $args{index_hint};
118            3                                 16      $self->{key_cols}        = $args{key_cols};
119            3                                 43      $self->{chunk_size}      = $self->{TableChunker}->size_to_rows(%args);
120            3                                 15      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
121            3                                 11      $self->{ChangeHandler}   = $args{ChangeHandler};
122                                                   
123            3                                 30      $self->{ChangeHandler}->fetch_back($args{dbh});
124                                                   
125            3                                 40      $self->{sel_stmt} = $self->{TableNibbler}->generate_asc_stmt(
126                                                         %args,
127                                                         index    => $args{chunk_index},  # expects an index arg, not chunk_index
128                                                         asc_only => 1,
129                                                      );
130                                                   
131            3                                 22      $self->{nibble}            = 0;
132            3                                 14      $self->{cached_row}        = undef;
133            3                                 16      $self->{cached_nibble}     = undef;
134            3                                 11      $self->{cached_boundaries} = undef;
135            3                                 12      $self->{state}             = 0;
136                                                   
137            3                                 18      return;
138                                                   }
139                                                   
140                                                   sub uses_checksum {
141   ***      0                    0             0      return 1;
142                                                   }
143                                                   
144                                                   sub set_checksum_queries {
145            1                    1            12      my ( $self, $nibble_sql, $row_sql ) = @_;
146   ***      1     50                           6      die "I need a nibble_sql argument" unless $nibble_sql;
147   ***      1     50                           7      die "I need a row_sql argument" unless $row_sql;
148            1                                  6      $self->{nibble_sql} = $nibble_sql;
149            1                                  7      $self->{row_sql} = $row_sql;
150            1                                  4      return;
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
167           12                   12        490337      my ( $self, %args ) = @_;
168           12                                 62      my $q = $self->{Quoter};
169           12    100                          62      if ( $self->{state} ) {
170                                                         # Selects the individual rows so that they can be compared.
171            6                                 25         return 'SELECT /*rows in nibble*/ '
172                                                            . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
173            3    100                          19            . join(', ', map { $q->quote($_) } @{$self->key_cols()})
      ***      3     50                          16   
                    100                               
174                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
175                                                            . ' FROM ' . $q->quote(@args{qw(database table)})
176                                                            . ' ' . ($self->{index_hint} ? $self->{index_hint} : '')
177                                                            . ' WHERE (' . $self->__get_boundaries(%args) . ')'
178                                                            . ($args{where} ? " AND ($args{where})" : '');
179                                                      }
180                                                      else {
181                                                         # Selects the rows as a nibble (aka a chunk).
182            9                                 58         my $where = $self->__get_boundaries(%args);
183            8                                109         return $self->{TableChunker}->inject_chunks(
184                                                            database   => $args{database},
185                                                            table      => $args{table},
186                                                            chunks     => [$where],
187                                                            chunk_num  => 0,
188                                                            query      => $self->{nibble_sql},
189                                                            index_hint => $self->{index_hint},
190                                                            where      => [$args{where}],
191                                                         );
192                                                      }
193                                                   }
194                                                   
195                                                   # Returns a WHERE clause for selecting rows in a nibble relative to lower
196                                                   # and upper boundary rows.  Initially neither boundary is defined, so we
197                                                   # get the first upper boundary row and return a clause like:
198                                                   #   WHERE rows < upper_boundary_row1
199                                                   # This selects all "lowest" rows: those before/below the first nibble
200                                                   # boundary.  The upper boundary row is saved (as cached_row) so that on the
201                                                   # next call it becomes the lower boundary and we get the next upper boundary,
202                                                   # resulting in a clause like:
203                                                   #   WHERE rows > cached_row && col < upper_boundary_row2
204                                                   # This process repeats for subsequent calls. Assuming that the source and
205                                                   # destination tables have different data, executing the same query against
206                                                   # them might give back a different boundary row, which is not what we want,
207                                                   # so each boundary needs to be cached until the nibble increases.
208                                                   sub __get_boundaries {
209           12                   12            86      my ( $self, %args ) = @_;
210           12                                 55      my $q = $self->{Quoter};
211           12                                 43      my $s = $self->{sel_stmt};
212           12                                 31      my $lb;   # Lower boundary part of WHERE
213           12                                 28      my $ub;   # Upper boundary part of WHERE
214           12                                 31      my $row;  # Next upper boundary row or cached_row
215                                                   
216           12    100                          60      if ( $self->{cached_boundaries} ) {
217            3                                  7         MKDEBUG && _d('Using cached boundaries');
218            3                                 29         return $self->{cached_boundaries};
219                                                      }
220                                                   
221   ***      9     50     66                   86      if ( $self->{cached_row} && $self->{cached_nibble} == $self->{nibble} ) {
222                                                         # If there's a cached (last) row and the nibble number hasn't increased
223                                                         # then a differing row was found in this nibble.  We re-use its
224                                                         # boundaries so that instead of advancing to the next nibble we'll look
225                                                         # at the row in this nibble (get_sql() will return its SELECT
226                                                         # /*rows in nibble*/ query).
227   ***      0                                  0         MKDEBUG && _d('Using cached row for boundaries');
228   ***      0                                  0         $row = $self->{cached_row};
229                                                      }
230                                                      else {
231            9                                 20         MKDEBUG && _d('Getting next upper boundary row');
232            9                                 26         my $sql;
233            9                                 64         ($sql, $lb) = $self->__make_boundary_sql(%args);  # $lb from outer scope!
234                                                   
235                                                         # Check that $sql will use the index chosen earlier in new().
236                                                         # Only do this for the first nibble.  I assume this will be safe
237                                                         # enough since the WHERE should use the same columns.
238            9    100                          55         if ( $self->{nibble} == 0 ) {
239            4                                 25            my $explain_index = $self->__get_explain_index($sql);
240            4    100    100                   40            if ( ($explain_index || '') ne $s->{index} ) {
241   ***      1     50                          12            die 'Cannot nibble table '.$q->quote($args{database}, $args{table})
242                                                               . " because MySQL chose "
243                                                               . ($explain_index ? "the `$explain_index`" : 'no') . ' index'
244                                                               . " instead of the `$s->{index}` index";
245                                                            }
246                                                         }
247                                                   
248            8                                 22         $row = $self->{dbh}->selectrow_hashref($sql);
249            8                                 48         MKDEBUG && _d($row ? 'Got a row' : "Didn't get a row");
250                                                      }
251                                                   
252            8    100                          37      if ( $row ) {
253                                                         # Add the row to the WHERE clause as the upper boundary.  As such,
254                                                         # the table rows should be <= to this boundary.  (Conversely, for
255                                                         # any lower boundary the table rows should be > the lower boundary.)
256            7                                 25         my $i = 0;
257            7                                 44         $ub   = $s->{boundaries}->{'<='};
258            7                                 83         $ub   =~ s/\?/$q->quote_val($row->{$s->{scols}->[$i++]})/eg;
              21                                151   
259                                                      }
260                                                      else {
261                                                         # This usually happens at the end of the table, after we've nibbled
262                                                         # all the rows.
263            1                                  3         MKDEBUG && _d('No upper boundary');
264            1                                  4         $ub = '1=1';
265                                                      }
266                                                   
267                                                      # If $lb is defined, then this is the 2nd or subsequent nibble and
268                                                      # $ub should be the previous boundary.  Else, this is the first nibble.
269            8    100                          52      my $where = $lb ? "($lb AND $ub)" : $ub;
270                                                   
271            8                                 34      $self->{cached_row}        = $row;
272            8                                 45      $self->{cached_nibble}     = $self->{nibble};
273            8                                 31      $self->{cached_boundaries} = $where;
274                                                   
275            8                                 21      MKDEBUG && _d('WHERE clause:', $where);
276            8                                 79      return $where;
277                                                   }
278                                                   
279                                                   # Returns a SELECT statement for the next upper boundary row and the
280                                                   # lower boundary part of WHERE if this is the 2nd or subsequent nibble.
281                                                   # (The first nibble doesn't have a lower boundary.)  The returned SELECT
282                                                   # is largely responsible for nibbling the table because if the boundaries
283                                                   # are off then the nibble may not advance properly and we'll get stuck
284                                                   # in an infinite loop (issue 96).
285                                                   sub __make_boundary_sql {
286           10                   10        483883      my ( $self, %args ) = @_;
287           10                                 32      my $lb;
288           10                                 40      my $q   = $self->{Quoter};
289           10                                 33      my $s   = $self->{sel_stmt};
290           30                                145      my $sql = "SELECT /*nibble boundary $self->{nibble}*/ "
291   ***     10            50                   63         . join(',', map { $q->quote($_) } @{$s->{cols}})
              10                                 55   
292                                                         . " FROM " . $q->quote($args{database}, $args{table})
293                                                         . ' ' . ($self->{index_hint} || '');
294                                                   
295           10    100                          63      if ( $self->{nibble} ) {
296                                                         # The lower boundaries of the nibble must be defined, based on the last
297                                                         # remembered row.
298            5                                 16         my $tmp = $self->{cached_row};
299            5                                 14         my $i   = 0;
300            5                                 28         $lb     = $s->{boundaries}->{'>'};
301            5                                 40         $lb     =~ s/\?/$q->quote_val($tmp->{$s->{scols}->[$i++]})/eg;
              15                                 92   
302            5                                 23         $sql   .= ' WHERE ' . $lb;
303                                                      }
304           10                                 39      $sql .= " ORDER BY " . join(',', map { $q->quote($_) } @{$self->{key_cols}})
              20                                 76   
              10                                 52   
305                                                            . ' LIMIT ' . ($self->{chunk_size} - 1) . ', 1';
306           10                                 30      MKDEBUG && _d('Lower boundary:', $lb);
307           10                                 26      MKDEBUG && _d('Next boundary sql:', $sql);
308           10                                 81      return $sql, $lb;
309                                                   }
310                                                   
311                                                   # Returns just the index value from EXPLAIN for the given query (sql).
312                                                   sub __get_explain_index {
313            4                    4            26      my ( $self, $sql ) = @_;
314   ***      4     50                          19      return unless $sql;
315            4                                  9      my $explain;
316            4                                 16      eval {
317            4                                 74         $explain = $self->{dbh}->selectall_arrayref("EXPLAIN $sql",{Slice => {}});
318                                                      };
319            4    100                          42      if ( $EVAL_ERROR ) {
320            1                                  8         MKDEBUG && _d($EVAL_ERROR);
321            1                                 10         return;
322                                                      }
323            3                                  9      MKDEBUG && _d('EXPLAIN key:', $explain->[0]->{key}); 
324            3                                 26      return $explain->[0]->{key}
325                                                   }
326                                                   
327                                                   sub same_row {
328            4                    4            23      my ( $self, $lr, $rr ) = @_;
329   ***      4    100     33                   27      if ( $self->{state} ) {
      ***            50                               
330            3    100                          28         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
331            1                                  8            $self->{ChangeHandler}->change('UPDATE', $lr, $self->key_cols());
332                                                         }
333                                                      }
334                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
335            1                                  2         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
336            1                                  3         MKDEBUG && _d('Will examine this nibble before moving to next');
337            1                                  4         $self->{state} = 1; # Must examine this nibble row-by-row
338                                                      }
339                                                   }
340                                                   
341                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
342                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
343                                                   # cnt will be 0, but the result set should still come back.
344                                                   sub not_in_right {
345   ***      0                    0             0      my ( $self, $lr ) = @_;
346   ***      0      0                           0      die "Called not_in_right in state 0" unless $self->{state};
347   ***      0                                  0      $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
348                                                   }
349                                                   
350                                                   sub not_in_left {
351            2                    2            10      my ( $self, $rr ) = @_;
352            2    100                         207      die "Called not_in_left in state 0" unless $self->{state};
353            1                                  6      $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
354                                                   }
355                                                   
356                                                   sub done_with_rows {
357            7                    7            33      my ( $self ) = @_;
358            7    100                          43      if ( $self->{state} == 1 ) {
359            1                                  4         $self->{state} = 2;
360            1                                  3         MKDEBUG && _d('Setting state =', $self->{state});
361                                                      }
362                                                      else {
363            6                                 24         $self->{state} = 0;
364            6                                 23         $self->{nibble}++;
365            6                                 26         delete $self->{cached_boundaries};
366            6                                 22         MKDEBUG && _d('Setting state =', $self->{state},
367                                                            ', nibble =', $self->{nibble});
368                                                      }
369                                                   }
370                                                   
371                                                   sub done {
372            2                    2             8      my ( $self ) = @_;
373            2                                  7      MKDEBUG && _d('Done with nibble', $self->{nibble});
374            2                                  5      MKDEBUG && $self->{state} && _d('Nibble differs; must examine rows');
375   ***      2            33                   44      return $self->{state} == 0 && $self->{nibble} && !$self->{cached_row};
      ***                   66                        
376                                                   }
377                                                   
378                                                   sub pending_changes {
379            3                    3            14      my ( $self ) = @_;
380            3    100                          13      if ( $self->{state} ) {
381            2                                  5         MKDEBUG && _d('There are pending changes');
382            2                                 12         return 1;
383                                                      }
384                                                      else {
385            1                                  3         MKDEBUG && _d('No pending changes');
386            1                                  6         return 0;
387                                                      }
388                                                   }
389                                                   
390                                                   sub key_cols {
391            6                    6            26      my ( $self ) = @_;
392            6                                 19      my @cols;
393            6    100                          31      if ( $self->{state} == 0 ) {
394            1                                  4         @cols = qw(chunk_num);
395                                                      }
396                                                      else {
397            5                                 17         @cols = @{$self->{key_cols}};
               5                                 35   
398                                                      }
399            6                                 17      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
400            6                                 52      return \@cols;
401                                                   }
402                                                   
403                                                   sub _d {
404   ***      0                    0                    my ($package, undef, $line) = caller 0;
405   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
406   ***      0                                              map { defined $_ ? $_ : 'undef' }
407                                                           @_;
408   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
409                                                   }
410                                                   
411                                                   1;
412                                                   
413                                                   # ###########################################################################
414                                                   # End TableSyncNibble package
415                                                   # ###########################################################################


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
169          100      3      9   if ($$self{'state'}) { }
173          100      2      1   $$self{'buffer_in_mysql'} ? :
      ***     50      3      0   $$self{'index_hint'} ? :
             100      2      1   $args{'where'} ? :
216          100      3      9   if ($$self{'cached_boundaries'})
221   ***     50      0      9   if ($$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}) { }
238          100      4      5   if ($$self{'nibble'} == 0)
240          100      1      3   if (($explain_index || '') ne $$s{'index'})
241   ***     50      0      1   $explain_index ? :
252          100      7      1   if ($row) { }
269          100      5      3   $lb ? :
295          100      5      5   if ($$self{'nibble'})
314   ***     50      0      4   unless $sql
319          100      1      3   if ($EVAL_ERROR)
329          100      3      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
330          100      1      2   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
346   ***      0      0      0   unless $$self{'state'}
352          100      1      1   unless $$self{'state'}
358          100      1      6   if ($$self{'state'} == 1) { }
380          100      2      1   if ($$self{'state'}) { }
393          100      1      5   if ($$self{'state'} == 0) { }
405   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
88    ***      0      0      0      0   $args{'chunk_index'} and $args{'chunk_index'} ne $nibble_index
221   ***     66      4      5      0   $$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}
375   ***     33      0      0      2   $$self{'state'} == 0 && $$self{'nibble'}
      ***     66      0      1      1   $$self{'state'} == 0 && $$self{'nibble'} && !$$self{'cached_row'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
240          100      3      1   $explain_index || ''
291   ***     50     10      0   $$self{'index_hint'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
329   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


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
__get_boundaries        12 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:209
__get_explain_index      4 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:313
__make_boundary_sql     10 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:286
done                     2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:372
done_with_rows           7 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:357
get_sql                 12 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:167
key_cols                 6 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:391
new                      1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:51 
not_in_left              2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:351
pending_changes          3 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:379
prepare_to_sync          3 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:108
same_row                 4 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:328
set_checksum_queries     1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:145

Uncovered Subroutines
---------------------

Subroutine           Count Location                                              
-------------------- ----- ------------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:404
can_sync                 0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:74 
name                     0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:60 
not_in_right             0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:345
prepare_sync_cycle       0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:154
uses_checksum            0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:141


