---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/TableSyncChunk.pm   90.2   66.7   38.5   88.2    n/a  100.0   81.0
Total                          90.2   66.7   38.5   88.2    n/a  100.0   81.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncChunk.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:16 2009
Finish:       Wed Jun 10 17:21:17 2009

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
18                                                    # TableSyncChunk package $Revision: 3186 $
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
29             1                    1            12   use strict;
               1                                  3   
               1                                  8   
30             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
31                                                    
32             1                    1             7   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
33             1                    1            10   use List::Util qw(max);
               1                                  4   
               1                                 15   
34             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  6   
35                                                    $Data::Dumper::Indent    = 0;
36                                                    $Data::Dumper::Quotekeys = 0;
37                                                    
38             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
39                                                    
40                                                    sub new {
41             4                    4          1434      my ( $class, %args ) = @_;
42             4                                 58      foreach my $arg ( qw(dbh database table handler chunker quoter struct
43                                                                            checksum cols vp chunksize where possible_keys
44                                                                            dumper trim) ) {
45    ***     60     50                         434         die "I need a $arg argument" unless defined $args{$arg};
46                                                       }
47                                                    
48                                                       # Sanity check.  The row-level (state 2) checksums use __crc, so the table
49                                                       # had better not use that...
50             4                                 30      $args{crc_col} = '__crc';
51             4                                 47      while ( $args{struct}->{is_col}->{$args{crc_col}} ) {
52    ***      0                                  0         $args{crc_col} = "_$args{crc_col}"; # Prepend more _ until not a column.
53                                                       }
54             4                                 16      MKDEBUG && _d('CRC column will be named', $args{crc_col});
55                                                    
56                                                       # Chunk the table and store the chunks for later processing.
57             4                                 16      my @chunks;
58             4                                 67      my ( $col, $idx ) = $args{chunker}->get_first_chunkable_column(
59                                                          $args{struct}, { possible_keys => $args{possible_keys} });
60             4                                 29      $args{index} = $idx;
61    ***      4     50                          28      if ( $col ) {
62             4                                 61         my %params = $args{chunker}->get_range_statistics(
63                                                             $args{dbh}, $args{database}, $args{table}, $col,
64                                                             $args{where});
65    ***      4     50                          31         if ( !grep { !defined $params{$_} }
              12                                 92   
66                                                                qw(min max rows_in_range) )
67                                                          {
68             4                                 84            @chunks = $args{chunker}->calculate_chunks(
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
79             4                                 42         $args{chunk_col} = $col;
80                                                       }
81    ***      4     50                          28      die "Cannot chunk $args{database}.$args{table}" unless @chunks;
82             4                                 30      $args{chunks}     = \@chunks;
83             4                                 28      $args{chunk_num}  = 0;
84                                                    
85                                                       # Decide on checksumming strategy and store checksum query prototypes for
86                                                       # later.
87             4                                 67      $args{algorithm} = $args{checksum}->best_algorithm(
88                                                          algorithm   => 'BIT_XOR',
89                                                          vp          => $args{vp},
90                                                          dbh         => $args{dbh},
91                                                          where       => 1,
92                                                          chunk       => 1,
93                                                          count       => 1,
94                                                       );
95             4                                 53      $args{func} = $args{checksum}->choose_hash_func(
96                                                          func => $args{func},
97                                                          dbh  => $args{dbh},
98                                                       );
99             4                                 53      $args{crc_wid}    = $args{checksum}->get_crc_wid($args{dbh}, $args{func});
100            4                                 43      ($args{crc_type}) = $args{checksum}->get_crc_type($args{dbh}, $args{func});
101   ***      4     50     33                  104      if ( $args{algorithm} eq 'BIT_XOR' && $args{crc_type} !~ m/int$/ ) {
102            4                                 60         $args{opt_slice}
103                                                            = $args{checksum}->optimize_xor(dbh => $args{dbh}, func => $args{func});
104                                                      }
105   ***      4            50                  201      $args{chunk_sql} ||= $args{checksum}->make_checksum_query(
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
119   ***      4            50                   85      $args{row_sql} ||= $args{checksum}->make_row_checksum(
120                                                         table     => $args{struct},
121                                                         quoter    => $args{quoter},
122                                                         func      => $args{func},
123                                                         cols      => $args{cols},
124                                                         trim      => $args{trim},
125                                                      );
126                                                   
127            4                                 28      $args{state} = 0;
128            4                                 48      $args{handler}->fetch_back($args{dbh});
129            4                                224      return bless { %args }, $class;
130                                                   }
131                                                   
132                                                   # Depth-first: if there are any bad chunks, return SQL to inspect their rows
133                                                   # individually.  Otherwise get the next chunk.  This way we can sync part of the
134                                                   # table before moving on to the next part.
135                                                   sub get_sql {
136            5                    5           158      my ( $self, %args ) = @_;
137            5    100                          49      if ( $self->{state} ) {
138   ***      1     50                          12         my $index_hint = defined $args{index_hint}
139                                                                          ? " USE INDEX (`$args{index_hint}`) "
140                                                                          : '';
141            1                                 10         return 'SELECT '
142                                                            . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
143   ***      1     50                          11            . join(', ', map { $self->{quoter}->quote($_) } @{$self->key_cols()})
      ***      1     50                           7   
144                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
145                                                            . ' FROM ' . $self->{quoter}->quote(@args{qw(database table)})
146                                                            . $index_hint 
147                                                            . ' WHERE (' . $self->{chunks}->[$self->{chunk_num}] . ')'
148                                                            . ($args{where} ? " AND ($args{where})" : '');
149                                                      }
150                                                      else {
151            4                                107         return $self->{chunker}->inject_chunks(
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
166   ***      0                                  0      $dbh->do(q{SET @crc := ''});
167                                                   }
168                                                   
169                                                   sub same_row {
170            3                    3            73      my ( $self, $lr, $rr ) = @_;
171   ***      3    100     33                   40      if ( $self->{state} ) {
      ***            50                               
172            2    100                          30         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
173            1                                 11            $self->{handler}->change('UPDATE', $lr, $self->key_cols());
174                                                         }
175                                                      }
176                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
177            1                                  5         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
178            1                                  3         MKDEBUG && _d('Will examine this chunk before moving to next');
179            1                                  9         $self->{state} = 1; # Must examine this chunk row-by-row
180                                                      }
181                                                   }
182                                                   
183                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
184                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
185                                                   # cnt will be 0, but the result set should still come back.
186                                                   sub not_in_right {
187            1                    1             9      my ( $self, $lr ) = @_;
188   ***      1     50                          11      die "Called not_in_right in state 0" unless $self->{state};
189            1                                  9      $self->{handler}->change('INSERT', $lr, $self->key_cols());
190                                                   }
191                                                   
192                                                   sub not_in_left {
193            2                    2           105      my ( $self, $rr ) = @_;
194            2    100                          14      die "Called not_in_left in state 0" unless $self->{state};
195            1                                 12      $self->{handler}->change('DELETE', $rr, $self->key_cols());
196                                                   }
197                                                   
198                                                   sub done_with_rows {
199            4                    4            35      my ( $self ) = @_;
200            4    100                          37      if ( $self->{state} == 1 ) {
201            1                                  6         $self->{state} = 2;
202            1                                  6         MKDEBUG && _d('Setting state =', $self->{state});
203                                                      }
204                                                      else {
205            3                                 17         $self->{state} = 0;
206            3                                 17         $self->{chunk_num}++;
207            3                                 16         MKDEBUG && _d('Setting state =', $self->{state},
208                                                            'chunk_num =', $self->{chunk_num});
209                                                      }
210                                                   }
211                                                   
212                                                   sub done {
213            1                    1             7      my ( $self ) = @_;
214                                                      MKDEBUG && _d('Done with', $self->{chunk_num}, 'of',
215            1                                  4         scalar(@{$self->{chunks}}), 'chunks');
216            1                                  3      MKDEBUG && $self->{state} && _d('Chunk differs; must examine rows');
217            1                                 24      return $self->{state} == 0
218   ***      1            33                   21         && $self->{chunk_num} >= scalar(@{$self->{chunks}})
219                                                   }
220                                                   
221                                                   sub pending_changes {
222            3                    3            33      my ( $self ) = @_;
223            3    100                          26      if ( $self->{state} ) {
224            2                                  8         MKDEBUG && _d('There are pending changes');
225            2                                 25         return 1;
226                                                      }
227                                                      else {
228            1                                  3         MKDEBUG && _d('No pending changes');
229            1                                 14         return 0;
230                                                      }
231                                                   }
232                                                   
233                                                   sub key_cols {
234            5                    5            32      my ( $self ) = @_;
235            5                                 20      my @cols;
236            5    100                          41      if ( $self->{state} == 0 ) {
237            1                                  6         @cols = qw(chunk_num);
238                                                      }
239                                                      else {
240            4                                 35         @cols = $self->{chunk_col};
241                                                      }
242            5                                 20      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
243            5                                 62      return \@cols;
244                                                   }
245                                                   
246                                                   sub _d {
247   ***      0                    0                    my ($package, undef, $line) = caller 0;
248   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
249   ***      0                                              map { defined $_ ? $_ : 'undef' }
250                                                           @_;
251   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
252                                                   }
253                                                   
254                                                   1;
255                                                   
256                                                   # ###########################################################################
257                                                   # End TableSyncChunk package
258                                                   # ###########################################################################


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
171          100      2      1   if ($$self{'state'}) { }
      ***     50      1      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
172          100      1      1   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
188   ***     50      0      1   unless $$self{'state'}
194          100      1      1   unless $$self{'state'}
200          100      1      3   if ($$self{'state'} == 1) { }
223          100      2      1   if ($$self{'state'}) { }
236          100      1      4   if ($$self{'state'} == 0) { }
248   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
101   ***     33      0      0      4   $args{'algorithm'} eq 'BIT_XOR' and not $args{'crc_type'} =~ /int$/
218   ***     33      0      0      1   $$self{'state'} == 0 && $$self{'chunk_num'} >= scalar @{$$self{'chunks'};}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
105   ***     50      0      4   $args{'chunk_sql'} ||= $args{'checksum'}->make_checksum_query('dbname', $args{'database'}, 'tblname', $args{'table'}, 'table', $args{'struct'}, 'quoter', $args{'quoter'}, 'algorithm', $args{'algorithm'}, 'func', $args{'func'}, 'crc_wid', $args{'crc_wid'}, 'crc_type', $args{'crc_type'}, 'opt_slice', $args{'opt_slice'}, 'cols', $args{'cols'}, 'trim', $args{'trim'}, 'buffer', $args{'bufferinmysql'})
119   ***     50      0      4   $args{'row_sql'} ||= $args{'checksum'}->make_row_checksum('table', $args{'struct'}, 'quoter', $args{'quoter'}, 'func', $args{'func'}, 'cols', $args{'cols'}, 'trim', $args{'trim'})

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
171   ***     33      1      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


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
done                1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:213
done_with_rows      4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:199
get_sql             5 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:136
key_cols            5 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:234
new                 4 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:41 
not_in_left         2 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:193
not_in_right        1 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:187
pending_changes     3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:222
same_row            3 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:170

Uncovered Subroutines
---------------------

Subroutine      Count Location                                             
--------------- ----- -----------------------------------------------------
_d                  0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:247
prepare             0 /home/daniel/dev/maatkit/common/TableSyncChunk.pm:165


