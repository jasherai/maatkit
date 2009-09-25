---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/TableSyncChunk.pm   89.0   80.0   54.5   81.8    n/a  100.0   84.5
Total                          89.0   80.0   54.5   81.8    n/a  100.0   84.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncChunk.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 18:33:02 2009
Finish:       Fri Sep 25 18:33:03 2009

/home/daniel/dev/maatkit/common/TableSyncChunk.pm

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
18                                                    # TableSyncChunk package $Revision: 4748 $
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
29             1                    1            13   use strict;
               1                                  3   
               1                                 12   
30             1                    1             8   use warnings FATAL => 'all';
               1                                  2   
               1                                 16   
31                                                    
32             1                    1             7   use English qw(-no_match_vars);
               1                                  4   
               1                                 11   
33             1                    1            19   use List::Util qw(max);
               1                                  2   
               1                                 22   
34             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  6   
35                                                    $Data::Dumper::Indent    = 1;
36                                                    $Data::Dumper::Sortkeys  = 1;
37                                                    $Data::Dumper::Quotekeys = 0;
38                                                    
39             1                    1             8   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
40                                                    
41                                                    sub new {
42             1                    1            23      my ( $class, %args ) = @_;
43             1                                  6      foreach my $arg ( qw(TableChunker Quoter) ) {
44    ***      2     50                          11         die "I need a $arg argument" unless defined $args{$arg};
45                                                       }
46             1                                  5      my $self = { %args };
47             1                                 16      return bless $self, $class;
48                                                    }
49                                                    
50                                                    sub name {
51    ***      0                    0             0      return 'Chunk';
52                                                    }
53                                                    
54                                                    # Returns a hash (true) with a chunk_col and chunk_index that can be used
55                                                    # to sync the given tbl_struct.  Else, returns nothing (false) if the table
56                                                    # cannot be synced.  Arguments:
57                                                    #   * tbl_struct    Return value of TableParser::parse()
58                                                    #   * chunk_col     (optional) Column name to chunk on
59                                                    #   * chunk_index   (optional) Index to use for chunking
60                                                    # If either chunk_col or chunk_index are given, then they are required so
61                                                    # the return value will only be true if they're among the possible chunkable
62                                                    # columns.  If neither is given, then the first (best) chunkable col and index
63                                                    # are returned.  The return value should be passed back to prepare_to_sync().
64                                                    sub can_sync {
65             7                    7           116      my ( $self, %args ) = @_;
66             7                                 35      foreach my $arg ( qw(tbl_struct) ) {
67    ***      7     50                          49         die "I need a $arg argument" unless defined $args{$arg};
68                                                       }
69                                                    
70                                                       # Find all possible chunkable cols/indexes.  If Chunker can handle it OK
71                                                       # but *not* with exact chunk sizes, it means it's using only the first
72                                                       # column of a multi-column index, which could be really bad.  It's better
73                                                       # to use Nibble for these, because at least it can reliably select a chunk
74                                                       # of rows of the desired size.
75             7                                 80      my ($exact, @chunkable_cols) = $self->{TableChunker}->find_chunk_columns(
76                                                          %args,
77                                                          exact => 1,
78                                                       );
79             7    100                          47      return unless $exact;
80                                                    
81                                                       # Check if the requested chunk col and/or index are among the possible
82                                                       # columns found above.
83             5                                 14      my $colno;
84             5    100    100                   43      if ( $args{chunk_col} || $args{chunk_index} ) {
85             4                                 10         MKDEBUG && _d('Checking requested col', $args{chunk_col},
86                                                             'and/or index', $args{chunk_index});
87             4                                 29         for my $i ( 0..$#chunkable_cols ) {
88             8    100                          37            if ( $args{chunk_col} ) {
89             6    100                          38               next unless $chunkable_cols[$i]->{column} eq $args{chunk_col};
90                                                             }
91             5    100                          20            if ( $args{chunk_index} ) {
92             4    100                          25               next unless $chunkable_cols[$i]->{index} eq $args{chunk_index};
93                                                             }
94             3                                 10            $colno = $i;
95             3                                  9            last;
96                                                          }
97                                                    
98             4    100                          17         if ( !$colno ) {
99             1                                  3            MKDEBUG && _d('Cannot chunk on column', $args{chunk_col},
100                                                               'and/or using index', $args{chunk_index});
101            1                                 11            return;
102                                                         }
103                                                      }
104                                                      else {
105            1                                  3         $colno = 0;  # First, best chunkable column/index.
106                                                      }
107                                                   
108            4                                 10      MKDEBUG && _d('Can chunk on column', $chunkable_cols[$colno]->{column},
109                                                         'using index', $chunkable_cols[$colno]->{index});
110                                                      return (
111            4                                 66         1,
112                                                         chunk_col   => $chunkable_cols[$colno]->{column},
113                                                         chunk_index => $chunkable_cols[$colno]->{index},
114                                                      ),
115                                                   }
116                                                   
117                                                   sub prepare_to_sync {
118            4                    4           117      my ( $self, %args ) = @_;
119            4                                 38      my @required_args = qw(dbh db tbl tbl_struct cols chunk_col
120                                                                             chunk_size crc_col ChangeHandler);
121            4                                 19      foreach my $arg ( @required_args ) {
122   ***     36     50                         157         die "I need a $arg argument" unless defined $args{$arg};
123                                                      }
124            4                                 20      my $chunker  = $self->{TableChunker};
125                                                   
126            4                                 17      $self->{chunk_col}       = $args{chunk_col};
127            4                                 18      $self->{crc_col}         = $args{crc_col};
128            4                                 15      $self->{index_hint}      = $args{index_hint};
129            4                                 16      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
130            4                                 17      $self->{ChangeHandler}   = $args{ChangeHandler};
131                                                   
132            4                                 35      $self->{ChangeHandler}->fetch_back($args{dbh});
133                                                   
134            4                                 11      my @chunks;
135            4                                 64      my %range_params = $chunker->get_range_statistics(%args);
136   ***      4     50                          31      if ( !grep { !defined $range_params{$_} } qw(min max rows_in_range) ) {
              12                                 66   
137            4                                 56         $args{chunk_size} = $chunker->size_to_rows(%args);
138            4                                 45         @chunks = $chunker->calculate_chunks(%args, %range_params);
139                                                      }
140                                                      else {
141   ***      0                                  0         MKDEBUG && _d('No range statistics; using single chunk 1=1');
142   ***      0                                  0         @chunks = '1=1';
143                                                      }
144                                                   
145            4                                 29      $self->{chunks}    = \@chunks;
146            4                                 23      $self->{chunk_num} = 0;
147            4                                 16      $self->{state}     = 0;
148                                                   
149            4                                 34      return;
150                                                   }
151                                                   
152                                                   sub uses_checksum {
153   ***      0                    0             0      return 1;
154                                                   }
155                                                   
156                                                   sub set_checksum_queries {
157            3                    3            20      my ( $self, $chunk_sql, $row_sql ) = @_;
158   ***      3     50                          15      die "I need a chunk_sql argument" unless $chunk_sql;
159   ***      3     50                          45      die "I need a row_sql argument" unless $row_sql;
160            3                                 14      $self->{chunk_sql} = $chunk_sql;
161            3                                 12      $self->{row_sql} = $row_sql;
162            3                                 13      return;
163                                                   }
164                                                   
165                                                   sub prepare_sync_cycle {
166   ***      0                    0             0      my ( $self, $host ) = @_;
167   ***      0                                  0      my $sql = 'SET @crc := "", @cnt := 0';
168   ***      0                                  0      MKDEBUG && _d($sql);
169   ***      0                                  0      $host->{dbh}->do($sql);
170   ***      0                                  0      return;
171                                                   }
172                                                   
173                                                   # Depth-first: if there are any bad chunks, return SQL to inspect their rows
174                                                   # individually.  Otherwise get the next chunk.  This way we can sync part of the
175                                                   # table before moving on to the next part.
176                                                   sub get_sql {
177            5                    5            46      my ( $self, %args ) = @_;
178            5    100                          29      if ( $self->{state} ) {  # checksum a chunk of rows
179            2                                  9         my $q = $self->{Quoter};
180            2                                 11         return 'SELECT /*rows in chunk*/ '
181                                                            . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
182            2                                 21            . join(', ', map { $q->quote($_) } @{$self->key_cols()})
               2                                  8   
183                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
184                                                            . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
185                                                            . ' '. ($self->{index_hint} || '')
186                                                            . ' WHERE (' . $self->{chunks}->[$self->{chunk_num}] . ')'
187                                                            . ($args{where} ? " AND ($args{where})" : '')
188   ***      2    100     50                   17            . ' ORDER BY ' . join(', ', map {$q->quote($_) } @{$self->key_cols()});
               2    100                           9   
189                                                      }
190                                                      else {  # checksum the rows
191            3                                 50         return $self->{TableChunker}->inject_chunks(
192                                                            database   => $args{database},
193                                                            table      => $args{table},
194                                                            chunks     => $self->{chunks},
195                                                            chunk_num  => $self->{chunk_num},
196                                                            query      => $self->{chunk_sql},
197                                                            index_hint => $self->{index_hint},
198                                                            where      => [ $args{where} ],
199                                                         );
200                                                      }
201                                                   }
202                                                   
203                                                   sub same_row {
204            3                    3            17      my ( $self, $lr, $rr ) = @_;
205   ***      3    100     33                   26      if ( $self->{state} ) {  # checksumming rows
      ***            50                               
206            2    100                          17         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
207            1                                  8            $self->{ChangeHandler}->change('UPDATE', $lr, $self->key_cols());
208                                                         }
209                                                      }
210                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
211                                                         # checksumming a chunk of rows
212            1                                  3         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
213            1                                  3         MKDEBUG && _d('Will examine this chunk before moving to next');
214            1                                  5         $self->{state} = 1; # Must examine this chunk row-by-row
215                                                      }
216                                                   }
217                                                   
218                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
219                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
220                                                   # cnt will be 0, but the result set should still come back.
221                                                   sub not_in_right {
222            1                    1             5      my ( $self, $lr ) = @_;
223   ***      1     50                           8      die "Called not_in_right in state 0" unless $self->{state};
224            1                                  7      $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
225            1                                  5      return;
226                                                   }
227                                                   
228                                                   sub not_in_left {
229            2                    2            10      my ( $self, $rr ) = @_;
230            2    100                          12      die "Called not_in_left in state 0" unless $self->{state};
231            1                                  9      $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
232            1                                  5      return;
233                                                   }
234                                                   
235                                                   sub done_with_rows {
236            4                    4            19      my ( $self ) = @_;
237            4    100                          26      if ( $self->{state} == 1 ) {
238                                                         # The chunk of rows differed, now checksum the rows.
239            1                                  4         $self->{state} = 2;
240            1                                  3         MKDEBUG && _d('Setting state =', $self->{state});
241                                                      }
242                                                      else {
243                                                         # State might be 0 or 2.  If 0 then the chunk of rows was the same
244                                                         # and we move on to the next chunk.  If 2 then we just resolved any
245                                                         # row differences by calling not_in_left/right() so move on to the
246                                                         # next chunk.
247            3                                 11         $self->{state} = 0;
248            3                                 10         $self->{chunk_num}++;
249            3                                  7         MKDEBUG && _d('Setting state =', $self->{state},
250                                                            'chunk_num =', $self->{chunk_num});
251                                                      }
252            4                                 14      return;
253                                                   }
254                                                   
255                                                   sub done {
256            1                    1             4      my ( $self ) = @_;
257                                                      MKDEBUG && _d('Done with', $self->{chunk_num}, 'of',
258            1                                  3         scalar(@{$self->{chunks}}), 'chunks');
259            1                                  2      MKDEBUG && $self->{state} && _d('Chunk differs; must examine rows');
260            1                                 14      return $self->{state} == 0
261   ***      1            33                   10         && $self->{chunk_num} >= scalar(@{$self->{chunks}})
262                                                   }
263                                                   
264                                                   sub pending_changes {
265            3                    3            15      my ( $self ) = @_;
266            3    100                          19      if ( $self->{state} ) {
267            2                                  5         MKDEBUG && _d('There are pending changes');
268                                                         # There are pending changes because in state 1 or 2 the chunk of rows
269                                                         # differs so there's at least 1 row that differs and needs to be changed.
270            2                                 17         return 1;
271                                                      }
272                                                      else {
273            1                                  3         MKDEBUG && _d('No pending changes');
274            1                                  9         return 0;
275                                                      }
276                                                   }
277                                                   
278                                                   sub key_cols {
279            8                    8            32      my ( $self ) = @_;
280            8                                 23      my @cols;
281            8    100                          41      if ( $self->{state} == 0 ) {
282            1                                  5         @cols = qw(chunk_num);
283                                                      }
284                                                      else {
285            7                                 39         @cols = $self->{chunk_col};
286                                                      }
287            8                                 23      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
288            8                                 73      return \@cols;
289                                                   }
290                                                   
291                                                   sub _d {
292   ***      0                    0                    my ($package, undef, $line) = caller 0;
293   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
294   ***      0                                              map { defined $_ ? $_ : 'undef' }
295                                                           @_;
296   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
297                                                   }
298                                                   
299                                                   1;
300                                                   
301                                                   # ###########################################################################
302                                                   # End TableSyncChunk package
303                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
44    ***     50      0      2   unless defined $args{$arg}
67    ***     50      0      7   unless defined $args{$arg}
79           100      2      5   unless $exact
84           100      4      1   if ($args{'chunk_col'} or $args{'chunk_index'}) { }
88           100      6      2   if ($args{'chunk_col'})
89           100      3      3   unless $chunkable_cols[$i]{'column'} eq $args{'chunk_col'}
91           100      4      1   if ($args{'chunk_index'})
92           100      2      2   unless $chunkable_cols[$i]{'index'} eq $args{'chunk_index'}
98           100      1      3   if (not $colno)
122   ***     50      0     36   unless defined $args{$arg}
136   ***     50      4      0   if (not grep {not defined $range_params{$_};} 'min', 'max', 'rows_in_range') { }
158   ***     50      0      3   unless $chunk_sql
159   ***     50      0      3   unless $row_sql
178          100      2      3   if ($$self{'state'}) { }
188          100      1      1   $$self{'buffer_in_mysql'} ? :
             100      1      1   $args{'where'} ? :
205          100      2      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
206          100      1      1   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
223   ***     50      0      1   unless $$self{'state'}
230          100      1      1   unless $$self{'state'}
237          100      1      3   if ($$self{'state'} == 1) { }
266          100      2      1   if ($$self{'state'}) { }
281          100      1      7   if ($$self{'state'} == 0) { }
293   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
261   ***     33      0      0      1   $$self{'state'} == 0 && $$self{'chunk_num'} >= scalar @{$$self{'chunks'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
188   ***     50      2      0   $$self{'index_hint'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
84           100      3      1      1   $args{'chunk_col'} or $args{'chunk_index'}
205   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


Covered Subroutines
-------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:29 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:30 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:32 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:33 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:34 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:39 
can_sync                 7 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:65 
done                     1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:256
done_with_rows           4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:236
get_sql                  5 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:177
key_cols                 8 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:279
new                      1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:42 
not_in_left              2 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:229
not_in_right             1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:222
pending_changes          3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:265
prepare_to_sync          4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:118
same_row                 3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:204
set_checksum_queries     3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:157

Uncovered Subroutines
---------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:292
name                     0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:51 
prepare_sync_cycle       0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:166
uses_checksum            0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:153


