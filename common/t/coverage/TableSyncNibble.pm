---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncNibble.pm   89.2   76.2   45.5   83.3    n/a  100.0   81.6
Total                          89.2   76.2   45.5   83.3    n/a  100.0   81.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncNibble.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:37 2009
Finish:       Wed Jun 10 17:21:37 2009

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
18                                                    # TableSyncNibble package $Revision: 3186 $
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
38             1                    1            12   use strict;
               1                                  2   
               1                                  8   
39             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
40                                                    
41             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
42             1                    1             9   use List::Util qw(max);
               1                                  3   
               1                                 14   
43             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  6   
44                                                    $Data::Dumper::Indent    = 0;
45                                                    $Data::Dumper::Quotekeys = 0;
46                                                    
47             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
48                                                    
49                                                    sub new {
50             2                    2           890      my ( $class, %args ) = @_;
51             2                                 32      foreach my $arg ( qw(dbh database table handler nibbler quoter struct
52                                                                            parser checksum cols vp chunksize where chunker
53                                                                            versionparser possible_keys trim) ) {
54    ***     34     50                         249         die "I need a $arg argument" unless defined $args{$arg};
55                                                       }
56                                                    
57                                                       # Sanity check.  The row-level (state 2) checksums use __crc, so the table
58                                                       # had better not use that...
59             2                                 15      $args{crc_col} = '__crc';
60             2                                 25      while ( $args{struct}->{is_col}->{$args{crc_col}} ) {
61    ***      0                                  0         $args{crc_col} = "_$args{crc_col}"; # Prepend more _ until not a column.
62                                                       }
63             2                                  7      MKDEBUG && _d('CRC column will be named', $args{crc_col});
64                                                    
65             2                                 42      $args{sel_stmt} = $args{nibbler}->generate_asc_stmt(
66                                                          parser   => $args{parser},
67                                                          tbl      => $args{struct},
68                                                          index    => $args{possible_keys}->[0],
69                                                          quoter   => $args{quoter},
70                                                          asconly  => 1,
71                                                       );
72                                                    
73    ***      2     50     33                   60      die "No suitable index found"
74                                                          unless $args{sel_stmt}->{index}
75                                                             && $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{is_unique};
76             2                                 25      $args{key_cols} = $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{cols};
77                                                    
78                                                       # Decide on checksumming strategy and store checksum query prototypes for
79                                                       # later. TODO: some of this code might be factored out into TableSyncer.
80             2                                 39      $args{algorithm} = $args{checksum}->best_algorithm(
81                                                          algorithm   => 'BIT_XOR',
82                                                          vp          => $args{vp},
83                                                          dbh         => $args{dbh},
84                                                          where       => 1,
85                                                          chunk       => 1,
86                                                          count       => 1,
87                                                       );
88             2                                 28      $args{func} = $args{checksum}->choose_hash_func(
89                                                          dbh  => $args{dbh},
90                                                          func => $args{func},
91                                                       );
92             2                                 27      $args{crc_wid}    = $args{checksum}->get_crc_wid($args{dbh}, $args{func});
93             2                                 29      ($args{crc_type}) = $args{checksum}->get_crc_type($args{dbh}, $args{func});
94    ***      2     50     33                   57      if ( $args{algorithm} eq 'BIT_XOR' && $args{crc_type} !~ m/int$/ ) {
95             2                                 34         $args{opt_slice}
96                                                             = $args{checksum}->optimize_xor(dbh => $args{dbh}, func => $args{func});
97                                                       }
98                                                    
99    ***      2            50                   77      $args{nibble_sql} ||= $args{checksum}->make_checksum_query(
100                                                         dbname    => $args{database},
101                                                         tblname   => $args{table},
102                                                         table     => $args{struct},
103                                                         quoter    => $args{quoter},
104                                                         algorithm => $args{algorithm},
105                                                         func      => $args{func},
106                                                         crc_wid   => $args{crc_wid},
107                                                         crc_type  => $args{crc_type},
108                                                         opt_slice => $args{opt_slice},
109                                                         cols      => $args{cols},
110                                                         trim      => $args{trim},
111                                                         buffer    => $args{bufferinmysql},
112                                                      );
113   ***      2            50                   40      $args{row_sql} ||= $args{checksum}->make_row_checksum(
114                                                         table     => $args{struct},
115                                                         quoter    => $args{quoter},
116                                                         func      => $args{func},
117                                                         cols      => $args{cols},
118                                                         trim      => $args{trim},
119                                                      );
120                                                   
121            2                                 14      $args{state}  = 0;
122            2                                 11      $args{nibble} = 0;
123            2                                 39      $args{handler}->fetch_back($args{dbh});
124            2                                137      return bless { %args }, $class;
125                                                   }
126                                                   
127                                                   # Depth-first: if a nibble is bad, return SQL to inspect rows individually.
128                                                   # Otherwise get the next nibble.  This way we can sync part of the table before
129                                                   # moving on to the next part.
130                                                   sub get_sql {
131           11                   11           270      my ( $self, %args ) = @_;
132           11    100                         107      if ( $self->{state} ) {
133            4                                 35         return 'SELECT '
134                                                            . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
135            2    100                          24            . join(', ', map { $self->{quoter}->quote($_) } @{$self->key_cols()})
               2    100                          15   
136                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
137                                                            . ' FROM ' . $self->{quoter}->quote(@args{qw(database table)})
138                                                            . ' WHERE (' . $self->__get_boundaries() . ')'
139                                                            . ($args{where} ? " AND ($args{where})" : '');
140                                                      }
141                                                      else {
142            9                                 73         my $where = $self->__get_boundaries();
143            9                                227         return $self->{chunker}->inject_chunks(
144                                                            database  => $args{database},
145                                                            table     => $args{table},
146                                                            chunks    => [$where],
147                                                            chunk_num => 0,
148                                                            query     => $self->{nibble_sql},
149                                                            where     => [$args{where}],
150                                                            quoter    => $self->{quoter},
151                                                         );
152                                                      }
153                                                   }
154                                                   
155                                                   # Returns a WHERE clause for finding out the boundaries of the nibble.
156                                                   # Initially, it'll just be something like "select key_cols ... limit 499, 1".
157                                                   # We then remember this row (it is also used elsewhere).  Next time it's like
158                                                   # "select key_cols ... where > remembered_row limit 499, 1".  Assuming that
159                                                   # the source and destination tables have different data, executing the same
160                                                   # query against them might give back a different boundary row, which is not
161                                                   # what we want, so each boundary needs to be cached until the 'nibble'
162                                                   # increases.
163                                                   sub __get_boundaries {
164           11                   11            68      my ( $self ) = @_;
165                                                   
166           11    100                          96      if ( $self->{cached_boundaries} ) {
167            3                                 11         MKDEBUG && _d('Using cached boundaries');
168            3                                 70         return $self->{cached_boundaries};
169                                                      }
170                                                   
171            8                                 48      my $q = $self->{quoter};
172            8                                 44      my $s = $self->{sel_stmt};
173            8                                 29      my $row;
174            8                                 28      my $lb; # Lower boundaries
175   ***      8     50     66                  135      if ( $self->{cached_row} && $self->{cached_nibble} == $self->{nibble} ) {
176   ***      0                                  0         MKDEBUG && _d('Using cached row for boundaries');
177   ***      0                                  0         $row = $self->{cached_row};
178                                                      }
179                                                      else {
180           24                                163         my $sql      = 'SELECT '
181   ***      8     50                          44            . join(',', map { $q->quote($_) } @{$s->{cols}})
               8                                 61   
182                                                            . " FROM " . $q->quote($self->{database}, $self->{table})
183                                                            . ($self->{versionparser}->version_ge($self->{dbh}, '4.0.9')
184                                                               ? " FORCE" : " USE")
185                                                            . " INDEX(" . $q->quote($s->{index}) . ")";
186            8    100                          79         if ( $self->{nibble} ) {
187                                                            # The lower boundaries of the nibble must be defined, based on the last
188                                                            # remembered row.
189            5                                 26            my $tmp = $self->{cached_row};
190            5                                 22            my $i   = 0;
191           15                                197            ($lb = $s->{boundaries}->{'>'})
192            5                                 85               =~ s{([=><]) \?}
193                                                                   {"$1 " . $q->quote_val($tmp->{$s->{scols}->[$i++]})}eg;
194            5                                 38            $sql .= ' WHERE ' . $lb;
195                                                         }
196            8                                 73         $sql .= ' LIMIT ' . ($self->{chunksize} - 1) . ', 1';
197            8                                 29         MKDEBUG && _d($sql);
198            8                                 31         $row = $self->{dbh}->selectrow_hashref($sql);
199                                                      }
200                                                   
201            8                                 82      my $where;
202            8    100                          53      if ( $row ) {
203                                                         # Inject the row into the WHERE clause.  The WHERE is for the <= case
204                                                         # because the bottom of the nibble is bounded strictly by >.
205            7                                 33         my $i = 0;
206           21                                311         ($where = $s->{boundaries}->{'<='})
207            7                                161            =~ s{([=><]) \?}{"$1 " . $q->quote_val($row->{$s->{scols}->[$i++]})}eg;
208                                                      }
209                                                      else {
210            1                                  9         $where = '1=1';
211                                                      }
212                                                   
213            8    100                          67      if ( $lb ) {
214            5                                 45         $where = "($lb AND $where)";
215                                                      }
216                                                   
217            8                                 67      $self->{cached_row}        = $row;
218            8                                 87      $self->{cached_nibble}     = $self->{nibble};
219            8                                 54      $self->{cached_boundaries} = $where;
220                                                   
221            8                                 27      MKDEBUG && _d('WHERE clause:', $where);
222            8                                 81      return $where;
223                                                   }
224                                                   
225                                                   sub prepare {
226   ***      0                    0             0      my ( $self, $dbh ) = @_;
227   ***      0                                  0      $dbh->do(q{SET @crc := ''});
228                                                   }
229                                                   
230                                                   sub same_row {
231            4                    4            31      my ( $self, $lr, $rr ) = @_;
232   ***      4    100     33                   54      if ( $self->{state} ) {
      ***            50                               
233            2    100                          29         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
234            1                                 11            $self->{handler}->change('UPDATE', $lr, $self->key_cols());
235                                                         }
236                                                      }
237                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
238            2                                  8         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
239            2                                  8         MKDEBUG && _d('Will examine this nibble before moving to next');
240            2                                 15         $self->{state} = 1; # Must examine this nibble row-by-row
241                                                      }
242                                                   }
243                                                   
244                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
245                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
246                                                   # cnt will be 0, but the result set should still come back.
247                                                   sub not_in_right {
248   ***      0                    0             0      my ( $self, $lr ) = @_;
249   ***      0      0                           0      die "Called not_in_right in state 0" unless $self->{state};
250   ***      0                                  0      $self->{handler}->change('INSERT', $lr, $self->key_cols());
251                                                   }
252                                                   
253                                                   sub not_in_left {
254            2                    2            18      my ( $self, $rr ) = @_;
255            2    100                          14      die "Called not_in_left in state 0" unless $self->{state};
256            1                                 10      $self->{handler}->change('DELETE', $rr, $self->key_cols());
257                                                   }
258                                                   
259                                                   sub done_with_rows {
260            7                    7            51      my ( $self ) = @_;
261            7    100                          70      if ( $self->{state} == 1 ) {
262            1                                  6         $self->{state} = 2;
263            1                                  6         MKDEBUG && _d('Setting state =', $self->{state});
264                                                      }
265                                                      else {
266            6                                 36         $self->{state} = 0;
267            6                                 31         $self->{nibble}++;
268            6                                 41         delete $self->{cached_boundaries};
269            6                                 35         MKDEBUG && _d('Setting state =', $self->{state},
270                                                            ', nibble =', $self->{nibble});
271                                                      }
272                                                   }
273                                                   
274                                                   sub done {
275            2                    2            14      my ( $self ) = @_;
276            2                                  7      MKDEBUG && _d('Done with nibble', $self->{nibble});
277            2                                  9      MKDEBUG && $self->{state} && _d('Nibble differs; must examine rows');
278   ***      2            33                   77      return $self->{state} == 0 && $self->{nibble} && !$self->{cached_row};
      ***                   66                        
279                                                   }
280                                                   
281                                                   sub pending_changes {
282            3                    3            20      my ( $self ) = @_;
283            3    100                          25      if ( $self->{state} ) {
284            2                                  7         MKDEBUG && _d('There are pending changes');
285            2                                 18         return 1;
286                                                      }
287                                                      else {
288            1                                  3         MKDEBUG && _d('No pending changes');
289            1                                 11         return 0;
290                                                      }
291                                                   }
292                                                   
293                                                   sub key_cols {
294            5                    5            32      my ( $self ) = @_;
295            5                                 21      my @cols;
296            5    100                          41      if ( $self->{state} == 0 ) {
297            1                                  6         @cols = qw(chunk_num);
298                                                      }
299                                                      else {
300            4                                 17         @cols = @{$self->{key_cols}};
               4                                 43   
301                                                      }
302            5                                 21      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
303            5                                 71      return \@cols;
304                                                   }
305                                                   
306                                                   sub _d {
307   ***      0                    0                    my ($package, undef, $line) = caller 0;
308   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
309   ***      0                                              map { defined $_ ? $_ : 'undef' }
310                                                           @_;
311   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
312                                                   }
313                                                   
314                                                   1;
315                                                   
316                                                   # ###########################################################################
317                                                   # End TableSyncNibble package
318                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
54    ***     50      0     34   unless defined $args{$arg}
73    ***     50      0      2   unless $args{'sel_stmt'}{'index'} and $args{'struct'}{'keys'}{$args{'sel_stmt'}{'index'}}{'is_unique'}
94    ***     50      2      0   if ($args{'algorithm'} eq 'BIT_XOR' and not $args{'crc_type'} =~ /int$/)
132          100      2      9   if ($$self{'state'}) { }
135          100      1      1   $$self{'bufferinmysql'} ? :
             100      1      1   $args{'where'} ? :
166          100      3      8   if ($$self{'cached_boundaries'})
175   ***     50      0      8   if ($$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}) { }
181   ***     50      8      0   $$self{'versionparser'}->version_ge($$self{'dbh'}, '4.0.9') ? :
186          100      5      3   if ($$self{'nibble'})
202          100      7      1   if ($row) { }
213          100      5      3   if ($lb)
232          100      2      2   if ($$self{'state'}) { }
      ***     50      2      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
233          100      1      1   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
249   ***      0      0      0   unless $$self{'state'}
255          100      1      1   unless $$self{'state'}
261          100      1      6   if ($$self{'state'} == 1) { }
283          100      2      1   if ($$self{'state'}) { }
296          100      1      4   if ($$self{'state'} == 0) { }
308   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
73    ***     33      0      0      2   $args{'sel_stmt'}{'index'} and $args{'struct'}{'keys'}{$args{'sel_stmt'}{'index'}}{'is_unique'}
94    ***     33      0      0      2   $args{'algorithm'} eq 'BIT_XOR' and not $args{'crc_type'} =~ /int$/
175   ***     66      3      5      0   $$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}
278   ***     33      0      0      2   $$self{'state'} == 0 && $$self{'nibble'}
      ***     66      0      1      1   $$self{'state'} == 0 && $$self{'nibble'} && !$$self{'cached_row'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
99    ***     50      0      2   $args{'nibble_sql'} ||= $args{'checksum'}->make_checksum_query('dbname', $args{'database'}, 'tblname', $args{'table'}, 'table', $args{'struct'}, 'quoter', $args{'quoter'}, 'algorithm', $args{'algorithm'}, 'func', $args{'func'}, 'crc_wid', $args{'crc_wid'}, 'crc_type', $args{'crc_type'}, 'opt_slice', $args{'opt_slice'}, 'cols', $args{'cols'}, 'trim', $args{'trim'}, 'buffer', $args{'bufferinmysql'})
113   ***     50      0      2   $args{'row_sql'} ||= $args{'checksum'}->make_row_checksum('table', $args{'struct'}, 'quoter', $args{'quoter'}, 'func', $args{'func'}, 'cols', $args{'cols'}, 'trim', $args{'trim'})

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
232   ***     33      2      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


Covered Subroutines
-------------------

Subroutine       Count Location                                              
---------------- ----- ------------------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:38 
BEGIN                1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:39 
BEGIN                1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:41 
BEGIN                1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:42 
BEGIN                1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:43 
BEGIN                1 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:47 
__get_boundaries    11 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:164
done                 2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:275
done_with_rows       7 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:260
get_sql             11 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:131
key_cols             5 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:294
new                  2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:50 
not_in_left          2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:254
pending_changes      3 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:282
same_row             4 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:231

Uncovered Subroutines
---------------------

Subroutine       Count Location                                              
---------------- ----- ------------------------------------------------------
_d                   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:307
not_in_right         0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:248
prepare              0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:226


