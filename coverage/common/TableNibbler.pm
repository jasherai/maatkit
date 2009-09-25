---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/TableNibbler.pm   95.3   76.1  100.0   90.0    n/a  100.0   91.3
Total                          95.3   76.1  100.0   90.0    n/a  100.0   91.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableNibbler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 21:18:16 2009
Finish:       Fri Sep 25 21:18:16 2009

/home/daniel/dev/maatkit/common/TableNibbler.pm

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
18                                                    # TableNibbler package $Revision: 4734 $
19                                                    # ###########################################################################
20                                                    package TableNibbler;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  6   
               1                                  5   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
28                                                    
29                                                    sub new {
30             1                    1            18      my ( $class, %args ) = @_;
31             1                                  5      my @required_args = qw(TableParser Quoter);
32             1                                  5      foreach my $arg ( @required_args ) {
33    ***      2     50                          12         die "I need a $arg argument" unless $args{$arg};
34                                                       }
35             1                                  5      my $self = { %args };
36             1                                 11      return bless $self, $class;
37                                                    }
38                                                    
39                                                    # Arguments are as follows:
40                                                    # * tbl_struct    Hashref returned from TableParser::parse().
41                                                    # * cols          Arrayref of columns to SELECT from the table
42                                                    # * index         Which index to ascend; optional.
43                                                    # * asc_only      Whether to ascend strictly, that is, the WHERE clause for
44                                                    #                 the asc_stmt will fetch the next row > the given arguments.
45                                                    #                 The option is to fetch the row >=, which could loop
46                                                    #                 infinitely.  Default is false.
47                                                    #
48                                                    # Returns a hashref of
49                                                    #   * cols:  columns in the select stmt, with required extras appended
50                                                    #   * index: index chosen to ascend
51                                                    #   * where: WHERE clause
52                                                    #   * slice: col ordinals to pull from a row that will satisfy ? placeholders
53                                                    #   * scols: ditto, but column names instead of ordinals
54                                                    #
55                                                    # In other words,
56                                                    #   $first = $dbh->prepare <....>;
57                                                    #   $next  = $dbh->prepare <....>;
58                                                    #   $row = $first->fetchrow_arrayref();
59                                                    #   $row = $next->fetchrow_arrayref(@{$row}[@slice]);
60                                                    sub generate_asc_stmt {
61            14                   14           263      my ( $self, %args ) = @_;
62            14                                 65      my @required_args = qw(tbl_struct index);
63            14                                 51      foreach my $arg ( @required_args ) {
64    ***     28     50                         137         die "I need a $arg argument" unless defined $args{$arg};
65                                                       }
66            14                                 78      my ($tbl_struct, $index) = @args{@required_args};
67            14    100                          59      my @cols = $args{cols}  ? @{$args{cols}} : @{$tbl_struct->{cols}};
              12                                 88   
               2                                 18   
68            14                                 60      my $q    = $self->{Quoter};
69                                                    
70                                                       # This shouldn't happen.  TableSyncNibble shouldn't call us with
71                                                       # a nonexistent index.
72            14    100                          75      die "Index '$index' does not exist in table"
73                                                          unless exists $tbl_struct->{keys}->{$index};
74                                                    
75            13                                 36      my @asc_cols = @{$tbl_struct->{keys}->{$index}->{cols}};
              13                                 79   
76            13                                 33      my @asc_slice;
77                                                    
78                                                       # These are the columns we'll ascend.
79            13                                 33      @asc_cols = @{$tbl_struct->{keys}->{$index}->{cols}};
              13                                 75   
80            13                                 31      MKDEBUG && _d('Will ascend index', $index);
81            13                                 30      MKDEBUG && _d('Will ascend columns', join(', ', @asc_cols));
82            13    100                          57      if ( $args{asc_first} ) {
83             1                                  5         @asc_cols = $asc_cols[0];
84             1                                  3         MKDEBUG && _d('Ascending only first column');
85                                                       }
86                                                    
87                                                       # We found the columns by name, now find their positions for use as
88                                                       # array slices, and make sure they are included in the SELECT list.
89            13                                 34      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
              13                                 37   
              13                                 43   
             109                                447   
90            13                                 67      foreach my $col ( @asc_cols ) {
91            27    100                         107         if ( !exists $col_posn{$col} ) {
92             1                                  3            push @cols, $col;
93             1                                  5            $col_posn{$col} = $#cols;
94                                                          }
95            27                                111         push @asc_slice, $col_posn{$col};
96                                                       }
97            13                                 33      MKDEBUG && _d('Will ascend, in ordinal position:', join(', ', @asc_slice));
98                                                    
99            13                                 97      my $asc_stmt = {
100                                                         cols  => \@cols,
101                                                         index => $index,
102                                                         where => '',
103                                                         slice => [],
104                                                         scols => [],
105                                                      };
106                                                   
107                                                      # ##########################################################################
108                                                      # Figure out how to ascend the index by building a possibly complicated
109                                                      # WHERE clause that will define a range beginning with a row retrieved by
110                                                      # asc_stmt.  If asc_only is given, the row's lower end should not include
111                                                      # the row.
112                                                      # ##########################################################################
113   ***     13     50                          57      if ( @asc_slice ) {
114           13                                 30         my $cmp_where;
115           13                                 50         foreach my $cmp ( qw(< <= >= >) ) {
116                                                            # Generate all 4 types, then choose the right one.
117           52                                313            $cmp_where = $self->generate_cmp_where(
118                                                               type        => $cmp,
119                                                               slice       => \@asc_slice,
120                                                               cols        => \@cols,
121                                                               quoter      => $q,
122                                                               is_nullable => $tbl_struct->{is_nullable},
123                                                            );
124           52                                351            $asc_stmt->{boundaries}->{$cmp} = $cmp_where->{where};
125                                                         }
126           13    100                          57         my $cmp = $args{asc_only} ? '>' : '>=';
127           13                                 62         $asc_stmt->{where} = $asc_stmt->{boundaries}->{$cmp};
128           13                                 48         $asc_stmt->{slice} = $cmp_where->{slice};
129           13                                 62         $asc_stmt->{scols} = $cmp_where->{scols};
130                                                      }
131                                                   
132           13                                259      return $asc_stmt;
133                                                   }
134                                                   
135                                                   # Generates a multi-column version of a WHERE statement.  It can generate >,
136                                                   # >=, < and <= versions.
137                                                   # Assuming >= and a non-NULLable two-column index, the WHERE clause should look
138                                                   # like this:
139                                                   # WHERE (col1 > ?) OR (col1 = ? AND col2 >= ?)
140                                                   # Ascending-only and nullable require variations on this.  The general
141                                                   # pattern is (>), (= >), (= = >), (= = = >=).
142                                                   sub generate_cmp_where {
143           56                   56           392      my ( $self, %args ) = @_;
144           56                                238      foreach my $arg ( qw(type slice cols is_nullable) ) {
145   ***    224     50                         963         die "I need a $arg arg" unless defined $args{$arg};
146                                                      }
147           56                                143      my @slice       = @{$args{slice}};
              56                                228   
148           56                                148      my @cols        = @{$args{cols}};
              56                                349   
149           56                                195      my $is_nullable = $args{is_nullable};
150           56                                176      my $type        = $args{type};
151           56                                177      my $q           = $self->{Quoter};
152                                                   
153           56                                211      (my $cmp = $type) =~ s/=//;
154                                                   
155           56                                127      my @r_slice;    # Resulting slice columns, by ordinal
156           56                                125      my @r_scols;    # Ditto, by name
157                                                   
158           56                                124      my @clauses;
159           56                                264      foreach my $i ( 0 .. $#slice ) {
160          116                                274         my @clause;
161                                                   
162                                                         # Most of the clauses should be strict equality.
163          116                                431         foreach my $j ( 0 .. $i - 1 ) {
164           88                                257            my $ord = $slice[$j];
165           88                                250            my $col = $cols[$ord];
166           88                                329            my $quo = $q->quote($col);
167           88    100                         345            if ( $is_nullable->{$col} ) {
168            8                                 34               push @clause, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
169            8                                 25               push @r_slice, $ord, $ord;
170            8                                 34               push @r_scols, $col, $col;
171                                                            }
172                                                            else {
173           80                                273               push @clause, "$quo = ?";
174           80                                232               push @r_slice, $ord;
175           80                                300               push @r_scols, $col;
176                                                            }
177                                                         }
178                                                   
179                                                         # The last clause in each parenthesized group should be > or <, unless
180                                                         # it's the very last of the whole WHERE clause and we are doing "or
181                                                         # equal," when it should be >= or <=.
182          116                                358         my $ord = $slice[$i];
183          116                                319         my $col = $cols[$ord];
184          116                                449         my $quo = $q->quote($col);
185          116                                411         my $end = $i == $#slice; # Last clause of the whole group.
186          116    100                         424         if ( $is_nullable->{$col} ) {
187           16    100    100                  130            if ( $type =~ m/=/ && $end ) {
                    100                               
188            4                                 20               push @clause, "(? IS NULL OR $quo $type ?)";
189                                                            }
190                                                            elsif ( $type =~ m/>/ ) {
191            6                                 35               push @clause, "((? IS NULL AND $quo IS NOT NULL) OR ($quo $cmp ?))";
192                                                            }
193                                                            else { # If $type =~ m/</ ) {
194            6                                 34               push @clause, "((? IS NOT NULL AND $quo IS NULL) OR ($quo $cmp ?))";
195                                                            }
196           16                                 51            push @r_slice, $ord, $ord;
197           16                                 53            push @r_scols, $col, $col;
198                                                         }
199                                                         else {
200          100                                322            push @r_slice, $ord;
201          100                                302            push @r_scols, $col;
202          100    100    100                  828            push @clause, ($type =~ m/=/ && $end ? "$quo $type ?" : "$quo $cmp ?");
203                                                         }
204                                                   
205                                                         # Add the clause to the larger WHERE clause.
206          116                                636         push @clauses, '(' . join(' AND ', @clause) . ')';
207                                                      }
208           56                                257      my $result = '(' . join(' OR ', @clauses) . ')';
209           56                                312      my $where = {
210                                                         slice => \@r_slice,
211                                                         scols => \@r_scols,
212                                                         where => $result,
213                                                      };
214           56                                361      return $where;
215                                                   }
216                                                   
217                                                   # Figure out how to delete rows. DELETE requires either an index or all
218                                                   # columns.  For that reason you should call this before calling
219                                                   # generate_asc_stmt(), so you know what columns you'll need to fetch from the
220                                                   # table.  Arguments:
221                                                   #   * tbl_struct
222                                                   #   * cols
223                                                   #   * index
224                                                   # These are the same as the arguments to generate_asc_stmt().  Return value is
225                                                   # similar too.
226                                                   sub generate_del_stmt {
227            4                    4            26      my ( $self, %args ) = @_;
228                                                   
229            4                                 17      my $tbl  = $args{tbl_struct};
230            4    100                          21      my @cols = $args{cols} ? @{$args{cols}} : ();
               1                                  5   
231            4                                 17      my $tp   = $self->{TableParser};
232            4                                 13      my $q    = $self->{Quoter};
233                                                   
234            4                                 12      my @del_cols;
235            4                                 12      my @del_slice;
236                                                   
237                                                      # ##########################################################################
238                                                      # Detect the best or preferred index to use for the WHERE clause needed to
239                                                      # delete the rows.
240                                                      # ##########################################################################
241            4                                 29      my $index = $tp->find_best_index($tbl, $args{index});
242   ***      4     50                          16      die "Cannot find an ascendable index in table" unless $index;
243                                                   
244                                                      # These are the columns needed for the DELETE statement's WHERE clause.
245   ***      4     50                          16      if ( $index ) {
246            4                                 11         @del_cols = @{$tbl->{keys}->{$index}->{cols}};
               4                                 27   
247                                                      }
248                                                      else {
249   ***      0                                  0         @del_cols = @{$tbl->{cols}};
      ***      0                                  0   
250                                                      }
251            4                                 10      MKDEBUG && _d('Columns needed for DELETE:', join(', ', @del_cols));
252                                                   
253                                                      # We found the columns by name, now find their positions for use as
254                                                      # array slices, and make sure they are included in the SELECT list.
255            4                                 10      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
               4                                 11   
               4                                 16   
               1                                  6   
256            4                                 13      foreach my $col ( @del_cols ) {
257   ***      8     50                          35         if ( !exists $col_posn{$col} ) {
258            8                                 23            push @cols, $col;
259            8                                 33            $col_posn{$col} = $#cols;
260                                                         }
261            8                                 34         push @del_slice, $col_posn{$col};
262                                                      }
263            4                                 11      MKDEBUG && _d('Ordinals needed for DELETE:', join(', ', @del_slice));
264                                                   
265            4                                 32      my $del_stmt = {
266                                                         cols  => \@cols,
267                                                         index => $index,
268                                                         where => '',
269                                                         slice => [],
270                                                         scols => [],
271                                                      };
272                                                   
273                                                      # ##########################################################################
274                                                      # Figure out how to target a single row with a WHERE clause.
275                                                      # ##########################################################################
276            4                                 12      my @clauses;
277            4                                 20      foreach my $i ( 0 .. $#del_slice ) {
278            8                                 24         my $ord = $del_slice[$i];
279            8                                 23         my $col = $cols[$ord];
280            8                                 35         my $quo = $q->quote($col);
281            8    100                          39         if ( $tbl->{is_nullable}->{$col} ) {
282            1                                  7            push @clauses, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
283            1                                  3            push @{$del_stmt->{slice}}, $ord, $ord;
               1                                  4   
284            1                                  4            push @{$del_stmt->{scols}}, $col, $col;
               1                                  5   
285                                                         }
286                                                         else {
287            7                                 24            push @clauses, "$quo = ?";
288            7                                 16            push @{$del_stmt->{slice}}, $ord;
               7                                 28   
289            7                                 16            push @{$del_stmt->{scols}}, $col;
               7                                 32   
290                                                         }
291                                                      }
292                                                   
293            4                                 24      $del_stmt->{where} = '(' . join(' AND ', @clauses) . ')';
294                                                   
295            4                                 55      return $del_stmt;
296                                                   }
297                                                   
298                                                   # Design an INSERT statement.  This actually does very little; it just maps
299                                                   # the columns you know you'll get from the SELECT statement onto the columns
300                                                   # in the INSERT statement, returning only those that exist in both sets.
301                                                   # Arguments:
302                                                   #    ins_tbl   hashref returned by TableParser::parse() for the INSERT table
303                                                   #    sel_cols  arrayref of columns to SELECT from the SELECT table
304                                                   # Returns a hashref:
305                                                   #    cols  => arrayref of columns for INSERT
306                                                   #    slice => arrayref of sel_cols indices corresponding to the INSERT cols
307                                                   # The cols array is used to construct the INSERT's INTO clause like:
308                                                   #    INSERT INTO ins_tbl (@cols) VALUES ...
309                                                   # The slice array is used like:
310                                                   #    $row = $sel_sth->fetchrow_arrayref();
311                                                   #    $ins_sth->execute(@{$row}[@slice]);
312                                                   # For example, if we select columns (a, b, c) but the insert table only
313                                                   # has columns (a, c), then the return hashref will be:
314                                                   #    cols  => [a, c]
315                                                   #    slice => [0, 2]
316                                                   # Therefore, the select statement will return an array with 3 elements
317                                                   # (one for each column), but the insert statement will slice this array
318                                                   # to get only the elements/columns it needs.
319                                                   sub generate_ins_stmt {
320            2                    2            34      my ( $self, %args ) = @_;
321            2                                  8      foreach my $arg ( qw(ins_tbl sel_cols) ) {
322   ***      4     50                          21         die "I need a $arg argument" unless $args{$arg};
323                                                      }
324            2                                  6      my $ins_tbl  = $args{ins_tbl};
325            2                                  5      my @sel_cols = @{$args{sel_cols}};
               2                                 13   
326                                                   
327   ***      2     50                           7      die "You didn't specify any SELECT columns" unless @sel_cols;
328                                                   
329            2                                  6      my @ins_cols;
330            2                                  4      my @ins_slice;
331            2                                  9      for my $i ( 0..$#sel_cols ) {
332           10    100                          52         next unless $ins_tbl->{is_col}->{$sel_cols[$i]};
333            3                                 11         push @ins_cols, $sel_cols[$i];
334            3                                 10         push @ins_slice, $i;
335                                                      }
336                                                   
337                                                      return {
338            2                                 27         cols  => \@ins_cols,
339                                                         slice => \@ins_slice,
340                                                      };
341                                                   }
342                                                   
343                                                   sub _d {
344   ***      0                    0                    my ($package, undef, $line) = caller 0;
345   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
346   ***      0                                              map { defined $_ ? $_ : 'undef' }
347                                                           @_;
348   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
349                                                   }
350                                                   
351                                                   1;
352                                                   
353                                                   # ###########################################################################
354                                                   # End TableNibbler package
355                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
33    ***     50      0      2   unless $args{$arg}
64    ***     50      0     28   unless defined $args{$arg}
67           100     12      2   $args{'cols'} ? :
72           100      1     13   unless exists $$tbl_struct{'keys'}{$index}
82           100      1     12   if ($args{'asc_first'})
91           100      1     26   if (not exists $col_posn{$col})
113   ***     50     13      0   if (@asc_slice)
126          100      3     10   $args{'asc_only'} ? :
145   ***     50      0    224   unless defined $args{$arg}
167          100      8     80   if ($$is_nullable{$col}) { }
186          100     16    100   if ($$is_nullable{$col}) { }
187          100      4     12   if ($type =~ /=/ and $end) { }
             100      6      6   elsif ($type =~ />/) { }
202          100     24     76   $type =~ /=/ && $end ? :
230          100      1      3   $args{'cols'} ? :
242   ***     50      0      4   unless $index
245   ***     50      4      0   if ($index) { }
257   ***     50      8      0   if (not exists $col_posn{$col})
281          100      1      7   if ($$tbl{'is_nullable'}{$col}) { }
322   ***     50      0      4   unless $args{$arg}
327   ***     50      0      2   unless @sel_cols
332          100      7      3   unless $$ins_tbl{'is_col'}{$sel_cols[$i]}
345   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
187          100      8      4      4   $type =~ /=/ and $end
202          100     50     26     24   $type =~ /=/ && $end


Covered Subroutines
-------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:22 
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:23 
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:25 
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:27 
generate_asc_stmt     14 /home/daniel/dev/maatkit/common/TableNibbler.pm:61 
generate_cmp_where    56 /home/daniel/dev/maatkit/common/TableNibbler.pm:143
generate_del_stmt      4 /home/daniel/dev/maatkit/common/TableNibbler.pm:227
generate_ins_stmt      2 /home/daniel/dev/maatkit/common/TableNibbler.pm:320
new                    1 /home/daniel/dev/maatkit/common/TableNibbler.pm:30 

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
_d                     0 /home/daniel/dev/maatkit/common/TableNibbler.pm:344


