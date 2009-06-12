---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/TableNibbler.pm   95.0   78.6  100.0   90.0    n/a  100.0   91.7
Total                          95.0   78.6  100.0   90.0    n/a  100.0   91.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableNibbler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:12 2009
Finish:       Wed Jun 10 17:21:12 2009

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
18                                                    # TableNibbler package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    package TableNibbler;
21                                                    
22             1                    1            13   use strict;
               1                                  3   
               1                                  9   
23             1                    1            10   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
28                                                    
29                                                    sub new {
30             1                    1            17      bless {}, shift;
31                                                    }
32                                                    
33                                                    # Arguments are as follows:
34                                                    # * parser   TableParser
35                                                    # * tbl      Hashref as provided by TableParser.
36                                                    # * cols     Arrayref of columns to SELECT from the table. Defaults to all.
37                                                    # * index    Which index to ascend; optional.
38                                                    # * ascfirst Ascend the first column of the given index.
39                                                    # * quoter   a Quoter object
40                                                    # * asconly  Whether to ascend strictly, that is, the WHERE clause for
41                                                    #            the asc_stmt will fetch the next row > the given arguments.
42                                                    #            The option is to fetch the row >=, which could loop
43                                                    #            infinitely.  Default is false.
44                                                    #
45                                                    # Returns a hashref of
46                                                    # * cols:  columns in the select stmt, with required extras appended
47                                                    # * index: index chosen to ascend
48                                                    # * where: WHERE clause
49                                                    # * slice: col ordinals to pull from a row that will satisfy ? placeholders
50                                                    # * scols: ditto, but column names instead of ordinals
51                                                    #
52                                                    # In other words,
53                                                    # $first = $dbh->prepare <....>;
54                                                    # $next  = $dbh->prepare <....>;
55                                                    # $row = $first->fetchrow_arrayref();
56                                                    # $row = $next->fetchrow_arrayref(@{$row}[@slice]);
57                                                    sub generate_asc_stmt {
58            15                   15           375      my ( $self, %args ) = @_;
59                                                    
60            15                                 68      my $tbl  = $args{tbl};
61            15    100                          68      my @cols = $args{cols} ? @{$args{cols}} : @{$tbl->{cols}};
              12                                 98   
               3                                 23   
62            15                                 56      my $q    = $args{quoter};
63                                                    
64            15                                 41      my @asc_cols;
65            15                                 37      my @asc_slice;
66                                                    
67                                                       # ##########################################################################
68                                                       # Detect indexes and columns needed.
69                                                       # ##########################################################################
70            15                                124      my $index = $args{parser}->find_best_index($tbl, $args{index});
71            14    100                          60      die "Cannot find an ascendable index in table" unless $index;
72                                                    
73                                                       # These are the columns we'll ascend.
74            13                                 34      @asc_cols = @{$tbl->{keys}->{$index}->{cols}};
              13                                 87   
75            13                                 30      MKDEBUG && _d('Will ascend index', $index);
76            13                                 28      MKDEBUG && _d('Will ascend columns', join(', ', @asc_cols));
77            13    100                          56      if ( $args{ascfirst} ) {
78             1                                  4         @asc_cols = $asc_cols[0];
79             1                                  3         MKDEBUG && _d('Ascending only first column');
80                                                       }
81                                                    
82                                                       # We found the columns by name, now find their positions for use as
83                                                       # array slices, and make sure they are included in the SELECT list.
84            13                                 37      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
              13                                 40   
              13                                 39   
             109                                474   
85            13                                 70      foreach my $col ( @asc_cols ) {
86            27    100                         111         if ( !exists $col_posn{$col} ) {
87             1                                  3            push @cols, $col;
88             1                                  5            $col_posn{$col} = $#cols;
89                                                          }
90            27                                109         push @asc_slice, $col_posn{$col};
91                                                       }
92            13                                 30      MKDEBUG && _d('Will ascend, in ordinal position:', join(', ', @asc_slice));
93                                                    
94            13                                100      my $asc_stmt = {
95                                                          cols  => \@cols,
96                                                          index => $index,
97                                                          where => '',
98                                                          slice => [],
99                                                          scols => [],
100                                                      };
101                                                   
102                                                      # ##########################################################################
103                                                      # Figure out how to ascend the index by building a possibly complicated
104                                                      # WHERE clause that will define a range beginning with a row retrieved by
105                                                      # asc_stmt.  If asconly is given, the row's lower end should not include
106                                                      # the row.
107                                                      # ##########################################################################
108   ***     13     50                          54      if ( @asc_slice ) {
109           13                                 31         my $cmp_where;
110           13                                 51         foreach my $cmp ( qw(< <= >= >) ) {
111                                                            # Generate all 4 types, then choose the right one.
112           52                                322            $cmp_where = $self->generate_cmp_where(
113                                                               type        => $cmp,
114                                                               slice       => \@asc_slice,
115                                                               cols        => \@cols,
116                                                               quoter      => $q,
117                                                               is_nullable => $tbl->{is_nullable},
118                                                            );
119           52                                379            $asc_stmt->{boundaries}->{$cmp} = $cmp_where->{where};
120                                                         }
121           13    100                          64         my $cmp = $args{asconly} ? '>' : '>=';
122           13                                 67         $asc_stmt->{where} = $asc_stmt->{boundaries}->{$cmp};
123           13                                 52         $asc_stmt->{slice} = $cmp_where->{slice};
124           13                                 65         $asc_stmt->{scols} = $cmp_where->{scols};
125                                                      }
126                                                   
127           13                                293      return $asc_stmt;
128                                                   }
129                                                   
130                                                   # Generates a multi-column version of a WHERE statement.  It can generate >,
131                                                   # >=, < and <= versions.
132                                                   # Assuming >= and a non-NULLable two-column index, the WHERE clause should look
133                                                   # like this:
134                                                   # WHERE (col1 > ?) OR (col1 = ? AND col2 >= ?)
135                                                   # Ascending-only and nullable require variations on this.  The general
136                                                   # pattern is (>), (= >), (= = >), (= = = >=).
137                                                   sub generate_cmp_where {
138           56                   56           401      my ( $self, %args ) = @_;
139           56                                239      foreach my $arg ( qw(type slice cols quoter is_nullable) ) {
140   ***    280     50                        1208         die "I need a $arg arg" unless defined $args{$arg};
141                                                      }
142                                                   
143           56                                157      my @slice       = @{$args{slice}};
              56                                233   
144           56                                153      my @cols        = @{$args{cols}};
              56                                357   
145           56                                199      my $q           = $args{quoter};
146           56                                165      my $is_nullable = $args{is_nullable};
147           56                                166      my $type        = $args{type};
148                                                   
149           56                                223      (my $cmp = $type) =~ s/=//;
150                                                   
151           56                                131      my @r_slice;    # Resulting slice columns, by ordinal
152           56                                122      my @r_scols;    # Ditto, by name
153                                                   
154           56                                121      my @clauses;
155           56                                291      foreach my $i ( 0 .. $#slice ) {
156          116                                288         my @clause;
157                                                   
158                                                         # Most of the clauses should be strict equality.
159          116                                449         foreach my $j ( 0 .. $i - 1 ) {
160           88                                254            my $ord = $slice[$j];
161           88                                250            my $col = $cols[$ord];
162           88                                325            my $quo = $q->quote($col);
163           88    100                         349            if ( $is_nullable->{$col} ) {
164            8                                 37               push @clause, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
165            8                                 27               push @r_slice, $ord, $ord;
166            8                                 37               push @r_scols, $col, $col;
167                                                            }
168                                                            else {
169           80                                283               push @clause, "$quo = ?";
170           80                                220               push @r_slice, $ord;
171           80                                298               push @r_scols, $col;
172                                                            }
173                                                         }
174                                                   
175                                                         # The last clause in each parenthesized group should be > or <, unless
176                                                         # it's the very last of the whole WHERE clause and we are doing "or
177                                                         # equal," when it should be >= or <=.
178          116                                362         my $ord = $slice[$i];
179          116                                324         my $col = $cols[$ord];
180          116                                448         my $quo = $q->quote($col);
181          116                                407         my $end = $i == $#slice; # Last clause of the whole group.
182          116    100                         452         if ( $is_nullable->{$col} ) {
183           16    100    100                  149            if ( $type =~ m/=/ && $end ) {
                    100                               
184            4                                 19               push @clause, "(? IS NULL OR $quo $type ?)";
185                                                            }
186                                                            elsif ( $type =~ m/>/ ) {
187            6                                 34               push @clause, "((? IS NULL AND $quo IS NOT NULL) OR ($quo $cmp ?))";
188                                                            }
189                                                            else { # If $type =~ m/</ ) {
190            6                                 36               push @clause, "((? IS NOT NULL AND $quo IS NULL) OR ($quo $cmp ?))";
191                                                            }
192           16                                 54            push @r_slice, $ord, $ord;
193           16                                 55            push @r_scols, $col, $col;
194                                                         }
195                                                         else {
196          100                                309            push @r_slice, $ord;
197          100                                291            push @r_scols, $col;
198          100    100    100                  823            push @clause, ($type =~ m/=/ && $end ? "$quo $type ?" : "$quo $cmp ?");
199                                                         }
200                                                   
201                                                         # Add the clause to the larger WHERE clause.
202          116                                613         push @clauses, '(' . join(' AND ', @clause) . ')';
203                                                      }
204           56                                250      my $result = '(' . join(' OR ', @clauses) . ')';
205                                                      return {
206           56                                527         slice => \@r_slice,
207                                                         scols => \@r_scols,
208                                                         where => $result,
209                                                      };
210                                                   }
211                                                   
212                                                   # Figure out how to delete rows. DELETE requires either an index or all
213                                                   # columns.  For that reason you should call this before calling
214                                                   # generate_asc_stmt(), so you know what columns you'll need to fetch from the
215                                                   # table.  Arguments:
216                                                   # * parser * tbl * cols * quoter * index
217                                                   # These are the same as the arguments to generate_asc_stmt().  Return value is
218                                                   # similar too.
219                                                   sub generate_del_stmt {
220            4                    4            31      my ( $self, %args ) = @_;
221                                                   
222            4                                 17      my $tbl  = $args{tbl};
223            4    100                          21      my @cols = $args{cols} ? @{$args{cols}} : ();
               1                                  4   
224            4                                 14      my $q    = $args{quoter};
225                                                   
226            4                                 12      my @del_cols;
227            4                                 10      my @del_slice;
228                                                   
229                                                      # ##########################################################################
230                                                      # Detect the best or preferred index to use for the WHERE clause needed to
231                                                      # delete the rows.
232                                                      # ##########################################################################
233            4                                 28      my $index = $args{parser}->find_best_index($tbl, $args{index});
234   ***      4     50                          15      die "Cannot find an ascendable index in table" unless $index;
235                                                   
236                                                      # These are the columns needed for the DELETE statement's WHERE clause.
237   ***      4     50                          15      if ( $index ) {
238            4                                 12         @del_cols = @{$tbl->{keys}->{$index}->{cols}};
               4                                 28   
239                                                      }
240                                                      else {
241   ***      0                                  0         @del_cols = @{$tbl->{cols}};
      ***      0                                  0   
242                                                      }
243            4                                 11      MKDEBUG && _d('Columns needed for DELETE:', join(', ', @del_cols));
244                                                   
245                                                      # We found the columns by name, now find their positions for use as
246                                                      # array slices, and make sure they are included in the SELECT list.
247            4                                 11      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
               4                                 12   
               4                                 16   
               1                                  7   
248            4                                 12      foreach my $col ( @del_cols ) {
249   ***      8     50                          34         if ( !exists $col_posn{$col} ) {
250            8                                 34            push @cols, $col;
251            8                                 35            $col_posn{$col} = $#cols;
252                                                         }
253            8                                 34         push @del_slice, $col_posn{$col};
254                                                      }
255            4                                  9      MKDEBUG && _d('Ordinals needed for DELETE:', join(', ', @del_slice));
256                                                   
257            4                                 32      my $del_stmt = {
258                                                         cols  => \@cols,
259                                                         index => $index,
260                                                         where => '',
261                                                         slice => [],
262                                                         scols => [],
263                                                      };
264                                                   
265                                                      # ##########################################################################
266                                                      # Figure out how to target a single row with a WHERE clause.
267                                                      # ##########################################################################
268            4                                 17      my @clauses;
269            4                                 20      foreach my $i ( 0 .. $#del_slice ) {
270            8                                 26         my $ord = $del_slice[$i];
271            8                                 25         my $col = $cols[$ord];
272            8                                 32         my $quo = $q->quote($col);
273            8    100                          41         if ( $tbl->{is_nullable}->{$col} ) {
274            1                                  8            push @clauses, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
275            1                                  2            push @{$del_stmt->{slice}}, $ord, $ord;
               1                                  6   
276            1                                  3            push @{$del_stmt->{scols}}, $col, $col;
               1                                  6   
277                                                         }
278                                                         else {
279            7                                 25            push @clauses, "$quo = ?";
280            7                                 18            push @{$del_stmt->{slice}}, $ord;
               7                                 44   
281            7                                 18            push @{$del_stmt->{scols}}, $col;
               7                                 34   
282                                                         }
283                                                      }
284                                                   
285            4                                 25      $del_stmt->{where} = '(' . join(' AND ', @clauses) . ')';
286                                                   
287            4                                 63      return $del_stmt;
288                                                   }
289                                                   
290                                                   # Design an INSERT statement.  This actually does very little; it just maps
291                                                   # the columns you know you'll get from the SELECT statement onto the columns
292                                                   # in the INSERT statement, returning only those that exist in both sets.
293                                                   # Arguments:
294                                                   #    ins_tbl   hashref returned by TableParser::parse() for the INSERT table
295                                                   #    sel_cols  arrayref of columns to SELECT from the SELECT table
296                                                   # Returns a hashref:
297                                                   #    cols  => arrayref of columns for INSERT
298                                                   #    slice => arrayref of sel_cols indices corresponding to the INSERT cols
299                                                   # The cols array is used to construct the INSERT's INTO clause like:
300                                                   #    INSERT INTO ins_tbl (@cols) VALUES ...
301                                                   # The slice array is used like:
302                                                   #    $row = $sel_sth->fetchrow_arrayref();
303                                                   #    $ins_sth->execute(@{$row}[@slice]);
304                                                   # For example, if we select columns (a, b, c) but the insert table only
305                                                   # has columns (a, c), then the return hashref will be:
306                                                   #    cols  => [a, c]
307                                                   #    slice => [0, 2]
308                                                   # Therefore, the select statement will return an array with 3 elements
309                                                   # (one for each column), but the insert statement will slice this array
310                                                   # to get only the elements/columns it needs.
311                                                   sub generate_ins_stmt {
312            2                    2            35      my ( $self, %args ) = @_;
313            2                                  8      foreach my $arg ( qw(ins_tbl sel_cols) ) {
314   ***      4     50                          20         die "I need a $arg argument" unless $args{$arg};
315                                                      }
316            2                                  7      my $ins_tbl  = $args{ins_tbl};
317            2                                  5      my @sel_cols = @{$args{sel_cols}};
               2                                 13   
318                                                   
319   ***      2     50                           8      die "You didn't specify any SELECT columns" unless @sel_cols;
320                                                   
321            2                                  6      my @ins_cols;
322            2                                  5      my @ins_slice;
323            2                                 10      for my $i ( 0..$#sel_cols ) {
324           10    100                          50         next unless $ins_tbl->{is_col}->{$sel_cols[$i]};
325            3                                  9         push @ins_cols, $sel_cols[$i];
326            3                                 12         push @ins_slice, $i;
327                                                      }
328                                                   
329                                                      return {
330            2                                 27         cols  => \@ins_cols,
331                                                         slice => \@ins_slice,
332                                                      };
333                                                   }
334                                                   
335                                                   sub _d {
336   ***      0                    0                    my ($package, undef, $line) = caller 0;
337   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
338   ***      0                                              map { defined $_ ? $_ : 'undef' }
339                                                           @_;
340   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
341                                                   }
342                                                   
343                                                   1;
344                                                   
345                                                   # ###########################################################################
346                                                   # End TableNibbler package
347                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
61           100     12      3   $args{'cols'} ? :
71           100      1     13   unless $index
77           100      1     12   if ($args{'ascfirst'})
86           100      1     26   if (not exists $col_posn{$col})
108   ***     50     13      0   if (@asc_slice)
121          100      3     10   $args{'asconly'} ? :
140   ***     50      0    280   unless defined $args{$arg}
163          100      8     80   if ($$is_nullable{$col}) { }
182          100     16    100   if ($$is_nullable{$col}) { }
183          100      4     12   if ($type =~ /=/ and $end) { }
             100      6      6   elsif ($type =~ />/) { }
198          100     24     76   $type =~ /=/ && $end ? :
223          100      1      3   $args{'cols'} ? :
234   ***     50      0      4   unless $index
237   ***     50      4      0   if ($index) { }
249   ***     50      8      0   if (not exists $col_posn{$col})
273          100      1      7   if ($$tbl{'is_nullable'}{$col}) { }
314   ***     50      0      4   unless $args{$arg}
319   ***     50      0      2   unless @sel_cols
324          100      7      3   unless $$ins_tbl{'is_col'}{$sel_cols[$i]}
337   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
183          100      8      4      4   $type =~ /=/ and $end
198          100     50     26     24   $type =~ /=/ && $end


Covered Subroutines
-------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:22 
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:23 
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:25 
BEGIN                  1 /home/daniel/dev/maatkit/common/TableNibbler.pm:27 
generate_asc_stmt     15 /home/daniel/dev/maatkit/common/TableNibbler.pm:58 
generate_cmp_where    56 /home/daniel/dev/maatkit/common/TableNibbler.pm:138
generate_del_stmt      4 /home/daniel/dev/maatkit/common/TableNibbler.pm:220
generate_ins_stmt      2 /home/daniel/dev/maatkit/common/TableNibbler.pm:312
new                    1 /home/daniel/dev/maatkit/common/TableNibbler.pm:30 

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
_d                     0 /home/daniel/dev/maatkit/common/TableNibbler.pm:336


