---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncNibble.pm   87.2   76.2   45.5   83.3    n/a  100.0   80.5
Total                          87.2   76.2   45.5   83.3    n/a  100.0   80.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncNibble.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:04:24 2009
Finish:       Sat Aug 29 15:04:24 2009

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
18                                                    # TableSyncNibble package $Revision: 4604 $
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
               1                                  8   
40                                                    
41             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
42             1                    1             8   use List::Util qw(max);
               1                                  2   
               1                                 11   
43             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  5   
44                                                    $Data::Dumper::Indent    = 0;
45                                                    $Data::Dumper::Quotekeys = 0;
46                                                    
47             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  9   
48                                                    
49                                                    sub new {
50             2                    2           105      my ( $class, %args ) = @_;
51             2                                 18      foreach my $arg ( qw(dbh database table handler nibbler quoter struct
52                                                                            parser checksum cols vp chunksize where chunker
53                                                                            versionparser possible_keys trim) ) {
54    ***     34     50                         142         die "I need a $arg argument" unless defined $args{$arg};
55                                                       }
56                                                    
57                                                       # Sanity check.  The row-level (state 2) checksums use __crc, so the table
58                                                       # had better not use that...
59             2                                 10      $args{crc_col} = '__crc';
60             2                                 15      while ( $args{struct}->{is_col}->{$args{crc_col}} ) {
61    ***      0                                  0         $args{crc_col} = "_$args{crc_col}"; # Prepend more _ until not a column.
62                                                       }
63             2                                  5      MKDEBUG && _d('CRC column will be named', $args{crc_col});
64                                                    
65             2                                 24      $args{sel_stmt} = $args{nibbler}->generate_asc_stmt(
66                                                          parser   => $args{parser},
67                                                          tbl      => $args{struct},
68                                                          index    => $args{possible_keys}->[0],
69                                                          quoter   => $args{quoter},
70                                                          asconly  => 1,
71                                                       );
72                                                    
73    ***      2     50     33                   30      die "No suitable index found"
74                                                          unless $args{sel_stmt}->{index}
75                                                             && $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{is_unique};
76             2                                 15      $args{key_cols} = $args{struct}->{keys}->{$args{sel_stmt}->{index}}->{cols};
77                                                    
78                                                       # Decide on checksumming strategy and store checksum query prototypes for
79                                                       # later. TODO: some of this code might be factored out into TableSyncer.
80             2                                 21      $args{algorithm} = $args{checksum}->best_algorithm(
81                                                          algorithm   => 'BIT_XOR',
82                                                          vp          => $args{vp},
83                                                          dbh         => $args{dbh},
84                                                          where       => 1,
85                                                          chunk       => 1,
86                                                          count       => 1,
87                                                       );
88             2                                 18      $args{func} = $args{checksum}->choose_hash_func(
89                                                          dbh  => $args{dbh},
90                                                          func => $args{func},
91                                                       );
92             2                                 18      $args{crc_wid}    = $args{checksum}->get_crc_wid($args{dbh}, $args{func});
93             2                                 15      ($args{crc_type}) = $args{checksum}->get_crc_type($args{dbh}, $args{func});
94    ***      2     50     33                   31      if ( $args{algorithm} eq 'BIT_XOR' && $args{crc_type} !~ m/int$/ ) {
95             2                                 20         $args{opt_slice}
96                                                             = $args{checksum}->optimize_xor(dbh => $args{dbh}, func => $args{func});
97                                                       }
98                                                    
99    ***      2            50                   47      $args{nibble_sql} ||= $args{checksum}->make_checksum_query(
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
113   ***      2            50                   23      $args{row_sql} ||= $args{checksum}->make_row_checksum(
114                                                         table     => $args{struct},
115                                                         quoter    => $args{quoter},
116                                                         func      => $args{func},
117                                                         cols      => $args{cols},
118                                                         trim      => $args{trim},
119                                                      );
120                                                   
121            2                                  8      $args{state}  = 0;
122            2                                  6      $args{nibble} = 0;
123            2                                 18      $args{handler}->fetch_back($args{dbh});
124            2                                 69      return bless { %args }, $class;
125                                                   }
126                                                   
127                                                   # Depth-first: if a nibble is bad, return SQL to inspect rows individually.
128                                                   # Otherwise get the next nibble.  This way we can sync part of the table before
129                                                   # moving on to the next part.
130                                                   sub get_sql {
131           11                   11           129      my ( $self, %args ) = @_;
132           11    100                          63      if ( $self->{state} ) {
133            4                                 20         return 'SELECT '
134                                                            . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
135            2    100                          14            . join(', ', map { $self->{quoter}->quote($_) } @{$self->key_cols()})
               2    100                          12   
136                                                            . ', ' . $self->{row_sql} . " AS $self->{crc_col}"
137                                                            . ' FROM ' . $self->{quoter}->quote(@args{qw(database table)})
138                                                            . ' WHERE (' . $self->__get_boundaries() . ')'
139                                                            . ($args{where} ? " AND ($args{where})" : '');
140                                                      }
141                                                      else {
142            9                                 44         my $where = $self->__get_boundaries();
143            9                                128         return $self->{chunker}->inject_chunks(
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
164           11                   11            40      my ( $self ) = @_;
165                                                   
166           11    100                          61      if ( $self->{cached_boundaries} ) {
167            3                                  6         MKDEBUG && _d('Using cached boundaries');
168            3                                 28         return $self->{cached_boundaries};
169                                                      }
170                                                   
171            8                                 32      my $q = $self->{quoter};
172            8                                 25      my $s = $self->{sel_stmt};
173            8                                 19      my $row;
174            8                                 22      my $lb; # Lower boundaries
175   ***      8     50     66                   84      if ( $self->{cached_row} && $self->{cached_nibble} == $self->{nibble} ) {
176   ***      0                                  0         MKDEBUG && _d('Using cached row for boundaries');
177   ***      0                                  0         $row = $self->{cached_row};
178                                                      }
179                                                      else {
180           24                                 93         my $sql      = 'SELECT '
181   ***      8     50                          29            . join(',', map { $q->quote($_) } @{$s->{cols}})
               8                                 51   
182                                                            . " FROM " . $q->quote($self->{database}, $self->{table})
183                                                            . ($self->{versionparser}->version_ge($self->{dbh}, '4.0.9')
184                                                               ? " FORCE" : " USE")
185                                                            . " INDEX(" . $q->quote($s->{index}) . ")";
186            8    100                          46         if ( $self->{nibble} ) {
187                                                            # The lower boundaries of the nibble must be defined, based on the last
188                                                            # remembered row.
189            5                                 17            my $tmp = $self->{cached_row};
190            5                                 16            my $i   = 0;
191           15                                115            ($lb = $s->{boundaries}->{'>'})
192            5                                 64               =~ s{([=><]) \?}
193                                                                   {"$1 " . $q->quote_val($tmp->{$s->{scols}->[$i++]})}eg;
194            5                                 45            $sql .= ' WHERE ' . $lb;
195                                                         }
196            8                                 45         $sql .= ' LIMIT ' . ($self->{chunksize} - 1) . ', 1';
197            8                                 20         MKDEBUG && _d($sql);
198            8                                 18         $row = $self->{dbh}->selectrow_hashref($sql);
199                                                      }
200                                                   
201            8                                 52      my $where;
202            8    100                          40      if ( $row ) {
203                                                         # Inject the row into the WHERE clause.  The WHERE is for the <= case
204                                                         # because the bottom of the nibble is bounded strictly by >.
205            7                                 33         my $i = 0;
206           21                                183         ($where = $s->{boundaries}->{'<='})
207            7                                114            =~ s{([=><]) \?}{"$1 " . $q->quote_val($row->{$s->{scols}->[$i++]})}eg;
208                                                      }
209                                                      else {
210            1                                  5         $where = '1=1';
211                                                      }
212                                                   
213            8    100                          42      if ( $lb ) {
214            5                                 28         $where = "($lb AND $where)";
215                                                      }
216                                                   
217            8                                 33      $self->{cached_row}        = $row;
218            8                                 40      $self->{cached_nibble}     = $self->{nibble};
219            8                                 36      $self->{cached_boundaries} = $where;
220                                                   
221            8                                 19      MKDEBUG && _d('WHERE clause:', $where);
222            8                                 50      return $where;
223                                                   }
224                                                   
225                                                   sub prepare {
226   ***      0                    0             0      my ( $self, $dbh ) = @_;
227   ***      0                                  0      my $sql = 'SET @crc := "", @cnt := 0';
228   ***      0                                  0      MKDEBUG && _d($sql);
229   ***      0                                  0      $dbh->do($sql);
230   ***      0                                  0      return;
231                                                   }
232                                                   
233                                                   sub same_row {
234            4                    4            20      my ( $self, $lr, $rr ) = @_;
235   ***      4    100     33                   34      if ( $self->{state} ) {
      ***            50                               
236            2    100                          16         if ( $lr->{$self->{crc_col}} ne $rr->{$self->{crc_col}} ) {
237            1                                  7            $self->{handler}->change('UPDATE', $lr, $self->key_cols());
238                                                         }
239                                                      }
240                                                      elsif ( $lr->{cnt} != $rr->{cnt} || $lr->{crc} ne $rr->{crc} ) {
241            2                                  6         MKDEBUG && _d('Rows:', Dumper($lr, $rr));
242            2                                  4         MKDEBUG && _d('Will examine this nibble before moving to next');
243            2                                 11         $self->{state} = 1; # Must examine this nibble row-by-row
244                                                      }
245                                                   }
246                                                   
247                                                   # This (and not_in_left) should NEVER be called in state 0.  If there are
248                                                   # missing rows in state 0 in one of the tables, the CRC will be all 0's and the
249                                                   # cnt will be 0, but the result set should still come back.
250                                                   sub not_in_right {
251   ***      0                    0             0      my ( $self, $lr ) = @_;
252   ***      0      0                           0      die "Called not_in_right in state 0" unless $self->{state};
253   ***      0                                  0      $self->{handler}->change('INSERT', $lr, $self->key_cols());
254                                                   }
255                                                   
256                                                   sub not_in_left {
257            2                    2             9      my ( $self, $rr ) = @_;
258            2    100                           8      die "Called not_in_left in state 0" unless $self->{state};
259            1                                  8      $self->{handler}->change('DELETE', $rr, $self->key_cols());
260                                                   }
261                                                   
262                                                   sub done_with_rows {
263            7                    7            35      my ( $self ) = @_;
264            7    100                          57      if ( $self->{state} == 1 ) {
265            1                                  3         $self->{state} = 2;
266            1                                  3         MKDEBUG && _d('Setting state =', $self->{state});
267                                                      }
268                                                      else {
269            6                                 21         $self->{state} = 0;
270            6                                 20         $self->{nibble}++;
271            6                                 38         delete $self->{cached_boundaries};
272            6                                 20         MKDEBUG && _d('Setting state =', $self->{state},
273                                                            ', nibble =', $self->{nibble});
274                                                      }
275                                                   }
276                                                   
277                                                   sub done {
278            2                    2             8      my ( $self ) = @_;
279            2                                  6      MKDEBUG && _d('Done with nibble', $self->{nibble});
280            2                                  5      MKDEBUG && $self->{state} && _d('Nibble differs; must examine rows');
281   ***      2            33                   57      return $self->{state} == 0 && $self->{nibble} && !$self->{cached_row};
      ***                   66                        
282                                                   }
283                                                   
284                                                   sub pending_changes {
285            3                    3            17      my ( $self ) = @_;
286            3    100                          16      if ( $self->{state} ) {
287            2                                  4         MKDEBUG && _d('There are pending changes');
288            2                                 12         return 1;
289                                                      }
290                                                      else {
291            1                                  3         MKDEBUG && _d('No pending changes');
292            1                                  6         return 0;
293                                                      }
294                                                   }
295                                                   
296                                                   sub key_cols {
297            5                    5            20      my ( $self ) = @_;
298            5                                 13      my @cols;
299            5    100                          27      if ( $self->{state} == 0 ) {
300            1                                  4         @cols = qw(chunk_num);
301                                                      }
302                                                      else {
303            4                                 13         @cols = @{$self->{key_cols}};
               4                                 26   
304                                                      }
305            5                                 14      MKDEBUG && _d('State', $self->{state},',', 'key cols', join(', ', @cols));
306            5                                 45      return \@cols;
307                                                   }
308                                                   
309                                                   sub _d {
310   ***      0                    0                    my ($package, undef, $line) = caller 0;
311   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
312   ***      0                                              map { defined $_ ? $_ : 'undef' }
313                                                           @_;
314   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
315                                                   }
316                                                   
317                                                   1;
318                                                   
319                                                   # ###########################################################################
320                                                   # End TableSyncNibble package
321                                                   # ###########################################################################


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
235          100      2      2   if ($$self{'state'}) { }
      ***     50      2      0   elsif ($$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}) { }
236          100      1      1   if ($$lr{$$self{'crc_col'}} ne $$rr{$$self{'crc_col'}})
252   ***      0      0      0   unless $$self{'state'}
258          100      1      1   unless $$self{'state'}
264          100      1      6   if ($$self{'state'} == 1) { }
286          100      2      1   if ($$self{'state'}) { }
299          100      1      4   if ($$self{'state'} == 0) { }
311   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
73    ***     33      0      0      2   $args{'sel_stmt'}{'index'} and $args{'struct'}{'keys'}{$args{'sel_stmt'}{'index'}}{'is_unique'}
94    ***     33      0      0      2   $args{'algorithm'} eq 'BIT_XOR' and not $args{'crc_type'} =~ /int$/
175   ***     66      3      5      0   $$self{'cached_row'} and $$self{'cached_nibble'} == $$self{'nibble'}
281   ***     33      0      0      2   $$self{'state'} == 0 && $$self{'nibble'}
      ***     66      0      1      1   $$self{'state'} == 0 && $$self{'nibble'} && !$$self{'cached_row'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
99    ***     50      0      2   $args{'nibble_sql'} ||= $args{'checksum'}->make_checksum_query('dbname', $args{'database'}, 'tblname', $args{'table'}, 'table', $args{'struct'}, 'quoter', $args{'quoter'}, 'algorithm', $args{'algorithm'}, 'func', $args{'func'}, 'crc_wid', $args{'crc_wid'}, 'crc_type', $args{'crc_type'}, 'opt_slice', $args{'opt_slice'}, 'cols', $args{'cols'}, 'trim', $args{'trim'}, 'buffer', $args{'bufferinmysql'})
113   ***     50      0      2   $args{'row_sql'} ||= $args{'checksum'}->make_row_checksum('table', $args{'struct'}, 'quoter', $args{'quoter'}, 'func', $args{'func'}, 'cols', $args{'cols'}, 'trim', $args{'trim'})

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
235   ***     33      2      0      0   $$lr{'cnt'} != $$rr{'cnt'} or $$lr{'crc'} ne $$rr{'crc'}


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
done                 2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:278
done_with_rows       7 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:263
get_sql             11 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:131
key_cols             5 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:297
new                  2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:50 
not_in_left          2 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:257
pending_changes      3 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:285
same_row             4 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:234

Uncovered Subroutines
---------------------

Subroutine       Count Location                                              
---------------- ----- ------------------------------------------------------
_d                   0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:310
not_in_right         0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:251
prepare              0 /home/daniel/dev/maatkit/common/TableSyncNibble.pm:226


