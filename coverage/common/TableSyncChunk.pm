---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/TableSyncChunk.pm   87.6   66.7   38.5   88.2    n/a  100.0   79.5
Total                          87.6   66.7   38.5   88.2    n/a  100.0   79.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncChunk.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:04:03 2009
Finish:       Sat Aug 29 15:04:04 2009

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
18                                                    # TableSyncChunk package $Revision: 4493 $
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
               1                                  2   
               1                                  8   
30             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
31                                                    
32             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
33             1                    1             7   use List::Util qw(max);
               1                                  3   
               1                                 12   
34             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
35                                                    $Data::Dumper::Indent    = 0;
36                                                    $Data::Dumper::Quotekeys = 0;
37                                                    
38             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
39                                                    
40                                                    sub new {
41             4                    4           778      my ( $class, %args ) = @_;
42             4                                 31      foreach my $arg ( qw(dbh database table handler chunker quoter struct
43                                                                            checksum cols vp chunksize where possible_keys
44                                                                            dumper trim) ) {
45    ***     60     50                         249         die "I need a $arg argument" unless defined $args{$arg};
46                                                       }
47                                                    
48                                                       # Sanity check.  The row-level (state 2) checksums use __crc, so the table
49                                                       # had better not use that...
50             4                                 17      $args{crc_col} = '__crc';
51             4                                 29      while ( $args{struct}->{is_col}->{$args{crc_col}} ) {
52    ***      0                                  0         $args{crc_col} = "_$args{crc_col}"; # Prepend more _ until not a column.
53                                                       }
54             4                                  8      MKDEBUG && _d('CRC column will be named', $args{crc_col});
55                                                    
56                                                       # Chunk the table and store the chunks for later processing.
57             4                                 12      my @chunks;
58             4                                 39      my ( $col, $idx ) = $args{chunker}->get_first_chunkable_column(
59                                                          $args{struct}, { possible_keys => $args{possible_keys} });
60             4                                 16      $args{index} = $idx;
61    ***      4     50                          17      if ( $col ) {
62             4                                 38         my %params = $args{chunker}->get_range_statistics(
63                                                             $args{dbh}, $args{database}, $args{table}, $col,
64                                                             $args{where});
65    ***      4     50                          20         if ( !grep { !defined $params{$_} }
              12                                 53   
66                                                                qw(min max rows_in_range) )
67                                                          {
68             4                                 45            @chunks = $args{chunker}->calculate_chunks(
69                                                                dbh      => $args{dbh},
70                                                                table    => $args{struct},
71                                                                col      => $col,
72                                                                size     => $args{chunksize},
73                                                                %params,
74                                                             );
75                                                          }
76                                                          else {
77    ***      0                                  0            @chunks = '1=1';
78                                                          }
79             4                                 24         $args{chunk_col} = $col;
80                                                       }
81    ***      4     50                          18      die "Cannot chunk $args{database}.$args{table}" unless @chunks;
82             4                                 18      $args{chunks}     = \@chunks;
83             4                                 14      $args{chunk_num}  = 0;
84                                                    
85                                                       # Decide on checksumming strategy and store checksum query prototypes for
86                                                       # later.
87             4                                 46      $args{algorithm} = $args{checksum}->best_algorithm(
88                                                          algorithm   => 'BIT_XOR',
89                                                          vp          => $args{vp},
90                                                          dbh         => $args{dbh},
91                                                          where       => 1,
92                                                          chunk       => 1,
93                                                          count       => 1,
94                                                       );
95             4                                 31      $args{func} = $args{checksum}->choose_hash_func(
96                                                          func => $args{func},
97                                                          dbh  => $args{dbh},
98                                                       );
99             4                                 43      $args{crc_wid}    = $args{checksum}->get_crc_wid($args{dbh}, $args{func});
100            4                                 30      ($args{crc_type}) = $args{checksum}->get_crc_type($args{dbh}, $args{func});
101   ***      4     50     33                   58      if ( $args{algorithm} eq 'BIT_XOR' && $args{crc_type} !~ m/int$/ ) {
102            4                                 35         $args{opt_slice}
103                                                            = $args{checksum}->optimize_xor(dbh => $args{dbh}, func => $args{func});
104                                                      }
105   ***      4            50                   89      $args{chunk_sql} ||= $args{checksum}->make_checksum_query(
106                                                         dbname    => $args{database},
107                                                         tblname   => $args{table},
108                                                         table     => $args{struct},
109                                                         quoter    => $args{quoter},
110                                                         algorithm => $args{algorithm},
111                                                         func      => $args{func},
112                                                         crc_wid   => $args{crc_wid},
113                                                         crc_type  => $args{crc_type},
114                                                         opt_slice => $args{opt_slice},
115                                                         cols      => $args{cols},
116                                                         trim      => $args{trim},
117                                                         buffer    => $args{bufferinmysql},
118                                                      );
119   ***      4            50                   46      $args{row_sql} ||= $args{checksum}->make_row_checksum(
120                                                         table     => $args{struct},
121                                                         quoter    => $args{quoter},
122                                                         func      => $args{func},
123                                                         cols      => $args{cols},
124                                                         trim      => $args{trim},
125                                                      );
126                                                   
127            4                                 16      $args{state} = 0;
128            4                                 31      $args{handler}->fetch_back($args{dbh});
129            4                                167      return bless { %args }, $class;
130                                                   }
131                                                   
132                                                   # Depth-first: if there are any bad chunks, return SQL to inspect their rows
133                                                   # individually.  Otherwise get the next chunk.  This way we can sync part of the
134                                                   # table before moving on to the next part.
135                                                   sub get_sql {
136            5                    5            87      my ( $self, %args ) = @_;
137            5    100                          28      if ( $self->{state} ) {
138   ***      1     50                           6         my $index_hint = defined $args{index_hint}
139                                                                          ? " USE INDEX (`$args{index_hint}`) "
140                                                                          : '';
141            1                                  5         return 'SELECT '
142                                                            . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
143   ***      1     50                           7            . join(', ', map { $self->{quoter}->quote($_) } @{$self->key_cols()})
      ***      1     50                           5   
144                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
145                                                            . ' FROM ' . $self->{quoter}->quote(@args{qw(database table)})
146                                                            . $index_hint 
147                                                            . ' WHERE (' . $self->{chunks}->[$self->{chunk_num}] . ')'
148                                                            . ($args{where} ? " AND ($args{where})" : '');
149                                                      }
150                                                      else {
151            4                                 63         return $self->{chunker}->inject_chunks(
152                                                            database   => $args{database},
153                                                            table      => $args{table},
154                                                            chunks     => $self->{chunks},
155                                                            chunk_num  => $self->{chunk_num},
156                                                            query      => $self->{chunk_sql},
157                                                            where      => [$args{where}],
158                                                            quoter     => $self->{quoter},
159                                                            index_hint => $args{index_hint},
160                                                         );
161                                                      }
162                                                   }
163                                                   
164                                                   sub prepare {
165   ***      0                    0             0      my ( $self, $dbh ) = @_;
166   ***      0                                  0      my $sql = 'SET @crc := "", @cnt := 0';
167   ***      0                                  0      MKDEBUG && _d($sql);
168   ***      0                                  0      $dbh->do($sql);
169   ***      0                                  0      return;
170                                                   }
171                                                   
172                                                   sub same_row {
173            3                    3            40      my ( $self, $lr, $rr ) = @_;
174   ***      3    100     33                   21      if ( $self->{state} ) {
      ***            50                               
175            2    100                          16         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
176            1                                  5            $self->{handler}->change('UPDATE', $lr, $self->key_cols());
177                                                         }
178                                                      }
179                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
180            1                                  3         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
181            1                                  3         MKDEBUG && _d('Will examine this chunk before moving to next');
182            1                                  5         $self->{state} = 1; # Must examine this chunk row-by-row
183                                                      }
184                                                   }
185                                                   
186                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
187                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
188                                                   # cnt will be 0, but the result set should still come back.
189                                                   sub not_in_right {
190            1                    1             4      my ( $self, $lr ) = @_;
191   ***      1     50                           6      die "Called not_in_right in state 0" unless $self->{state};
192            1                                  7      $self->{handler}->change('INSERT', $lr, $self->key_cols());
193                                                   }
194                                                   
195                                                   sub not_in_left {
196            2                    2            62      my ( $self, $rr ) = @_;
197            2    100                           8      die "Called not_in_left in state 0" unless $self->{state};
198            1                                  6      $self->{handler}->change('DELETE', $rr, $self->key_cols());
199                                                   }
200                                                   
201                                                   sub done_with_rows {
202            4                    4            19      my ( $self ) = @_;
203            4    100                          22      if ( $self->{state} == 1 ) {
204            1                                  4         $self->{state} = 2;
205            1                                  3         MKDEBUG && _d('Setting state =', $self->{state});
206                                                      }
207                                                      else {
208            3                                 10         $self->{state} = 0;
209            3                                 11         $self->{chunk_num}++;
210            3                                 10         MKDEBUG && _d('Setting state =', $self->{state},
211                                                            'chunk_num =', $self->{chunk_num});
212                                                      }
213                                                   }
214                                                   
215                                                   sub done {
216            1                    1             5      my ( $self ) = @_;
217                                                      MKDEBUG && _d('Done with', $self->{chunk_num}, 'of',
218            1                                  3         scalar(@{$self->{chunks}}), 'chunks');
219            1                                  2      MKDEBUG && $self->{state} && _d('Chunk differs; must examine rows');
220            1                                 15      return $self->{state} == 0
221   ***      1            33                    9         && $self->{chunk_num} >= scalar(@{$self->{chunks}})
222                                                   }
223                                                   
224                                                   sub pending_changes {
225            3                    3            22      my ( $self ) = @_;
226            3    100                          15      if ( $self->{state} ) {
227            2                                  4         MKDEBUG && _d('There are pending changes');
228            2                                 15         return 1;
229                                                      }
230                                                      else {
231            1                                  3         MKDEBUG && _d('No pending changes');
232            1                                  5         return 0;
233                                                      }
234                                                   }
235                                                   
236                                                   sub key_cols {
237            5                    5            20      my ( $self ) = @_;
238            5                                 15      my @cols;
239            5    100                          27      if ( $self->{state} == 0 ) {
240            1                                  4         @cols = qw(chunk_num);
241                                                      }
242                                                      else {
243            4                                 20         @cols = $self->{chunk_col};
244                                                      }
245            5                                 13      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
246            5                                 37      return \@cols;
247                                                   }
248                                                   
249                                                   sub _d {
250   ***      0                    0                    my ($package, undef, $line) = caller 0;
251   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
252   ***      0                                              map { defined $_ ? $_ : 'undef' }
253                                                           @_;
254   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
255                                                   }
256                                                   
257                                                   1;
258                                                   
259                                                   # ###########################################################################
260                                                   # End TableSyncChunk package
261                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0     60   unless defined $args{$arg}
61    ***     50      4      0   if ($col)
65    ***     50      4      0   if (not grep {not defined $params{$_};} 'min', 'max', 'rows_in_range') { }
81    ***     50      0      4   unless @chunks
101   ***     50      4      0   if ($args{'algorithm'} eq 'BIT_XOR' and not $args{'crc_type'} =~ /int$/)
137          100      1      4   if ($$self{'state'}) { }
138   ***     50      0      1   defined $args{'index_hint'} ? :
143   ***     50      0      1   $$self{'bufferinmysql'} ? :
      ***     50      0      1   $args{'where'} ? :
174          100      2      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
175          100      1      1   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
191   ***     50      0      1   unless $$self{'state'}
197          100      1      1   unless $$self{'state'}
203          100      1      3   if ($$self{'state'} == 1) { }
226          100      2      1   if ($$self{'state'}) { }
239          100      1      4   if ($$self{'state'} == 0) { }
251   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
101   ***     33      0      0      4   $args{'algorithm'} eq 'BIT_XOR' and not $args{'crc_type'} =~ /int$/
221   ***     33      0      0      1   $$self{'state'} == 0 && $$self{'chunk_num'} >= scalar @{$$self{'chunks'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
105   ***     50      0      4   $args{'chunk_sql'} ||= $args{'checksum'}->make_checksum_query('dbname', $args{'database'}, 'tblname', $args{'table'}, 'table', $args{'struct'}, 'quoter', $args{'quoter'}, 'algorithm', $args{'algorithm'}, 'func', $args{'func'}, 'crc_wid', $args{'crc_wid'}, 'crc_type', $args{'crc_type'}, 'opt_slice', $args{'opt_slice'}, 'cols', $args{'cols'}, 'trim', $args{'trim'}, 'buffer', $args{'bufferinmysql'})
119   ***     50      0      4   $args{'row_sql'} ||= $args{'checksum'}->make_row_checksum('table', $args{'struct'}, 'quoter', $args{'quoter'}, 'func', $args{'func'}, 'cols', $args{'cols'}, 'trim', $args{'trim'})

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
174   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


Covered Subroutines
-------------------

Subroutine      Count Location                                             
--------------- ----- -----------------------------------------------------
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:29 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:30 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:32 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:33 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:34 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:38 
done                1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:216
done_with_rows      4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:202
get_sql             5 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:136
key_cols            5 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:237
new                 4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:41 
not_in_left         2 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:196
not_in_right        1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:190
pending_changes     3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:225
same_row            3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:173

Uncovered Subroutines
---------------------

Subroutine      Count Location                                             
--------------- ----- -----------------------------------------------------
_d                  0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:250
prepare             0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:165


