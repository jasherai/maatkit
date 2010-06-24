---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/TableSyncChunk.pm   86.5   76.8   61.5   78.3    0.0    1.5   77.2
TableSyncChunk.t               98.0   50.0   33.3  100.0    n/a   98.5   95.6
Total                          92.2   74.2   56.2   88.4    0.0  100.0   84.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:48:39 2010
Finish:       Thu Jun 24 19:48:39 2010

Run:          TableSyncChunk.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:48:41 2010
Finish:       Thu Jun 24 19:48:42 2010

/home/daniel/dev/maatkit/common/TableSyncChunk.pm

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
18                                                    # TableSyncChunk package $Revision: 6389 $
19                                                    # ###########################################################################
20                                                    package TableSyncChunk;
21                                                    # This package implements a simple sync algorithm:
22                                                    # * Chunk the table (see TableChunker.pm)
23                                                    # * Checksum each chunk (state 0)
24                                                    # * If a chunk differs, make a note to checksum the rows in the chunk (state 1)
25                                                    # * Checksum them (state 2)
26                                                    # * If a row differs, it must be synced
27                                                    # See TableSyncStream for the TableSync interface this conforms to.
28                                                    
29             1                    1             6   use strict;
               1                                  2   
               1                                 12   
30             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                 10   
31                                                    
32             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
33             1                    1             8   use List::Util qw(max);
               1                                  3   
               1                                 18   
34             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  6   
35                                                    $Data::Dumper::Indent    = 1;
36                                                    $Data::Dumper::Sortkeys  = 1;
37                                                    $Data::Dumper::Quotekeys = 0;
38                                                    
39    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 23   
40                                                    
41                                                    # Required args:
42                                                    #   * TableChunker   obj: common module
43                                                    #   * Quoter         obj: common module
44                                                    # Optional args:
45                                                    #   * same_row       coderef: These three callbacks allow the caller to
46                                                    #   * not_in_left    coderef: override the default behavior of the respective
47                                                    #   * not_in_right   coderef: subs.  Used for bidirectional syncs.
48                                                    sub new {
49    ***      1                    1      0     11      my ( $class, %args ) = @_;
50             1                                 10      foreach my $arg ( qw(TableChunker Quoter) ) {
51    ***      2     50                          20         die "I need a $arg argument" unless defined $args{$arg};
52                                                       }
53             1                                 10      my $self = { %args };
54             1                                 39      return bless $self, $class;
55                                                    }
56                                                    
57                                                    sub name {
58    ***      0                    0      0      0      return 'Chunk';
59                                                    }
60                                                    
61                                                    sub set_callback {
62    ***      0                    0      0      0      my ( $self, $callback, $code ) = @_;
63    ***      0                                  0      $self->{$callback} = $code;
64    ***      0                                  0      return;
65                                                    }
66                                                    
67                                                    # Returns a hash (true) with a chunk_col and chunk_index that can be used
68                                                    # to sync the given tbl_struct.  Else, returns nothing (false) if the table
69                                                    # cannot be synced.  Arguments:
70                                                    #   * tbl_struct    Return value of TableParser::parse()
71                                                    #   * chunk_col     (optional) Column name to chunk on
72                                                    #   * chunk_index   (optional) Index to use for chunking
73                                                    # If either chunk_col or chunk_index are given, then they are required so
74                                                    # the return value will only be true if they're among the possible chunkable
75                                                    # columns.  If neither is given, then the first (best) chunkable col and index
76                                                    # are returned.  The return value should be passed back to prepare_to_sync().
77                                                    sub can_sync {
78    ***      7                    7      0     71      my ( $self, %args ) = @_;
79             7                                 55      foreach my $arg ( qw(tbl_struct) ) {
80    ***      7     50                          69         die "I need a $arg argument" unless defined $args{$arg};
81                                                       }
82                                                    
83                                                       # Find all possible chunkable cols/indexes.  If Chunker can handle it OK
84                                                       # but *not* with exact chunk sizes, it means it's using only the first
85                                                       # column of a multi-column index, which could be really bad.  It's better
86                                                       # to use Nibble for these, because at least it can reliably select a chunk
87                                                       # of rows of the desired size.
88             7                                 95      my ($exact, @chunkable_cols) = $self->{TableChunker}->find_chunk_columns(
89                                                          %args,
90                                                          exact => 1,
91                                                       );
92             7    100                        2312      return unless $exact;
93                                                    
94                                                       # Check if the requested chunk col and/or index are among the possible
95                                                       # columns found above.
96             5                                 17      my $colno;
97             5    100    100                   66      if ( $args{chunk_col} || $args{chunk_index} ) {
98             4                                 14         MKDEBUG && _d('Checking requested col', $args{chunk_col},
99                                                             'and/or index', $args{chunk_index});
100            4                                 37         for my $i ( 0..$#chunkable_cols ) {
101            8    100                          52            if ( $args{chunk_col} ) {
102            6    100                          52               next unless $chunkable_cols[$i]->{column} eq $args{chunk_col};
103                                                            }
104            5    100                          32            if ( $args{chunk_index} ) {
105            4    100                          36               next unless $chunkable_cols[$i]->{index} eq $args{chunk_index};
106                                                            }
107            3                                 12            $colno = $i;
108            3                                 13            last;
109                                                         }
110                                                   
111            4    100                          26         if ( !$colno ) {
112            1                                  4            MKDEBUG && _d('Cannot chunk on column', $args{chunk_col},
113                                                               'and/or using index', $args{chunk_index});
114            1                                  8            return;
115                                                         }
116                                                      }
117                                                      else {
118            1                                  6         $colno = 0;  # First, best chunkable column/index.
119                                                      }
120                                                   
121            4                                 13      MKDEBUG && _d('Can chunk on column', $chunkable_cols[$colno]->{column},
122                                                         'using index', $chunkable_cols[$colno]->{index});
123                                                      return (
124            4                                 96         1,
125                                                         chunk_col   => $chunkable_cols[$colno]->{column},
126                                                         chunk_index => $chunkable_cols[$colno]->{index},
127                                                      ),
128                                                   }
129                                                   
130                                                   sub prepare_to_sync {
131   ***      5                    5      0    100      my ( $self, %args ) = @_;
132            5                                 66      my @required_args = qw(dbh db tbl tbl_struct cols chunk_col
133                                                                             chunk_size crc_col ChangeHandler);
134            5                                 29      foreach my $arg ( @required_args ) {
135   ***     45     50                         304         die "I need a $arg argument" unless defined $args{$arg};
136                                                      }
137            5                                 27      my $chunker  = $self->{TableChunker};
138                                                   
139            5                                 30      $self->{chunk_col}       = $args{chunk_col};
140            5                                 28      $self->{crc_col}         = $args{crc_col};
141            5                                 29      $self->{index_hint}      = $args{index_hint};
142            5                                 28      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
143            5                                 38      $self->{ChangeHandler}   = $args{ChangeHandler};
144                                                   
145            5                                 62      $self->{ChangeHandler}->fetch_back($args{dbh});
146                                                   
147                                                      # Make sure our chunk col is in the list of comparison columns
148                                                      # used by TableChecksum::make_row_checksum() to create $row_sql.
149            5                                119      push @{$args{cols}}, $args{chunk_col};
               5                                 38   
150                                                   
151            5                                 19      my @chunks;
152            5                                 81      my %range_params = $chunker->get_range_statistics(%args);
153   ***      5     50                         220      if ( !grep { !defined $range_params{$_} } qw(min max rows_in_range) ) {
              15                                 97   
154            5                                 74         ($args{chunk_size}) = $chunker->size_to_rows(%args);
155            5                                805         @chunks = $chunker->calculate_chunks(%args, %range_params);
156                                                      }
157                                                      else {
158   ***      0                                  0         MKDEBUG && _d('No range statistics; using single chunk 1=1');
159   ***      0                                  0         @chunks = '1=1';
160                                                      }
161                                                   
162            5                               4397      $self->{chunks}    = \@chunks;
163            5                                 33      $self->{chunk_num} = 0;
164            5                                 27      $self->{state}     = 0;
165                                                   
166            5                                 52      return;
167                                                   }
168                                                   
169                                                   sub uses_checksum {
170   ***      0                    0      0      0      return 1;
171                                                   }
172                                                   
173                                                   sub set_checksum_queries {
174   ***      3                    3      0   5961      my ( $self, $chunk_sql, $row_sql ) = @_;
175   ***      3     50                          29      die "I need a chunk_sql argument" unless $chunk_sql;
176   ***      3     50                          18      die "I need a row_sql argument" unless $row_sql;
177            3                                 19      $self->{chunk_sql} = $chunk_sql;
178            3                                 16      $self->{row_sql}   = $row_sql;
179            3                                 16      return;
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
190                                                   # Depth-first: if there are any bad chunks, return SQL to inspect their rows
191                                                   # individually.  Otherwise get the next chunk.  This way we can sync part of the
192                                                   # table before moving on to the next part.
193                                                   sub get_sql {
194   ***      8                    8      0     89      my ( $self, %args ) = @_;
195            8    100                          71      if ( $self->{state} ) {  # select rows in a chunk
196            3                                 16         my $q = $self->{Quoter};
197            3                                 18         return 'SELECT /*rows in chunk*/ '
198                                                            . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
199                                                            . $self->{row_sql} . " AS $self->{crc_col}"
200                                                            . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
201                                                            . ' '. ($self->{index_hint} || '')
202                                                            . ' WHERE (' . $self->{chunks}->[$self->{chunk_num}] . ')'
203                                                            . ($args{where} ? " AND ($args{where})" : '')
204            3    100    100                   65            . ' ORDER BY ' . join(', ', map {$q->quote($_) } @{$self->key_cols()});
               3    100                         236   
205                                                      }
206                                                      else {  # select a chunk of rows
207            5                                100         return $self->{TableChunker}->inject_chunks(
208                                                            database   => $args{database},
209                                                            table      => $args{table},
210                                                            chunks     => $self->{chunks},
211                                                            chunk_num  => $self->{chunk_num},
212                                                            query      => $self->{chunk_sql},
213                                                            index_hint => $self->{index_hint},
214                                                            where      => [ $args{where} ],
215                                                         );
216                                                      }
217                                                   }
218                                                   
219                                                   sub same_row {
220   ***      3                    3      0     33      my ( $self, %args ) = @_;
221            3                                 28      my ($lr, $rr) = @args{qw(lr rr)};
222                                                   
223   ***      3    100     33                   34      if ( $self->{state} ) {  # checksumming rows
      ***            50                               
224            2    100                          27         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
225            1                                  5            my $action   = 'UPDATE';
226            1                                  5            my $auth_row = $lr;
227            1                                  4            my $change_dbh;
228                                                   
229                                                            # Give callback a chance to determine how to handle this difference.
230   ***      1     50                           9            if ( $self->{same_row} ) {
231   ***      0                                  0               ($action, $auth_row, $change_dbh) = $self->{same_row}->(%args);
232                                                            }
233                                                   
234            1                                  9            $self->{ChangeHandler}->change(
235                                                               $action,            # Execute the action
236                                                               $auth_row,          # with these row values
237                                                               $self->key_cols(),  # identified by these key cols
238                                                               $change_dbh,        # on this dbh
239                                                            );
240                                                         }
241                                                      }
242                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
243                                                         # checksumming a chunk of rows
244            1                                  3         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
245            1                                  4         MKDEBUG && _d('Will examine this chunk before moving to next');
246            1                                  9         $self->{state} = 1; # Must examine this chunk row-by-row
247                                                      }
248                                                   }
249                                                   
250                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
251                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
252                                                   # cnt will be 0, but the result set should still come back.
253                                                   sub not_in_right {
254   ***      1                    1      0     19      my ( $self, %args ) = @_;
255   ***      1     50                          11      die "Called not_in_right in state 0" unless $self->{state};
256                                                   
257            1                                  5      my $action   = 'INSERT';
258            1                                  5      my $auth_row = $args{lr};
259            1                                  4      my $change_dbh;
260                                                   
261                                                      # Give callback a chance to determine how to handle this difference.
262   ***      1     50                           8      if ( $self->{not_in_right} ) {
263   ***      0                                  0         ($action, $auth_row, $change_dbh) = $self->{not_in_right}->(%args);
264                                                      }
265                                                   
266            1                                  9      $self->{ChangeHandler}->change(
267                                                         $action,            # Execute the action
268                                                         $auth_row,          # with these row values
269                                                         $self->key_cols(),  # identified by these key cols
270                                                         $change_dbh,        # on this dbh
271                                                      );
272            1                                 33      return;
273                                                   }
274                                                   
275                                                   sub not_in_left {
276   ***      2                    2      0     20      my ( $self, %args ) = @_;
277            2    100                          13      die "Called not_in_left in state 0" unless $self->{state};
278                                                   
279            1                                  4      my $action   = 'DELETE';
280            1                                  6      my $auth_row = $args{rr};
281            1                                  5      my $change_dbh;
282                                                   
283                                                      # Give callback a chance to determine how to handle this difference.
284   ***      1     50                           9      if ( $self->{not_in_left} ) {
285   ***      0                                  0         ($action, $auth_row, $change_dbh) = $self->{not_in_left}->(%args);
286                                                      }
287                                                   
288            1                                  9      $self->{ChangeHandler}->change(
289                                                         $action,            # Execute the action
290                                                         $auth_row,          # with these row values
291                                                         $self->key_cols(),  # identified by these key cols
292                                                         $change_dbh,        # on this dbh
293                                                      );
294            1                                 29      return;
295                                                   }
296                                                   
297                                                   sub done_with_rows {
298   ***      5                    5      0     31      my ( $self ) = @_;
299            5    100                          41      if ( $self->{state} == 1 ) {
300                                                         # The chunk of rows differed, now checksum the rows.
301            1                                  7         $self->{state} = 2;
302            1                                  5         MKDEBUG && _d('Setting state =', $self->{state});
303                                                      }
304                                                      else {
305                                                         # State might be 0 or 2.  If 0 then the chunk of rows was the same
306                                                         # and we move on to the next chunk.  If 2 then we just resolved any
307                                                         # row differences by calling not_in_left/right() so move on to the
308                                                         # next chunk.
309            4                                 20         $self->{state} = 0;
310            4                                 19         $self->{chunk_num}++;
311            4                                 15         MKDEBUG && _d('Setting state =', $self->{state},
312                                                            'chunk_num =', $self->{chunk_num});
313                                                      }
314            5                                 37      return;
315                                                   }
316                                                   
317                                                   sub done {
318   ***      1                    1      0      8      my ( $self ) = @_;
319                                                      MKDEBUG && _d('Done with', $self->{chunk_num}, 'of',
320            1                                  4         scalar(@{$self->{chunks}}), 'chunks');
321            1                                  3      MKDEBUG && $self->{state} && _d('Chunk differs; must examine rows');
322            1                                 23      return $self->{state} == 0
323   ***      1            33                   24         && $self->{chunk_num} >= scalar(@{$self->{chunks}})
324                                                   }
325                                                   
326                                                   sub pending_changes {
327   ***      3                    3      0     21      my ( $self ) = @_;
328            3    100                          23      if ( $self->{state} ) {
329            2                                  7         MKDEBUG && _d('There are pending changes');
330                                                         # There are pending changes because in state 1 or 2 the chunk of rows
331                                                         # differs so there's at least 1 row that differs and needs to be changed.
332            2                                 19         return 1;
333                                                      }
334                                                      else {
335            1                                  4         MKDEBUG && _d('No pending changes');
336            1                                 11         return 0;
337                                                      }
338                                                   }
339                                                   
340                                                   sub key_cols {
341   ***      7                    7      0     43      my ( $self ) = @_;
342            7                                 28      my @cols;
343            7    100                          51      if ( $self->{state} == 0 ) {
344            1                                  7         @cols = qw(chunk_num);
345                                                      }
346                                                      else {
347            6                                 43         @cols = $self->{chunk_col};
348                                                      }
349            7                                 25      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
350            7                                 77      return \@cols;
351                                                   }
352                                                   
353                                                   sub _d {
354   ***      0                    0                    my ($package, undef, $line) = caller 0;
355   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
356   ***      0                                              map { defined $_ ? $_ : 'undef' }
357                                                           @_;
358   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
359                                                   }
360                                                   
361                                                   1;
362                                                   
363                                                   # ###########################################################################
364                                                   # End TableSyncChunk package
365                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
51    ***     50      0      2   unless defined $args{$arg}
80    ***     50      0      7   unless defined $args{$arg}
92           100      2      5   unless $exact
97           100      4      1   if ($args{'chunk_col'} or $args{'chunk_index'}) { }
101          100      6      2   if ($args{'chunk_col'})
102          100      3      3   unless $chunkable_cols[$i]{'column'} eq $args{'chunk_col'}
104          100      4      1   if ($args{'chunk_index'})
105          100      2      2   unless $chunkable_cols[$i]{'index'} eq $args{'chunk_index'}
111          100      1      3   if (not $colno)
135   ***     50      0     45   unless defined $args{$arg}
153   ***     50      5      0   if (not grep {not defined $range_params{$_};} 'min', 'max', 'rows_in_range') { }
175   ***     50      0      3   unless $chunk_sql
176   ***     50      0      3   unless $row_sql
195          100      3      5   if ($$self{'state'}) { }
204          100      1      2   $$self{'buffer_in_mysql'} ? :
             100      2      1   $args{'where'} ? :
223          100      2      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
224          100      1      1   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
230   ***     50      0      1   if ($$self{'same_row'})
255   ***     50      0      1   unless $$self{'state'}
262   ***     50      0      1   if ($$self{'not_in_right'})
277          100      1      1   unless $$self{'state'}
284   ***     50      0      1   if ($$self{'not_in_left'})
299          100      1      4   if ($$self{'state'} == 1) { }
328          100      2      1   if ($$self{'state'}) { }
343          100      1      6   if ($$self{'state'} == 0) { }
355   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
323   ***     33      0      0      1   $$self{'state'} == 0 && $$self{'chunk_num'} >= scalar @{$$self{'chunks'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
39    ***     50      0      1   $ENV{'MKDEBUG'} || 0
204          100      2      1   $$self{'index_hint'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
97           100      3      1      1   $args{'chunk_col'} or $args{'chunk_index'}
223   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                             
-------------------- ----- --- -----------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncChunk.pm:29 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncChunk.pm:30 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncChunk.pm:32 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncChunk.pm:33 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncChunk.pm:34 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncChunk.pm:39 
can_sync                 7   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:78 
done                     1   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:318
done_with_rows           5   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:298
get_sql                  8   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:194
key_cols                 7   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:341
new                      1   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:49 
not_in_left              2   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:276
not_in_right             1   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:254
pending_changes          3   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:327
prepare_to_sync          5   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:131
same_row                 3   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:220
set_checksum_queries     3   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:174

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                             
-------------------- ----- --- -----------------------------------------------------
_d                       0     /home/daniel/dev/maatkit/common/TableSyncChunk.pm:354
name                     0   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:58 
prepare_sync_cycle       0   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:183
set_callback             0   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:62 
uses_checksum            0   0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:170


TableSyncChunk.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            34      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  3   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More;
               1                                  3   
               1                                  9   
13                                                    
14                                                    # Open a connection to MySQL, or skip the rest of the tests.
15             1                    1            16   use DSNParser;
               1                                  3   
               1                                 12   
16             1                    1            14   use Sandbox;
               1                                  4   
               1                                 10   
17             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 37   
18                                                    
19             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
20             1                                231   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
21             1                                 52   my $dbh = $sb->get_dbh_for('master');
22                                                    
23    ***      1     50                         379   if ( $dbh ) {
24             1                                  9      plan tests => 34;
25                                                    }
26                                                    else {
27    ***      0                                  0      plan skip_all => 'Cannot connect to MySQL';
28                                                    }
29                                                    
30             1                                498   $sb->create_dbs($dbh, ['test']);
31                                                    
32             1                    1            13   use TableSyncChunk;
               1                                  4   
               1                                 13   
33             1                    1            11   use Quoter;
               1                                  3   
               1                                 11   
34             1                    1            17   use ChangeHandler;
               1                                  4   
               1                                 11   
35             1                    1            10   use TableChecksum;
               1                                  4   
               1                                 15   
36             1                    1            12   use TableChunker;
               1                                  3   
               1                                 12   
37             1                    1            12   use TableParser;
               1                                  3   
               1                                 12   
38             1                    1            11   use MySQLDump;
               1                                  3   
               1                                 13   
39             1                    1            10   use VersionParser;
               1                                  2   
               1                                 11   
40             1                    1             9   use TableSyncer;
               1                                  3   
               1                                 11   
41             1                    1            11   use MasterSlave;
               1                                  3   
               1                                 13   
42                                                    
43             1                                831   my $mysql = $sb->_use_for('master');
44                                                    
45             1                             1133099   diag(`$mysql < $trunk/common/t/samples/before-TableSyncChunk.sql`);
46                                                    
47             1                                 26   my $q  = new Quoter();
48             1                                100   my $tp = new TableParser(Quoter => $q);
49             1                                131   my $du = new MySQLDump();
50             1                                 85   my $vp = new VersionParser();
51             1                                 60   my $ms = new MasterSlave();
52             1                                 77   my $chunker    = new TableChunker( Quoter => $q, MySQLDump => $du );
53             1                                102   my $checksum   = new TableChecksum( Quoter => $q, VersionParser => $vp );
54             1                                117   my $syncer     = new TableSyncer(
55                                                       MasterSlave   => $ms,
56                                                       TableChecksum => $checksum,
57                                                       Quoter        => $q,
58                                                       VersionParser => $vp
59                                                    );
60                                                    
61             1                                119   my $ddl;
62             1                                  4   my $tbl_struct;
63             1                                  3   my %args;
64             1                                  5   my @rows;
65             1                                 31   my $src = {
66                                                       db  => 'test',
67                                                       tbl => 'test1',
68                                                       dbh => $dbh,
69                                                    };
70             1                                  9   my $dst = {
71                                                       db  => 'test',
72                                                       tbl => 'test1',
73                                                       dbh => $dbh,
74                                                    };
75                                                    
76                                                    my $ch = new ChangeHandler(
77                                                       Quoter    => new Quoter(),
78                                                       right_db  => 'test',
79                                                       right_tbl => 'test1',
80                                                       left_db   => 'test',
81                                                       left_tbl  => 'test1',
82                                                       replace   => 0,
83             1                    3            10      actions   => [ sub { push @rows, $_[0] }, ],
               3                               1149   
84                                                       queue     => 0,
85                                                    );
86                                                    
87             1                                537   my $t = new TableSyncChunk(
88                                                       TableChunker  => $chunker,
89                                                       Quoter        => $q,
90                                                    );
91             1                                 18   isa_ok($t, 'TableSyncChunk');
92                                                    
93             1                                 28   $ddl        = $du->get_create_table($dbh, $q, 'test', 'test1');
94             1                                272   $tbl_struct = $tp->parse($ddl);
95             1                               1310   %args       = (
96                                                       src           => $src,
97                                                       dst           => $dst,
98                                                       dbh           => $dbh,
99                                                       db            => 'test',
100                                                      tbl           => 'test1',
101                                                      tbl_struct    => $tbl_struct,
102                                                      cols          => $tbl_struct->{cols},
103                                                      chunk_col     => 'a',
104                                                      chunk_index   => 'PRIMARY',
105                                                      chunk_size    => 2,
106                                                      where         => 'a>2',
107                                                      crc_col       => '__crc',
108                                                      index_hint    => 'USE INDEX (`PRIMARY`)',
109                                                      ChangeHandler => $ch,
110                                                   );
111            1                                 27   $t->prepare_to_sync(%args);
112                                                   
113                                                   # Test with FNV_64 just to make sure there are no errors
114            1                                  7   eval { $dbh->do('select fnv_64(1)') };
               1                                 78   
115   ***      1     50                          20   SKIP: {
116            1                                  8      skip 'No FNV_64 function installed', 1 if $EVAL_ERROR;
117                                                   
118   ***      0                                  0      $t->set_checksum_queries(
119                                                         $syncer->make_checksum_queries(%args, function => 'FNV_64')
120                                                      );
121   ***      0                                  0      is(
122                                                         $t->get_sql(
123                                                            where      => 'foo=1',
124                                                            database   => 'test',
125                                                            table      => 'test1', 
126                                                         ),
127                                                         q{SELECT /*test.test1:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, }
128                                                         . q{COALESCE(LOWER(CONV(BIT_XOR(CAST(FNV_64(`a`, `b`) AS UNSIGNED)), 10, 16)) AS }
129                                                         . q{crc FROM `test`.`test1` USE INDEX (`PRIMARY`) WHERE (1=1) AND ((foo=1))},
130                                                         'First nibble SQL with FNV_64 (with USE INDEX)',
131                                                      );
132                                                   }
133                                                   
134                                                   $t->set_checksum_queries(
135            1                                 36      $syncer->make_checksum_queries(%args, function => 'SHA1')
136                                                   );
137            1                                 21   is_deeply(
138                                                      $t->{chunks},
139                                                      [
140                                                         # it should really chunk in chunks of 1, but table stats are bad.
141                                                         '1=1',
142                                                      ],
143                                                      'Chunks with WHERE'
144                                                   );
145                                                   
146            1                                 29   unlike(
147                                                      $t->get_sql(
148                                                         where    => 'foo=1',
149                                                         database => 'test',
150                                                         table    => 'test1',
151                                                      ),
152                                                      qr/SQL_BUFFER_RESULT/,
153                                                      'No buffering',
154                                                   );
155                                                   
156                                                   # SQL_BUFFER_RESULT only appears in the row query, state 1 or 2.
157            1                                 36   $t->prepare_to_sync(%args, buffer_in_mysql => 1);
158            1                                  8   $t->{state} = 1;
159            1                                 12   like(
160                                                      $t->get_sql(
161                                                         where    => 'foo=1',
162                                                         database => 'test',
163                                                         table    => 'test1', 
164                                                      ),
165                                                      qr/SELECT ..rows in chunk.. SQL_BUFFER_RESULT/,
166                                                      'Has SQL_BUFFER_RESULT',
167                                                   );
168                                                   
169                                                   # Remove the WHERE so we get enough rows to make chunks.
170            1                                 15   $args{where} = undef;
171            1                                 16   $t->prepare_to_sync(%args);
172            1                                 19   $t->set_checksum_queries(
173                                                      $syncer->make_checksum_queries(%args, function => 'SHA1')
174                                                   );
175            1                                 17   is_deeply(
176                                                      $t->{chunks},
177                                                      [
178                                                         "`a` < '3'",
179                                                         "`a` >= '3'",
180                                                      ],
181                                                      'Chunks'
182                                                   );
183                                                   
184            1                                 21   like(
185                                                      $t->get_sql(
186                                                         where    => 'foo=1',
187                                                         database => 'test',
188                                                         table    => 'test1',
189                                                      ),
190                                                      qr/SELECT .*?CONCAT_WS.*?`a` < '3'/,
191                                                      'First chunk SQL (without index hint)',
192                                                   );
193                                                   
194            1                                 18   is_deeply($t->key_cols(), [qw(chunk_num)], 'Key cols in state 0');
195            1                                 26   $t->done_with_rows();
196                                                   
197            1                                 11   like($t->get_sql(
198                                                         quoter     => $q,
199                                                         where      => 'foo=1',
200                                                         database   => 'test',
201                                                         table      => 'test1',
202                                                         index_hint => 'USE INDEX (`PRIMARY`)',
203                                                      ),
204                                                      qr/SELECT .*?CONCAT_WS.*?FROM `test`\.`test1` USE INDEX \(`PRIMARY`\) WHERE.*?`a` >= '3'/,
205                                                      'Second chunk SQL (with index hint)',
206                                                   );
207                                                   
208            1                                 16   $t->done_with_rows();
209            1                                 14   ok($t->done(), 'Now done');
210                                                   
211                                                   # Now start over, and this time "find some bad chunks," as it were.
212                                                   
213            1                                 17   $t->prepare_to_sync(%args);
214            1                                 18   $t->set_checksum_queries(
215                                                      $syncer->make_checksum_queries(%args, function => 'SHA1')
216                                                   );
217                                                   throws_ok(
218            1                    1            34      sub { $t->not_in_left() },
219            1                                 46      qr/in state 0/,
220                                                      'not_in_(side) illegal in state 0',
221                                                   );
222                                                   
223                                                   # "find a bad row"
224            1                                 37   $t->same_row(
225                                                      lr => { chunk_num => 0, cnt => 0, crc => 'abc' },
226                                                      rr => { chunk_num => 0, cnt => 1, crc => 'abc' },
227                                                   );
228            1                                 12   ok($t->pending_changes(), 'Pending changes found');
229            1                                 12   is($t->{state}, 1, 'Working inside chunk');
230            1                                 10   $t->done_with_rows();
231            1                                 10   is($t->{state}, 2, 'Now in state to fetch individual rows');
232            1                                  8   ok($t->pending_changes(), 'Pending changes not done yet');
233            1                                 12   is(
234                                                      $t->get_sql(
235                                                         database => 'test',
236                                                         table    => 'test1',
237                                                      ),
238                                                      "SELECT /*rows in chunk*/ `a`, `b`, SHA1(CONCAT_WS('#', `a`, `b`)) AS __crc FROM "
239                                                         . "`test`.`test1` USE INDEX (`PRIMARY`) WHERE (`a` < '3')"
240                                                         . " ORDER BY `a`",
241                                                      'SQL now working inside chunk'
242                                                   );
243            1                                 14   ok($t->{state}, 'Still working inside chunk');
244            1                                  9   is(scalar(@rows), 0, 'No bad row triggered');
245                                                   
246            1                                 17   $t->not_in_left(rr => {a => 1});
247                                                   
248            1                                 12   is_deeply(\@rows,
249                                                      ["DELETE FROM `test`.`test1` WHERE `a`='1' LIMIT 1"],
250                                                      'Working inside chunk, got a bad row',
251                                                   );
252                                                   
253                                                   # Should cause it to fetch back from the DB to figure out the right thing to do
254            1                                 25   $t->not_in_right(lr => {a => 1});
255            1                                 15   is_deeply(\@rows,
256                                                      [
257                                                      "DELETE FROM `test`.`test1` WHERE `a`='1' LIMIT 1",
258                                                      "INSERT INTO `test`.`test1`(`a`, `b`) VALUES ('1', 'en')",
259                                                      ],
260                                                      'Missing row fetched back from DB',
261                                                   );
262                                                   
263                                                   # Shouldn't cause anything to happen
264            1                                 28   $t->same_row( lr => {a => 1, __crc => 'foo'}, rr => {a => 1, __crc => 'foo'} );
265                                                   
266            1                                 14   is_deeply(\@rows,
267                                                      [
268                                                      "DELETE FROM `test`.`test1` WHERE `a`='1' LIMIT 1",
269                                                      "INSERT INTO `test`.`test1`(`a`, `b`) VALUES ('1', 'en')",
270                                                      ],
271                                                      'No more rows added',
272                                                   );
273                                                   
274            1                                 30   $t->same_row( lr => {a => 1, __crc => 'foo'}, rr => {a => 1, __crc => 'bar'} );
275                                                   
276            1                                 44   is_deeply(\@rows,
277                                                      [
278                                                         "DELETE FROM `test`.`test1` WHERE `a`='1' LIMIT 1",
279                                                         "INSERT INTO `test`.`test1`(`a`, `b`) VALUES ('1', 'en')",
280                                                         "UPDATE `test`.`test1` SET `b`='en' WHERE `a`='1' LIMIT 1",
281                                                      ],
282                                                      'Row added to update differing row',
283                                                   );
284                                                   
285            1                                 18   $t->done_with_rows();
286            1                                 11   is($t->{state}, 0, 'Now not working inside chunk');
287            1                                 10   is($t->pending_changes(), 0, 'No pending changes');
288                                                   
289                                                   # ###########################################################################
290                                                   # Test can_sync().
291                                                   # ###########################################################################
292            1                                 14   $ddl        = $du->get_create_table($dbh, $q, 'test', 'test6');
293            1                                248   $tbl_struct = $tp->parse($ddl);
294            1                                785   is_deeply(
295                                                      [ $t->can_sync(tbl_struct=>$tbl_struct) ],
296                                                      [],
297                                                      'Cannot sync table1 (no good single column index)'
298                                                   );
299                                                   
300            1                                 25   $ddl        = $du->get_create_table($dbh, $q, 'test', 'test5');
301            1                                249   $tbl_struct = $tp->parse($ddl);
302            1                                611   is_deeply(
303                                                      [ $t->can_sync(tbl_struct=>$tbl_struct) ],
304                                                      [],
305                                                      'Cannot sync table5 (no indexes)'
306                                                   );
307                                                   
308                                                   # create table test3(a int not null primary key, b int not null, unique(b));
309                                                   
310            1                                 21   $ddl        = $du->get_create_table($dbh, $q, 'test', 'test3');
311            1                                279   $tbl_struct = $tp->parse($ddl);
312            1                               1089   is_deeply(
313                                                      [ $t->can_sync(tbl_struct=>$tbl_struct) ],
314                                                      [ 1,
315                                                        chunk_col   => 'a',
316                                                        chunk_index => 'PRIMARY',
317                                                      ],
318                                                      'Can sync table3, chooses best col and index'
319                                                   );
320                                                   
321            1                                 23   is_deeply(
322                                                      [ $t->can_sync(tbl_struct=>$tbl_struct, chunk_col=>'b') ],
323                                                      [ 1,
324                                                        chunk_col   => 'b',
325                                                        chunk_index => 'b',
326                                                      ],
327                                                      'Can sync table3 with requested col'
328                                                   );
329                                                   
330            1                                 27   is_deeply(
331                                                      [ $t->can_sync(tbl_struct=>$tbl_struct, chunk_index=>'b') ],
332                                                      [ 1,
333                                                        chunk_col   => 'b',
334                                                        chunk_index => 'b',
335                                                      ],
336                                                      'Can sync table3 with requested index'
337                                                   );
338                                                    
339            1                                 22   is_deeply(
340                                                      [ $t->can_sync(tbl_struct=>$tbl_struct, chunk_col=>'b', chunk_index=>'b') ],
341                                                      [ 1,
342                                                        chunk_col   => 'b',
343                                                        chunk_index => 'b',
344                                                      ],
345                                                      'Can sync table3 with requested col and index'
346                                                   );
347                                                   
348            1                                 13   is_deeply(
349                                                      [ $t->can_sync(tbl_struct=>$tbl_struct, chunk_col=>'b', chunk_index=>'PRIMARY') ],
350                                                      [],
351                                                      'Cannot sync table3 with requested col and index'
352                                                   );
353                                                   
354                                                   
355                                                   # #############################################################################
356                                                   # Issue 560: mk-table-sync generates impossible WHERE
357                                                   # Issue 996: might not chunk inside of mk-table-checksum's boundaries
358                                                   # #############################################################################
359            1                                 15   $t->prepare_to_sync(%args, index_hint => undef, replicate => 'test.checksum');
360            1                                  9   is(
361                                                      $t->get_sql(
362                                                         where    => 'x > 1 AND x <= 9',  # e.g. range from mk-table-checksum
363                                                         database => 'test',
364                                                         table    => 'test1', 
365                                                      ),
366                                                      "SELECT /*test.test1:1/2*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc := SHA1(CONCAT_WS('#', `a`, `b`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc FROM `test`.`test1`  WHERE (`a` < '3') AND ((x > 1 AND x <= 9))",
367                                                      'Chunk within chunk (chunk sql)'
368                                                   );
369                                                   
370                                                   # The above test shows that we can chunk (a<3) inside a given range (x>1 AND x<=9).
371                                                   # That tests issue 996.  Issue 560 was really an issue with nibbling within a chunk,
372                                                   # so there's a test similar to this one in TableSyncNibble.t.
373                                                   
374            1                                  6   $t->{state} = 2;
375            1                                  6   is(
376                                                      $t->get_sql(
377                                                         where    => 'x > 1 AND x <= 9',
378                                                         database => 'test',
379                                                         table    => 'test1', 
380                                                      ),
381                                                      "SELECT /*rows in chunk*/ `a`, `b`, SHA1(CONCAT_WS('#', `a`, `b`)) AS __crc FROM `test`.`test1`  WHERE (`a` < '3') AND (x > 1 AND x <= 9) ORDER BY `a`",
382                                                      'Chunk within chunk (row sql)'
383                                                   );
384                                                   
385            1                                  6   $t->{state} = 0;
386            1                                  6   $t->done_with_rows();
387            1                                  5   is(
388                                                      $t->get_sql(
389                                                         where    => 'x > 1 AND x <= 9',
390                                                         database => 'test',
391                                                         table    => 'test1', 
392                                                      ),
393                                                      "SELECT /*test.test1:2/2*/ 1 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, '0'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(\@crc := SHA1(CONCAT_WS('#', `a`, `b`)), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, '0'))), 0) AS crc FROM `test`.`test1`  WHERE (`a` >= '3') AND ((x > 1 AND x <= 9))",
394                                                      'Second chunk within chunk'
395                                                   );
396                                                   
397                                                   # #############################################################################
398                                                   # Done.
399                                                   # #############################################################################
400            1                                 18   $sb->wipe_clean($dbh);
401            1                                  7   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
23    ***     50      1      0   if ($dbh) { }
115   ***     50      1      0   if $EVAL_ERROR


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location            
---------- ----- --------------------
BEGIN          1 TableSyncChunk.t:10 
BEGIN          1 TableSyncChunk.t:11 
BEGIN          1 TableSyncChunk.t:12 
BEGIN          1 TableSyncChunk.t:15 
BEGIN          1 TableSyncChunk.t:16 
BEGIN          1 TableSyncChunk.t:17 
BEGIN          1 TableSyncChunk.t:32 
BEGIN          1 TableSyncChunk.t:33 
BEGIN          1 TableSyncChunk.t:34 
BEGIN          1 TableSyncChunk.t:35 
BEGIN          1 TableSyncChunk.t:36 
BEGIN          1 TableSyncChunk.t:37 
BEGIN          1 TableSyncChunk.t:38 
BEGIN          1 TableSyncChunk.t:39 
BEGIN          1 TableSyncChunk.t:4  
BEGIN          1 TableSyncChunk.t:40 
BEGIN          1 TableSyncChunk.t:41 
BEGIN          1 TableSyncChunk.t:9  
__ANON__       1 TableSyncChunk.t:218
__ANON__       3 TableSyncChunk.t:83 


