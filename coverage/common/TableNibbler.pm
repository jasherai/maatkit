---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/TableNibbler.pm   95.2   78.6  100.0   90.9    n/a  100.0   92.0
Total                          95.2   78.6  100.0   90.9    n/a  100.0   92.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableNibbler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:59 2009
Finish:       Sat Aug 29 15:03:59 2009

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
18                                                    # TableNibbler package $Revision: 4586 $
19                                                    # ###########################################################################
20                                                    package TableNibbler;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
26             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                 11   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  7   
32                                                    
33                                                    sub new {
34             1                    1            20      return bless {}, shift;
35                                                    }
36                                                    
37                                                    # Arguments are as follows:
38                                                    # * parser   TableParser
39                                                    # * tbl      Hashref as provided by TableParser.
40                                                    # * cols     Arrayref of columns to SELECT from the table. Defaults to all.
41                                                    # * index    Which index to ascend; optional.
42                                                    # * ascfirst Ascend the first column of the given index.
43                                                    # * quoter   a Quoter object
44                                                    # * asconly  Whether to ascend strictly, that is, the WHERE clause for
45                                                    #            the asc_stmt will fetch the next row > the given arguments.
46                                                    #            The option is to fetch the row >=, which could loop
47                                                    #            infinitely.  Default is false.
48                                                    #
49                                                    # Returns a hashref of
50                                                    # * cols:  columns in the select stmt, with required extras appended
51                                                    # * index: index chosen to ascend
52                                                    # * where: WHERE clause
53                                                    # * slice: col ordinals to pull from a row that will satisfy ? placeholders
54                                                    # * scols: ditto, but column names instead of ordinals
55                                                    #
56                                                    # In other words,
57                                                    # $first = $dbh->prepare <....>;
58                                                    # $next  = $dbh->prepare <....>;
59                                                    # $row = $first->fetchrow_arrayref();
60                                                    # $row = $next->fetchrow_arrayref(@{$row}[@slice]);
61                                                    sub generate_asc_stmt {
62            15                   15           361      my ( $self, %args ) = @_;
63                                                    
64            15                                 65      my $tbl  = $args{tbl};
65            15    100                          71      my @cols = $args{cols} ? @{$args{cols}} : @{$tbl->{cols}};
              12                                 95   
               3                                 24   
66            15                                 56      my $q    = $args{quoter};
67                                                    
68            15                                 36      my @asc_cols;
69            15                                 39      my @asc_slice;
70                                                    
71                                                       # ##########################################################################
72                                                       # Detect indexes and columns needed.
73                                                       # ##########################################################################
74            15                                118      my $index = $args{parser}->find_best_index($tbl, $args{index});
75            14    100                          58      die "Cannot find an ascendable index in table" unless $index;
76                                                    
77                                                       # These are the columns we'll ascend.
78            13                                 35      @asc_cols = @{$tbl->{keys}->{$index}->{cols}};
              13                                 86   
79            13                                 36      MKDEBUG && _d('Will ascend index', $index);
80            13                                 30      MKDEBUG && _d('Will ascend columns', join(', ', @asc_cols));
81            13    100                          57      if ( $args{ascfirst} ) {
82             1                                  4         @asc_cols = $asc_cols[0];
83             1                                  3         MKDEBUG && _d('Ascending only first column');
84                                                       }
85                                                    
86                                                       # We found the columns by name, now find their positions for use as
87                                                       # array slices, and make sure they are included in the SELECT list.
88            13                                 36      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
              13                                 35   
              13                                 41   
             109                                452   
89            13                                 76      foreach my $col ( @asc_cols ) {
90            27    100                         109         if ( !exists $col_posn{$col} ) {
91             1                                  4            push @cols, $col;
92             1                                  6            $col_posn{$col} = $#cols;
93                                                          }
94            27                                116         push @asc_slice, $col_posn{$col};
95                                                       }
96            13                                 30      MKDEBUG && _d('Will ascend, in ordinal position:', join(', ', @asc_slice));
97                                                    
98            13                                105      my $asc_stmt = {
99                                                          cols  => \@cols,
100                                                         index => $index,
101                                                         where => '',
102                                                         slice => [],
103                                                         scols => [],
104                                                      };
105                                                   
106                                                      # ##########################################################################
107                                                      # Figure out how to ascend the index by building a possibly complicated
108                                                      # WHERE clause that will define a range beginning with a row retrieved by
109                                                      # asc_stmt.  If asconly is given, the row's lower end should not include
110                                                      # the row.
111                                                      # ##########################################################################
112   ***     13     50                          52      if ( @asc_slice ) {
113           13                                 35         my $cmp_where;
114           13                                 58         foreach my $cmp ( qw(< <= >= >) ) {
115                                                            # Generate all 4 types, then choose the right one.
116           52                                331            $cmp_where = $self->generate_cmp_where(
117                                                               type        => $cmp,
118                                                               slice       => \@asc_slice,
119                                                               cols        => \@cols,
120                                                               quoter      => $q,
121                                                               is_nullable => $tbl->{is_nullable},
122                                                            );
123           52                                358            $asc_stmt->{boundaries}->{$cmp} = $cmp_where->{where};
124                                                         }
125           13    100                          63         my $cmp = $args{asconly} ? '>' : '>=';
126           13                                 61         $asc_stmt->{where} = $asc_stmt->{boundaries}->{$cmp};
127           13                                 49         $asc_stmt->{slice} = $cmp_where->{slice};
128           13                                 61         $asc_stmt->{scols} = $cmp_where->{scols};
129                                                      }
130                                                   
131           13                                275      return $asc_stmt;
132                                                   }
133                                                   
134                                                   # Generates a multi-column version of a WHERE statement.  It can generate >,
135                                                   # >=, < and <= versions.
136                                                   # Assuming >= and a non-NULLable two-column index, the WHERE clause should look
137                                                   # like this:
138                                                   # WHERE (col1 > ?) OR (col1 = ? AND col2 >= ?)
139                                                   # Ascending-only and nullable require variations on this.  The general
140                                                   # pattern is (>), (= >), (= = >), (= = = >=).
141                                                   sub generate_cmp_where {
142           56                   56           390      my ( $self, %args ) = @_;
143           56                                236      foreach my $arg ( qw(type slice cols quoter is_nullable) ) {
144   ***    280     50                        1190         die "I need a $arg arg" unless defined $args{$arg};
145                                                      }
146           56                                131      MKDEBUG && _d('generate_cmp_where args:', Dumper(\%args));
147           56                                141      my @slice       = @{$args{slice}};
              56                                253   
148           56                                137      my @cols        = @{$args{cols}};
              56                                351   
149           56                                193      my $q           = $args{quoter};
150           56                                162      my $is_nullable = $args{is_nullable};
151           56                                165      my $type        = $args{type};
152                                                   
153           56                                220      (my $cmp = $type) =~ s/=//;
154                                                   
155           56                                124      my @r_slice;    # Resulting slice columns, by ordinal
156           56                                133      my @r_scols;    # Ditto, by name
157                                                   
158           56                                127      my @clauses;
159           56                                272      foreach my $i ( 0 .. $#slice ) {
160          116                                281         my @clause;
161                                                   
162                                                         # Most of the clauses should be strict equality.
163          116                                449         foreach my $j ( 0 .. $i - 1 ) {
164           88                                255            my $ord = $slice[$j];
165           88                                243            my $col = $cols[$ord];
166           88                                338            my $quo = $q->quote($col);
167           88    100                         355            if ( $is_nullable->{$col} ) {
168            8                                 36               push @clause, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
169            8                                 25               push @r_slice, $ord, $ord;
170            8                                 40               push @r_scols, $col, $col;
171                                                            }
172                                                            else {
173           80                                264               push @clause, "$quo = ?";
174           80                                218               push @r_slice, $ord;
175           80                                314               push @r_scols, $col;
176                                                            }
177                                                         }
178                                                   
179                                                         # The last clause in each parenthesized group should be > or <, unless
180                                                         # it's the very last of the whole WHERE clause and we are doing "or
181                                                         # equal," when it should be >= or <=.
182          116                                355         my $ord = $slice[$i];
183          116                                336         my $col = $cols[$ord];
184          116                                450         my $quo = $q->quote($col);
185          116                                414         my $end = $i == $#slice; # Last clause of the whole group.
186          116    100                         462         if ( $is_nullable->{$col} ) {
187           16    100    100                  122            if ( $type =~ m/=/ && $end ) {
                    100                               
188            4                                 20               push @clause, "(? IS NULL OR $quo $type ?)";
189                                                            }
190                                                            elsif ( $type =~ m/>/ ) {
191            6                                 35               push @clause, "((? IS NULL AND $quo IS NOT NULL) OR ($quo $cmp ?))";
192                                                            }
193                                                            else { # If $type =~ m/</ ) {
194            6                                 36               push @clause, "((? IS NOT NULL AND $quo IS NULL) OR ($quo $cmp ?))";
195                                                            }
196           16                                 50            push @r_slice, $ord, $ord;
197           16                                 51            push @r_scols, $col, $col;
198                                                         }
199                                                         else {
200          100                                312            push @r_slice, $ord;
201          100                                289            push @r_scols, $col;
202          100    100    100                 6431            push @clause, ($type =~ m/=/ && $end ? "$quo $type ?" : "$quo $cmp ?");
203                                                         }
204                                                   
205                                                         # Add the clause to the larger WHERE clause.
206          116                                641         push @clauses, '(' . join(' AND ', @clause) . ')';
207                                                      }
208           56                                255      my $result = '(' . join(' OR ', @clauses) . ')';
209           56                                312      my $where = {
210                                                         slice => \@r_slice,
211                                                         scols => \@r_scols,
212                                                         where => $result,
213                                                      };
214           56                                125      MKDEBUG && _d('generate_cmp_where:', Dumper($where));
215           56                                357      return $where;
216                                                   }
217                                                   
218                                                   # Figure out how to delete rows. DELETE requires either an index or all
219                                                   # columns.  For that reason you should call this before calling
220                                                   # generate_asc_stmt(), so you know what columns you'll need to fetch from the
221                                                   # table.  Arguments:
222                                                   # * parser * tbl * cols * quoter * index
223                                                   # These are the same as the arguments to generate_asc_stmt().  Return value is
224                                                   # similar too.
225                                                   sub generate_del_stmt {
226            4                    4            35      my ( $self, %args ) = @_;
227                                                   
228            4                                 16      my $tbl  = $args{tbl};
229            4    100                          22      my @cols = $args{cols} ? @{$args{cols}} : ();
               1                                  5   
230            4                                 13      my $q    = $args{quoter};
231                                                   
232            4                                 11      my @del_cols;
233            4                                  9      my @del_slice;
234                                                   
235                                                      # ##########################################################################
236                                                      # Detect the best or preferred index to use for the WHERE clause needed to
237                                                      # delete the rows.
238                                                      # ##########################################################################
239            4                                 36      my $index = $args{parser}->find_best_index($tbl, $args{index});
240   ***      4     50                          17      die "Cannot find an ascendable index in table" unless $index;
241                                                   
242                                                      # These are the columns needed for the DELETE statement's WHERE clause.
243   ***      4     50                          16      if ( $index ) {
244            4                                  9         @del_cols = @{$tbl->{keys}->{$index}->{cols}};
               4                                 29   
245                                                      }
246                                                      else {
247   ***      0                                  0         @del_cols = @{$tbl->{cols}};
      ***      0                                  0   
248                                                      }
249            4                                 10      MKDEBUG && _d('Columns needed for DELETE:', join(', ', @del_cols));
250                                                   
251                                                      # We found the columns by name, now find their positions for use as
252                                                      # array slices, and make sure they are included in the SELECT list.
253            4                                 11      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
               4                                 11   
               4                                 17   
               1                                  6   
254            4                                 16      foreach my $col ( @del_cols ) {
255   ***      8     50                          34         if ( !exists $col_posn{$col} ) {
256            8                                 23            push @cols, $col;
257            8                                 36            $col_posn{$col} = $#cols;
258                                                         }
259            8                                 32         push @del_slice, $col_posn{$col};
260                                                      }
261            4                                  9      MKDEBUG && _d('Ordinals needed for DELETE:', join(', ', @del_slice));
262                                                   
263            4                                 31      my $del_stmt = {
264                                                         cols  => \@cols,
265                                                         index => $index,
266                                                         where => '',
267                                                         slice => [],
268                                                         scols => [],
269                                                      };
270                                                   
271                                                      # ##########################################################################
272                                                      # Figure out how to target a single row with a WHERE clause.
273                                                      # ##########################################################################
274            4                                 10      my @clauses;
275            4                                 19      foreach my $i ( 0 .. $#del_slice ) {
276            8                                 25         my $ord = $del_slice[$i];
277            8                                 24         my $col = $cols[$ord];
278            8                                 36         my $quo = $q->quote($col);
279            8    100                          40         if ( $tbl->{is_nullable}->{$col} ) {
280            1                                  6            push @clauses, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
281            1                                  3            push @{$del_stmt->{slice}}, $ord, $ord;
               1                                  4   
282            1                                  3            push @{$del_stmt->{scols}}, $col, $col;
               1                                  5   
283                                                         }
284                                                         else {
285            7                                 31            push @clauses, "$quo = ?";
286            7                                 22            push @{$del_stmt->{slice}}, $ord;
               7                                 28   
287            7                                 19            push @{$del_stmt->{scols}}, $col;
               7                                 33   
288                                                         }
289                                                      }
290                                                   
291            4                                 25      $del_stmt->{where} = '(' . join(' AND ', @clauses) . ')';
292                                                   
293            4                                 57      return $del_stmt;
294                                                   }
295                                                   
296                                                   # Design an INSERT statement.  This actually does very little; it just maps
297                                                   # the columns you know you'll get from the SELECT statement onto the columns
298                                                   # in the INSERT statement, returning only those that exist in both sets.
299                                                   # Arguments:
300                                                   #    ins_tbl   hashref returned by TableParser::parse() for the INSERT table
301                                                   #    sel_cols  arrayref of columns to SELECT from the SELECT table
302                                                   # Returns a hashref:
303                                                   #    cols  => arrayref of columns for INSERT
304                                                   #    slice => arrayref of sel_cols indices corresponding to the INSERT cols
305                                                   # The cols array is used to construct the INSERT's INTO clause like:
306                                                   #    INSERT INTO ins_tbl (@cols) VALUES ...
307                                                   # The slice array is used like:
308                                                   #    $row = $sel_sth->fetchrow_arrayref();
309                                                   #    $ins_sth->execute(@{$row}[@slice]);
310                                                   # For example, if we select columns (a, b, c) but the insert table only
311                                                   # has columns (a, c), then the return hashref will be:
312                                                   #    cols  => [a, c]
313                                                   #    slice => [0, 2]
314                                                   # Therefore, the select statement will return an array with 3 elements
315                                                   # (one for each column), but the insert statement will slice this array
316                                                   # to get only the elements/columns it needs.
317                                                   sub generate_ins_stmt {
318            2                    2            37      my ( $self, %args ) = @_;
319            2                                  7      foreach my $arg ( qw(ins_tbl sel_cols) ) {
320   ***      4     50                          21         die "I need a $arg argument" unless $args{$arg};
321                                                      }
322            2                                  7      my $ins_tbl  = $args{ins_tbl};
323            2                                  5      my @sel_cols = @{$args{sel_cols}};
               2                                 12   
324                                                   
325   ***      2     50                           9      die "You didn't specify any SELECT columns" unless @sel_cols;
326                                                   
327            2                                  4      my @ins_cols;
328            2                                  6      my @ins_slice;
329            2                                  9      for my $i ( 0..$#sel_cols ) {
330           10    100                          50         next unless $ins_tbl->{is_col}->{$sel_cols[$i]};
331            3                                 11         push @ins_cols, $sel_cols[$i];
332            3                                 11         push @ins_slice, $i;
333                                                      }
334                                                   
335                                                      return {
336            2                                 25         cols  => \@ins_cols,
337                                                         slice => \@ins_slice,
338                                                      };
339                                                   }
340                                                   
341                                                   sub _d {
342   ***      0                    0                    my ($package, undef, $line) = caller 0;
343   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
344   ***      0                                              map { defined $_ ? $_ : 'undef' }
345                                                           @_;
346   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
347                                                   }
348                                                   
349                                                   1;
350                                                   
351                                                   # ###########################################################################
352                                                   # End TableNibbler package
353                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
65           100     12      3   $args{'cols'} ? :
75           100      1     13   unless $index
81           100      1     12   if ($args{'ascfirst'})
90           100      1     26   if (not exists $col_posn{$col})
112   ***     50     13      0   if (@asc_slice)
125          100      3     10   $args{'asconly'} ? :
144   ***     50      0    280   unless defined $args{$arg}
167          100      8     80   if ($$is_nullable{$col}) { }
186          100     16    100   if ($$is_nullable{$col}) { }
187          100      4     12   if ($type =~ /=/ and $end) { }
             100      6      6   elsif ($type =~ />/) { }
202          100     24     76   $type =~ /=/ && $end ? :
229          100      1      3   $args{'cols'} ? :
240   ***     50      0      4   unless $index
243   ***     50      4      0   if ($index) { }
255   ***     50      8      0   if (not exists $col_posn{$col})
279          100      1      7   if ($$tbl{'is_nullable'}{$col}) { }
320   ***     50      0      4   unless $args{$arg}
325   ***     50      0      2   unless @sel_cols
330          100      7      3   unless $$ins_tbl{'is_col'}{$sel_cols[$i]}
343   ***      0      0      0   defined $_ ? :


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
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:26 
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:31 
generate_asc_stmt     15 /home/daniel/dev/maatkit/common/TableNibbler.pm:62 
generate_cmp_where    56 /home/daniel/dev/maatkit/common/TableNibbler.pm:142
generate_del_stmt      4 /home/daniel/dev/maatkit/common/TableNibbler.pm:226
generate_ins_stmt      2 /home/daniel/dev/maatkit/common/TableNibbler.pm:318
new                    1 /home/daniel/dev/maatkit/common/TableNibbler.pm:34 

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
_d                     0 /home/daniel/dev/maatkit/common/TableNibbler.pm:342


