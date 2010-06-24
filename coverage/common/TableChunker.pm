---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/TableChunker.pm   93.9   70.2   73.7   93.1    0.0    5.5   83.7
TableChunker.t                 99.4   50.0   33.3  100.0    n/a   94.5   92.2
Total                          95.6   68.9   62.3   95.7    0.0  100.0   85.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:35 2010
Finish:       Thu Jun 24 19:37:35 2010

Run:          TableChunker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:37 2010
Finish:       Thu Jun 24 19:37:39 2010

/home/daniel/dev/maatkit/common/TableChunker.pm

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
18                                                    # TableChunker package $Revision: 6492 $
19                                                    # ###########################################################################
20                                                    package TableChunker;
21                                                    
22                                                    # This package helps figure out how to "chunk" a table.  Chunk are
23                                                    # pre-determined ranges of rows defined by boundary values (sometimes also
24                                                    # called endpoints) on numeric or numeric-like columns, including date/time
25                                                    # types.  Any numeric column type that MySQL can do positional comparisons (<,
26                                                    # <=, >, >=) on works.  Chunking over character data is not supported yet (but
27                                                    # see issue 568).  Usually chunks range over all rows in a table but sometimes
28                                                    # they only range over a subset of rows if an optional where arg is passed to
29                                                    # various subs.  In either case a chunk is like "`col` >= 5 AND `col` < 10".  If
30                                                    # col is of type int and is unique, then that chunk ranges over up to 5 rows.
31                                                    # Chunks are included in WHERE clauses by various tools to do work on discrete
32                                                    # chunks of the table instead of trying to work on the entire table at once.
33                                                    # Chunks do not overlap and their size is configurable via the chunk_size arg
34                                                    # passed to several subs.  The chunk_size can be a number of rows or a size like
35                                                    # 1M, in which case it's in estimated bytes of data.  Real chunk sizes are
36                                                    # usually close to the requested chunk_size but unless the optional exact arg is
37                                                    # passed the real chunk sizes are approximate.  Sometimes the distribution of
38                                                    # values on the chunk colun can skew chunking.  If, for example, col has values
39                                                    # 0, 100, 101, ... then the zero value skews chunking.  The zero_chunk arg
40                                                    # handles this.
41                                                    
42             1                    1             4   use strict;
               1                                  3   
               1                                  4   
43             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
44             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
45                                                    
46             1                    1            10   use POSIX qw(ceil);
               1                                  3   
               1                                  8   
47             1                    1             7   use List::Util qw(min max);
               1                                  3   
               1                                 13   
48             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
49                                                    $Data::Dumper::Indent    = 1;
50                                                    $Data::Dumper::Sortkeys  = 1;
51                                                    $Data::Dumper::Quotekeys = 0;
52                                                    
53    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 13   
54                                                    
55                                                    sub new {
56    ***      1                    1      0      7      my ( $class, %args ) = @_;
57             1                                  5      foreach my $arg ( qw(Quoter MySQLDump) ) {
58    ***      2     50                          13         die "I need a $arg argument" unless $args{$arg};
59                                                       }
60             1                                  4      my $self = { %args };
61             1                                 11      return bless $self, $class;
62                                                    }
63                                                    
64                                                    my $EPOCH      = '1970-01-01';
65                                                    my %int_types  = map { $_ => 1 }
66                                                       qw(bigint date datetime int mediumint smallint time timestamp tinyint year);
67                                                    my %real_types = map { $_ => 1 }
68                                                       qw(decimal double float);
69                                                    
70                                                    # Arguments:
71                                                    #   * table_struct    Hashref returned from TableParser::parse
72                                                    #   * exact           (optional) bool: Try to support exact chunk sizes
73                                                    #                     (may still chunk fuzzily)
74                                                    # Returns an array:
75                                                    #   whether the table can be chunked exactly, if requested (zero otherwise)
76                                                    #   arrayref of columns that support chunking
77                                                    sub find_chunk_columns {
78    ***      9                    9      0     95      my ( $self, %args ) = @_;
79             9                                 62      foreach my $arg ( qw(tbl_struct) ) {
80    ***      9     50                          75         die "I need a $arg argument" unless $args{$arg};
81                                                       }
82             9                                 62      my $tbl_struct = $args{tbl_struct};
83                                                    
84                                                       # See if there's an index that will support chunking.
85             9                                 37      my @possible_indexes;
86             9                                 34      foreach my $index ( values %{ $tbl_struct->{keys} } ) {
               9                                 74   
87                                                    
88                                                          # Accept only BTREE indexes.
89    ***     35     50                         219         next unless $index->{type} eq 'BTREE';
90                                                    
91                                                          # Reject indexes with prefixed columns.
92            35           100                   94         defined $_ && next for @{ $index->{col_prefixes} };
              35                                124   
              35                                334   
93                                                    
94                                                          # If exact, accept only unique, single-column indexes.
95            35    100                         203         if ( $args{exact} ) {
96    ***      4    100     66                   25            next unless $index->{is_unique} && @{$index->{cols}} == 1;
               1                                  7   
97                                                          }
98                                                    
99            32                                154         push @possible_indexes, $index;
100                                                      }
101                                                      MKDEBUG && _d('Possible chunk indexes in order:',
102            9                                 30         join(', ', map { $_->{name} } @possible_indexes));
103                                                   
104                                                      # Build list of candidate chunk columns.   
105            9                                 34      my $can_chunk_exact = 0;
106            9                                 38      my @candidate_cols;
107            9                                 43      foreach my $index ( @possible_indexes ) { 
108           32                                172         my $col = $index->{cols}->[0];
109                                                   
110                                                         # Accept only integer or real number type columns.
111   ***     32    100     66                  405         next unless ( $int_types{$tbl_struct->{type_for}->{$col}}
112                                                                       || $real_types{$tbl_struct->{type_for}->{$col}} );
113                                                   
114                                                         # Save the candidate column and its index.
115           24                                226         push @candidate_cols, { column => $col, index => $index->{name} };
116                                                      }
117                                                   
118            9    100    100                   79      $can_chunk_exact = 1 if $args{exact} && scalar @candidate_cols;
119                                                   
120            9                                 29      if ( MKDEBUG ) {
121                                                         my $chunk_type = $args{exact} ? 'Exact' : 'Inexact';
122                                                         _d($chunk_type, 'chunkable:',
123                                                            join(', ', map { "$_->{column} on $_->{index}" } @candidate_cols));
124                                                      }
125                                                   
126                                                      # Order the candidates by their original column order.
127                                                      # Put the PK's first column first, if it's a candidate.
128            9                                 31      my @result;
129            9                                 31      MKDEBUG && _d('Ordering columns by order in tbl, PK first');
130   ***      9     50                          69      if ( $tbl_struct->{keys}->{PRIMARY} ) {
131            9                                 70         my $pk_first_col = $tbl_struct->{keys}->{PRIMARY}->{cols}->[0];
132            9                                 39         @result          = grep { $_->{column} eq $pk_first_col } @candidate_cols;
              24                                152   
133            9                                 43         @candidate_cols  = grep { $_->{column} ne $pk_first_col } @candidate_cols;
              24                                161   
134                                                      }
135            9                                 37      my $i = 0;
136            9                                 32      my %col_pos = map { $_ => $i++ } @{$tbl_struct->{cols}};
             107                                609   
               9                                 59   
137            9                                 35      push @result, sort { $col_pos{$a->{column}} <=> $col_pos{$b->{column}} }
               7                                 52   
138                                                                       @candidate_cols;
139                                                   
140            9                                 46      if ( MKDEBUG ) {
141                                                         _d('Chunkable columns:',
142                                                            join(', ', map { "$_->{column} on $_->{index}" } @result));
143                                                         _d('Can chunk exactly:', $can_chunk_exact);
144                                                      }
145                                                   
146            9                                142      return ($can_chunk_exact, @result);
147                                                   }
148                                                   
149                                                   # Calculate chunks for the given range statistics.  Args min, max and
150                                                   # rows_in_range are returned from get_range_statistics() which is usually
151                                                   # called before this sub.  Min and max are expected to be valid values
152                                                   # (NULL is valid).
153                                                   # Arguments:
154                                                   #   * dbh            dbh
155                                                   #   * db             scalar: database name
156                                                   #   * tbl            scalar: table name
157                                                   #   * tbl_struct     hashref: retval of TableParser::parse()
158                                                   #   * chunk_col      scalar: column name to chunk on
159                                                   #   * min            scalar: min col value
160                                                   #   * max            scalar: max col value
161                                                   #   * rows_in_range  scalar: number of rows to chunk
162                                                   #   * chunk_size     scalar: requested size of each chunk
163                                                   # Optional arguments:
164                                                   #   * exact          bool: use exact chunk_size if true else use approximates
165                                                   #   * tries
166                                                   # Returns a list of WHERE predicates like "`col` >= '10' AND `col` < '20'",
167                                                   # one for each chunk.  All values are single-quoted due to
168                                                   # http://code.google.com/p/maatkit/issues/detail?id=1002
169                                                   sub calculate_chunks {
170   ***     23                   23      0    412      my ( $self, %args ) = @_;
171           23                                261      my @required_args = qw(dbh db tbl tbl_struct chunk_col min max rows_in_range
172                                                                             chunk_size);
173           23                                121      foreach my $arg ( @required_args ) {
174          200    100                        1315         die "I need a $arg argument" unless defined $args{$arg};
175                                                      }
176           22                                 68      MKDEBUG && _d('Calculate chunks for', Dumper(\%args));
177           22                                155      my ($dbh, $db, $tbl) = @args{@required_args};
178           22                                100      my $q        = $self->{Quoter};
179           22                                142      my $db_tbl   = $q->quote($db, $tbl);
180           22                               1132      my $col_type = $args{tbl_struct}->{type_for}->{$args{chunk_col}};
181           22                                 57      MKDEBUG && _d('chunk col type:', $col_type);
182                                                   
183           22                                144      my $range_func = $self->range_func_for($col_type);
184           22                                 75      my ($start_point, $end_point);
185           22                                 75      eval {
186           22                                163         $start_point = $self->value_to_number(
187                                                            value       => $args{min},
188                                                            column_type => $col_type,
189                                                            dbh         => $dbh,
190                                                         );
191           22                                147         $end_point  = $self->value_to_number(
192                                                            value       => $args{max},
193                                                            column_type => $col_type,
194                                                            dbh         => $dbh,
195                                                         );
196                                                      };
197   ***     22     50                         106      if ( $EVAL_ERROR ) {
198   ***      0      0                           0         if ( $EVAL_ERROR =~ m/don't know how to chunk/ ) {
199                                                            # Special kind of error doesn't make sense with the more verbose
200                                                            # description below.
201   ***      0                                  0            die $EVAL_ERROR;
202                                                         }
203                                                         else {
204   ***      0      0                           0            die "Error calculating chunk start and end points for table "
205                                                               . "`$args{tbl_struct}->{name}` on column `$args{chunk_col}` "
206                                                               . "with min/max values "
207                                                               . join('/',
208   ***      0                                  0                     map { defined $args{$_} ? $args{$_} : 'undef' } qw(min max))
209                                                               . ":\n\n"
210                                                               . $EVAL_ERROR
211                                                               . "\nVerify that the min and max values are valid for the column.  "
212                                                               . "If they are valid, this error could be caused by a bug in the "
213                                                               . "tool.";
214                                                         }
215                                                      }
216                                                   
217                                                      # The end points might be NULL in the pathological case that the table
218                                                      # has nothing but NULL values.  If there's at least one non-NULL value
219                                                      # then MIN() and MAX() will return it.  Otherwise, the only thing to do
220                                                      # is make NULL end points zero to make the code below work and any NULL
221                                                      # values will be handled by the special "IS NULL" chunk.
222           22    100                         105      if ( !defined $start_point ) {
223            1                                  3         MKDEBUG && _d('Start point is undefined');
224            1                                  4         $start_point = 0;
225                                                      }
226   ***     22     50     33                  302      if ( !defined $end_point || $end_point < $start_point ) {
227   ***      0                                  0         MKDEBUG && _d('End point is undefined or before start point');
228   ***      0                                  0         $end_point = 0;
229                                                      }
230           22                                 62      MKDEBUG && _d("Actual chunk range:", $start_point, "to", $end_point);
231                                                   
232                                                      # Determine if we can include a zero chunk (col = 0).  If yes, then
233                                                      # make sure the start point is non-zero.
234           22                                 79      my $have_zero_chunk = 0;
235           22    100                         122      if ( $args{zero_chunk} ) {
236   ***      6    100     66                  106         if ( $start_point != $end_point && $start_point >= 0 ) {
237            4                                 15            MKDEBUG && _d('Zero chunking');
238            4                                 78            my $nonzero_val = $self->get_nonzero_value(
239                                                               %args,
240                                                               db_tbl   => $db_tbl,
241                                                               col      => $args{chunk_col},
242                                                               col_type => $col_type,
243                                                               val      => $args{min}
244                                                            );
245                                                            # Since we called value_to_number() before with this column type
246                                                            # we shouldn't have to worry about it dying here--it would have
247                                                            # died earlier if we can't chunk the column type.
248            4                                 48            $start_point = $self->value_to_number(
249                                                               value       => $nonzero_val,
250                                                               column_type => $col_type,
251                                                               dbh         => $dbh,
252                                                            );
253            4                                 22            $have_zero_chunk = 1;
254                                                         }
255                                                         else {
256            2                                 10            MKDEBUG && _d("Cannot zero chunk");
257                                                         }
258                                                      }
259           22                                 55      MKDEBUG && _d("Using chunk range:", $start_point, "to", $end_point);
260                                                   
261                                                      # Calculate the chunk size in terms of "distance between endpoints"
262                                                      # that will give approximately the right number of rows between the
263                                                      # endpoints.  If possible and requested, forbid chunks from being any
264                                                      # bigger than specified.
265           22                                186      my $interval = $args{chunk_size}
266                                                                   * ($end_point - $start_point)
267                                                                   / $args{rows_in_range};
268           22    100                         124      if ( $int_types{$col_type} ) {
269           17                                142         $interval = ceil($interval);
270                                                      }
271           22           100                  112      $interval ||= $args{chunk_size};
272   ***     22     50                         114      if ( $args{exact} ) {
273   ***      0                                  0         $interval = $args{chunk_size};
274                                                      }
275           22                                 56      MKDEBUG && _d('Chunk interval:', $interval, 'units');
276                                                   
277                                                      # Generate a list of chunk boundaries.  The first and last chunks are
278                                                      # inclusive, and will catch any rows before or after the end of the
279                                                      # supposed range.  So 1-100 divided into chunks of 30 should actually end
280                                                      # up with chunks like this:
281                                                      #           < 30
282                                                      # >= 30 AND < 60
283                                                      # >= 60 AND < 90
284                                                      # >= 90
285                                                      # If zero_chunk was specified and zero chunking was possible, the first
286                                                      # chunk will be = 0 to catch any zero or zero-equivalent (e.g. 00:00:00)
287                                                      # rows.
288           22                                 66      my @chunks;
289           22                                145      my $col = $q->quote($args{chunk_col});
290           22    100                         843      if ( $start_point < $end_point ) {
291                                                   
292                                                         # The zero chunk, if there is one.  It doesn't have to be the first
293                                                         # chunk.  The 0 cannot be quoted because if d='0000-00-00' then
294                                                         # d=0 will work but d='0' will cause warning 1292: Incorrect date
295                                                         # value: '0' for column 'd'.  This might have to column-specific in
296                                                         # future when we chunk on more exotic column types.
297           21    100                         110         push @chunks, "$col = 0" if $have_zero_chunk;
298                                                   
299           21                                 73         my ( $beg, $end );
300           21                                 70         my $iter = 0;
301                                                         for ( my $i = $start_point; $i < $end_point; $i += $interval ) {
302           66                               1105            ( $beg, $end ) = $self->$range_func($dbh, $i, $interval, $end_point);
303                                                   
304                                                            # The first chunk.
305           65    100                        4735            if ( $iter++ == 0 ) {
306           20    100                         206               push @chunks,
307                                                                  ($have_zero_chunk ? "$col > 0 AND " : "")
308                                                                  ."$col < " . $q->quote_val($end);
309                                                            }
310                                                            else {
311                                                               # The normal case is a chunk in the middle of the range somewhere.
312           45                                322               push @chunks, "$col >= " . $q->quote_val($beg) . " AND $col < " . $q->quote_val($end);
313                                                            }
314           21                                 72         }
315                                                   
316                                                         # Remove the last chunk and replace it with one that matches everything
317                                                         # from the beginning of the last chunk to infinity.  If the chunk column
318                                                         # is nullable, do NULL separately.
319           20                                149         my $nullable = $args{tbl_struct}->{is_nullable}->{$args{chunk_col}};
320           20                                 70         pop @chunks;
321           20    100                          95         if ( @chunks ) {
322           19                                124            push @chunks, "$col >= " . $q->quote_val($beg);
323                                                         }
324                                                         else {
325   ***      1     50                           6            push @chunks, $nullable ? "$col IS NOT NULL" : '1=1';
326                                                         }
327           20    100                         571         if ( $nullable ) {
328            2                                 11            push @chunks, "$col IS NULL";
329                                                         }
330                                                      }
331                                                      else {
332                                                         # There are no chunks; just do the whole table in one chunk.
333            1                                  3         MKDEBUG && _d('No chunks; using single chunk 1=1');
334            1                                  3         push @chunks, '1=1';
335                                                      }
336                                                   
337           21                                303      return @chunks;
338                                                   }
339                                                   
340                                                   # Arguments:
341                                                   #   * tbl_struct  hashref: return val from TableParser::parse()
342                                                   # Optional arguments:
343                                                   #   * chunk_column  scalar: preferred chunkable column name
344                                                   #   * chunk_index   scalar: preferred chunkable column index name
345                                                   #   * exact         bool: passed to find_chunk_columns()
346                                                   # Returns the first sane chunkable column and index.  "Sane" means that
347                                                   # the first auto-detected chunk col/index are used if any combination of
348                                                   # preferred chunk col or index would be really bad, like chunk col=x
349                                                   # and chunk index=some index over (y, z).  That's bad because the index
350                                                   # doesn't include the column; it would also be bad if the column wasn't
351                                                   # a left-most prefix of the index.
352                                                   sub get_first_chunkable_column {
353   ***      5                    5      0     62      my ( $self, %args ) = @_;
354            5                                 34      foreach my $arg ( qw(tbl_struct) ) {
355   ***      5     50                          55         die "I need a $arg argument" unless $args{$arg};
356                                                      }
357                                                   
358                                                      # First auto-detected chunk col/index.  If any combination of preferred 
359                                                      # chunk col or index are specified and are sane, they will overwrite
360                                                      # these defaults.  Else, these defaults will be returned.
361            5                                 57      my ($exact, @cols) = $self->find_chunk_columns(%args);
362            5                                 40      my $col = $cols[0]->{column};
363            5                                 27      my $idx = $cols[0]->{index};
364                                                   
365                                                      # Wanted/preferred chunk column and index.  Caller only gets what
366                                                      # they want, though, if it results in a sane col/index pair.
367            5                                 27      my $wanted_col = $args{chunk_column};
368            5                                 24      my $wanted_idx = $args{chunk_index};
369            5                                 16      MKDEBUG && _d("Preferred chunk col/idx:", $wanted_col, $wanted_idx);
370                                                   
371            5    100    100                   75      if ( $wanted_col && $wanted_idx ) {
                    100                               
                    100                               
372                                                         # Preferred column and index: check that the pair is sane.
373            2                                 12         foreach my $chunkable_col ( @cols ) {
374            5    100    100                   81            if (    $wanted_col eq $chunkable_col->{column}
375                                                                 && $wanted_idx eq $chunkable_col->{index} ) {
376                                                               # The wanted column is chunkable with the wanted index.
377            1                                  5               $col = $wanted_col;
378            1                                  5               $idx = $wanted_idx;
379            1                                  6               last;
380                                                            }
381                                                         }
382                                                      }
383                                                      elsif ( $wanted_col ) {
384                                                         # Preferred column, no index: check if column is chunkable, if yes
385                                                         # then use its index, else fall back to default col/index.
386            1                                  6         foreach my $chunkable_col ( @cols ) {
387            2    100                          18            if ( $wanted_col eq $chunkable_col->{column} ) {
388                                                               # The wanted column is chunkable, so use its index and overwrite
389                                                               # the defaults.
390            1                                  5               $col = $wanted_col;
391            1                                 15               $idx = $chunkable_col->{index};
392            1                                  7               last;
393                                                            }
394                                                         }
395                                                      }
396                                                      elsif ( $wanted_idx ) {
397                                                         # Preferred index, no column: check if index's left-most column is
398                                                         # chunkable, if yes then use its column, else fall back to auto-detected
399                                                         # col/index.
400            1                                  7         foreach my $chunkable_col ( @cols ) {
401            3    100                          24            if ( $wanted_idx eq $chunkable_col->{index} ) {
402                                                               # The wanted index has a chunkable column, so use it and overwrite
403                                                               # the defaults.
404            1                                  7               $col = $chunkable_col->{column};
405            1                                  4               $idx = $wanted_idx;
406            1                                  5               last;
407                                                            }
408                                                         }
409                                                      }
410                                                   
411            5                                 16      MKDEBUG && _d('First chunkable col/index:', $col, $idx);
412            5                                 94      return $col, $idx;
413                                                   }
414                                                   
415                                                   # Convert a size in rows or bytes to a number of rows in the table, using SHOW
416                                                   # TABLE STATUS.  If the size is a string with a suffix of M/G/k, interpret it as
417                                                   # mebibytes, gibibytes, or kibibytes respectively.  If it's just a number, treat
418                                                   # it as a number of rows and return right away.
419                                                   # Returns an array: number of rows, average row size.
420                                                   sub size_to_rows {
421   ***      5                    5      0     48      my ( $self, %args ) = @_;
422            5                                 30      my @required_args = qw(dbh db tbl chunk_size);
423            5                                 19      foreach my $arg ( @required_args ) {
424   ***     20     50                          98         die "I need a $arg argument" unless $args{$arg};
425                                                      }
426            5                                 29      my ($dbh, $db, $tbl, $chunk_size) = @args{@required_args};
427            5                                 19      my $q  = $self->{Quoter};
428            5                                 21      my $du = $self->{MySQLDump};
429                                                   
430            5                                 17      my ($n_rows, $avg_row_length);
431                                                   
432            5                                 43      my ( $num, $suffix ) = $chunk_size =~ m/^(\d+)([MGk])?$/;
433            5    100                          28      if ( $suffix ) { # Convert to bytes.
                    100                               
434   ***      2      0                          25         $chunk_size = $suffix eq 'k' ? $num * 1_024
      ***            50                               
435                                                                     : $suffix eq 'M' ? $num * 1_024 * 1_024
436                                                                     :                  $num * 1_024 * 1_024 * 1_024;
437                                                      }
438                                                      elsif ( $num ) {
439            2                                  7         $n_rows = $num;
440                                                      }
441                                                      else {
442            1                                  3         die "Invalid chunk size $chunk_size; must be an integer "
443                                                            . "with optional suffix kMG";
444                                                      }
445                                                   
446            4    100    100                   36      if ( $suffix || $args{avg_row_length} ) {
447            3                                 27         my ($status) = $du->get_table_status($dbh, $q, $db, $tbl);
448            3                                447         $avg_row_length = $status->{avg_row_length};
449            3    100                          20         if ( !defined $n_rows ) {
450   ***      2     50                          32            $n_rows = $avg_row_length ? ceil($chunk_size / $avg_row_length) : undef;
451                                                         }
452                                                      }
453                                                   
454            4                                 38      return $n_rows, $avg_row_length;
455                                                   }
456                                                   
457                                                   # Determine the range of values for the chunk_col column on this table.
458                                                   # Arguments:
459                                                   #   * dbh        dbh
460                                                   #   * db         scalar: database name
461                                                   #   * tbl        scalar: table name
462                                                   #   * chunk_col  scalar: column name to chunk on
463                                                   #   * tbl_struct hashref: retval of TableParser::parse()
464                                                   # Optional arguments:
465                                                   #   * where      scalar: WHERE clause without "WHERE" to restrict range
466                                                   #   * index_hint scalar: "FORCE INDEX (...)" clause
467                                                   #   * tries      scalar: number of tries to get next real value
468                                                   # Returns an array:
469                                                   #   * min row value
470                                                   #   * max row values
471                                                   #   * rows in range (given optional where)
472                                                   sub get_range_statistics {
473   ***     12                   12      0    246      my ( $self, %args ) = @_;
474           12                                123      my @required_args = qw(dbh db tbl chunk_col tbl_struct);
475           12                                 79      foreach my $arg ( @required_args ) {
476   ***     60     50                         434         die "I need a $arg argument" unless $args{$arg};
477                                                      }
478           12                                120      my ($dbh, $db, $tbl, $col) = @args{@required_args};
479           12                                 58      my $where = $args{where};
480           12                                 76      my $q     = $self->{Quoter};
481                                                   
482           12                                 84      my $col_type       = $args{tbl_struct}->{type_for}->{$col};
483           12                                 83      my $col_is_numeric = $args{tbl_struct}->{is_numeric}->{$col};
484                                                   
485                                                      # Quote these once so we don't have to do it again. 
486           12                                102      my $db_tbl = $q->quote($db, $tbl);
487           12                               2648      $col       = $q->quote($col);
488                                                   
489           12                                513      my ($min, $max);
490           12                                 53      eval {
491                                                         # First get the actual end points, whatever MySQL considers the
492                                                         # min and max values to be for this column.
493   ***     12     50                         191         my $sql = "SELECT MIN($col), MAX($col) FROM $db_tbl"
                    100                               
494                                                                 . ($args{index_hint} ? " $args{index_hint}" : "")
495                                                                 . ($where ? " WHERE ($where)" : '');
496           12                                 39         MKDEBUG && _d($dbh, $sql);
497           12                                 37         ($min, $max) = $dbh->selectrow_array($sql);
498           11                               3505         MKDEBUG && _d("Actual end points:", $min, $max);
499                                                   
500                                                         # Now, for two reasons, get the valid end points.  For one, an
501                                                         # end point may be 0 or some zero-equivalent and the user doesn't
502                                                         # want that because it skews the range.  Or two, an end point may
503                                                         # be an invalid value like date 2010-00-00 and we can't use that.
504           11                                210         ($min, $max) = $self->get_valid_end_points(
505                                                            %args,
506                                                            dbh      => $dbh,
507                                                            db_tbl   => $db_tbl,
508                                                            col      => $col,
509                                                            col_type => $col_type,
510                                                            min      => $min,
511                                                            max      => $max,
512                                                         );
513           10                                 51         MKDEBUG && _d("Valid end points:", $min, $max);
514                                                      };
515           12    100                         107      if ( $EVAL_ERROR ) {
516            2                                  7         die "Error getting min and max values for table $db_tbl "
517                                                            . "on column $col: $EVAL_ERROR";
518                                                      }
519                                                   
520                                                      # Finally get the total number of rows in range, usually the whole
521                                                      # table unless there's a where arg restricting the range.
522   ***     10     50                         128      my $sql = "EXPLAIN SELECT * FROM $db_tbl"
      ***            50                               
523                                                              . ($args{index_hint} ? " $args{index_hint}" : "")
524                                                              . ($where ? " WHERE $where" : '');
525           10                                 35      MKDEBUG && _d($sql);
526           10                                 37      my $expl = $dbh->selectrow_hashref($sql);
527                                                   
528                                                      return (
529           10                                352         min           => $min,
530                                                         max           => $max,
531                                                         rows_in_range => $expl->{rows},
532                                                      );
533                                                   }
534                                                   
535                                                   # Takes a query prototype and fills in placeholders.  The 'where' arg should be
536                                                   # an arrayref of WHERE clauses that will be joined with AND.
537                                                   sub inject_chunks {
538   ***      4                    4      0     54      my ( $self, %args ) = @_;
539            4                                 25      foreach my $arg ( qw(database table chunks chunk_num query) ) {
540   ***     20     50                          97         die "I need a $arg argument" unless defined $args{$arg};
541                                                      }
542            4                                 11      MKDEBUG && _d('Injecting chunk', $args{chunk_num});
543            4                                 20      my $query   = $args{query};
544            4                                 26      my $comment = sprintf("/*%s.%s:%d/%d*/",
545                                                         $args{database}, $args{table},
546            4                                 24         $args{chunk_num} + 1, scalar @{$args{chunks}});
547            4                                 25      $query =~ s!/\*PROGRESS_COMMENT\*/!$comment!;
548            4                                 24      my $where = "WHERE (" . $args{chunks}->[$args{chunk_num}] . ')';
549   ***      4    100     66                   43      if ( $args{where} && grep { $_ } @{$args{where}} ) {
               5                                 27   
               4                                 24   
550            4                                 22         $where .= " AND ("
551            3                                 10            . join(" AND ", map { "($_)" } grep { $_ } @{$args{where}} )
               5                                 16   
               3                                 12   
552                                                            . ")";
553                                                      }
554            4                                 34      my $db_tbl     = $self->{Quoter}->quote(@args{qw(database table)});
555            4           100                  183      my $index_hint = $args{index_hint} || '';
556                                                   
557            4                                 13      MKDEBUG && _d('Parameters:',
558                                                         Dumper({WHERE => $where, DB_TBL => $db_tbl, INDEX_HINT => $index_hint}));
559            4                                 31      $query =~ s!/\*WHERE\*/! $where!;
560            4                                 15      $query =~ s!/\*DB_TBL\*/!$db_tbl!;
561            4                                 17      $query =~ s!/\*INDEX_HINT\*/! $index_hint!;
562            4                                 28      $query =~ s!/\*CHUNK_NUM\*/! $args{chunk_num} AS chunk_num,!;
563                                                   
564            4                                 39      return $query;
565                                                   }
566                                                   
567                                                   # #############################################################################
568                                                   # MySQL value to Perl number conversion.
569                                                   # #############################################################################
570                                                   
571                                                   # Convert a MySQL column value to a Perl integer.
572                                                   # Arguments:
573                                                   #   * value       scalar: MySQL value to convert
574                                                   #   * column_type scalar: MySQL column type of the value
575                                                   #   * dbh         dbh
576                                                   # Returns an integer or undef if the value isn't convertible
577                                                   # (e.g. date 0000-00-00 is not convertible).
578                                                   sub value_to_number {
579   ***     48                   48      0    439      my ( $self, %args ) = @_;
580           48                                285      my @required_args = qw(value column_type dbh);
581           48                                348      foreach my $arg ( @required_args ) {
582   ***    144     50                         844         die "I need a $arg argument" unless defined $args{$arg};
583                                                      }
584           48                                285      my ($val, $col_type, $dbh) = @args{@required_args};
585           48                                129      MKDEBUG && _d('Converting MySQL', $col_type, $val);
586                                                   
587                                                      # MySQL functions to convert a non-numeric value to a number
588                                                      # so we can do basic math on it in Perl.  Right now we just
589                                                      # convert temporal values but later we'll need to convert char
590                                                      # and hex values.
591           48                                379      my %mysql_conv_func_for = (
592                                                         timestamp => 'UNIX_TIMESTAMP',
593                                                         date      => 'TO_DAYS',
594                                                         time      => 'TIME_TO_SEC',
595                                                         datetime  => 'TO_DAYS',
596                                                      );
597                                                   
598                                                      # Convert the value to a number that Perl can do arithmetic with.
599           48                                132      my $num;
600           48    100                         492      if ( $col_type =~ m/(?:int|year|float|double|decimal)$/ ) {
                    100                               
      ***            50                               
601                                                         # These types are already numbers.
602           28                                103         $num = $val;
603                                                      }
604                                                      elsif ( $col_type =~ m/^(?:timestamp|date|time)$/ ) {
605                                                         # These are temporal values.  Convert them using a MySQL func.
606           11                                 43         my $func = $mysql_conv_func_for{$col_type};
607           11                                 54         my $sql = "SELECT $func(?)";
608           11                                 30         MKDEBUG && _d($dbh, $sql, $val);
609           11                                 35         my $sth = $dbh->prepare($sql);
610           11                               1769         $sth->execute($val);
611           11                                366         ($num) = $sth->fetchrow_array();
612                                                      }
613                                                      elsif ( $col_type eq 'datetime' ) {
614                                                         # This type is temporal, too, but needs special handling.
615                                                         # Newer versions of MySQL could use TIMESTAMPDIFF, but it's easier
616                                                         # to maintain just one kind of code, so I do it all with DATE_ADD().
617            9                                 74         $num = $self->timestampdiff($dbh, $val);
618                                                      }
619                                                      else {
620   ***      0                                  0         die "I don't know how to chunk $col_type\n";
621                                                      }
622           48                                132      MKDEBUG && _d('Converts to', $num);
623           48                                472      return $num;
624                                                   }
625                                                   
626                                                   sub range_func_for {
627   ***     22                   22      0    118      my ( $self, $col_type ) = @_;
628   ***     22     50                         100      return unless $col_type;
629           22                                 64      my $range_func;
630           22    100                         284      if ( $col_type =~ m/(?:int|year|float|double|decimal)$/ ) {
                    100                               
      ***            50                               
631           13                                 50         $range_func  = 'range_num';
632                                                      }
633                                                      elsif ( $col_type =~ m/^(?:timestamp|date|time)$/ ) {
634            5                                 21         $range_func  = "range_$col_type";
635                                                      }
636                                                      elsif ( $col_type eq 'datetime' ) {
637            4                                 17         $range_func  = 'range_datetime';
638                                                      }
639           22                                104      return $range_func;
640                                                   }
641                                                   
642                                                   # ###########################################################################
643                                                   # Range functions.
644                                                   # ###########################################################################
645                                                   sub range_num {
646   ***     38                   38      0    248      my ( $self, $dbh, $start, $interval, $max ) = @_;
647           38                                268      my $end = min($max, $start + $interval);
648                                                   
649                                                   
650                                                      # "Remove" scientific notation so the regex below does not make
651                                                      # 6.123456e+18 into 6.12345.
652   ***     38     50                         242      $start = sprintf('%.17f', $start) if $start =~ /e/;
653   ***     38     50                         241      $end   = sprintf('%.17f', $end)   if $end   =~ /e/;
654                                                   
655                                                      # Trim decimal places, if needed.  This helps avoid issues with float
656                                                      # precision differing on different platforms.
657           38                                165      $start =~ s/\.(\d{5}).*$/.$1/;
658           38                                179      $end   =~ s/\.(\d{5}).*$/.$1/;
659                                                   
660           38    100                         198      if ( $end > $start ) {
661           37                                251         return ( $start, $end );
662                                                      }
663                                                      else {
664            1                                  3         die "Chunk size is too small: $end !> $start\n";
665                                                      }
666                                                   }
667                                                   
668                                                   sub range_time {
669   ***      3                    3      0     18      my ( $self, $dbh, $start, $interval, $max ) = @_;
670            3                                 32      my $sql = "SELECT SEC_TO_TIME($start), SEC_TO_TIME(LEAST($max, $start + $interval))";
671            3                                  8      MKDEBUG && _d($sql);
672            3                                  6      return $dbh->selectrow_array($sql);
673                                                   }
674                                                   
675                                                   sub range_date {
676   ***     13                   13      0     73      my ( $self, $dbh, $start, $interval, $max ) = @_;
677           13                                130      my $sql = "SELECT FROM_DAYS($start), FROM_DAYS(LEAST($max, $start + $interval))";
678           13                                 29      MKDEBUG && _d($sql);
679           13                                 31      return $dbh->selectrow_array($sql);
680                                                   }
681                                                   
682                                                   sub range_datetime {
683   ***     12                   12      0     90      my ( $self, $dbh, $start, $interval, $max ) = @_;
684           12                                195      my $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $start SECOND), "
685                                                          . "DATE_ADD('$EPOCH', INTERVAL LEAST($max, $start + $interval) SECOND)";
686           12                                 35      MKDEBUG && _d($sql);
687           12                                 32      return $dbh->selectrow_array($sql);
688                                                   }
689                                                   
690                                                   sub range_timestamp {
691   ***      0                    0      0      0      my ( $self, $dbh, $start, $interval, $max ) = @_;
692   ***      0                                  0      my $sql = "SELECT FROM_UNIXTIME($start), FROM_UNIXTIME(LEAST($max, $start + $interval))";
693   ***      0                                  0      MKDEBUG && _d($sql);
694   ***      0                                  0      return $dbh->selectrow_array($sql);
695                                                   }
696                                                   
697                                                   # Returns the number of seconds between $EPOCH and the value, according to
698                                                   # the MySQL server.  (The server can do no wrong).  I believe this code is right
699                                                   # after looking at the source of sql/time.cc but I am paranoid and add in an
700                                                   # extra check just to make sure.  Earlier versions overflow on large interval
701                                                   # values, such as on 3.23.58, '1970-01-01' - interval 58000000000 second is
702                                                   # 2037-06-25 11:29:04.  I know of no workaround.  TO_DAYS('0000-....') is NULL,
703                                                   # so we treat it as 0.
704                                                   sub timestampdiff {
705   ***      9                    9      0     65      my ( $self, $dbh, $time ) = @_;
706            9                                 89      my $sql = "SELECT (COALESCE(TO_DAYS('$time'), 0) * 86400 + TIME_TO_SEC('$time')) "
707                                                         . "- TO_DAYS('$EPOCH 00:00:00') * 86400";
708            9                                 28      MKDEBUG && _d($sql);
709            9                                 28      my ( $diff ) = $dbh->selectrow_array($sql);
710            9                               2283      $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $diff SECOND)";
711            9                                 31      MKDEBUG && _d($sql);
712            9                                 25      my ( $check ) = $dbh->selectrow_array($sql);
713   ***      9     50                        1658      die <<"   EOF"
714                                                      Incorrect datetime math: given $time, calculated $diff but checked to $check.
715                                                      This could be due to a version of MySQL that overflows on large interval
716                                                      values to DATE_ADD(), or the given datetime is not a valid date.  If not,
717                                                      please report this as a bug.
718                                                      EOF
719                                                         unless $check eq $time;
720            9                                 67      return $diff;
721                                                   }
722                                                   
723                                                   
724                                                   # #############################################################################
725                                                   # End point validation.
726                                                   # #############################################################################
727                                                   
728                                                   # These sub require val (or min and max) args which usually aren't NULL
729                                                   # but could be zero so the usual "die ... unless $args{$arg}" check does
730                                                   # not work.
731                                                   
732                                                   # Returns valid min and max values.  A valid val evaluates to a non-NULL value.
733                                                   # Arguments:
734                                                   #   * dbh       dbh
735                                                   #   * db_tbl    scalar: quoted `db`.`tbl`
736                                                   #   * col       scalar: quoted `column`
737                                                   #   * col_type  scalar: column type of the value
738                                                   #   * min       scalar: any scalar value
739                                                   #   * max       scalar: any scalar value
740                                                   # Optional arguments:
741                                                   #   * index_hint scalar: "FORCE INDEX (...)" hint
742                                                   #   * where      scalar: WHERE clause without "WHERE"
743                                                   #   * tries      scalar: only try this many times/rows to find a real value
744                                                   #   * zero_chunk bool: do a separate chunk for zero values
745                                                   # Some column types can store invalid values, like most of the temporal
746                                                   # types.  When evaluated, invalid values return NULL.  If the value is
747                                                   # NULL to begin with, then it is not invalid because NULL is valid.
748                                                   # For example, TO_DAYS('2009-00-00') evalues to NULL because that date
749                                                   # is invalid, even though it's storable.
750                                                   sub get_valid_end_points {
751   ***     11                   11      0    332      my ( $self, %args ) = @_;
752           11                                140      my @required_args = qw(dbh db_tbl col col_type);
753           11                                 77      foreach my $arg ( @required_args ) {
754   ***     44     50                         361         die "I need a $arg argument" unless $args{$arg};
755                                                      }
756           11                                106      my ($dbh, $db_tbl, $col, $col_type) = @args{@required_args};
757           11                                 82      my ($real_min, $real_max)           = @args{qw(min max)};
758                                                   
759                                                      # Common error message format in case there's a problem with
760                                                      # finding a valid min or max value.
761   ***     11     50                         158      my $err_fmt = "Error finding a valid %s value for table $db_tbl on "
762                                                                  . "column $col. The real %s value %s is invalid and "
763                                                                  . "no other valid values were found.  Verify that the table "
764                                                                  . "has at least one valid value for this column"
765                                                                  . ($args{where} ? " where $args{where}." : ".");
766                                                   
767                                                      # Validate min value if it's not NULL.  NULL is valid.
768           11                                 46      my $valid_min = $real_min;
769   ***     11     50                          74      if ( defined $valid_min ) {
770                                                         # Get a valid min end point.
771           11                                 41         MKDEBUG && _d("Validating min end point:", $real_min);
772           11                                143         $valid_min = $self->_get_valid_end_point(
773                                                            %args,
774                                                            val      => $real_min,
775                                                            endpoint => 'min',
776                                                         );
777   ***     11    100     50                   89         die sprintf($err_fmt, 'minimum', 'minimum', ($real_min || "NULL"))
778                                                            unless defined $valid_min;
779                                                      }
780                                                      
781                                                      # Validate max value if it's not NULL.  NULL is valid.
782           10                                 46      my $valid_max = $real_max;
783   ***     10     50                          67      if ( defined $valid_max ) {
784                                                         # Get a valid max end point.  So far I've not found a case where
785                                                         # the actual max val is invalid, but check anyway just in case.
786           10                                 32         MKDEBUG && _d("Validating max end point:", $real_min);
787           10                                111         $valid_max = $self->_get_valid_end_point(
788                                                            %args,
789                                                            val      => $real_max,
790                                                            endpoint => 'max',
791                                                         );
792   ***     10     50      0                   82         die sprintf($err_fmt, 'maximum', 'maximum', ($real_max || "NULL"))
793                                                            unless defined $valid_max;
794                                                      }
795                                                   
796           10                                117      return $valid_min, $valid_max;
797                                                   }
798                                                   
799                                                   # Does the actual work for get_valid_end_points() for each end point.
800                                                   sub _get_valid_end_point {
801           21                   21           449      my ( $self, %args ) = @_;
802           21                                220      my @required_args = qw(dbh db_tbl col col_type);
803           21                                121      foreach my $arg ( @required_args ) {
804   ***     84     50                         603         die "I need a $arg argument" unless $args{$arg};
805                                                      }
806           21                                167      my ($dbh, $db_tbl, $col, $col_type) = @args{@required_args};
807           21                                102      my $val = $args{val};
808                                                   
809                                                      # NULL is valid.
810   ***     21     50                         126      return $val unless defined $val;
811                                                   
812                                                      # Right now we only validate temporal types, but when we begin
813                                                      # chunking char and hex columns we'll need to validate those.
814                                                      # E.g. HEX('abcdefg') is invalid and we'll probably find some
815                                                      # combination of char val + charset/collation that's invalid.
816           21    100                         254      my $validate = $col_type =~ m/time|date/ ? \&_validate_temporal_value
817                                                                   :                             undef;
818                                                   
819                                                      # If we cannot validate the value, assume it's valid.
820           21    100                         135      if ( !$validate ) {
821           10                                 31         MKDEBUG && _d("No validator for", $col_type, "values");
822           10                                104         return $val;
823                                                      }
824                                                   
825                                                      # Return the value if it's already valid.
826           11    100                         101      return $val if defined $validate->($dbh, $val);
827                                                   
828                                                      # The value is not valid so find the first one in the table that is.
829            6                                 19      MKDEBUG && _d("Value is invalid, getting first valid value");
830            6                                 86      $val = $self->get_first_valid_value(
831                                                         %args,
832                                                         val      => $val,
833                                                         validate => $validate,
834                                                      );
835                                                   
836            6                                 77      return $val;
837                                                   }
838                                                   
839                                                   # Arguments:
840                                                   #   * dbh       dbh
841                                                   #   * db_tbl    scalar: quoted `db`.`tbl`
842                                                   #   * col       scalar: quoted `column` name
843                                                   #   * val       scalar: the current value, may be real, maybe not
844                                                   #   * validate  coderef: returns a defined value if the given value is valid
845                                                   #   * endpoint  scalar: "min" or "max", i.e. find first endpoint() real val
846                                                   # Optional arguments:
847                                                   #   * tries      scalar: only try this many times/rows to find a real value
848                                                   #   * index_hint scalar: "FORCE INDEX (...)" hint
849                                                   #   * where      scalar: WHERE clause without "WHERE"
850                                                   # Returns the first column value from the given db_tbl that does *not*
851                                                   # evaluate to NULL.  This is used mostly to eliminate unreal temporal
852                                                   # values which MySQL allows to be stored, like "2010-00-00".  Returns
853                                                   # undef if no real value is found.
854                                                   sub get_first_valid_value {
855   ***      6                    6      0    154      my ( $self, %args ) = @_;
856            6                                 71      my @required_args = qw(dbh db_tbl col validate endpoint);
857            6                                 38      foreach my $arg ( @required_args ) {
858   ***     30     50                         336         die "I need a $arg argument" unless $args{$arg};
859                                                      }
860            6                                 59      my ($dbh, $db_tbl, $col, $validate, $endpoint) = @args{@required_args};
861            6    100                          45      my $tries = defined $args{tries} ? $args{tries} : 5;
862            6                                 31      my $val   = $args{val};
863                                                   
864                                                      # NULL values are valid and shouldn't be passed to us.
865   ***      6     50                          42      return unless defined $val;
866                                                   
867                                                      # Prep a sth for fetching the next col val.
868   ***      6      0                          64      my $cmp = $endpoint =~ m/min/i ? '>'
      ***            50                               
869                                                              : $endpoint =~ m/max/i ? '<'
870                                                              :                        die "Invalid endpoint arg: $endpoint";
871   ***      6     50                         125      my $sql = "SELECT $col FROM $db_tbl "
      ***            50                               
872                                                              . ($args{index_hint} ? "$args{index_hint} " : "")
873                                                              . "WHERE $col $cmp ? AND $col IS NOT NULL "
874                                                              . ($args{where} ? "AND ($args{where}) " : "")
875                                                              . "ORDER BY $col LIMIT 1";
876            6                                 20      MKDEBUG && _d($dbh, $sql);
877            6                                 20      my $sth = $dbh->prepare($sql);
878                                                   
879                                                      # Fetch the next col val from the db.tbl until we find a valid one
880                                                      # or run out of rows.  Only try a limited number of next rows.
881            6                                 56      my $last_val = $val;
882            6                                 46      while ( $tries-- ) {
883           16                               4979         $sth->execute($last_val);
884           16                                343         my ($next_val) = $sth->fetchrow_array();
885           16                                 62         MKDEBUG && _d('Next value:', $next_val, '; tries left:', $tries);
886   ***     16     50                         114         if ( !defined $next_val ) {
887   ***      0                                  0            MKDEBUG && _d('No more rows in table');
888   ***      0                                  0            last;
889                                                         }
890           16    100                         105         if ( defined $validate->($dbh, $next_val) ) {
891            5                                 19            MKDEBUG && _d('First valid value:', $next_val);
892            5                                 70            $sth->finish();
893            5                                151            return $next_val;
894                                                         }
895           11                                107         $last_val = $next_val;
896                                                      }
897            1                                 16      $sth->finish();
898            1                                  6      $val = undef;  # no valid value found
899                                                   
900            1                                 28      return $val;
901                                                   }
902                                                   
903                                                   # Evalutes any temporal value, returns NULL if it's invalid, else returns
904                                                   # a value (possibly zero). It's magical but tested.  See also,
905                                                   # http://hackmysql.com/blog/2010/05/26/detecting-invalid-and-zero-temporal-values/
906                                                   sub _validate_temporal_value {
907           47                   47           347      my ( $dbh, $val ) = @_;
908           47                                229      my $sql = "SELECT IF(TIME_FORMAT(?,'%H:%i:%s')=?, TIME_TO_SEC(?), TO_DAYS(?))";
909           47                                169      my $res;
910           47                                190      eval {
911           47                                148         MKDEBUG && _d($dbh, $sql, $val);
912           47                                177         my $sth = $dbh->prepare($sql);
913           47                              14457         $sth->execute($val, $val, $val, $val);
914           47                               1024         ($res) = $sth->fetchrow_array();
915           47                               1693         $sth->finish();
916                                                      };
917   ***     47     50                         369      if ( $EVAL_ERROR ) {
918   ***      0                                  0         MKDEBUG && _d($EVAL_ERROR);
919                                                      }
920           47                                447      return $res;
921                                                   }
922                                                   
923                                                   sub get_nonzero_value {
924   ***      4                    4      0    125      my ( $self, %args ) = @_;
925            4                                 46      my @required_args = qw(dbh db_tbl col col_type);
926            4                                 28      foreach my $arg ( @required_args ) {
927   ***     16     50                         122         die "I need a $arg argument" unless $args{$arg};
928                                                      }
929            4                                 37      my ($dbh, $db_tbl, $col, $col_type) = @args{@required_args};
930   ***      4     50                          31      my $tries = defined $args{tries} ? $args{tries} : 5;
931            4                                 20      my $val   = $args{val};
932                                                   
933                                                      # Right now we only need a special check for temporal values.
934                                                      # _validate_temporal_value() does double-duty for this.  The
935                                                      # default anonymous sub handles ints.
936                                                      my $is_nonzero = $col_type =~ m/time|date/ ? \&_validate_temporal_value
937            4    100             3            67                     :                             sub { return $_[1]; };
               3                                 31   
938                                                   
939            4    100                          27      if ( !$is_nonzero->($dbh, $val) ) {  # quasi-double-negative, sorry
940            1                                  4         MKDEBUG && _d('Discarding zero value:', $val);
941   ***      1     50                          26         my $sql = "SELECT $col FROM $db_tbl "
      ***            50                               
942                                                                 . ($args{index_hint} ? "$args{index_hint} " : "")
943                                                                 . "WHERE $col > ? AND $col IS NOT NULL "
944                                                                 . ($args{where} ? "AND ($args{where}) " : '')
945                                                                 . "ORDER BY $col LIMIT 1";
946            1                                  3         MKDEBUG && _d($sql);
947            1                                  5         my $sth = $dbh->prepare($sql);
948                                                   
949            1                                 11         my $last_val = $val;
950            1                                  7         while ( $tries-- ) {
951            1                                941            $sth->execute($last_val);
952            1                                 34            my ($next_val) = $sth->fetchrow_array();
953   ***      1     50                           7            if ( $is_nonzero->($dbh, $next_val) ) {
954            1                                  4               MKDEBUG && _d('First non-zero value:', $next_val);
955            1                                 17               $sth->finish();
956            1                                 53               return $next_val;
957                                                            }
958   ***      0                                  0            $last_val = $next_val;
959                                                         }
960   ***      0                                  0         $sth->finish();
961   ***      0                                  0         $val = undef;  # no non-zero value found
962                                                      }
963                                                   
964            3                                 47      return $val;
965                                                   }
966                                                   
967                                                   sub _d {
968   ***      0                    0                    my ($package, undef, $line) = caller 0;
969   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
970   ***      0                                              map { defined $_ ? $_ : 'undef' }
971                                                           @_;
972   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
973                                                   }
974                                                   
975                                                   1;
976                                                   
977                                                   # ###########################################################################
978                                                   # End TableChunker package
979                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
58    ***     50      0      2   unless $args{$arg}
80    ***     50      0      9   unless $args{$arg}
89    ***     50      0     35   unless $$index{'type'} eq 'BTREE'
95           100      4     31   if ($args{'exact'})
96           100      3      1   unless $$index{'is_unique'} and @{$$index{'cols'};} == 1
111          100      8     24   unless $int_types{$$tbl_struct{'type_for'}{$col}} or $real_types{$$tbl_struct{'type_for'}{$col}}
118          100      1      8   if $args{'exact'} and scalar @candidate_cols
130   ***     50      9      0   if ($$tbl_struct{'keys'}{'PRIMARY'})
174          100      1    199   unless defined $args{$arg}
197   ***     50      0     22   if ($EVAL_ERROR)
198   ***      0      0      0   if ($EVAL_ERROR =~ /don't know how to chunk/) { }
204   ***      0      0      0   defined $args{$_} ? :
222          100      1     21   if (not defined $start_point)
226   ***     50      0     22   if (not defined $end_point or $end_point < $start_point)
235          100      6     16   if ($args{'zero_chunk'})
236          100      4      2   if ($start_point != $end_point and $start_point >= 0) { }
268          100     17      5   if ($int_types{$col_type})
272   ***     50      0     22   if ($args{'exact'})
290          100     21      1   if ($start_point < $end_point) { }
297          100      4     17   if $have_zero_chunk
305          100     20     45   if ($iter++ == 0) { }
306          100      4     16   $have_zero_chunk ? :
321          100     19      1   if (@chunks) { }
325   ***     50      0      1   $nullable ? :
327          100      2     18   if ($nullable)
355   ***     50      0      5   unless $args{$arg}
371          100      2      3   if ($wanted_col and $wanted_idx) { }
             100      1      2   elsif ($wanted_col) { }
             100      1      1   elsif ($wanted_idx) { }
374          100      1      4   if ($wanted_col eq $$chunkable_col{'column'} and $wanted_idx eq $$chunkable_col{'index'})
387          100      1      1   if ($wanted_col eq $$chunkable_col{'column'})
401          100      1      2   if ($wanted_idx eq $$chunkable_col{'index'})
424   ***     50      0     20   unless $args{$arg}
433          100      2      3   if ($suffix) { }
             100      2      1   elsif ($num) { }
434   ***      0      0      0   $suffix eq 'M' ? :
      ***     50      2      0   $suffix eq 'k' ? :
446          100      3      1   if ($suffix or $args{'avg_row_length'})
449          100      2      1   if (not defined $n_rows)
450   ***     50      2      0   $avg_row_length ? :
476   ***     50      0     60   unless $args{$arg}
493   ***     50      0     12   $args{'index_hint'} ? :
             100      1     11   $where ? :
515          100      2     10   if ($EVAL_ERROR)
522   ***     50      0     10   $args{'index_hint'} ? :
      ***     50      0     10   $where ? :
540   ***     50      0     20   unless defined $args{$arg}
549          100      3      1   if ($args{'where'} and grep {$_;} @{$args{'where'};})
582   ***     50      0    144   unless defined $args{$arg}
600          100     28     20   if ($col_type =~ /(?:int|year|float|double|decimal)$/) { }
             100     11      9   elsif ($col_type =~ /^(?:timestamp|date|time)$/) { }
      ***     50      9      0   elsif ($col_type eq 'datetime') { }
628   ***     50      0     22   unless $col_type
630          100     13      9   if ($col_type =~ /(?:int|year|float|double|decimal)$/) { }
             100      5      4   elsif ($col_type =~ /^(?:timestamp|date|time)$/) { }
      ***     50      4      0   elsif ($col_type eq 'datetime') { }
652   ***     50      0     38   if $start =~ /e/
653   ***     50      0     38   if $end =~ /e/
660          100     37      1   if ($end > $start) { }
713   ***     50      0      9   unless $check eq $time
754   ***     50      0     44   unless $args{$arg}
761   ***     50      0     11   $args{'where'} ? :
769   ***     50     11      0   if (defined $valid_min)
777          100      1     10   unless defined $valid_min
783   ***     50     10      0   if (defined $valid_max)
792   ***     50      0     10   unless defined $valid_max
804   ***     50      0     84   unless $args{$arg}
810   ***     50      0     21   unless defined $val
816          100     11     10   $col_type =~ /time|date/ ? :
820          100     10     11   if (not $validate)
826          100      5      6   if defined &$validate($dbh, $val)
858   ***     50      0     30   unless $args{$arg}
861          100      1      5   defined $args{'tries'} ? :
865   ***     50      0      6   unless defined $val
868   ***      0      0      0   $endpoint =~ /max/i ? :
      ***     50      6      0   $endpoint =~ /min/i ? :
871   ***     50      0      6   $args{'index_hint'} ? :
      ***     50      0      6   $args{'where'} ? :
886   ***     50      0     16   if (not defined $next_val)
890          100      5     11   if (defined &$validate($dbh, $next_val))
917   ***     50      0     47   if ($EVAL_ERROR)
927   ***     50      0     16   unless $args{$arg}
930   ***     50      0      4   defined $args{'tries'} ? :
937          100      2      2   $col_type =~ /time|date/ ? :
939          100      1      3   if (not &$is_nonzero($dbh, $val))
941   ***     50      0      1   $args{'index_hint'} ? :
      ***     50      0      1   $args{'where'} ? :
953   ***     50      1      0   if (&$is_nonzero($dbh, $next_val))
969   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
92           100     34      1   defined $_ and next
118          100      8      1   $args{'exact'} and scalar @candidate_cols

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
96    ***     66      3      0      1   $$index{'is_unique'} and @{$$index{'cols'};} == 1
236   ***     66      0      2      4   $start_point != $end_point and $start_point >= 0
371          100      2      1      2   $wanted_col and $wanted_idx
374          100      3      1      1   $wanted_col eq $$chunkable_col{'column'} and $wanted_idx eq $$chunkable_col{'index'}
549   ***     66      0      1      3   $args{'where'} and grep {$_;} @{$args{'where'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
53    ***     50      0      1   $ENV{'MKDEBUG'} || 0
271          100     21      1   $interval ||= $args{'chunk_size'}
555          100      1      3   $args{'index_hint'} || ''
777   ***     50      1      0   $real_min || 'NULL'
792   ***      0      0      0   $real_max || 'NULL'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
111   ***     66     24      0      8   $int_types{$$tbl_struct{'type_for'}{$col}} or $real_types{$$tbl_struct{'type_for'}{$col}}
226   ***     33      0      0     22   not defined $end_point or $end_point < $start_point
446          100      2      1      1   $suffix or $args{'avg_row_length'}


Covered Subroutines
-------------------

Subroutine                 Count Pod Location                                           
-------------------------- ----- --- ---------------------------------------------------
BEGIN                          1     /home/daniel/dev/maatkit/common/TableChunker.pm:42 
BEGIN                          1     /home/daniel/dev/maatkit/common/TableChunker.pm:43 
BEGIN                          1     /home/daniel/dev/maatkit/common/TableChunker.pm:44 
BEGIN                          1     /home/daniel/dev/maatkit/common/TableChunker.pm:46 
BEGIN                          1     /home/daniel/dev/maatkit/common/TableChunker.pm:47 
BEGIN                          1     /home/daniel/dev/maatkit/common/TableChunker.pm:48 
BEGIN                          1     /home/daniel/dev/maatkit/common/TableChunker.pm:53 
__ANON__                       3     /home/daniel/dev/maatkit/common/TableChunker.pm:937
_get_valid_end_point          21     /home/daniel/dev/maatkit/common/TableChunker.pm:801
_validate_temporal_value      47     /home/daniel/dev/maatkit/common/TableChunker.pm:907
calculate_chunks              23   0 /home/daniel/dev/maatkit/common/TableChunker.pm:170
find_chunk_columns             9   0 /home/daniel/dev/maatkit/common/TableChunker.pm:78 
get_first_chunkable_column     5   0 /home/daniel/dev/maatkit/common/TableChunker.pm:353
get_first_valid_value          6   0 /home/daniel/dev/maatkit/common/TableChunker.pm:855
get_nonzero_value              4   0 /home/daniel/dev/maatkit/common/TableChunker.pm:924
get_range_statistics          12   0 /home/daniel/dev/maatkit/common/TableChunker.pm:473
get_valid_end_points          11   0 /home/daniel/dev/maatkit/common/TableChunker.pm:751
inject_chunks                  4   0 /home/daniel/dev/maatkit/common/TableChunker.pm:538
new                            1   0 /home/daniel/dev/maatkit/common/TableChunker.pm:56 
range_date                    13   0 /home/daniel/dev/maatkit/common/TableChunker.pm:676
range_datetime                12   0 /home/daniel/dev/maatkit/common/TableChunker.pm:683
range_func_for                22   0 /home/daniel/dev/maatkit/common/TableChunker.pm:627
range_num                     38   0 /home/daniel/dev/maatkit/common/TableChunker.pm:646
range_time                     3   0 /home/daniel/dev/maatkit/common/TableChunker.pm:669
size_to_rows                   5   0 /home/daniel/dev/maatkit/common/TableChunker.pm:421
timestampdiff                  9   0 /home/daniel/dev/maatkit/common/TableChunker.pm:705
value_to_number               48   0 /home/daniel/dev/maatkit/common/TableChunker.pm:579

Uncovered Subroutines
---------------------

Subroutine                 Count Pod Location                                           
-------------------------- ----- --- ---------------------------------------------------
_d                             0     /home/daniel/dev/maatkit/common/TableChunker.pm:968
range_timestamp                0   0 /home/daniel/dev/maatkit/common/TableChunker.pm:691


TableChunker.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            15   use TableParser;
               1                                  3   
               1                                 11   
15             1                    1            11   use TableChunker;
               1                                  3   
               1                                 14   
16             1                    1            16   use MySQLDump;
               1                                  3   
               1                                 12   
17             1                    1            11   use Quoter;
               1                                  5   
               1                                 10   
18             1                    1            10   use DSNParser;
               1                                  4   
               1                                 12   
19             1                    1            13   use Sandbox;
               1                                  4   
               1                                 11   
20             1                    1            12   use MaatkitTest;
               1                                  7   
               1                                 38   
21                                                    
22             1                                 14   my $dp = new DSNParser(opts=>$dsn_opts);
23             1                                239   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
24             1                                 61   my $dbh = $sb->get_dbh_for('master');
25                                                    
26    ***      1     50                         406   if ( !$dbh ) {
27    ***      0                                  0      plan skip_all => 'Cannot connect to sandbox master';
28                                                    }
29                                                    else {
30             1                                  8      plan tests => 70;
31                                                    }
32                                                    
33             1                                284   $sb->create_dbs($dbh, ['test']);
34                                                    
35             1                                862   my $q  = new Quoter();
36             1                                 34   my $p  = new TableParser(Quoter => $q);
37             1                                 49   my $du = new MySQLDump();
38             1                                 33   my $c  = new TableChunker(Quoter => $q, MySQLDump => $du);
39             1                                  3   my $t;
40                                                    
41             1                                  7   $t = $p->parse( load_file('common/t/samples/sakila.film.sql') );
42             1                               1487   is_deeply(
43                                                       [ $c->find_chunk_columns(tbl_struct=>$t) ],
44                                                       [ 0,
45                                                         { column => 'film_id', index => 'PRIMARY' },
46                                                         { column => 'language_id', index => 'idx_fk_language_id' },
47                                                         { column => 'original_language_id',
48                                                           index => 'idx_fk_original_language_id' },
49                                                       ],
50                                                       'Found chunkable columns on sakila.film',
51                                                    );
52                                                    
53             1                                 16   is_deeply(
54                                                       [ $c->find_chunk_columns(tbl_struct=>$t, exact => 1) ],
55                                                       [ 1, { column => 'film_id', index => 'PRIMARY' } ],
56                                                       'Found exact chunkable columns on sakila.film',
57                                                    );
58                                                    
59                                                    # This test was removed because possible_keys was only used (vaguely)
60                                                    # by mk-table-sync/TableSync* but this functionality is now handled
61                                                    # in TableSync*::can_sync() with the optional args col and index.
62                                                    # In other words: it's someone else's job to get/check the preferred index.
63                                                    #is_deeply(
64                                                    #   [ $c->find_chunk_columns($t, { possible_keys => [qw(idx_fk_language_id)] }) ],
65                                                    #   [ 0,
66                                                    #     [
67                                                    #        { column => 'language_id', index => 'idx_fk_language_id' },
68                                                    #        { column => 'original_language_id',
69                                                    #             index => 'idx_fk_original_language_id' },
70                                                    #        { column => 'film_id', index => 'PRIMARY' },
71                                                    #     ]
72                                                    #   ],
73                                                    #   'Found preferred chunkable columns on sakila.film',
74                                                    #);
75                                                    
76             1                                 12   $t = $p->parse( load_file('common/t/samples/pk_not_first.sql') );
77             1                               1559   is_deeply(
78                                                       [ $c->find_chunk_columns(tbl_struct=>$t) ],
79                                                       [ 0,
80                                                         { column => 'film_id', index => 'PRIMARY' },
81                                                         { column => 'language_id', index => 'idx_fk_language_id' },
82                                                         { column => 'original_language_id',
83                                                            index => 'idx_fk_original_language_id' },
84                                                       ],
85                                                       'PK column is first',
86                                                    );
87                                                    
88             1                                 26   is(
89                                                       $c->inject_chunks(
90                                                          query     => 'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ FOO FROM 1/*WHERE*/',
91                                                          database  => 'sakila',
92                                                          table     => 'film',
93                                                          chunks    => [ '1=1', 'a=b' ],
94                                                          chunk_num => 1,
95                                                          where     => ['FOO=BAR'],
96                                                       ),
97                                                       'SELECT /*sakila.film:2/2*/ 1 AS chunk_num, FOO FROM 1 WHERE (a=b) AND ((FOO=BAR))',
98                                                       'Replaces chunk info into query',
99                                                    );
100                                                   
101            1                                 11   is(
102                                                      $c->inject_chunks(
103                                                         query     => 'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ FOO FROM 1/*WHERE*/',
104                                                         database  => 'sakila',
105                                                         table     => 'film',
106                                                         chunks    => [ '1=1', 'a=b' ],
107                                                         chunk_num => 1,
108                                                         where     => ['FOO=BAR', undef],
109                                                      ),
110                                                      'SELECT /*sakila.film:2/2*/ 1 AS chunk_num, FOO FROM 1 WHERE (a=b) AND ((FOO=BAR))',
111                                                      'Inject WHERE clause with undef item',
112                                                   );
113                                                   
114            1                                 10   is(
115                                                      $c->inject_chunks(
116                                                         query     => 'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ FOO FROM 1/*WHERE*/',
117                                                         database  => 'sakila',
118                                                         table     => 'film',
119                                                         chunks    => [ '1=1', 'a=b' ],
120                                                         chunk_num => 1,
121                                                         where     => ['FOO=BAR', 'BAZ=BAT'],
122                                                      ),
123                                                      'SELECT /*sakila.film:2/2*/ 1 AS chunk_num, FOO FROM 1 WHERE (a=b) '
124                                                         . 'AND ((FOO=BAR) AND (BAZ=BAT))',
125                                                      'Inject WHERE with defined item',
126                                                   );
127                                                   
128                                                   # #############################################################################
129                                                   # Sandbox tests.
130                                                   # #############################################################################
131            1                                  4   SKIP: {
132            1                                  4      skip 'Sandbox master does not have the sakila database', 21
133   ***      1     50                           3         unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};
134                                                   
135            1                                530      my @chunks;
136                                                   
137            1                                 15      @chunks = $c->calculate_chunks(
138                                                         tbl_struct    => $t,
139                                                         chunk_col     => 'film_id',
140                                                         min           => 0,
141                                                         max           => 99,
142                                                         rows_in_range => 100,
143                                                         chunk_size    => 30,
144                                                         dbh           => $dbh,
145                                                         db            => 'sakila',
146                                                         tbl           => 'film_id',
147                                                      );
148            1                                  8      is_deeply(
149                                                         \@chunks,
150                                                         [
151                                                            "`film_id` < '30'",
152                                                            "`film_id` >= '30' AND `film_id` < '60'",
153                                                            "`film_id` >= '60' AND `film_id` < '90'",
154                                                            "`film_id` >= '90'",
155                                                         ],
156                                                         'Got the right chunks from dividing 100 rows into 30-row chunks',
157                                                      );
158                                                   
159            1                                 13      @chunks = $c->calculate_chunks(
160                                                         tbl_struct    => $t,
161                                                         chunk_col     => 'film_id',
162                                                         min           => 0,
163                                                         max           => 99,
164                                                         rows_in_range => 100,
165                                                         chunk_size    => 300,
166                                                         dbh           => $dbh,
167                                                         db            => 'sakila',
168                                                         tbl           => 'film',
169                                                      );
170            1                                  7      is_deeply(
171                                                         \@chunks,
172                                                         [
173                                                            '1=1',
174                                                         ],
175                                                         'Got the right chunks from dividing 100 rows into 300-row chunks',
176                                                      );
177                                                   
178            1                                 12      @chunks = $c->calculate_chunks(
179                                                         tbl_struct    => $t,
180                                                         chunk_col     => 'film_id',
181                                                         min           => 0,
182                                                         max           => 0,
183                                                         rows_in_range => 100,
184                                                         chunk_size    => 300,
185                                                         dbh           => $dbh,
186                                                         db            => 'sakila',
187                                                         tbl           => 'film',
188                                                      );
189            1                                  7      is_deeply(
190                                                         \@chunks,
191                                                         [
192                                                            '1=1',
193                                                         ],
194                                                         'No rows, so one chunk',
195                                                      );
196                                                   
197            1                                 11      @chunks = $c->calculate_chunks(
198                                                         tbl_struct    => $t,
199                                                         chunk_col     => 'original_language_id',
200                                                         min           => 0,
201                                                         max           => 99,
202                                                         rows_in_range => 100,
203                                                         chunk_size    => 50,
204                                                         dbh           => $dbh,
205                                                         db            => 'sakila',
206                                                         tbl           => 'film',
207                                                      );
208            1                                  6      is_deeply(
209                                                         \@chunks,
210                                                         [
211                                                            "`original_language_id` < '50'",
212                                                            "`original_language_id` >= '50'",
213                                                            "`original_language_id` IS NULL",
214                                                         ],
215                                                         'Nullable column adds IS NULL chunk',
216                                                      );
217                                                   
218            1                                 12      $t = $p->parse( load_file('common/t/samples/daycol.sql') );
219                                                   
220            1                                682      @chunks = $c->calculate_chunks(
221                                                         tbl_struct    => $t,
222                                                         chunk_col     => 'a',
223                                                         min           => '2001-01-01',
224                                                         max           => '2002-01-01',
225                                                         rows_in_range => 365,
226                                                         chunk_size    => 90,
227                                                         dbh           => $dbh,
228                                                         db            => 'sakila',
229                                                         tbl           => 'checksum_test_5',
230                                                      );
231            1                                 10      is_deeply(
232                                                         \@chunks,
233                                                         [
234                                                            "`a` < '2001-04-01'",
235                                                            "`a` >= '2001-04-01' AND `a` < '2001-06-30'",
236                                                            "`a` >= '2001-06-30' AND `a` < '2001-09-28'",
237                                                            "`a` >= '2001-09-28' AND `a` < '2001-12-27'",
238                                                            "`a` >= '2001-12-27'",
239                                                         ],
240                                                         'Date column chunks OK',
241                                                      );
242                                                   
243            1                                 10      $t = $p->parse( load_file('common/t/samples/date.sql') );
244            1                                615      @chunks = $c->calculate_chunks(
245                                                         tbl_struct    => $t,
246                                                         chunk_col     => 'a',
247                                                         min           => '2000-01-01',
248                                                         max           => '2005-11-26',
249                                                         rows_in_range => 3,
250                                                         chunk_size    => 1,
251                                                         dbh           => $dbh,
252                                                         db            => 'sakila',
253                                                         tbl           => 'checksum_test_5',
254                                                      );
255            1                                  8      is_deeply(
256                                                         \@chunks,
257                                                         [
258                                                            "`a` < '2001-12-20'",
259                                                            "`a` >= '2001-12-20' AND `a` < '2003-12-09'",
260                                                            "`a` >= '2003-12-09'",
261                                                         ],
262                                                         'Date column chunks OK',
263                                                      );
264                                                   
265            1                                 14      @chunks = $c->calculate_chunks(
266                                                         tbl_struct    => $t,
267                                                         chunk_col     => 'a',
268                                                         min           => '0000-00-00',
269                                                         max           => '2005-11-26',
270                                                         rows_in_range => 3,
271                                                         chunk_size    => 1,
272                                                         dbh           => $dbh,
273                                                         db            => 'sakila',
274                                                         tbl           => 'checksum_test_5',
275                                                      );
276            1                                  8      is_deeply(
277                                                         \@chunks,
278                                                         [
279                                                            "`a` < '0668-08-20'",
280                                                            "`a` >= '0668-08-20' AND `a` < '1337-04-09'",
281                                                            "`a` >= '1337-04-09'",
282                                                         ],
283                                                         'Date column where min date is 0000-00-00',
284                                                      );
285                                                   
286            1                                 11      $t = $p->parse( load_file('common/t/samples/datetime.sql') );
287            1                                614      @chunks = $c->calculate_chunks(
288                                                         tbl_struct    => $t,
289                                                         chunk_col     => 'a',
290                                                         min           => '1922-01-14 05:18:23',
291                                                         max           => '2005-11-26 00:59:19',
292                                                         rows_in_range => 3,
293                                                         chunk_size    => 1,
294                                                         dbh           => $dbh,
295                                                         db            => 'sakila',
296                                                         tbl           => 'checksum_test_5',
297                                                      );
298            1                                 11      is_deeply(
299                                                         \@chunks,
300                                                         [
301                                                            "`a` < '1949-12-28 19:52:02'",
302                                                            "`a` >= '1949-12-28 19:52:02' AND `a` < '1977-12-12 10:25:41'",
303                                                            "`a` >= '1977-12-12 10:25:41'",
304                                                         ],
305                                                         'Datetime column chunks OK',
306                                                      );
307                                                   
308            1                                 15      @chunks = $c->calculate_chunks(
309                                                         tbl_struct    => $t,
310                                                         chunk_col     => 'a',
311                                                         min           => '0000-00-00 00:00:00',
312                                                         max           => '2005-11-26 00:59:19',
313                                                         rows_in_range => 3,
314                                                         chunk_size    => 1,
315                                                         dbh           => $dbh,
316                                                         db            => 'sakila',
317                                                         tbl           => 'checksum_test_5',
318                                                      );
319            1                                 10      is_deeply(
320                                                         \@chunks,
321                                                         [
322                                                            "`a` < '0668-08-19 16:19:47'",
323                                                            "`a` >= '0668-08-19 16:19:47' AND `a` < '1337-04-08 08:39:34'",
324                                                            "`a` >= '1337-04-08 08:39:34'",
325                                                         ],
326                                                         'Datetime where min is 0000-00-00 00:00:00',
327                                                      );
328                                                   
329            1                                 12      $t = $p->parse( load_file('common/t/samples/timecol.sql') );
330            1                                635      @chunks = $c->calculate_chunks(
331                                                         tbl_struct    => $t,
332                                                         chunk_col     => 'a',
333                                                         min           => '00:59:19',
334                                                         max           => '09:03:15',
335                                                         rows_in_range => 3,
336                                                         chunk_size    => 1,
337                                                         dbh           => $dbh,
338                                                         db            => 'sakila',
339                                                         tbl           => 'checksum_test_7',
340                                                      );
341            1                                 10      is_deeply(
342                                                         \@chunks,
343                                                         [
344                                                            "`a` < '03:40:38'",
345                                                            "`a` >= '03:40:38' AND `a` < '06:21:57'",
346                                                            "`a` >= '06:21:57'",
347                                                         ],
348                                                         'Time column chunks OK',
349                                                      );
350                                                   
351            1                                 11      $t = $p->parse( load_file('common/t/samples/doublecol.sql') );
352            1                                554      @chunks = $c->calculate_chunks(
353                                                         tbl_struct    => $t,
354                                                         chunk_col     => 'a',
355                                                         min           => '1',
356                                                         max           => '99.999',
357                                                         rows_in_range => 3,
358                                                         chunk_size    => 1,
359                                                         dbh           => $dbh,
360                                                         db            => 'sakila',
361                                                         tbl           => 'checksum_test_8',
362                                                      );
363            1                                  8      is_deeply(
364                                                         \@chunks,
365                                                         [
366                                                            "`a` < '33.99966'",
367                                                            "`a` >= '33.99966' AND `a` < '66.99933'",
368                                                            "`a` >= '66.99933'",
369                                                         ],
370                                                         'Double column chunks OK',
371                                                      );
372                                                   
373            1                                 26      @chunks = $c->calculate_chunks(
374                                                         tbl_struct    => $t,
375                                                         chunk_col     => 'a',
376                                                         min           => '1',
377                                                         max           => '2',
378                                                         rows_in_range => 5,
379                                                         chunk_size    => 3,
380                                                         dbh           => $dbh,
381                                                         db            => 'sakila',
382                                                         tbl           => 'checksum_test_5',
383                                                      );
384            1                                  8      is_deeply(
385                                                         \@chunks,
386                                                         [
387                                                            "`a` < '1.6'",
388                                                            "`a` >= '1.6'",
389                                                         ],
390                                                         'Double column chunks OK with smaller-than-int values',
391                                                      );
392                                                   
393            1                                  9      eval {
394            1                                  8         @chunks = $c->calculate_chunks(
395                                                            tbl_struct    => $t,
396                                                            chunk_col     => 'a',
397                                                            min           => '1',
398                                                            max           => '2',
399                                                            rows_in_range => 50000000,
400                                                            chunk_size    => 3,
401                                                            dbh           => $dbh,
402                                                            db            => 'sakila',
403                                                            tbl           => 'checksum_test_5',
404                                                         );
405                                                      };
406            1                                  7      is(
407                                                         $EVAL_ERROR,
408                                                         "Chunk size is too small: 1.00000 !> 1\n",
409                                                         'Throws OK when too many chunks',
410                                                      );
411                                                   
412            1                                  7      $t = $p->parse( load_file('common/t/samples/floatcol.sql') );
413            1                                534      @chunks = $c->calculate_chunks(
414                                                         tbl_struct    => $t,
415                                                         chunk_col     => 'a',
416                                                         min           => '1',
417                                                         max           => '99.999',
418                                                         rows_in_range => 3,
419                                                         chunk_size    => 1,
420                                                         dbh           => $dbh,
421                                                         db            => 'sakila',
422                                                         tbl           => 'checksum_test_5',
423                                                      );
424            1                                 10      is_deeply(
425                                                         \@chunks,
426                                                         [
427                                                            "`a` < '33.99966'",
428                                                            "`a` >= '33.99966' AND `a` < '66.99933'",
429                                                            "`a` >= '66.99933'",
430                                                         ],
431                                                         'Float column chunks OK',
432                                                      );
433                                                   
434            1                                 11      $t = $p->parse( load_file('common/t/samples/decimalcol.sql') );
435            1                                520      @chunks = $c->calculate_chunks(
436                                                         tbl_struct    => $t,
437                                                         chunk_col     => 'a',
438                                                         min           => '1',
439                                                         max           => '99.999',
440                                                         rows_in_range => 3,
441                                                         chunk_size    => 1,
442                                                         dbh           => $dbh,
443                                                         db            => 'sakila',
444                                                         tbl           => 'checksum_test_5',
445                                                      );
446            1                                  9      is_deeply(
447                                                         \@chunks,
448                                                         [
449                                                            "`a` < '33.99966'",
450                                                            "`a` >= '33.99966' AND `a` < '66.99933'",
451                                                            "`a` >= '66.99933'",
452                                                         ],
453                                                         'Decimal column chunks OK',
454                                                      );
455                                                   
456                                                      throws_ok(
457            1                    1            34         sub { $c->get_range_statistics(
458                                                               dbh        => $dbh,
459                                                               db         => 'sakila',
460                                                               tbl        => 'film',
461                                                               chunk_col  => 'film_id',
462                                                               tbl_struct => {
463                                                                  type_for   => { film_id => 'int' },
464                                                                  is_numeric => { film_id => 1     },
465                                                               },
466                                                               where      => 'film_id>'
467                                                            )
468                                                         },
469            1                                 49         qr/WHERE \(film_id>\)/,
470                                                         'Shows full SQL on error',
471                                                      );
472                                                   
473                                                      throws_ok(
474            1                    1            26         sub { $c->size_to_rows(
475                                                               dbh        => $dbh,
476                                                               db         => 'sakila',
477                                                               tbl        => 'film',
478                                                               chunk_size => 'foo'
479                                                            )
480                                                         },
481            1                                 30         qr/Invalid chunk size/,
482                                                         'Rejects chunk size',
483                                                      );
484                                                   
485            1                                 14      is_deeply(
486                                                         [ $c->size_to_rows(
487                                                            dbh        => $dbh,
488                                                            db         => 'sakila',
489                                                            tbl        => 'film',
490                                                            chunk_size => '5'
491                                                         ) ],
492                                                         [5, undef],
493                                                         'Numeric size'
494                                                      );
495            1                                 13      my ($size) = $c->size_to_rows(
496                                                         dbh        => $dbh,
497                                                         db         => 'sakila',
498                                                         tbl        => 'film',
499                                                         chunk_size => '5k'
500                                                      );
501   ***      1            33                   17      ok($size >= 20 && $size <= 30, 'Convert bytes to rows');
502                                                   
503            1                                  3      my $avg;
504            1                                  9      ($size, $avg) = $c->size_to_rows(
505                                                         dbh        => $dbh,
506                                                         db         => 'sakila',
507                                                         tbl        => 'film',
508                                                         chunk_size => '5k'
509                                                      );
510                                                      # This may fail because Rows and Avg_row_length can vary
511                                                      # slightly for InnoDB tables.
512   ***      1            33                   19      ok(
513                                                         $avg >= 173 && $avg <= 206,
514                                                         "size_to_rows() returns avg row len in list context (173<=$avg<=206)"
515                                                      );
516                                                   
517            1                                 10      ($size, $avg) = $c->size_to_rows(
518                                                         dbh            => $dbh,
519                                                         db             => 'sakila',
520                                                         tbl            => 'film',
521                                                         chunk_size     => 5,
522                                                         avg_row_length => 1,
523                                                      );
524   ***      1            33                   21      ok(
      ***                   33                        
525                                                         $size == 5 && ($avg >= 173 && $avg <= 206),
526                                                         'size_to_rows() gets avg row length if asked'
527                                                      );
528                                                   };
529                                                   
530                                                   # #############################################################################
531                                                   # Issue 47: TableChunker::range_num broken for very large bigint
532                                                   # #############################################################################
533            1                                 15   $sb->load_file('master', 'common/t/samples/issue_47.sql');
534            1                             101558   $t = $p->parse( $du->get_create_table($dbh, $q, 'test', 'issue_47') );
535            1                               1024   my %params = $c->get_range_statistics(
536                                                      dbh        => $dbh,
537                                                      db         => 'test',
538                                                      tbl        => 'issue_47',
539                                                      chunk_col  => 'userid',
540                                                      tbl_struct => {
541                                                         type_for   => { userid => 'int' },
542                                                         is_numeric => { userid => 1     },
543                                                      },
544                                                   );
545            1                                  7   my @chunks;
546            1                                  3   eval {
547            1                                 21      @chunks = $c->calculate_chunks(
548                                                         dbh        => $dbh,
549                                                         tbl_struct => $t,
550                                                         chunk_col  => 'userid',
551                                                         chunk_size => '4',
552                                                         %params,
553                                                      );
554                                                   };
555            1                                 28   unlike($EVAL_ERROR, qr/Chunk size is too small/, 'Does not die chunking unsigned bitint (issue 47)');
556                                                   
557                                                   # #############################################################################
558                                                   # Issue 8: Add --force-index parameter to mk-table-checksum and mk-table-sync
559                                                   # #############################################################################
560            1                                 19   is(
561                                                      $c->inject_chunks(
562                                                         query       => 'SELECT /*CHUNK_NUM*/ FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/',
563                                                         database    => 'test',
564                                                         table       => 'issue_8',
565                                                         chunks      => [ '1=1', 'a=b' ],
566                                                         chunk_num   => 1,
567                                                         where       => [],
568                                                         index_hint  => 'USE INDEX (`idx_a`)',
569                                                      ),
570                                                      'SELECT  1 AS chunk_num, FROM `test`.`issue_8` USE INDEX (`idx_a`) WHERE (a=b)',
571                                                      'Adds USE INDEX (issue 8)'
572                                                   );
573                                                   
574            1                                 14   $sb->load_file('master', 'common/t/samples/issue_8.sql');
575            1                             209028   $t = $p->parse( $du->get_create_table($dbh, $q, 'test', 'issue_8') );
576            1                               1922   my @candidates = $c->find_chunk_columns(tbl_struct=>$t);
577            1                                 36   is_deeply(
578                                                      \@candidates,
579                                                      [
580                                                         0,
581                                                         { column => 'id',    index => 'PRIMARY'  },
582                                                         { column => 'foo',   index => 'uidx_foo' },
583                                                      ],
584                                                      'find_chunk_columns() returns col and idx candidates'
585                                                   );
586                                                   
587                                                   # #############################################################################
588                                                   # Issue 941: mk-table-checksum chunking should treat zero dates similar to NULL
589                                                   # #############################################################################
590            1                    1            13   use Data::Dumper;
               1                                  8   
               1                                  9   
591            1                                 22   $Data::Dumper::Indent    = 1;
592            1                                  6   $Data::Dumper::Sortkeys  = 1;
593            1                                  5   $Data::Dumper::Quotekeys = 0;
594                                                   
595                                                   # These tables have rows like: 0, 100, 101, 102, etc.  Without the
596                                                   # zero-row option, the result is like:
597                                                   #   range stats:
598                                                   #     min           => '0',
599                                                   #     max           => '107',
600                                                   #     rows_in_range => '9'
601                                                   #   chunks:
602                                                   #     '`i` < 24',
603                                                   #     '`i` >= 24 AND `i` < 48',
604                                                   #     '`i` >= 48 AND `i` < 72',
605                                                   #     '`i` >= 72 AND `i` < 96',
606                                                   #     '`i` >= 96'
607                                                   # Problem is that the last chunk does all the work.  If the zero row
608                                                   # is ignored then the chunks are much better and the first chunk will
609                                                   # cover the zero row.
610                                                   
611            1                                 17   $sb->load_file('master', 'common/t/samples/issue_941.sql');
612                                                   
613                                                   sub test_zero_row {
614            6                    6            66      my ( $tbl, $range, $chunks, $zero_chunk ) = @_;
615   ***      6     50                          68      $zero_chunk = 1 unless defined $zero_chunk;
616            6                                102      $t = $p->parse( $du->get_create_table($dbh, $q, 'issue_941', $tbl) );
617            6                               6583      %params = $c->get_range_statistics(
618                                                         dbh        => $dbh,
619                                                         db         => 'issue_941',
620                                                         tbl        => $tbl,
621                                                         chunk_col  => $tbl,
622                                                         tbl_struct => $t,
623                                                         zero_chunk => $zero_chunk,
624                                                      );
625   ***      6     50                         100      is_deeply(
626                                                         \%params,
627                                                         $range,
628                                                         "$tbl range without zero row"
629                                                      ) or print STDERR "Got ", Dumper(\%params);
630                                                   
631            6                                196      @chunks = $c->calculate_chunks(
632                                                         dbh        => $dbh,
633                                                         db         => 'issue_941',
634                                                         tbl        => $tbl,
635                                                         tbl_struct => $t,
636                                                         chunk_col  => $tbl,
637                                                         chunk_size => '2',
638                                                         zero_chunk => $zero_chunk,
639                                                         %params,
640                                                      );
641   ***      6     50                          79      is_deeply(
642                                                         \@chunks,
643                                                         $chunks,
644                                                         "$tbl chunks without zero row"
645                                                      ) or print STDERR "Got ", Dumper(\@chunks);
646                                                   
647            6                                 92      return;
648                                                   }
649                                                   
650                                                   # This can zero chunk because the min, 0, is >= 0.
651                                                   # The effective min becomes 100.
652            1                             812451   test_zero_row(
653                                                      'i',
654                                                      { min=>0, max=>107, rows_in_range=>9 },
655                                                      [
656                                                         "`i` = 0",
657                                                         "`i` > 0 AND `i` < '102'",
658                                                         "`i` >= '102' AND `i` < '104'",
659                                                         "`i` >= '104' AND `i` < '106'",
660                                                         "`i` >= '106'",
661                                                      ],
662                                                   );
663                                                   
664                                                   # This cannot zero chunk because the min is < 0.
665            1                                 23   test_zero_row(
666                                                      'i_neg',
667                                                      { min=>-10, max=>-2, rows_in_range=>8 },
668                                                      [
669                                                         "`i_neg` < '-8'",
670                                                         "`i_neg` >= '-8' AND `i_neg` < '-6'",
671                                                         "`i_neg` >= '-6' AND `i_neg` < '-4'",
672                                                         "`i_neg` >= '-4'"
673                                                      ],
674                                                   );
675                                                   
676                                                   # This cannot zero chunk because the min is < 0.
677            1                                 23   test_zero_row(
678                                                      'i_neg_pos',
679                                                      { min=>-10, max=>4, rows_in_range=>14 },
680                                                      [
681                                                         "`i_neg_pos` < '-8'",
682                                                         "`i_neg_pos` >= '-8' AND `i_neg_pos` < '-6'",
683                                                         "`i_neg_pos` >= '-6' AND `i_neg_pos` < '-4'",
684                                                         "`i_neg_pos` >= '-4' AND `i_neg_pos` < '-2'",
685                                                         "`i_neg_pos` >= '-2' AND `i_neg_pos` < '0'",
686                                                         "`i_neg_pos` >= '0' AND `i_neg_pos` < '2'",
687                                                         "`i_neg_pos` >= '2'",
688                                                      ],
689                                                   );
690                                                   
691                                                   # There's no zero values in this table, but it can still
692                                                   # zero chunk because the min is >= 0.
693            1                                 24   test_zero_row(
694                                                      'i_null',
695                                                      { min=>100, max=>107, rows_in_range=>9 },
696                                                      [
697                                                         "`i_null` = 0",
698                                                         "`i_null` > 0 AND `i_null` < '102'",
699                                                         "`i_null` >= '102' AND `i_null` < '104'",
700                                                         "`i_null` >= '104' AND `i_null` < '106'",
701                                                         "`i_null` >= '106'",
702                                                         "`i_null` IS NULL",
703                                                      ],
704                                                   );
705                                                   
706                                                   # Table d has a zero row, 0000-00-00, which is not a valid value
707                                                   # for min but can be selected by the zero chunk.
708            1                                 29   test_zero_row(
709                                                      'd',
710                                                      {
711                                                         min => '2010-03-01',
712                                                         max => '2010-03-05',
713                                                         rows_in_range => '6'
714                                                      },
715                                                      [
716                                                         "`d` = 0",
717                                                         "`d` > 0 AND `d` < '2010-03-03'",
718                                                         "`d` >= '2010-03-03'",
719                                                      ],
720                                                   );
721                                                   
722                                                   # Same as above: one zero row which we can select with the zero chunk.
723            1                                 24   test_zero_row(
724                                                      'dt',
725                                                      {
726                                                         min => '2010-03-01 02:01:00',
727                                                         max => '2010-03-05 00:30:00',
728                                                         rows_in_range => '6',
729                                                      },
730                                                      [
731                                                         "`dt` = 0",
732                                                         "`dt` > 0 AND `dt` < '2010-03-02 09:30:40'",
733                                                         "`dt` >= '2010-03-02 09:30:40' AND `dt` < '2010-03-03 17:00:20'",
734                                                         "`dt` >= '2010-03-03 17:00:20'",
735                                                      ],
736                                                   );
737                                                   
738                                                   # #############################################################################
739                                                   # Issue 602: mk-table-checksum issue with invalid dates
740                                                   # #############################################################################
741            1                                 26   $sb->load_file('master', 'mk-table-checksum/t/samples/issue_602.sql');
742            1                             202633   $t = $p->parse( $du->get_create_table($dbh, $q, 'issue_602', 't') );
743            1                               1381   %params = $c->get_range_statistics(
744                                                      dbh        => $dbh,
745                                                      db         => 'issue_602',
746                                                      tbl        => 't',
747                                                      chunk_col  => 'b',
748                                                      tbl_struct => {
749                                                         type_for   => { b => 'datetime' },
750                                                         is_numeric => { b => 0          },
751                                                      },
752                                                   );
753                                                   
754            1                                 40   is_deeply(
755                                                      \%params,
756                                                      {
757                                                         max => '2010-05-09 00:00:00',
758                                                         min => '2010-04-30 00:00:00',
759                                                         rows_in_range => '11',
760                                                      },
761                                                      "Ignores invalid min val, gets next valid min val"
762                                                   );
763                                                   
764                                                   throws_ok(
765                                                      sub {
766            1                    1            47         @chunks = $c->calculate_chunks(
767                                                            dbh        => $dbh,
768                                                            db         => 'issue_602',
769                                                            tbl        => 't',
770                                                            tbl_struct => $t,
771                                                            chunk_col  => 'b',
772                                                            chunk_size => '5',
773                                                            %params,
774                                                         )
775                                                      },
776            1                                 54      qr//,
777                                                      "No error with invalid min datetime (issue 602)"
778                                                   );
779                                                   
780                                                   # Like the test above but t2 has nothing but invalid rows.
781            1                                 35   $t = $p->parse( $du->get_create_table($dbh, $q, 'issue_602', 't2') );
782                                                   throws_ok(
783                                                      sub {
784            1                    1            43         $c->get_range_statistics(
785                                                            dbh        => $dbh,
786                                                            db         => 'issue_602',
787                                                            tbl        => 't2',
788                                                            chunk_col  => 'b',
789                                                            tbl_struct => {
790                                                               type_for   => { b => 'datetime' },
791                                                               is_numeric => { b => 0          },
792                                                            },
793                                                         );
794                                                      },
795            1                               1177      qr/Error finding a valid minimum value/,
796                                                      "Dies if valid min value cannot be found"
797                                                   );
798                                                   
799                                                   # Try again with more tries: 6 instead of default 5.  Should
800                                                   # find a row this time.
801            1                                 35   %params = $c->get_range_statistics(
802                                                      dbh        => $dbh,
803                                                      db         => 'issue_602',
804                                                      tbl        => 't2',
805                                                      chunk_col  => 'b',
806                                                      tbl_struct => {
807                                                         type_for   => { b => 'datetime' },
808                                                         is_numeric => { b => 0          },
809                                                      },
810                                                      tries     => 6,
811                                                   );
812                                                   
813            1                                 21   is_deeply(
814                                                      \%params,
815                                                      {
816                                                         max => '2010-01-08 00:00:08',
817                                                         min => '2010-01-07 00:00:07',
818                                                         rows_in_range => 8,
819                                                      },
820                                                      "Gets valid min with enough tries"
821                                                   );
822                                                   
823                                                   
824                                                   # #############################################################################
825                                                   # Test issue 941 + issue 602
826                                                   # #############################################################################
827                                                   
828            1                                348   $dbh->do("insert into issue_602.t values ('12', '0000-00-00 00:00:00')");
829                                                   # Now we have:
830                                                   # |   12 | 0000-00-00 00:00:00 | 
831                                                   # |   11 | 2010-00-09 00:00:00 | 
832                                                   # |   10 | 2010-04-30 00:00:00 | 
833                                                   # So min is a zero row.  If we don't want zero row, next min will be an
834                                                   # invalid row, and we don't want that.  So we should get row "10" as min.
835                                                   
836            1                                 26   %params = $c->get_range_statistics(
837                                                      dbh        => $dbh,
838                                                      db         => 'issue_602',
839                                                      tbl        => 't',
840                                                      chunk_col  => 'b',
841                                                      tbl_struct => {
842                                                         type_for   => { b => 'datetime' },
843                                                         is_numeric => { b => 0          },
844                                                      },
845                                                   );
846                                                   
847            1                                 20   is_deeply(
848                                                      \%params,
849                                                      {
850                                                         min => '2010-04-30 00:00:00',
851                                                         max => '2010-05-09 00:00:00',
852                                                         rows_in_range => 12,
853                                                      },
854                                                      "Gets valid min after zero row"
855                                                   );
856                                                   
857                                                   # #############################################################################
858                                                   # Test _validate_temporal_value() because it's magical.
859                                                   # #############################################################################
860            1                                 24   my @invalid_t = (
861                                                      '00:00:60',
862                                                      '00:60:00',
863                                                      '0000-00-00',
864                                                      '2009-00-00',
865                                                      '2009-13-00',
866                                                      '0000-00-00 00:00:00',
867                                                      '1000-00-00 00:00:00',
868                                                      '2009-00-00 00:00:00',
869                                                      '2009-13-00 00:00:00',
870                                                      '2009-05-26 00:00:60',
871                                                      '2009-05-26 00:60:00',
872                                                      '2009-05-26 24:00:00',
873                                                   );
874            1                                 13   foreach my $t ( @invalid_t ) {
875           12                                109      my $res = TableChunker::_validate_temporal_value($dbh, $t);
876           12                                125      is(
877                                                         $res,
878                                                         undef,
879                                                         "$t is invalid"
880                                                      );
881                                                   }
882                                                   
883            1                                 18   my @valid_t = (
884                                                      '00:00:01',
885                                                      '1000-01-01',
886                                                      '2009-01-01',
887                                                      '1000-01-01 00:00:00',
888                                                      '2009-01-01 00:00:00',
889                                                      '2010-05-26 17:48:30',
890                                                   );
891            1                                  5   foreach my $t ( @valid_t ) {
892            6                                 52      my $res = TableChunker::_validate_temporal_value($dbh, $t);
893            6                                 68      ok(
894                                                         defined $res,
895                                                         "$t is valid"
896                                                      );
897                                                   }
898                                                   
899                                                   # #############################################################################
900                                                   # Test get_first_chunkable_column().
901                                                   # #############################################################################
902            1                                 26   $t = $p->parse( load_file('common/t/samples/sakila.film.sql') );
903                                                   
904            1                               2893   is_deeply(
905                                                      [ $c->get_first_chunkable_column(tbl_struct=>$t) ],
906                                                      [ 'film_id', 'PRIMARY' ],
907                                                      "get_first_chunkable_column(), default column and index"
908                                                   );
909                                                   
910            1                                 21   is_deeply(
911                                                      [ $c->get_first_chunkable_column(
912                                                         tbl_struct   => $t,
913                                                         chunk_column => 'language_id',
914                                                      ) ],
915                                                      [ 'language_id', 'idx_fk_language_id' ],
916                                                      "get_first_chunkable_column(), preferred column"
917                                                   );
918                                                   
919            1                                 20   is_deeply(
920                                                      [ $c->get_first_chunkable_column(
921                                                         tbl_struct  => $t,
922                                                         chunk_index => 'idx_fk_original_language_id',
923                                                      ) ],
924                                                      [ 'original_language_id', 'idx_fk_original_language_id' ],
925                                                      "get_first_chunkable_column(), preferred index"
926                                                   );
927                                                   
928            1                                 20   is_deeply(
929                                                      [ $c->get_first_chunkable_column(
930                                                         tbl_struct   => $t,
931                                                         chunk_column => 'language_id',
932                                                         chunk_index  => 'idx_fk_language_id',
933                                                      ) ],
934                                                      [ 'language_id', 'idx_fk_language_id' ],
935                                                      "get_first_chunkable_column(), preferred column and index"
936                                                   );
937                                                   
938            1                                 22   is_deeply(
939                                                      [ $c->get_first_chunkable_column(
940                                                         tbl_struct   => $t,
941                                                         chunk_column => 'film_id',
942                                                         chunk_index  => 'idx_fk_language_id',
943                                                      ) ],
944                                                      [ 'film_id', 'PRIMARY' ],
945                                                      "get_first_chunkable_column(), bad preferred column and index"
946                                                   );
947                                                   
948                                                   # #############################################################################
949                                                   # Done.
950                                                   # #############################################################################
951            1                                 30   $sb->wipe_clean($dbh);
952            1                                  6   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
26    ***     50      0      1   if (not $dbh) { }
133   ***     50      0      1   unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"');}
615   ***     50      6      0   unless defined $zero_chunk
625   ***     50      0      6   unless is_deeply(\%params, $range, "$tbl range without zero row")
641   ***     50      0      6   unless is_deeply(\@chunks, $chunks, "$tbl chunks without zero row")


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
501   ***     33      0      0      1   $size >= 20 && $size <= 30
512   ***     33      0      0      1   $avg >= 173 && $avg <= 206
524   ***     33      0      0      1   $avg >= 173 && $avg <= 206
      ***     33      0      0      1   $size == 5 && ($avg >= 173 && $avg <= 206)


Covered Subroutines
-------------------

Subroutine    Count Location          
------------- ----- ------------------
BEGIN             1 TableChunker.t:10 
BEGIN             1 TableChunker.t:11 
BEGIN             1 TableChunker.t:12 
BEGIN             1 TableChunker.t:14 
BEGIN             1 TableChunker.t:15 
BEGIN             1 TableChunker.t:16 
BEGIN             1 TableChunker.t:17 
BEGIN             1 TableChunker.t:18 
BEGIN             1 TableChunker.t:19 
BEGIN             1 TableChunker.t:20 
BEGIN             1 TableChunker.t:4  
BEGIN             1 TableChunker.t:590
BEGIN             1 TableChunker.t:9  
__ANON__          1 TableChunker.t:457
__ANON__          1 TableChunker.t:474
__ANON__          1 TableChunker.t:766
__ANON__          1 TableChunker.t:784
test_zero_row     6 TableChunker.t:614


