---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/TableSyncChunk.pm   88.7   80.0   54.5   81.8    n/a  100.0   84.3
Total                          88.7   80.0   54.5   81.8    n/a  100.0   84.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncChunk.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Sep 24 23:37:25 2009
Finish:       Thu Sep 24 23:37:26 2009

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
18                                                    # TableSyncChunk package $Revision: 4743 $
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
               1                                  8   
30             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  7   
31                                                    
32             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
33             1                    1             8   use List::Util qw(max);
               1                                  3   
               1                                 12   
34             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  5   
35                                                    $Data::Dumper::Indent    = 1;
36                                                    $Data::Dumper::Sortkeys  = 1;
37                                                    $Data::Dumper::Quotekeys = 0;
38                                                    
39             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
40                                                    
41                                                    sub new {
42             1                    1            25      my ( $class, %args ) = @_;
43             1                                  7      foreach my $arg ( qw(TableChunker Quoter) ) {
44    ***      2     50                          10         die "I need a $arg argument" unless defined $args{$arg};
45                                                       }
46             1                                  6      my $self = { %args };
47             1                                 17      return bless $self, $class;
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
65             7                    7            94      my ( $self, %args ) = @_;
66             7                                 31      foreach my $arg ( qw(tbl_struct) ) {
67    ***      7     50                          49         die "I need a $arg argument" unless defined $args{$arg};
68                                                       }
69                                                    
70                                                       # Find all possible chunkable cols/indexes.  If Chunker can handle it OK
71                                                       # but *not* with exact chunk sizes, it means it's using only the first
72                                                       # column of a multi-column index, which could be really bad.  It's better
73                                                       # to use Nibble for these, because at least it can reliably select a chunk
74                                                       # of rows of the desired size.
75             7                                 70      my ($exact, @chunkable_cols) = $self->{TableChunker}->find_chunk_columns(
76                                                          %args,
77                                                          exact => 1,
78                                                       );
79             7    100                          40      return unless $exact;
80                                                    
81                                                       # Check if the requested chunk col and/or index are among the possible
82                                                       # columns found above.
83             5                                 13      my $colno;
84             5    100    100                   40      if ( $args{chunk_col} || $args{chunk_index} ) {
85             4                                 11         MKDEBUG && _d('Checking requested col', $args{chunk_col},
86                                                             'and/or index', $args{chunk_index});
87             4                                 26         for my $i ( 0..$#chunkable_cols ) {
88             8    100                          33            if ( $args{chunk_col} ) {
89             6    100                          34               next unless $chunkable_cols[$i]->{column} eq $args{chunk_col};
90                                                             }
91             5    100                          23            if ( $args{chunk_index} ) {
92             4    100                          25               next unless $chunkable_cols[$i]->{index} eq $args{chunk_index};
93                                                             }
94             3                                  8            $colno = $i;
95             3                                 10            last;
96                                                          }
97                                                    
98             4    100                          16         if ( !$colno ) {
99             1                                  3            MKDEBUG && _d('Cannot chunk on column', $args{chunk_col},
100                                                               'and/or using index', $args{chunk_index});
101            1                                  8            return;
102                                                         }
103                                                      }
104                                                      else {
105            1                                  3         $colno = 0;  # First, best chunkable column/index.
106                                                      }
107                                                   
108            4                                 10      MKDEBUG && _d('Can chunk on column', $chunkable_cols[$colno]->{column},
109                                                         'using index', $chunkable_cols[$colno]->{index});
110                                                      return (
111            4                                 67         1,
112                                                         chunk_col   => $chunkable_cols[$colno]->{column},
113                                                         chunk_index => $chunkable_cols[$colno]->{index},
114                                                      ),
115                                                   }
116                                                   
117                                                   sub prepare_to_sync {
118            4                    4           122      my ( $self, %args ) = @_;
119            4                                 36      my @required_args = qw(dbh db tbl tbl_struct cols chunk_col
120                                                                             chunk_size crc_col ChangeHandler);
121            4                                 16      foreach my $arg ( @required_args ) {
122   ***     36     50                         155         die "I need a $arg argument" unless defined $args{$arg};
123                                                      }
124            4                                 16      my $chunker  = $self->{TableChunker};
125                                                   
126            4                                 18      $self->{chunk_col}       = $args{chunk_col};
127            4                                 19      $self->{crc_col}         = $args{crc_col};
128            4                                 16      $self->{index_hint}      = $args{index_hint};
129            4                                 15      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
130            4                                 16      $self->{ChangeHandler}   = $args{ChangeHandler};
131                                                   
132            4                                 29      $self->{ChangeHandler}->fetch_back($args{dbh});
133                                                   
134            4                                 13      my @chunks;
135            4                                 46      my %range_params = $chunker->get_range_statistics(%args);
136   ***      4     50                          23      if ( !grep { !defined $range_params{$_} } qw(min max rows_in_range) ) {
              12                                 53   
137            4                                 44         $args{chunk_size} = $chunker->size_to_rows(%args);
138            4                                 42         @chunks = $chunker->calculate_chunks(%args, %range_params);
139                                                      }
140                                                      else {
141   ***      0                                  0         MKDEBUG && _d('No range statistics; using single chunk 1=1');
142   ***      0                                  0         @chunks = '1=1';
143                                                      }
144                                                   
145            4                                 29      $self->{chunks}    = \@chunks;
146            4                                 21      $self->{chunk_num} = 0;
147            4                                 13      $self->{state}     = 0;
148                                                   
149            4                                 55      return;
150                                                   }
151                                                   
152                                                   sub uses_checksum {
153   ***      0                    0             0      return 1;
154                                                   }
155                                                   
156                                                   sub set_checksum_queries {
157            3                    3            18      my ( $self, $chunk_sql, $row_sql ) = @_;
158   ***      3     50                          14      die "I need a chunk_sql argument" unless $chunk_sql;
159   ***      3     50                          12      die "I need a row_sql argument" unless $row_sql;
160            3                                 14      $self->{chunk_sql} = $chunk_sql;
161            3                                 12      $self->{row_sql} = $row_sql;
162            3                                 12      return;
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
177            5                    5            42      my ( $self, %args ) = @_;
178            5    100                          27      if ( $self->{state} ) {  # checksum a chunk of rows
179            2                                 13         return 'SELECT '
180                                                            . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
181   ***      2    100     50                   14            . join(', ', map { $self->{Quoter}->quote($_) } @{$self->key_cols()})
               2    100                          15   
182                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
183                                                            . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
184                                                            . ' '. ($self->{index_hint} || '')
185                                                            . ' WHERE (' . $self->{chunks}->[$self->{chunk_num}] . ')'
186                                                            . ($args{where} ? " AND ($args{where})" : '');
187                                                      }
188                                                      else {  # checksum the rows
189            3                                 47         return $self->{TableChunker}->inject_chunks(
190                                                            database   => $args{database},
191                                                            table      => $args{table},
192                                                            chunks     => $self->{chunks},
193                                                            chunk_num  => $self->{chunk_num},
194                                                            query      => $self->{chunk_sql},
195                                                            index_hint => $self->{index_hint},
196                                                            where      => [ $args{where} ],
197                                                         );
198                                                      }
199                                                   }
200                                                   
201                                                   sub same_row {
202            3                    3            17      my ( $self, $lr, $rr ) = @_;
203   ***      3    100     33                   24      if ( $self->{state} ) {  # checksumming rows
      ***            50                               
204            2    100                          18         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
205            1                                  7            $self->{ChangeHandler}->change('UPDATE', $lr, $self->key_cols());
206                                                         }
207                                                      }
208                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
209                                                         # checksumming a chunk of rows
210            1                                  2         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
211            1                                  3         MKDEBUG && _d('Will examine this chunk before moving to next');
212            1                                  5         $self->{state} = 1; # Must examine this chunk row-by-row
213                                                      }
214                                                   }
215                                                   
216                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
217                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
218                                                   # cnt will be 0, but the result set should still come back.
219                                                   sub not_in_right {
220            1                    1             6      my ( $self, $lr ) = @_;
221   ***      1     50                           8      die "Called not_in_right in state 0" unless $self->{state};
222            1                                  7      $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
223            1                                  5      return;
224                                                   }
225                                                   
226                                                   sub not_in_left {
227            2                    2             9      my ( $self, $rr ) = @_;
228            2    100                           8      die "Called not_in_left in state 0" unless $self->{state};
229            1                                  5      $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
230            1                                  6      return;
231                                                   }
232                                                   
233                                                   sub done_with_rows {
234            4                    4            18      my ( $self ) = @_;
235            4    100                          28      if ( $self->{state} == 1 ) {
236                                                         # The chunk of rows differed, now checksum the rows.
237            1                                  3         $self->{state} = 2;
238            1                                  3         MKDEBUG && _d('Setting state =', $self->{state});
239                                                      }
240                                                      else {
241                                                         # State might be 0 or 2.  If 0 then the chunk of rows was the same
242                                                         # and we move on to the next chunk.  If 2 then we just resolved any
243                                                         # row differences by calling not_in_left/right() so move on to the
244                                                         # next chunk.
245            3                                 13         $self->{state} = 0;
246            3                                 11         $self->{chunk_num}++;
247            3                                  7         MKDEBUG && _d('Setting state =', $self->{state},
248                                                            'chunk_num =', $self->{chunk_num});
249                                                      }
250            4                                 14      return;
251                                                   }
252                                                   
253                                                   sub done {
254            1                    1             4      my ( $self ) = @_;
255                                                      MKDEBUG && _d('Done with', $self->{chunk_num}, 'of',
256            1                                  4         scalar(@{$self->{chunks}}), 'chunks');
257            1                                  2      MKDEBUG && $self->{state} && _d('Chunk differs; must examine rows');
258            1                                 20      return $self->{state} == 0
259   ***      1            33                    9         && $self->{chunk_num} >= scalar(@{$self->{chunks}})
260                                                   }
261                                                   
262                                                   sub pending_changes {
263            3                    3            13      my ( $self ) = @_;
264            3    100                          17      if ( $self->{state} ) {
265            2                                  4         MKDEBUG && _d('There are pending changes');
266                                                         # There are pending changes because in state 1 or 2 the chunk of rows
267                                                         # differs so there's at least 1 row that differs and needs to be changed.
268            2                                 12         return 1;
269                                                      }
270                                                      else {
271            1                                  3         MKDEBUG && _d('No pending changes');
272            1                                  6         return 0;
273                                                      }
274                                                   }
275                                                   
276                                                   sub key_cols {
277            6                    6            24      my ( $self ) = @_;
278            6                                 18      my @cols;
279            6    100                          31      if ( $self->{state} == 0 ) {
280            1                                  4         @cols = qw(chunk_num);
281                                                      }
282                                                      else {
283            5                                 24         @cols = $self->{chunk_col};
284                                                      }
285            6                                 18      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
286            6                                 43      return \@cols;
287                                                   }
288                                                   
289                                                   sub _d {
290   ***      0                    0                    my ($package, undef, $line) = caller 0;
291   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
292   ***      0                                              map { defined $_ ? $_ : 'undef' }
293                                                           @_;
294   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
295                                                   }
296                                                   
297                                                   1;
298                                                   
299                                                   # ###########################################################################
300                                                   # End TableSyncChunk package
301                                                   # ###########################################################################


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
181          100      1      1   $$self{'buffer_in_mysql'} ? :
             100      1      1   $args{'where'} ? :
203          100      2      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
204          100      1      1   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
221   ***     50      0      1   unless $$self{'state'}
228          100      1      1   unless $$self{'state'}
235          100      1      3   if ($$self{'state'} == 1) { }
264          100      2      1   if ($$self{'state'}) { }
279          100      1      5   if ($$self{'state'} == 0) { }
291   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
259   ***     33      0      0      1   $$self{'state'} == 0 && $$self{'chunk_num'} >= scalar @{$$self{'chunks'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
181   ***     50      2      0   $$self{'index_hint'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
84           100      3      1      1   $args{'chunk_col'} or $args{'chunk_index'}
203   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


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
done                     1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:254
done_with_rows           4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:234
get_sql                  5 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:177
key_cols                 6 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:277
new                      1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:42 
not_in_left              2 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:227
not_in_right             1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:220
pending_changes          3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:263
prepare_to_sync          4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:118
same_row                 3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:202
set_checksum_queries     3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:157

Uncovered Subroutines
---------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:290
name                     0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:51 
prepare_sync_cycle       0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:166
uses_checksum            0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:153


