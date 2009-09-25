---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/TableChunker.pm   90.6   73.8   75.0   86.4    n/a  100.0   85.6
Total                          90.6   73.8   75.0   86.4    n/a  100.0   85.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableChunker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 21:18:13 2009
Finish:       Fri Sep 25 21:18:14 2009

/home/daniel/dev/maatkit/common/TableChunker.pm

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
18                                                    # TableChunker package $Revision: 4742 $
19                                                    # ###########################################################################
20             1                    1             8   use strict;
               1                                  2   
               1                                  6   
21             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  9   
22                                                    
23                                                    package TableChunker;
24                                                    
25             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
26             1                    1            11   use POSIX qw(ceil);
               1                                  4   
               1                                  9   
27             1                    1             9   use List::Util qw(min max);
               1                                  3   
               1                                 24   
28             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  8   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
34                                                    
35                                                    sub new {
36             1                    1            17      my ( $class, %args ) = @_;
37             1                                  5      foreach my $arg ( qw(Quoter MySQLDump) ) {
38    ***      2     50                          10         die "I need a $arg argument" unless $args{$arg};
39                                                       }
40             1                                 11      my $self = { %args };
41             1                                 12      return bless $self, $class;
42                                                    }
43                                                    
44                                                    my $EPOCH      = '1970-01-01';
45                                                    my %int_types  = map { $_ => 1 }
46                                                       qw(bigint date datetime int mediumint smallint time timestamp tinyint year);
47                                                    my %real_types = map { $_ => 1 }
48                                                       qw(decimal double float);
49                                                    
50                                                    # Arguments:
51                                                    #   * table_struct    Hashref returned from TableParser::parse
52                                                    #   * exact           (optional) bool: Try to support exact chunk sizes
53                                                    #                     (may still chunk fuzzily)
54                                                    # Returns an array:
55                                                    #   whether the table can be chunked exactly, if requested (zero otherwise)
56                                                    #   arrayref of columns that support chunking
57                                                    sub find_chunk_columns {
58             4                    4            96      my ( $self, %args ) = @_;
59             4                                 18      foreach my $arg ( qw(tbl_struct) ) {
60    ***      4     50                          35         die "I need a $arg argument" unless $args{$arg};
61                                                       }
62             4                                 13      my $tbl_struct = $args{tbl_struct};
63                                                    
64                                                       # See if there's an index that will support chunking.
65             4                                 11      my @possible_indexes;
66             4                                 11      foreach my $index ( values %{ $tbl_struct->{keys} } ) {
               4                                 23   
67                                                    
68                                                          # Accept only BTREE indexes.
69    ***     15     50                          61         next unless $index->{type} eq 'BTREE';
70                                                    
71                                                          # Reject indexes with prefixed columns.
72            15           100                   33         defined $_ && next for @{ $index->{col_prefixes} };
              15                                 31   
              15                                100   
73                                                    
74                                                          # If exact, accept only unique, single-column indexes.
75            15    100                          59         if ( $args{exact} ) {
76    ***      4    100     66                   27            next unless $index->{is_unique} && @{$index->{cols}} == 1;
               1                                  7   
77                                                          }
78                                                    
79            12                                 42         push @possible_indexes, $index;
80                                                       }
81                                                       MKDEBUG && _d('Possible chunk indexes in order:',
82             4                                 12         join(', ', map { $_->{name} } @possible_indexes));
83                                                    
84                                                       # Build list of candidate chunk columns.   
85             4                                 11      my $can_chunk_exact = 0;
86             4                                 11      my @candidate_cols;
87             4                                 12      foreach my $index ( @possible_indexes ) { 
88            12                                 47         my $col = $index->{cols}->[0];
89                                                    
90                                                          # Accept only integer or real number type columns.
91    ***     12    100     66                   91         next unless ( $int_types{$tbl_struct->{type_for}->{$col}}
92                                                                        || $real_types{$tbl_struct->{type_for}->{$col}} );
93                                                    
94                                                          # Save the candidate column and its index.
95             9                                 57         push @candidate_cols, { column => $col, index => $index->{name} };
96                                                       }
97                                                    
98             4    100    100                   26      $can_chunk_exact = 1 if $args{exact} && scalar @candidate_cols;
99                                                    
100            4                                  9      if ( MKDEBUG ) {
101                                                         my $chunk_type = $args{exact} ? 'Exact' : 'Inexact';
102                                                         _d($chunk_type, 'chunkable:',
103                                                            join(', ', map { "$_->{column} on $_->{index}" } @candidate_cols));
104                                                      }
105                                                   
106                                                      # Order the candidates by their original column order.
107                                                      # Put the PK's first column first, if it's a candidate.
108            4                                 11      my @result;
109            4                                  9      MKDEBUG && _d('Ordering columns by order in tbl, PK first');
110   ***      4     50                          23      if ( $tbl_struct->{keys}->{PRIMARY} ) {
111            4                                 22         my $pk_first_col = $tbl_struct->{keys}->{PRIMARY}->{cols}->[0];
112            4                                 12         @result          = grep { $_->{column} eq $pk_first_col } @candidate_cols;
               9                                 42   
113            4                                 13         @candidate_cols  = grep { $_->{column} ne $pk_first_col } @candidate_cols;
               9                                 39   
114                                                      }
115            4                                 11      my $i = 0;
116            4                                 10      my %col_pos = map { $_ => $i++ } @{$tbl_struct->{cols}};
              42                                170   
               4                                 18   
117            4                                 19      push @result, sort { $col_pos{$a->{column}} <=> $col_pos{$b->{column}} }
               2                                 10   
118                                                                       @candidate_cols;
119                                                   
120            4                                 13      if ( MKDEBUG ) {
121                                                         _d('Chunkable columns:',
122                                                            join(', ', map { "$_->{column} on $_->{index}" } @result));
123                                                         _d('Can chunk exactly:', $can_chunk_exact);
124                                                      }
125                                                   
126            4                                 51      return ($can_chunk_exact, @result);
127                                                   }
128                                                   
129                                                   # Arguments:
130                                                   #   * tbl_struct     Return value from TableParser::parse()
131                                                   #   * chunk_col      Which column to chunk on
132                                                   #   * min            Min value of col
133                                                   #   * max            Max value of col
134                                                   #   * rows_in_range  How many rows are in the table between min and max
135                                                   #   * chunk_size     How large each chunk should be (not adjusted)
136                                                   #   * dbh            A DBI connection to MySQL
137                                                   #   * exact          Whether to chunk exactly (optional)
138                                                   #
139                                                   # Returns a list of WHERE clauses, one for each chunk.  Each is quoted with
140                                                   # double-quotes, so it'll be easy to enclose them in single-quotes when used as
141                                                   # command-line arguments.
142                                                   sub calculate_chunks {
143           16                   16           527      my ( $self, %args ) = @_;
144           16                                102      foreach my $arg ( qw(dbh tbl_struct chunk_col min max rows_in_range
145                                                                           chunk_size dbh) ) {
146   ***    128     50                         548         die "I need a $arg argument" unless defined $args{$arg};
147                                                      }
148           16                                 39      MKDEBUG && _d('Calculate chunks for', Dumper(\%args));
149           16                                 63      my $dbh = $args{dbh};
150                                                   
151           16                                 38      my @chunks;
152           16                                 48      my ($range_func, $start_point, $end_point);
153           16                                 84      my $col_type = $args{tbl_struct}->{type_for}->{$args{chunk_col}};
154           16                                 38      MKDEBUG && _d('chunk col type:', $col_type);
155                                                   
156                                                      # Determine chunk size in "distance between endpoints" that will give
157                                                      # approximately the right number of rows between the endpoints.  Also
158                                                      # find the start/end points as a number that Perl can do + and < on.
159                                                   
160           16    100                         163      if ( $col_type =~ m/(?:int|year|float|double|decimal)$/ ) {
      ***            50                               
                    100                               
                    100                               
      ***            50                               
161           10                                 32         $start_point = $args{min};
162           10                                 32         $end_point   = $args{max};
163           10                                 32         $range_func  = 'range_num';
164                                                      }
165                                                      elsif ( $col_type eq 'timestamp' ) {
166   ***      0                                  0         my $sql = "SELECT UNIX_TIMESTAMP('$args{min}'), UNIX_TIMESTAMP('$args{max}')";
167   ***      0                                  0         MKDEBUG && _d($sql);
168   ***      0                                  0         ($start_point, $end_point) = $dbh->selectrow_array($sql);
169   ***      0                                  0         $range_func  = 'range_timestamp';
170                                                      }
171                                                      elsif ( $col_type eq 'date' ) {
172            3                                 21         my $sql = "SELECT TO_DAYS('$args{min}'), TO_DAYS('$args{max}')";
173            3                                  8         MKDEBUG && _d($sql);
174            3                                  8         ($start_point, $end_point) = $dbh->selectrow_array($sql);
175            3                                851         $range_func  = 'range_date';
176                                                      }
177                                                      elsif ( $col_type eq 'time' ) {
178            1                                  7         my $sql = "SELECT TIME_TO_SEC('$args{min}'), TIME_TO_SEC('$args{max}')";
179            1                                  3         MKDEBUG && _d($sql);
180            1                                  3         ($start_point, $end_point) = $dbh->selectrow_array($sql);
181            1                                188         $range_func  = 'range_time';
182                                                      }
183                                                      elsif ( $col_type eq 'datetime' ) {
184                                                         # Newer versions of MySQL could use TIMESTAMPDIFF, but it's easier
185                                                         # to maintain just one kind of code, so I do it all with DATE_ADD().
186            2                                 10         $start_point = $self->timestampdiff($dbh, $args{min});
187            2                                 12         $end_point   = $self->timestampdiff($dbh, $args{max});
188            2                                  7         $range_func  = 'range_datetime';
189                                                      }
190                                                      else {
191   ***      0                                  0         die "I don't know how to chunk $col_type\n";
192                                                      }
193                                                   
194                                                      # The endpoints could easily be undef, because of things like dates that
195                                                      # are '0000-00-00'.  The only thing to do is make them zeroes and
196                                                      # they'll be done in a single chunk then.
197           16    100                          69      if ( !defined $start_point ) {
198            1                                  2         MKDEBUG && _d('Start point is undefined');
199            1                                  4         $start_point = 0;
200                                                      }
201   ***     16     50     33                  177      if ( !defined $end_point || $end_point < $start_point ) {
202   ***      0                                  0         MKDEBUG && _d('End point is undefined or before start point');
203   ***      0                                  0         $end_point = 0;
204                                                      }
205           16                                 35      MKDEBUG && _d('Start and end of chunk range:',$start_point,',', $end_point);
206                                                   
207                                                      # Calculate the chunk size, in terms of "distance between endpoints."  If
208                                                      # possible and requested, forbid chunks from being any bigger than
209                                                      # specified.
210           16                                106      my $interval = $args{chunk_size}
211                                                                   * ($end_point - $start_point)
212                                                                   / $args{rows_in_range};
213           16    100                          79      if ( $int_types{$col_type} ) {
214           11                                 81         $interval = ceil($interval);
215                                                      }
216           16           100                   62      $interval ||= $args{chunk_size};
217   ***     16     50                          66      if ( $args{exact} ) {
218   ***      0                                  0         $interval = $args{chunk_size};
219                                                      }
220           16                                 35      MKDEBUG && _d('Chunk interval:', $interval, 'units');
221                                                   
222                                                      # Generate a list of chunk boundaries.  The first and last chunks are
223                                                      # inclusive, and will catch any rows before or after the end of the
224                                                      # supposed range.  So 1-100 divided into chunks of 30 should actually end
225                                                      # up with chunks like this:
226                                                      #           < 30
227                                                      # >= 30 AND < 60
228                                                      # >= 60 AND < 90
229                                                      # >= 90
230           16                                116      my $col = $self->{Quoter}->quote($args{chunk_col});
231           16    100                          68      if ( $start_point < $end_point ) {
232           15                                 42         my ( $beg, $end );
233           15                                 38         my $iter = 0;
234                                                         for ( my $i = $start_point; $i < $end_point; $i += $interval ) {
235           42                                223            ( $beg, $end ) = $self->$range_func($dbh, $i, $interval, $end_point);
236                                                   
237                                                            # The first chunk.
238           41    100                       11411            if ( $iter++ == 0 ) {
239           14                                 88               push @chunks, "$col < " . $self->quote($end);
240                                                            }
241                                                            else {
242                                                               # The normal case is a chunk in the middle of the range somewhere.
243           27                                150               push @chunks, "$col >= " . $self->quote($beg) . " AND $col < " . $self->quote($end);
244                                                            }
245           15                                 46         }
246                                                   
247                                                         # Remove the last chunk and replace it with one that matches everything
248                                                         # from the beginning of the last chunk to infinity.  If the chunk column
249                                                         # is nullable, do NULL separately.
250           14                                 77         my $nullable = $args{tbl_struct}->{is_nullable}->{$args{chunk_col}};
251           14                                 39         pop @chunks;
252           14    100                          53         if ( @chunks ) {
253           13                                 60            push @chunks, "$col >= " . $self->quote($beg);
254                                                         }
255                                                         else {
256   ***      1     50                           5            push @chunks, $nullable ? "$col IS NOT NULL" : '1=1';
257                                                         }
258           14    100                          65         if ( $nullable ) {
259            1                                  5            push @chunks, "$col IS NULL";
260                                                         }
261                                                   
262                                                      }
263                                                      else {
264                                                         # There are no chunks; just do the whole table in one chunk.
265            1                                  3         MKDEBUG && _d('No chunks; using single chunk 1=1');
266            1                                  3         push @chunks, '1=1';
267                                                      }
268                                                   
269           15                                150      return @chunks;
270                                                   }
271                                                   
272                                                   sub get_first_chunkable_column {
273   ***      0                    0             0      my ( $self, $table, $opts ) = @_;
274   ***      0                                  0      my ($exact, $cols) = $self->find_chunk_columns($table, $opts);
275   ***      0                                  0      return ( $cols->[0]->{column}, $cols->[0]->{index} );
276                                                   }
277                                                   
278                                                   # Convert a size in rows or bytes to a number of rows in the table, using SHOW
279                                                   # TABLE STATUS.  If the size is a string with a suffix of M/G/k, interpret it as
280                                                   # mebibytes, gibibytes, or kibibytes respectively.  If it's just a number, treat
281                                                   # it as a number of rows and return right away.
282                                                   sub size_to_rows {
283            3                    3            74      my ( $self, %args ) = @_;
284            3                                 16      my @required_args = qw(dbh db tbl chunk_size);
285            3                                 10      foreach my $arg ( @required_args ) {
286   ***     12     50                          51         die "I need a $arg argument" unless $args{$arg};
287                                                      }
288            3                                 15      my ($dbh, $db, $tbl, $chunk_size) = @args{@required_args};
289            3                                 11      my $q  = $self->{Quoter};
290            3                                  9      my $du = $self->{MySQLDump};
291                                                   
292            3                                 20      my ( $num, $suffix ) = $chunk_size =~ m/^(\d+)([MGk])?$/;
293            3    100                          15      if ( $suffix ) { # Convert to bytes.
                    100                               
294   ***      1      0                           7         $chunk_size = $suffix eq 'k' ? $num * 1_024
      ***            50                               
295                                                                     : $suffix eq 'M' ? $num * 1_024 * 1_024
296                                                                     :                  $num * 1_024 * 1_024 * 1_024;
297                                                      }
298                                                      elsif ( $num ) {
299            1                                  8         return $num;
300                                                      }
301                                                      else {
302            1                                  3         die "Invalid chunk size $chunk_size; must be an integer "
303                                                            . "with optional suffix kMG";
304                                                      }
305                                                   
306            1                                  7      my @status = $du->get_table_status($dbh, $q, $db);
307            1                                  5      my ($status) = grep { $_->{name} eq $tbl } @status;
              23                                 82   
308            1                                  6      my $avg_row_length = $status->{avg_row_length};
309   ***      1     50                          21      return $avg_row_length ? ceil($chunk_size / $avg_row_length) : undef;
310                                                   }
311                                                   
312                                                   # Determine the range of values for the chunk_col column on this table.
313                                                   # The $where could come from many places; it is not trustworthy.
314                                                   sub get_range_statistics {
315            2                    2           110      my ( $self, %args ) = @_;
316            2                                 15      my @required_args = qw(dbh db tbl chunk_col);
317            2                                 10      foreach my $arg ( @required_args ) {
318   ***      8     50                          34         die "I need a $arg argument" unless $args{$arg};
319                                                      }
320            2                                 11      my ($dbh, $db, $tbl, $col) = @args{@required_args};
321            2                                  6      my $where = $args{where};
322            2                                  8      my $q = $self->{Quoter};
323            2    100                           9      my $sql = "SELECT MIN(" . $q->quote($col) . "), MAX(" . $q->quote($col)
324                                                         . ") FROM " . $q->quote($db, $tbl)
325                                                         . ($where ? " WHERE $where" : '');
326            2                                  6      MKDEBUG && _d($sql);
327            2                                  6      my ( $min, $max );
328            2                                  5      eval {
329            2                                  4         ( $min, $max ) = $dbh->selectrow_array($sql);
330                                                      };
331            2    100                         215      if ( $EVAL_ERROR ) {
332            1                                  5         chomp $EVAL_ERROR;
333   ***      1     50                           5         if ( $EVAL_ERROR =~ m/in your SQL syntax/ ) {
334            1                                  2            die "$EVAL_ERROR (WHERE clause: $where)";
335                                                         }
336                                                         else {
337   ***      0                                  0            die $EVAL_ERROR;
338                                                         }
339                                                      }
340   ***      1     50                           6      $sql = "EXPLAIN SELECT * FROM " . $q->quote($db, $tbl)
341                                                         . ($where ? " WHERE $where" : '');
342            1                                  3      MKDEBUG && _d($sql);
343            1                                  3      my $expl = $dbh->selectrow_hashref($sql);
344                                                      return (
345            1                                 22         min           => $min,
346                                                         max           => $max,
347                                                         rows_in_range => $expl->{rows},
348                                                      );
349                                                   }
350                                                   
351                                                   # Quotes values only when needed, and uses double-quotes instead of
352                                                   # single-quotes (see comments earlier).
353                                                   sub quote {
354           81                   81           317      my ( $self, $val ) = @_;
355           81    100                         818      return $val =~ m/\d[:-]/ ? qq{"$val"} : $val;
356                                                   }
357                                                   
358                                                   # Takes a query prototype and fills in placeholders.  The 'where' arg should be
359                                                   # an arrayref of WHERE clauses that will be joined with AND.
360                                                   sub inject_chunks {
361            4                    4            65      my ( $self, %args ) = @_;
362            4                                 23      foreach my $arg ( qw(database table chunks chunk_num query) ) {
363   ***     20     50                          89         die "I need a $arg argument" unless defined $args{$arg};
364                                                      }
365            4                                 11      MKDEBUG && _d('Injecting chunk', $args{chunk_num});
366            4                                 14      my $query   = $args{query};
367            4                                 25      my $comment = sprintf("/*%s.%s:%d/%d*/",
368                                                         $args{database}, $args{table},
369            4                                 20         $args{chunk_num} + 1, scalar @{$args{chunks}});
370            4                                 20      $query =~ s!/\*PROGRESS_COMMENT\*/!$comment!;
371            4                                 21      my $where = "WHERE (" . $args{chunks}->[$args{chunk_num}] . ')';
372   ***      4    100     66                   29      if ( $args{where} && grep { $_ } @{$args{where}} ) {
               5                                 28   
               4                                 18   
373            4                                 23         $where .= " AND ("
374            3                                  9            . join(" AND ", map { "($_)" } grep { $_ } @{$args{where}} )
               5                                 15   
               3                                 12   
375                                                            . ")";
376                                                      }
377            4                                 32      my $db_tbl     = $self->{Quoter}->quote(@args{qw(database table)});
378            4           100                   32      my $index_hint = $args{index_hint} || '';
379                                                   
380            4                                  8      MKDEBUG && _d('Parameters:',
381                                                         Dumper({WHERE => $where, DB_TBL => $db_tbl, INDEX_HINT => $index_hint}));
382            4                                 27      $query =~ s!/\*WHERE\*/! $where!;
383            4                                 16      $query =~ s!/\*DB_TBL\*/!$db_tbl!;
384            4                                 14      $query =~ s!/\*INDEX_HINT\*/! $index_hint!;
385            4                                 28      $query =~ s!/\*CHUNK_NUM\*/! $args{chunk_num} AS chunk_num,!;
386                                                   
387            4                                 37      return $query;
388                                                   }
389                                                   
390                                                   # ###########################################################################
391                                                   # Range functions.
392                                                   # ###########################################################################
393                                                   sub range_num {
394           22                   22           107      my ( $self, $dbh, $start, $interval, $max ) = @_;
395           22                                128      my $end = min($max, $start + $interval);
396                                                   
397                                                   
398                                                      # "Remove" scientific notation so the regex below does not make
399                                                      # 6.123456e+18 into 6.12345.
400           22    100                         139      $start = sprintf('%.17f', $start) if $start =~ /e/;
401           22    100                         172      $end   = sprintf('%.17f', $end)   if $end   =~ /e/;
402                                                   
403                                                      # Trim decimal places, if needed.  This helps avoid issues with float
404                                                      # precision differing on different platforms.
405           22                                108      $start =~ s/\.(\d{5}).*$/.$1/;
406           22                                130      $end   =~ s/\.(\d{5}).*$/.$1/;
407                                                   
408           22    100                          93      if ( $end > $start ) {
409           21                                114         return ( $start, $end );
410                                                      }
411                                                      else {
412            1                                  3         die "Chunk size is too small: $end !> $start\n";
413                                                      }
414                                                   }
415                                                   
416                                                   sub range_time {
417            3                    3            16      my ( $self, $dbh, $start, $interval, $max ) = @_;
418            3                                 23      my $sql = "SELECT SEC_TO_TIME($start), SEC_TO_TIME(LEAST($max, $start + $interval))";
419            3                                  8      MKDEBUG && _d($sql);
420            3                                  7      return $dbh->selectrow_array($sql);
421                                                   }
422                                                   
423                                                   sub range_date {
424           11                   11            61      my ( $self, $dbh, $start, $interval, $max ) = @_;
425           11                                103      my $sql = "SELECT FROM_DAYS($start), FROM_DAYS(LEAST($max, $start + $interval))";
426           11                                 23      MKDEBUG && _d($sql);
427           11                                 26      return $dbh->selectrow_array($sql);
428                                                   }
429                                                   
430                                                   sub range_datetime {
431            6                    6            30      my ( $self, $dbh, $start, $interval, $max ) = @_;
432            6                                 65      my $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $start SECOND), "
433                                                          . "DATE_ADD('$EPOCH', INTERVAL LEAST($max, $start + $interval) SECOND)";
434            6                                 13      MKDEBUG && _d($sql);
435            6                                 13      return $dbh->selectrow_array($sql);
436                                                   }
437                                                   
438                                                   sub range_timestamp {
439   ***      0                    0             0      my ( $self, $dbh, $start, $interval, $max ) = @_;
440   ***      0                                  0      my $sql = "SELECT FROM_UNIXTIME($start), FROM_UNIXTIME(LEAST($max, $start + $interval))";
441   ***      0                                  0      MKDEBUG && _d($sql);
442   ***      0                                  0      return $dbh->selectrow_array($sql);
443                                                   }
444                                                   
445                                                   # Returns the number of seconds between $EPOCH and the value, according to
446                                                   # the MySQL server.  (The server can do no wrong).  I believe this code is right
447                                                   # after looking at the source of sql/time.cc but I am paranoid and add in an
448                                                   # extra check just to make sure.  Earlier versions overflow on large interval
449                                                   # values, such as on 3.23.58, '1970-01-01' - interval 58000000000 second is
450                                                   # 2037-06-25 11:29:04.  I know of no workaround.  TO_DAYS('0000-....') is NULL,
451                                                   # so we treat it as 0.
452                                                   sub timestampdiff {
453            4                    4            18      my ( $self, $dbh, $time ) = @_;
454            4                                 28      my $sql = "SELECT (COALESCE(TO_DAYS('$time'), 0) * 86400 + TIME_TO_SEC('$time')) "
455                                                         . "- TO_DAYS('$EPOCH 00:00:00') * 86400";
456            4                                  8      MKDEBUG && _d($sql);
457            4                                 10      my ( $diff ) = $dbh->selectrow_array($sql);
458            4                                937      $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $diff SECOND)";
459            4                                 11      MKDEBUG && _d($sql);
460            4                                 11      my ( $check ) = $dbh->selectrow_array($sql);
461   ***      4     50                         537      die <<"   EOF"
462                                                      Incorrect datetime math: given $time, calculated $diff but checked to $check.
463                                                      This is probably because you are using a version of MySQL that overflows on
464                                                      large interval values to DATE_ADD().  If not, please report this as a bug.
465                                                      EOF
466                                                         unless $check eq $time;
467            4                                 20      return $diff;
468                                                   }
469                                                   
470                                                   sub _d {
471   ***      0                    0                    my ($package, undef, $line) = caller 0;
472   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
473   ***      0                                              map { defined $_ ? $_ : 'undef' }
474                                                           @_;
475   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
476                                                   }
477                                                   
478                                                   1;
479                                                   
480                                                   # ###########################################################################
481                                                   # End TableChunker package
482                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
38    ***     50      0      2   unless $args{$arg}
60    ***     50      0      4   unless $args{$arg}
69    ***     50      0     15   unless $$index{'type'} eq 'BTREE'
75           100      4     11   if ($args{'exact'})
76           100      3      1   unless $$index{'is_unique'} and @{$$index{'cols'};} == 1
91           100      3      9   unless $int_types{$$tbl_struct{'type_for'}{$col}} or $real_types{$$tbl_struct{'type_for'}{$col}}
98           100      1      3   if $args{'exact'} and scalar @candidate_cols
110   ***     50      4      0   if ($$tbl_struct{'keys'}{'PRIMARY'})
146   ***     50      0    128   unless defined $args{$arg}
160          100     10      6   if ($col_type =~ /(?:int|year|float|double|decimal)$/) { }
      ***     50      0      6   elsif ($col_type eq 'timestamp') { }
             100      3      3   elsif ($col_type eq 'date') { }
             100      1      2   elsif ($col_type eq 'time') { }
      ***     50      2      0   elsif ($col_type eq 'datetime') { }
197          100      1     15   if (not defined $start_point)
201   ***     50      0     16   if (not defined $end_point or $end_point < $start_point)
213          100     11      5   if ($int_types{$col_type})
217   ***     50      0     16   if ($args{'exact'})
231          100     15      1   if ($start_point < $end_point) { }
238          100     14     27   if ($iter++ == 0) { }
252          100     13      1   if (@chunks) { }
256   ***     50      0      1   $nullable ? :
258          100      1     13   if ($nullable)
286   ***     50      0     12   unless $args{$arg}
293          100      1      2   if ($suffix) { }
             100      1      1   elsif ($num) { }
294   ***      0      0      0   $suffix eq 'M' ? :
      ***     50      1      0   $suffix eq 'k' ? :
309   ***     50      1      0   $avg_row_length ? :
318   ***     50      0      8   unless $args{$arg}
323          100      1      1   $where ? :
331          100      1      1   if ($EVAL_ERROR)
333   ***     50      1      0   if ($EVAL_ERROR =~ /in your SQL syntax/) { }
340   ***     50      0      1   $where ? :
355          100     40     41   $val =~ /\d[:-]/ ? :
363   ***     50      0     20   unless defined $args{$arg}
372          100      3      1   if ($args{'where'} and grep {$_;} @{$args{'where'};})
400          100      2     20   if $start =~ /e/
401          100      2     20   if $end =~ /e/
408          100     21      1   if ($end > $start) { }
461   ***     50      0      4   unless $check eq $time
472   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
72           100     14      1   defined $_ and next
98           100      3      1   $args{'exact'} and scalar @candidate_cols

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
76    ***     66      3      0      1   $$index{'is_unique'} and @{$$index{'cols'};} == 1
372   ***     66      0      1      3   $args{'where'} and grep {$_;} @{$args{'where'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
216          100     15      1   $interval ||= $args{'chunk_size'}
378          100      1      3   $args{'index_hint'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
91    ***     66      9      0      3   $int_types{$$tbl_struct{'type_for'}{$col}} or $real_types{$$tbl_struct{'type_for'}{$col}}
201   ***     33      0      0     16   not defined $end_point or $end_point < $start_point


Covered Subroutines
-------------------

Subroutine                 Count Location                                           
-------------------------- ----- ---------------------------------------------------
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:20 
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:21 
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:25 
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:26 
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:27 
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:28 
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:33 
calculate_chunks              16 /home/daniel/dev/maatkit/common/TableChunker.pm:143
find_chunk_columns             4 /home/daniel/dev/maatkit/common/TableChunker.pm:58 
get_range_statistics           2 /home/daniel/dev/maatkit/common/TableChunker.pm:315
inject_chunks                  4 /home/daniel/dev/maatkit/common/TableChunker.pm:361
new                            1 /home/daniel/dev/maatkit/common/TableChunker.pm:36 
quote                         81 /home/daniel/dev/maatkit/common/TableChunker.pm:354
range_date                    11 /home/daniel/dev/maatkit/common/TableChunker.pm:424
range_datetime                 6 /home/daniel/dev/maatkit/common/TableChunker.pm:431
range_num                     22 /home/daniel/dev/maatkit/common/TableChunker.pm:394
range_time                     3 /home/daniel/dev/maatkit/common/TableChunker.pm:417
size_to_rows                   3 /home/daniel/dev/maatkit/common/TableChunker.pm:283
timestampdiff                  4 /home/daniel/dev/maatkit/common/TableChunker.pm:453

Uncovered Subroutines
---------------------

Subroutine                 Count Location                                           
-------------------------- ----- ---------------------------------------------------
_d                             0 /home/daniel/dev/maatkit/common/TableChunker.pm:471
get_first_chunkable_column     0 /home/daniel/dev/maatkit/common/TableChunker.pm:273
range_timestamp                0 /home/daniel/dev/maatkit/common/TableChunker.pm:439


