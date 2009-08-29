---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/TableChunker.pm   90.4   77.4   77.8   86.4    n/a  100.0   86.2
Total                          90.4   77.4   77.8   86.4    n/a  100.0   86.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableChunker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:57 2009
Finish:       Sat Aug 29 15:03:57 2009

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
18                                                    # TableChunker package $Revision: 3186 $
19                                                    # ###########################################################################
20             1                    1             8   use strict;
               1                                  4   
               1                                  6   
21             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
22                                                    
23                                                    package TableChunker;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
26             1                    1            13   use POSIX qw(ceil);
               1                                  4   
               1                                  8   
27             1                    1             9   use List::Util qw(min max);
               1                                  3   
               1                                 15   
28             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                 13   
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    $Data::Dumper::Indent    = 0;
31                                                    
32             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
33                                                    
34                                                    sub new {
35             1                    1            16      my ( $class, %args ) = @_;
36    ***      1     50                           6      die "I need a quoter" unless $args{quoter};
37             1                                 13      bless { %args }, $class;
38                                                    }
39                                                    
40                                                    my $EPOCH      = '1970-01-01';
41                                                    my %int_types  = map { $_ => 1 }
42                                                       qw( bigint date datetime int mediumint smallint time timestamp tinyint year );
43                                                    my %real_types = map { $_ => 1 }
44                                                       qw( decimal double float );
45                                                    
46                                                    # $table  hashref returned from TableParser::parse
47                                                    # $opts   hashref of options
48                                                    #         exact: try to support exact chunk sizes (may still chunk fuzzily)
49                                                    #         possible_keys: arrayref of keys to prefer, in order.  These can be
50                                                    #                        generated from EXPLAIN by TableParser.pm
51                                                    # Returns an array:
52                                                    #   whether the table can be chunked exactly, if requested (zero otherwise)
53                                                    #   arrayref of columns that support chunking
54                                                    sub find_chunk_columns {
55             5                    5            94      my ( $self, $table, $opts ) = @_;
56             5           100                   23      $opts ||= {};
57                                                    
58             5                                 15      my %prefer;
59    ***      5    100     66                   30      if ( $opts->{possible_keys} && @{$opts->{possible_keys}} ) {
               1                                  8   
60             1                                  3         my $i = 1;
61             1                                  3         %prefer = map { $_ => $i++ } @{$opts->{possible_keys}};
               1                                  7   
               1                                  5   
62                                                          MKDEBUG && _d('Preferred indexes for chunking:',
63             1                                  3            join(', ', @{$opts->{possible_keys}}));
64                                                       }
65                                                    
66                                                       # See if there's an index that will support chunking.
67             5                                 14      my @possible_keys;
68             5                                 34      KEY:
69             5                                 13      foreach my $key ( values %{ $table->{keys} } ) {
70                                                    
71                                                          # Accept only BTREE indexes.
72    ***     19     50                          83         next unless $key->{type} eq 'BTREE';
73                                                    
74                                                          # Reject indexes with prefixed columns.
75            19           100                   40         defined $_ && next KEY for @{ $key->{col_prefixes} };
              19                                 49   
              19                                128   
76                                                    
77                                                          # If exact, accept only unique, single-column indexes.
78            18    100                          73         if ( $opts->{exact} ) {
79    ***      4    100     66                   24            next unless $key->{is_unique} && @{$key->{cols}} == 1;
               1                                  9   
80                                                          }
81                                                    
82            15                                 49         push @possible_keys, $key;
83                                                       }
84                                                    
85                                                       # Sort keys by preferred-ness.
86            13           100                  151      @possible_keys = sort {
                           100                        
87             5                                 12         ($prefer{$a->{name}} || 9999) <=> ($prefer{$b->{name}} || 9999)
88                                                       } @possible_keys;
89                                                    
90                                                       MKDEBUG && _d('Possible keys in order:',
91             5                                 14         join(', ', map { $_->{name} } @possible_keys));
92                                                    
93                                                       # Build list of candidate chunk columns.   
94             5                                 15      my $can_chunk_exact = 0;
95             5                                 13      my @candidate_cols;
96             5                                 18      foreach my $key ( @possible_keys ) { 
97            15                                 56         my $col = $key->{cols}->[0];
98                                                    
99                                                          # Accept only integer or real number type columns.
100   ***     15    100     66                  117         next unless ( $int_types{$table->{type_for}->{$col}}
101                                                                       || $real_types{$table->{type_for}->{$col}} );
102                                                   
103                                                         # Save the candidate column and its index.
104           12                                 78         push @candidate_cols, { column => $col, index => $key->{name} };
105                                                      }
106                                                   
107            5    100    100                   34      $can_chunk_exact = 1 if ( $opts->{exact} && scalar @candidate_cols );
108                                                   
109            5                                 11      if ( MKDEBUG ) {
110                                                         my $chunk_type = $opts->{exact} ? 'Exact' : 'Inexact';
111                                                         _d($chunk_type, 'chunkable:',
112                                                            join(', ', map { "$_->{column} on $_->{index}" } @candidate_cols));
113                                                      }
114                                                   
115                                                      # Order the candidates by their original column order.
116                                                      # Put the PK's first column first, if it's a candidate.
117            5                                 14      my @result;
118            5    100                          21      if ( !%prefer ) {
119            4                                 10         MKDEBUG && _d('Ordering columns by order in tbl, PK first');
120   ***      4     50                          22         if ( $table->{keys}->{PRIMARY} ) {
121            4                                 21            my $pk_first_col = $table->{keys}->{PRIMARY}->{cols}->[0];
122            4                                 13            @result = grep { $_->{column} eq $pk_first_col } @candidate_cols;
               9                                 40   
123            4                                 15            @candidate_cols = grep { $_->{column} ne $pk_first_col } @candidate_cols;
               9                                 38   
124                                                         }
125            4                                 11         my $i = 0;
126            4                                 11         my %col_pos = map { $_ => $i++ } @{$table->{cols}};
              42                                171   
               4                                 19   
127            4                                 17         push @result, sort { $col_pos{$a->{column}} <=> $col_pos{$b->{column}} }
               2                                  9   
128                                                                          @candidate_cols;
129                                                      }
130                                                      else {
131            1                                  4         @result = @candidate_cols;
132                                                      }
133                                                   
134            5                                 18      if ( MKDEBUG ) {
135                                                         _d('Chunkable columns:',
136                                                            join(', ', map { "$_->{column} on $_->{index}" } @result));
137                                                         _d('Can chunk exactly:', $can_chunk_exact);
138                                                      }
139                                                   
140            5                                 65      return ($can_chunk_exact, \@result);
141                                                   }
142                                                   
143                                                   # table:         output from TableParser::parse
144                                                   # col:           which column to chunk on
145                                                   # min:           min value of col
146                                                   # max:           max value of col
147                                                   # rows_in_range: how many rows are in the table between min and max
148                                                   # size:          how large each chunk should be
149                                                   # dbh:           a DBI connection to MySQL
150                                                   # exact:         whether to chunk exactly (optional)
151                                                   #
152                                                   # Returns a list of WHERE clauses, one for each chunk.  Each is quoted with
153                                                   # double-quotes, so it'll be easy to enclose them in single-quotes when used as
154                                                   # command-line arguments.
155                                                   sub calculate_chunks {
156           16                   16          1054      my ( $self, %args ) = @_;
157           16                                 97      foreach my $arg ( qw(table col min max rows_in_range size dbh) ) {
158   ***    112     50                         487         die "Required argument $arg not given or undefined"
159                                                            unless defined $args{$arg};
160                                                      }
161                                                      MKDEBUG && _d('Arguments:',
162                                                         join(', ',
163           16                                 42            map { "$_=" . (defined $args{$_} ? $args{$_} : 'undef') } keys %args));
164                                                   
165           16                                 44      my @chunks;
166           16                                 51      my ($range_func, $start_point, $end_point);
167           16                                 88      my $col_type = $args{table}->{type_for}->{$args{col}};
168           16                                 39      MKDEBUG && _d('Chunking on', $args{col}, '(',$col_type,')');
169                                                   
170                                                      # Determine chunk size in "distance between endpoints" that will give
171                                                      # approximately the right number of rows between the endpoints.  Also
172                                                      # find the start/end points as a number that Perl can do + and < on.
173                                                   
174           16    100                         184      if ( $col_type =~ m/(?:int|year|float|double|decimal)$/ ) {
      ***            50                               
                    100                               
                    100                               
      ***            50                               
175           10                                 31         $start_point = $args{min};
176           10                                 31         $end_point   = $args{max};
177           10                                 31         $range_func  = 'range_num';
178                                                      }
179                                                      elsif ( $col_type eq 'timestamp' ) {
180   ***      0                                  0         my $sql = "SELECT UNIX_TIMESTAMP('$args{min}'), UNIX_TIMESTAMP('$args{max}')";
181   ***      0                                  0         MKDEBUG && _d($sql);
182   ***      0                                  0         ($start_point, $end_point) = $args{dbh}->selectrow_array($sql);
183   ***      0                                  0         $range_func  = 'range_timestamp';
184                                                      }
185                                                      elsif ( $col_type eq 'date' ) {
186            3                                 19         my $sql = "SELECT TO_DAYS('$args{min}'), TO_DAYS('$args{max}')";
187            3                                  7         MKDEBUG && _d($sql);
188            3                                  9         ($start_point, $end_point) = $args{dbh}->selectrow_array($sql);
189            3                                758         $range_func  = 'range_date';
190                                                      }
191                                                      elsif ( $col_type eq 'time' ) {
192            1                                  8         my $sql = "SELECT TIME_TO_SEC('$args{min}'), TIME_TO_SEC('$args{max}')";
193            1                                  3         MKDEBUG && _d($sql);
194            1                                  3         ($start_point, $end_point) = $args{dbh}->selectrow_array($sql);
195            1                                329         $range_func  = 'range_time';
196                                                      }
197                                                      elsif ( $col_type eq 'datetime' ) {
198                                                         # Newer versions of MySQL could use TIMESTAMPDIFF, but it's easier
199                                                         # to maintain just one kind of code, so I do it all with DATE_ADD().
200            2                                 12         $start_point = $self->timestampdiff($args{dbh}, $args{min});
201            2                                 11         $end_point   = $self->timestampdiff($args{dbh}, $args{max});
202            2                                  8         $range_func  = 'range_datetime';
203                                                      }
204                                                      else {
205   ***      0                                  0         die "I don't know how to chunk $col_type\n";
206                                                      }
207                                                   
208                                                      # The endpoints could easily be undef, because of things like dates that
209                                                      # are '0000-00-00'.  The only thing to do is make them zeroes and
210                                                      # they'll be done in a single chunk then.
211           16    100                          76      if ( !defined $start_point ) {
212            1                                  3         MKDEBUG && _d('Start point is undefined');
213            1                                  3         $start_point = 0;
214                                                      }
215   ***     16     50     33                  174      if ( !defined $end_point || $end_point < $start_point ) {
216   ***      0                                  0         MKDEBUG && _d('End point is undefined or before start point');
217   ***      0                                  0         $end_point = 0;
218                                                      }
219           16                                 35      MKDEBUG && _d('Start and end of chunk range:',$start_point,',', $end_point);
220                                                   
221                                                      # Calculate the chunk size, in terms of "distance between endpoints."  If
222                                                      # possible and requested, forbid chunks from being any bigger than
223                                                      # specified.
224           16                                109      my $interval = $args{size} * ($end_point - $start_point) / $args{rows_in_range};
225           16    100                          76      if ( $int_types{$col_type} ) {
226           11                                 78         $interval = ceil($interval);
227                                                      }
228           16           100                   62      $interval ||= $args{size};
229   ***     16     50                          67      if ( $args{exact} ) {
230   ***      0                                  0         $interval = $args{size};
231                                                      }
232           16                                 37      MKDEBUG && _d('Chunk interval:', $interval, 'units');
233                                                   
234                                                      # Generate a list of chunk boundaries.  The first and last chunks are
235                                                      # inclusive, and will catch any rows before or after the end of the
236                                                      # supposed range.  So 1-100 divided into chunks of 30 should actually end
237                                                      # up with chunks like this:
238                                                      #           < 30
239                                                      # >= 30 AND < 60
240                                                      # >= 60 AND < 90
241                                                      # >= 90
242           16                                 72      my $col = "`$args{col}`";
243           16    100                          60      if ( $start_point < $end_point ) {
244           15                                 44         my ( $beg, $end );
245           15                                 47         my $iter = 0;
246                                                         for ( my $i = $start_point; $i < $end_point; $i += $interval ) {
247           42                                244            ( $beg, $end ) = $self->$range_func($args{dbh}, $i, $interval, $end_point);
248                                                   
249                                                            # The first chunk.
250           41    100                        3185            if ( $iter++ == 0 ) {
251           14                                 93               push @chunks, "$col < " . $self->quote($end);
252                                                            }
253                                                            else {
254                                                               # The normal case is a chunk in the middle of the range somewhere.
255           27                                139               push @chunks, "$col >= " . $self->quote($beg) . " AND $col < " . $self->quote($end);
256                                                            }
257           15                                 46         }
258                                                   
259                                                         # Remove the last chunk and replace it with one that matches everything
260                                                         # from the beginning of the last chunk to infinity.  If the chunk column
261                                                         # is nullable, do NULL separately.
262           14                                 76         my $nullable = $args{table}->{is_nullable}->{$args{col}};
263           14                                 39         pop @chunks;
264           14    100                          51         if ( @chunks ) {
265           13                                 59            push @chunks, "$col >= " . $self->quote($beg);
266                                                         }
267                                                         else {
268   ***      1     50                           6            push @chunks, $nullable ? "$col IS NOT NULL" : '1=1';
269                                                         }
270           14    100                          62         if ( $nullable ) {
271            1                                  5            push @chunks, "$col IS NULL";
272                                                         }
273                                                   
274                                                      }
275                                                      else {
276                                                         # There are no chunks; just do the whole table in one chunk.
277            1                                  4         push @chunks, '1=1';
278                                                      }
279                                                   
280           15                                137      return @chunks;
281                                                   }
282                                                   
283                                                   sub get_first_chunkable_column {
284   ***      0                    0             0      my ( $self, $table, $opts ) = @_;
285   ***      0                                  0      my ($exact, $cols) = $self->find_chunk_columns($table, $opts);
286   ***      0                                  0      return ( $cols->[0]->{column}, $cols->[0]->{index} );
287                                                   }
288                                                   
289                                                   # Convert a size in rows or bytes to a number of rows in the table, using SHOW
290                                                   # TABLE STATUS.  If the size is a string with a suffix of M/G/k, interpret it as
291                                                   # mebibytes, gibibytes, or kibibytes respectively.  If it's just a number, treat
292                                                   # it as a number of rows and return right away.
293                                                   sub size_to_rows {
294            3                    3            70      my ( $self, $dbh, $db, $tbl, $size, $dumper ) = @_;
295                                                     
296            3                                 23      my ( $num, $suffix ) = $size =~ m/^(\d+)([MGk])?$/;
297            3    100                          14      if ( $suffix ) { # Convert to bytes.
                    100                               
298   ***      1      0                           9         $size = $suffix eq 'k' ? $num * 1_024
      ***            50                               
299                                                               : $suffix eq 'M' ? $num * 1_024 * 1_024
300                                                               :                  $num * 1_024 * 1_024 * 1_024;
301                                                      }
302                                                      elsif ( $num ) {
303            1                                  7         return $num;
304                                                      }
305                                                      else {
306            1                                  3         die "Invalid size spec $size; must be an integer with optional suffix kMG";
307                                                      }
308                                                   
309            1                                  8      my @status = $dumper->get_table_status($dbh, $self->{quoter}, $db);
310            1                                  6      my ($status) = grep { $_->{name} eq $tbl } @status;
              23                                 84   
311            1                                  6      my $avg_row_length = $status->{avg_row_length};
312   ***      1     50                          20      return $avg_row_length ? ceil($size / $avg_row_length) : undef;
313                                                   }
314                                                   
315                                                   # Determine the range of values for the chunk_col column on this table.
316                                                   # The $where could come from many places; it is not trustworthy.
317                                                   sub get_range_statistics {
318            2                    2           100      my ( $self, $dbh, $db, $tbl, $col, $where ) = @_;
319            2                                  9      my $q = $self->{quoter};
320            2    100                          12      my $sql = "SELECT MIN(" . $q->quote($col) . "), MAX(" . $q->quote($col)
321                                                         . ") FROM " . $q->quote($db, $tbl)
322                                                         . ($where ? " WHERE $where" : '');
323            2                                  6      MKDEBUG && _d($sql);
324            2                                  7      my ( $min, $max );
325            2                                  7      eval {
326            2                                  6         ( $min, $max ) = $dbh->selectrow_array($sql);
327                                                      };
328            2    100                         237      if ( $EVAL_ERROR ) {
329            1                                  5         chomp $EVAL_ERROR;
330   ***      1     50                           7         if ( $EVAL_ERROR =~ m/in your SQL syntax/ ) {
331            1                                  3            die "$EVAL_ERROR (WHERE clause: $where)";
332                                                         }
333                                                         else {
334   ***      0                                  0            die $EVAL_ERROR;
335                                                         }
336                                                      }
337   ***      1     50                           6      $sql = "EXPLAIN SELECT * FROM " . $q->quote($db, $tbl)
338                                                         . ($where ? " WHERE $where" : '');
339            1                                  3      MKDEBUG && _d($sql);
340            1                                  3      my $expl = $dbh->selectrow_hashref($sql);
341                                                      return (
342            1                                 18         min           => $min,
343                                                         max           => $max,
344                                                         rows_in_range => $expl->{rows},
345                                                      );
346                                                   }
347                                                   
348                                                   # Quotes values only when needed, and uses double-quotes instead of
349                                                   # single-quotes (see comments earlier).
350                                                   sub quote {
351           81                   81           326      my ( $self, $val ) = @_;
352           81    100                         801      return $val =~ m/\d[:-]/ ? qq{"$val"} : $val;
353                                                   }
354                                                   
355                                                   # Takes a query prototype and fills in placeholders.  The 'where' arg should be
356                                                   # an arrayref of WHERE clauses that will be joined with AND.
357                                                   sub inject_chunks {
358            4                    4            65      my ( $self, %args ) = @_;
359            4                                 25      foreach my $arg ( qw(database table chunks chunk_num query) ) {
360   ***     20     50                          90         die "$arg is required" unless defined $args{$arg};
361                                                      }
362            4                                 11      MKDEBUG && _d('Injecting chunk', $args{chunk_num});
363            4                                 27      my $comment = sprintf("/*%s.%s:%d/%d*/",
364                                                         $args{database}, $args{table},
365            4                                 19         $args{chunk_num} + 1, scalar @{$args{chunks}});
366            4                                 28      $args{query} =~ s!/\*PROGRESS_COMMENT\*/!$comment!;
367            4                                 22      my $where = "WHERE (" . $args{chunks}->[$args{chunk_num}] . ')';
368   ***      4    100     66                   28      if ( $args{where} && grep { $_ } @{$args{where}} ) {
               5                                 25   
               4                                 20   
369            4                                 24         $where .= " AND ("
370            3                                 11            . join(" AND ", map { "($_)" } grep { $_ } @{$args{where}} )
               5                                 16   
               3                                 11   
371                                                            . ")";
372                                                      }
373            4                                 31      my $db_tbl     = $self->{quoter}->quote(@args{qw(database table)});
374            4    100                          22      my $index_hint = defined $args{index_hint}
375                                                                       ? "USE INDEX (`$args{index_hint}`)"
376                                                                       : '';
377            4                                  9      MKDEBUG && _d('Parameters:',
378                                                         Dumper({WHERE => $where, DB_TBL => $db_tbl, INDEX_HINT => $index_hint}));
379            4                                 31      $args{query} =~ s!/\*WHERE\*/! $where!;
380            4                                 16      $args{query} =~ s!/\*DB_TBL\*/!$db_tbl!;
381            4                                 18      $args{query} =~ s!/\*INDEX_HINT\*/! $index_hint!;
382            4                                 29      $args{query} =~ s!/\*CHUNK_NUM\*/! $args{chunk_num} AS chunk_num,!;
383            4                                 39      return $args{query};
384                                                   }
385                                                   
386                                                   # ###########################################################################
387                                                   # Range functions.
388                                                   # ###########################################################################
389                                                   sub range_num {
390           22                   22           105      my ( $self, $dbh, $start, $interval, $max ) = @_;
391           22                                128      my $end = min($max, $start + $interval);
392                                                   
393                                                   
394                                                      # "Remove" scientific notation so the regex below does not make
395                                                      # 6.123456e+18 into 6.12345.
396           22    100                         138      $start = sprintf('%.17f', $start) if $start =~ /e/;
397           22    100                         197      $end   = sprintf('%.17f', $end)   if $end   =~ /e/;
398                                                   
399                                                      # Trim decimal places, if needed.  This helps avoid issues with float
400                                                      # precision differing on different platforms.
401           22                                108      $start =~ s/\.(\d{5}).*$/.$1/;
402           22                                114      $end   =~ s/\.(\d{5}).*$/.$1/;
403                                                   
404           22    100                          89      if ( $end > $start ) {
405           21                                145         return ( $start, $end );
406                                                      }
407                                                      else {
408            1                                  3         die "Chunk size is too small: $end !> $start\n";
409                                                      }
410                                                   }
411                                                   
412                                                   sub range_time {
413            3                    3            17      my ( $self, $dbh, $start, $interval, $max ) = @_;
414            3                                 30      my $sql = "SELECT SEC_TO_TIME($start), SEC_TO_TIME(LEAST($max, $start + $interval))";
415            3                                  7      MKDEBUG && _d($sql);
416            3                                  8      return $dbh->selectrow_array($sql);
417                                                   }
418                                                   
419                                                   sub range_date {
420           11                   11            56      my ( $self, $dbh, $start, $interval, $max ) = @_;
421           11                                 94      my $sql = "SELECT FROM_DAYS($start), FROM_DAYS(LEAST($max, $start + $interval))";
422           11                                 25      MKDEBUG && _d($sql);
423           11                                 25      return $dbh->selectrow_array($sql);
424                                                   }
425                                                   
426                                                   sub range_datetime {
427            6                    6            32      my ( $self, $dbh, $start, $interval, $max ) = @_;
428            6                                 63      my $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $start SECOND), "
429                                                          . "DATE_ADD('$EPOCH', INTERVAL LEAST($max, $start + $interval) SECOND)";
430            6                                 12      MKDEBUG && _d($sql);
431            6                                 28      return $dbh->selectrow_array($sql);
432                                                   }
433                                                   
434                                                   sub range_timestamp {
435   ***      0                    0             0      my ( $self, $dbh, $start, $interval, $max ) = @_;
436   ***      0                                  0      my $sql = "SELECT FROM_UNIXTIME($start), FROM_UNIXTIME(LEAST($max, $start + $interval))";
437   ***      0                                  0      MKDEBUG && _d($sql);
438   ***      0                                  0      return $dbh->selectrow_array($sql);
439                                                   }
440                                                   
441                                                   # Returns the number of seconds between $EPOCH and the value, according to
442                                                   # the MySQL server.  (The server can do no wrong).  I believe this code is right
443                                                   # after looking at the source of sql/time.cc but I am paranoid and add in an
444                                                   # extra check just to make sure.  Earlier versions overflow on large interval
445                                                   # values, such as on 3.23.58, '1970-01-01' - interval 58000000000 second is
446                                                   # 2037-06-25 11:29:04.  I know of no workaround.  TO_DAYS('0000-....') is NULL,
447                                                   # so we treat it as 0.
448                                                   sub timestampdiff {
449            4                    4            18      my ( $self, $dbh, $time ) = @_;
450            4                                 27      my $sql = "SELECT (COALESCE(TO_DAYS('$time'), 0) * 86400 + TIME_TO_SEC('$time')) "
451                                                         . "- TO_DAYS('$EPOCH 00:00:00') * 86400";
452            4                                 29      MKDEBUG && _d($sql);
453            4                                  8      my ( $diff ) = $dbh->selectrow_array($sql);
454            4                                734      $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $diff SECOND)";
455            4                                 12      MKDEBUG && _d($sql);
456            4                                 10      my ( $check ) = $dbh->selectrow_array($sql);
457   ***      4     50                         514      die <<"   EOF"
458                                                      Incorrect datetime math: given $time, calculated $diff but checked to $check.
459                                                      This is probably because you are using a version of MySQL that overflows on
460                                                      large interval values to DATE_ADD().  If not, please report this as a bug.
461                                                      EOF
462                                                         unless $check eq $time;
463            4                                 19      return $diff;
464                                                   }
465                                                   
466                                                   sub _d {
467   ***      0                    0                    my ($package, undef, $line) = caller 0;
468   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
469   ***      0                                              map { defined $_ ? $_ : 'undef' }
470                                                           @_;
471   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
472                                                   }
473                                                   
474                                                   1;
475                                                   
476                                                   # ###########################################################################
477                                                   # End TableChunker package
478                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0      1   unless $args{'quoter'}
59           100      1      4   if ($$opts{'possible_keys'} and @{$$opts{'possible_keys'};})
72    ***     50      0     19   unless $$key{'type'} eq 'BTREE'
78           100      4     14   if ($$opts{'exact'})
79           100      3      1   unless $$key{'is_unique'} and @{$$key{'cols'};} == 1
100          100      3     12   unless $int_types{$$table{'type_for'}{$col}} or $real_types{$$table{'type_for'}{$col}}
107          100      1      4   if $$opts{'exact'} and scalar @candidate_cols
118          100      4      1   if (not %prefer) { }
120   ***     50      4      0   if ($$table{'keys'}{'PRIMARY'})
158   ***     50      0    112   unless defined $args{$arg}
174          100     10      6   if ($col_type =~ /(?:int|year|float|double|decimal)$/) { }
      ***     50      0      6   elsif ($col_type eq 'timestamp') { }
             100      3      3   elsif ($col_type eq 'date') { }
             100      1      2   elsif ($col_type eq 'time') { }
      ***     50      2      0   elsif ($col_type eq 'datetime') { }
211          100      1     15   if (not defined $start_point)
215   ***     50      0     16   if (not defined $end_point or $end_point < $start_point)
225          100     11      5   if ($int_types{$col_type})
229   ***     50      0     16   if ($args{'exact'})
243          100     15      1   if ($start_point < $end_point) { }
250          100     14     27   if ($iter++ == 0) { }
264          100     13      1   if (@chunks) { }
268   ***     50      0      1   $nullable ? :
270          100      1     13   if ($nullable)
297          100      1      2   if ($suffix) { }
             100      1      1   elsif ($num) { }
298   ***      0      0      0   $suffix eq 'M' ? :
      ***     50      1      0   $suffix eq 'k' ? :
312   ***     50      1      0   $avg_row_length ? :
320          100      1      1   $where ? :
328          100      1      1   if ($EVAL_ERROR)
330   ***     50      1      0   if ($EVAL_ERROR =~ /in your SQL syntax/) { }
337   ***     50      0      1   $where ? :
352          100     40     41   $val =~ /\d[:-]/ ? :
360   ***     50      0     20   unless defined $args{$arg}
368          100      3      1   if ($args{'where'} and grep {$_;} @{$args{'where'};})
374          100      1      3   defined $args{'index_hint'} ? :
396          100      2     20   if $start =~ /e/
397          100      2     20   if $end =~ /e/
404          100     21      1   if ($end > $start) { }
457   ***     50      0      4   unless $check eq $time
468   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
75           100     18      1   defined $_ and next KEY
107          100      4      1   $$opts{'exact'} and scalar @candidate_cols

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
59    ***     66      4      0      1   $$opts{'possible_keys'} and @{$$opts{'possible_keys'};}
79    ***     66      3      0      1   $$key{'is_unique'} and @{$$key{'cols'};} == 1
368   ***     66      0      1      3   $args{'where'} and grep {$_;} @{$args{'where'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
56           100      2      3   $opts ||= {}
86           100      1     12   $prefer{$$a{'name'}} || 9999
             100      1     12   $prefer{$$b{'name'}} || 9999
228          100     15      1   $interval ||= $args{'size'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
100   ***     66     12      0      3   $int_types{$$table{'type_for'}{$col}} or $real_types{$$table{'type_for'}{$col}}
215   ***     33      0      0     16   not defined $end_point or $end_point < $start_point


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
BEGIN                          1 /home/daniel/dev/maatkit/common/TableChunker.pm:32 
calculate_chunks              16 /home/daniel/dev/maatkit/common/TableChunker.pm:156
find_chunk_columns             5 /home/daniel/dev/maatkit/common/TableChunker.pm:55 
get_range_statistics           2 /home/daniel/dev/maatkit/common/TableChunker.pm:318
inject_chunks                  4 /home/daniel/dev/maatkit/common/TableChunker.pm:358
new                            1 /home/daniel/dev/maatkit/common/TableChunker.pm:35 
quote                         81 /home/daniel/dev/maatkit/common/TableChunker.pm:351
range_date                    11 /home/daniel/dev/maatkit/common/TableChunker.pm:420
range_datetime                 6 /home/daniel/dev/maatkit/common/TableChunker.pm:427
range_num                     22 /home/daniel/dev/maatkit/common/TableChunker.pm:390
range_time                     3 /home/daniel/dev/maatkit/common/TableChunker.pm:413
size_to_rows                   3 /home/daniel/dev/maatkit/common/TableChunker.pm:294
timestampdiff                  4 /home/daniel/dev/maatkit/common/TableChunker.pm:449

Uncovered Subroutines
---------------------

Subroutine                 Count Location                                           
-------------------------- ----- ---------------------------------------------------
_d                             0 /home/daniel/dev/maatkit/common/TableChunker.pm:467
get_first_chunkable_column     0 /home/daniel/dev/maatkit/common/TableChunker.pm:284
range_timestamp                0 /home/daniel/dev/maatkit/common/TableChunker.pm:435


