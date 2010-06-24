---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/TableNibbler.pm   95.3   76.1   87.5   90.0    0.0   66.4   89.1
TableNibbler.t                100.0   50.0   33.3  100.0    n/a   33.6   96.2
Total                          96.6   75.0   72.7   95.0    0.0  100.0   90.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:41 2010
Finish:       Thu Jun 24 19:37:41 2010

Run:          TableNibbler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:43 2010
Finish:       Thu Jun 24 19:37:43 2010

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
18                                                    # TableNibbler package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package TableNibbler;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 12   
28                                                    
29                                                    sub new {
30    ***      1                    1      0      8      my ( $class, %args ) = @_;
31             1                                  5      my @required_args = qw(TableParser Quoter);
32             1                                  7      foreach my $arg ( @required_args ) {
33    ***      2     50                          10         die "I need a $arg argument" unless $args{$arg};
34                                                       }
35             1                                  6      my $self = { %args };
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
61    ***     14                   14      0     99      my ( $self, %args ) = @_;
62            14                                 66      my @required_args = qw(tbl_struct index);
63            14                                 52      foreach my $arg ( @required_args ) {
64    ***     28     50                         143         die "I need a $arg argument" unless defined $args{$arg};
65                                                       }
66            14                                 62      my ($tbl_struct, $index) = @args{@required_args};
67            14    100                          68      my @cols = $args{cols}  ? @{$args{cols}} : @{$tbl_struct->{cols}};
              12                                 90   
               2                                 18   
68            14                                 59      my $q    = $self->{Quoter};
69                                                    
70                                                       # This shouldn't happen.  TableSyncNibble shouldn't call us with
71                                                       # a nonexistent index.
72            14    100                          81      die "Index '$index' does not exist in table"
73                                                          unless exists $tbl_struct->{keys}->{$index};
74                                                    
75            13                                 34      my @asc_cols = @{$tbl_struct->{keys}->{$index}->{cols}};
              13                                 80   
76            13                                 38      my @asc_slice;
77                                                    
78                                                       # These are the columns we'll ascend.
79            13                                 35      @asc_cols = @{$tbl_struct->{keys}->{$index}->{cols}};
              13                                 77   
80            13                                 29      MKDEBUG && _d('Will ascend index', $index);
81            13                                 32      MKDEBUG && _d('Will ascend columns', join(', ', @asc_cols));
82            13    100                          56      if ( $args{asc_first} ) {
83             1                                  4         @asc_cols = $asc_cols[0];
84             1                                  9         MKDEBUG && _d('Ascending only first column');
85                                                       }
86                                                    
87                                                       # We found the columns by name, now find their positions for use as
88                                                       # array slices, and make sure they are included in the SELECT list.
89            13                                 34      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
              13                                 40   
              13                                 46   
             109                                441   
90            13                                 63      foreach my $col ( @asc_cols ) {
91            27    100                         109         if ( !exists $col_posn{$col} ) {
92             1                                  3            push @cols, $col;
93             1                                  4            $col_posn{$col} = $#cols;
94                                                          }
95            27                                101         push @asc_slice, $col_posn{$col};
96                                                       }
97            13                                 29      MKDEBUG && _d('Will ascend, in ordinal position:', join(', ', @asc_slice));
98                                                    
99            13                                 95      my $asc_stmt = {
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
114           13                                 34         my $cmp_where;
115           13                                 48         foreach my $cmp ( qw(< <= >= >) ) {
116                                                            # Generate all 4 types, then choose the right one.
117           52                                319            $cmp_where = $self->generate_cmp_where(
118                                                               type        => $cmp,
119                                                               slice       => \@asc_slice,
120                                                               cols        => \@cols,
121                                                               quoter      => $q,
122                                                               is_nullable => $tbl_struct->{is_nullable},
123                                                            );
124           52                                354            $asc_stmt->{boundaries}->{$cmp} = $cmp_where->{where};
125                                                         }
126           13    100                          61         my $cmp = $args{asc_only} ? '>' : '>=';
127           13                                 65         $asc_stmt->{where} = $asc_stmt->{boundaries}->{$cmp};
128           13                                 48         $asc_stmt->{slice} = $cmp_where->{slice};
129           13                                 61         $asc_stmt->{scols} = $cmp_where->{scols};
130                                                      }
131                                                   
132           13                                277      return $asc_stmt;
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
143   ***     56                   56      0    344      my ( $self, %args ) = @_;
144           56                                243      foreach my $arg ( qw(type slice cols is_nullable) ) {
145   ***    224     50                         958         die "I need a $arg arg" unless defined $args{$arg};
146                                                      }
147           56                                147      my @slice       = @{$args{slice}};
              56                                224   
148           56                                155      my @cols        = @{$args{cols}};
              56                                349   
149           56                                203      my $is_nullable = $args{is_nullable};
150           56                                372      my $type        = $args{type};
151           56                                175      my $q           = $self->{Quoter};
152                                                   
153           56                                218      (my $cmp = $type) =~ s/=//;
154                                                   
155           56                                126      my @r_slice;    # Resulting slice columns, by ordinal
156           56                                122      my @r_scols;    # Ditto, by name
157                                                   
158           56                                126      my @clauses;
159           56                                270      foreach my $i ( 0 .. $#slice ) {
160          116                                286         my @clause;
161                                                   
162                                                         # Most of the clauses should be strict equality.
163          116                                456         foreach my $j ( 0 .. $i - 1 ) {
164           88                                260            my $ord = $slice[$j];
165           88                                252            my $col = $cols[$ord];
166           88                                350            my $quo = $q->quote($col);
167           88    100                        2122            if ( $is_nullable->{$col} ) {
168            8                                 37               push @clause, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
169            8                                 26               push @r_slice, $ord, $ord;
170            8                                 45               push @r_scols, $col, $col;
171                                                            }
172                                                            else {
173           80                                260               push @clause, "$quo = ?";
174           80                                225               push @r_slice, $ord;
175           80                                297               push @r_scols, $col;
176                                                            }
177                                                         }
178                                                   
179                                                         # The last clause in each parenthesized group should be > or <, unless
180                                                         # it's the very last of the whole WHERE clause and we are doing "or
181                                                         # equal," when it should be >= or <=.
182          116                                359         my $ord = $slice[$i];
183          116                                336         my $col = $cols[$ord];
184          116                                508         my $quo = $q->quote($col);
185          116                               2835         my $end = $i == $#slice; # Last clause of the whole group.
186          116    100                         451         if ( $is_nullable->{$col} ) {
187           16    100    100                  129            if ( $type =~ m/=/ && $end ) {
                    100                               
188            4                                 18               push @clause, "(? IS NULL OR $quo $type ?)";
189                                                            }
190                                                            elsif ( $type =~ m/>/ ) {
191            6                                 36               push @clause, "((? IS NULL AND $quo IS NOT NULL) OR ($quo $cmp ?))";
192                                                            }
193                                                            else { # If $type =~ m/</ ) {
194            6                                 33               push @clause, "((? IS NOT NULL AND $quo IS NULL) OR ($quo $cmp ?))";
195                                                            }
196           16                                 50            push @r_slice, $ord, $ord;
197           16                                 55            push @r_scols, $col, $col;
198                                                         }
199                                                         else {
200          100                                509            push @r_slice, $ord;
201          100                                283            push @r_scols, $col;
202          100    100    100                  821            push @clause, ($type =~ m/=/ && $end ? "$quo $type ?" : "$quo $cmp ?");
203                                                         }
204                                                   
205                                                         # Add the clause to the larger WHERE clause.
206          116                                619         push @clauses, '(' . join(' AND ', @clause) . ')';
207                                                      }
208           56                                309      my $result = '(' . join(' OR ', @clauses) . ')';
209           56                                307      my $where = {
210                                                         slice => \@r_slice,
211                                                         scols => \@r_scols,
212                                                         where => $result,
213                                                      };
214           56                                356      return $where;
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
227   ***      4                    4      0     27      my ( $self, %args ) = @_;
228                                                   
229            4                                 15      my $tbl  = $args{tbl_struct};
230            4    100                          18      my @cols = $args{cols} ? @{$args{cols}} : ();
               1                                  6   
231            4                                 17      my $tp   = $self->{TableParser};
232            4                                 14      my $q    = $self->{Quoter};
233                                                   
234            4                                 10      my @del_cols;
235            4                                 11      my @del_slice;
236                                                   
237                                                      # ##########################################################################
238                                                      # Detect the best or preferred index to use for the WHERE clause needed to
239                                                      # delete the rows.
240                                                      # ##########################################################################
241            4                                 26      my $index = $tp->find_best_index($tbl, $args{index});
242   ***      4     50                         158      die "Cannot find an ascendable index in table" unless $index;
243                                                   
244                                                      # These are the columns needed for the DELETE statement's WHERE clause.
245   ***      4     50                          16      if ( $index ) {
246            4                                 10         @del_cols = @{$tbl->{keys}->{$index}->{cols}};
               4                                 26   
247                                                      }
248                                                      else {
249   ***      0                                  0         @del_cols = @{$tbl->{cols}};
      ***      0                                  0   
250                                                      }
251            4                                 11      MKDEBUG && _d('Columns needed for DELETE:', join(', ', @del_cols));
252                                                   
253                                                      # We found the columns by name, now find their positions for use as
254                                                      # array slices, and make sure they are included in the SELECT list.
255            4                                 12      my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
               4                                 11   
               4                                 14   
               1                                  7   
256            4                                 17      foreach my $col ( @del_cols ) {
257   ***      8     50                          33         if ( !exists $col_posn{$col} ) {
258            8                                 24            push @cols, $col;
259            8                                 36            $col_posn{$col} = $#cols;
260                                                         }
261            8                                 39         push @del_slice, $col_posn{$col};
262                                                      }
263            4                                 10      MKDEBUG && _d('Ordinals needed for DELETE:', join(', ', @del_slice));
264                                                   
265            4                                 33      my $del_stmt = {
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
276            4                                 10      my @clauses;
277            4                                 21      foreach my $i ( 0 .. $#del_slice ) {
278            8                                 29         my $ord = $del_slice[$i];
279            8                                 24         my $col = $cols[$ord];
280            8                                 41         my $quo = $q->quote($col);
281            8    100                         213         if ( $tbl->{is_nullable}->{$col} ) {
282            1                                  6            push @clauses, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
283            1                                  3            push @{$del_stmt->{slice}}, $ord, $ord;
               1                                  5   
284            1                                  2            push @{$del_stmt->{scols}}, $col, $col;
               1                                  6   
285                                                         }
286                                                         else {
287            7                                 27            push @clauses, "$quo = ?";
288            7                                 17            push @{$del_stmt->{slice}}, $ord;
               7                                 27   
289            7                                 17            push @{$del_stmt->{scols}}, $col;
               7                                 33   
290                                                         }
291                                                      }
292                                                   
293            4                                 23      $del_stmt->{where} = '(' . join(' AND ', @clauses) . ')';
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
320   ***      2                    2      0     13      my ( $self, %args ) = @_;
321            2                                  8      foreach my $arg ( qw(ins_tbl sel_cols) ) {
322   ***      4     50                          22         die "I need a $arg argument" unless $args{$arg};
323                                                      }
324            2                                  6      my $ins_tbl  = $args{ins_tbl};
325            2                                  6      my @sel_cols = @{$args{sel_cols}};
               2                                 12   
326                                                   
327   ***      2     50                           9      die "You didn't specify any SELECT columns" unless @sel_cols;
328                                                   
329            2                                  5      my @ins_cols;
330            2                                  4      my @ins_slice;
331            2                                 11      for my $i ( 0..$#sel_cols ) {
332           10    100                          50         next unless $ins_tbl->{is_col}->{$sel_cols[$i]};
333            3                                 10         push @ins_cols, $sel_cols[$i];
334            3                                 14         push @ins_slice, $i;
335                                                      }
336                                                   
337                                                      return {
338            2                                 24         cols  => \@ins_cols,
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

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                           
------------------ ----- --- ---------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/TableNibbler.pm:22 
BEGIN                  1     /home/daniel/dev/maatkit/common/TableNibbler.pm:23 
BEGIN                  1     /home/daniel/dev/maatkit/common/TableNibbler.pm:25 
BEGIN                  1     /home/daniel/dev/maatkit/common/TableNibbler.pm:27 
generate_asc_stmt     14   0 /home/daniel/dev/maatkit/common/TableNibbler.pm:61 
generate_cmp_where    56   0 /home/daniel/dev/maatkit/common/TableNibbler.pm:143
generate_del_stmt      4   0 /home/daniel/dev/maatkit/common/TableNibbler.pm:227
generate_ins_stmt      2   0 /home/daniel/dev/maatkit/common/TableNibbler.pm:320
new                    1   0 /home/daniel/dev/maatkit/common/TableNibbler.pm:30 

Uncovered Subroutines
---------------------

Subroutine         Count Pod Location                                           
------------------ ----- --- ---------------------------------------------------
_d                     0     /home/daniel/dev/maatkit/common/TableNibbler.pm:344


TableNibbler.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 24;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use TableParser;
               1                                  3   
               1                                 12   
15             1                    1            52   use TableNibbler;
               1                                  3   
               1                                 10   
16             1                    1            10   use Quoter;
               1                                  2   
               1                                 10   
17             1                    1            14   use MaatkitTest;
               1                                  4   
               1                                112   
18                                                    
19             1                                  9   my $q  = new Quoter();
20             1                                 28   my $tp = new TableParser(Quoter => $q);
21             1                                 46   my $n  = new TableNibbler(
22                                                       TableParser => $tp,
23                                                       Quoter      => $q,
24                                                    );
25                                                    
26             1                                  3   my $t;
27                                                    
28             1                                 21   $t = $tp->parse( load_file('common/t/samples/sakila.film.sql') );
29                                                    
30             1                               1522   is_deeply(
31                                                       $n->generate_asc_stmt (
32                                                          tbl_struct => $t,
33                                                          cols       => $t->{cols},
34                                                          index      => 'PRIMARY',
35                                                       ),
36                                                       {
37                                                          cols  => [qw(film_id title description release_year language_id
38                                                                      original_language_id rental_duration rental_rate
39                                                                      length replacement_cost rating special_features
40                                                                      last_update)],
41                                                          index => 'PRIMARY',
42                                                          where => '((`film_id` >= ?))',
43                                                          slice => [0],
44                                                          scols => [qw(film_id)],
45                                                          boundaries => {
46                                                             '>=' => '((`film_id` >= ?))',
47                                                             '>'  => '((`film_id` > ?))',
48                                                             '<=' => '((`film_id` <= ?))',
49                                                             '<'  => '((`film_id` < ?))',
50                                                          },
51                                                       },
52                                                       'asc stmt on sakila.film',
53                                                    );
54                                                    
55             1                                 24   is_deeply(
56                                                       $n->generate_del_stmt (
57                                                          tbl_struct => $t,
58                                                       ),
59                                                       {
60                                                          cols  => [qw(film_id)],
61                                                          index => 'PRIMARY',
62                                                          where => '(`film_id` = ?)',
63                                                          slice => [0],
64                                                          scols => [qw(film_id)],
65                                                       },
66                                                       'del stmt on sakila.film',
67                                                    );
68                                                    
69             1                                 17   is_deeply(
70                                                       $n->generate_asc_stmt (
71                                                          tbl_struct => $t,
72                                                          index      => 'PRIMARY',
73                                                       ),
74                                                       {
75                                                          cols  => [qw(film_id title description release_year language_id
76                                                                      original_language_id rental_duration rental_rate
77                                                                      length replacement_cost rating special_features
78                                                                      last_update)],
79                                                          index => 'PRIMARY',
80                                                          where => '((`film_id` >= ?))',
81                                                          slice => [0],
82                                                          scols => [qw(film_id)],
83                                                          boundaries => {
84                                                             '>=' => '((`film_id` >= ?))',
85                                                             '>'  => '((`film_id` > ?))',
86                                                             '<=' => '((`film_id` <= ?))',
87                                                             '<'  => '((`film_id` < ?))',
88                                                          },
89                                                       },
90                                                       'defaults to all columns',
91                                                    );
92                                                    
93                                                    throws_ok(
94                                                       sub {
95             1                    1            19         $n->generate_asc_stmt (
96                                                             tbl_struct => $t,
97                                                             cols   => $t->{cols},
98                                                             index  => 'title',
99                                                          )
100                                                      },
101            1                                 37      qr/Index 'title' does not exist in table/,
102                                                      'Error on nonexistent index',
103                                                   );
104                                                   
105            1                                 20   is_deeply(
106                                                      $n->generate_asc_stmt (
107                                                         tbl_struct => $t,
108                                                         cols   => $t->{cols},
109                                                         index  => 'idx_title',
110                                                      ),
111                                                      {
112                                                         cols  => [qw(film_id title description release_year language_id
113                                                                     original_language_id rental_duration rental_rate
114                                                                     length replacement_cost rating special_features
115                                                                     last_update)],
116                                                         index => 'idx_title',
117                                                         where => '((`title` >= ?))',
118                                                         slice => [1],
119                                                         scols => [qw(title)],
120                                                         boundaries => {
121                                                            '>=' => '((`title` >= ?))',
122                                                            '>'  => '((`title` > ?))',
123                                                            '<=' => '((`title` <= ?))',
124                                                            '<'  => '((`title` < ?))',
125                                                         },
126                                                      },
127                                                      'asc stmt on sakila.film with different index',
128                                                   );
129                                                   
130            1                                 28   is_deeply(
131                                                      $n->generate_del_stmt (
132                                                         tbl_struct => $t,
133                                                         index  => 'idx_title',
134                                                         cols   => [qw(film_id)],
135                                                      ),
136                                                      {
137                                                         cols  => [qw(film_id title)],
138                                                         index => 'idx_title',
139                                                         where => '(`title` = ?)',
140                                                         slice => [1],
141                                                         scols => [qw(title)],
142                                                      },
143                                                      'del stmt on sakila.film with different index and extra column',
144                                                   );
145                                                   
146                                                   # TableParser::find_best_index() is case-insensitive, returning the
147                                                   # correct case even if the wrong case is given.  But generate_asc_stmt()
148                                                   # no longer calls find_best_index() so this test is a moot point.
149            1                                 18   is_deeply(
150                                                      $n->generate_asc_stmt (
151                                                         tbl_struct => $t,
152                                                         cols   => $t->{cols},
153                                                         index  => 'idx_title',
154                                                      ),
155                                                      {
156                                                         cols  => [qw(film_id title description release_year language_id
157                                                                     original_language_id rental_duration rental_rate
158                                                                     length replacement_cost rating special_features
159                                                                     last_update)],
160                                                         index => 'idx_title',
161                                                         where => '((`title` >= ?))',
162                                                         slice => [1],
163                                                         scols => [qw(title)],
164                                                         boundaries => {
165                                                            '>=' => '((`title` >= ?))',
166                                                            '>'  => '((`title` > ?))',
167                                                            '<=' => '((`title` <= ?))',
168                                                            '<'  => '((`title` < ?))',
169                                                         },
170                                                      },
171                                                      'Index returned in correct lettercase',
172                                                   );
173                                                   
174            1                                 20   is_deeply(
175                                                      $n->generate_asc_stmt (
176                                                         tbl_struct => $t,
177                                                         cols   => [qw(title)],
178                                                         index  => 'PRIMARY',
179                                                      ),
180                                                      {
181                                                         cols  => [qw(title film_id)],
182                                                         index => 'PRIMARY',
183                                                         where => '((`film_id` >= ?))',
184                                                         slice => [1],
185                                                         scols => [qw(film_id)],
186                                                         boundaries => {
187                                                            '>=' => '((`film_id` >= ?))',
188                                                            '>'  => '((`film_id` > ?))',
189                                                            '<=' => '((`film_id` <= ?))',
190                                                            '<'  => '((`film_id` < ?))',
191                                                         },
192                                                      },
193                                                      'Required columns added to SELECT list',
194                                                   );
195                                                   
196                                                   # ##########################################################################
197                                                   # Switch to the rental table
198                                                   # ##########################################################################
199            1                                 17   $t = $tp->parse( load_file('common/t/samples/sakila.rental.sql') );
200                                                   
201            1                               1384   is_deeply(
202                                                      $n->generate_asc_stmt(
203                                                         tbl_struct => $t,
204                                                         cols   => $t->{cols},
205                                                         index  => 'rental_date',
206                                                      ),
207                                                      {
208                                                         cols  => [qw(rental_id rental_date inventory_id customer_id
209                                                                     return_date staff_id last_update)],
210                                                         index => 'rental_date',
211                                                         where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
212                                                            . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` >= ?))',
213                                                         slice => [1, 1, 2, 1, 2, 3],
214                                                         scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
215                                                         boundaries => {
216                                                            '>=' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
217                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
218                                                               . '= ? AND `customer_id` >= ?))',
219                                                            '>' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
220                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
221                                                               . '= ? AND `customer_id` > ?))',
222                                                            '<=' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
223                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
224                                                               . '= ? AND `customer_id` <= ?))',
225                                                            '<' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
226                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
227                                                               . '= ? AND `customer_id` < ?))',
228                                                         },
229                                                      },
230                                                      'Alternate index on sakila.rental',
231                                                   );
232                                                   
233            1                                 21   is_deeply(
234                                                      $n->generate_del_stmt (
235                                                         tbl_struct => $t,
236                                                         index  => 'rental_date',
237                                                      ),
238                                                      {
239                                                         cols  => [qw(rental_date inventory_id customer_id)],
240                                                         index => 'rental_date',
241                                                         where => '(`rental_date` = ? AND `inventory_id` = ? AND `customer_id` = ?)',
242                                                         slice => [0, 1, 2],
243                                                         scols => [qw(rental_date inventory_id customer_id)],
244                                                      },
245                                                      'Alternate index on sakila.rental delete statement',
246                                                   );
247                                                   
248                                                   # Check that I can select from one table and insert into another OK
249            1                                 15   my $f = $tp->parse( load_file('common/t/samples/sakila.film.sql') );
250            1                               1440   is_deeply(
251                                                      $n->generate_ins_stmt(
252                                                         ins_tbl  => $f,
253                                                         sel_cols => $t->{cols},
254                                                      ),
255                                                      {
256                                                         cols  => [qw(last_update)],
257                                                         slice => [6],
258                                                      },
259                                                      'Generated an INSERT statement from film into rental',
260                                                   );
261                                                   
262            1                                 13   my $sel_tbl = $tp->parse( load_file('common/t/samples/issue_131_sel.sql') );
263            1                                528   my $ins_tbl = $tp->parse( load_file('common/t/samples/issue_131_ins.sql') );  
264            1                                474   is_deeply(
265                                                      $n->generate_ins_stmt(
266                                                         ins_tbl  => $ins_tbl,
267                                                         sel_cols => $sel_tbl->{cols},
268                                                      ),
269                                                      {
270                                                         cols  => [qw(id name)],
271                                                         slice => [0, 2],
272                                                      },
273                                                      'INSERT stmt with different col order and a missing ins col'
274                                                   );
275                                                   
276            1                                 15   is_deeply(
277                                                      $n->generate_asc_stmt(
278                                                         tbl_struct => $t,
279                                                         cols   => $t->{cols},
280                                                         index  => 'rental_date',
281                                                         asc_first => 1,
282                                                      ),
283                                                      {
284                                                         cols  => [qw(rental_id rental_date inventory_id customer_id
285                                                                     return_date staff_id last_update)],
286                                                         index => 'rental_date',
287                                                         where => '((`rental_date` >= ?))',
288                                                         slice => [1],
289                                                         scols => [qw(rental_date)],
290                                                         boundaries => {
291                                                            '>=' => '((`rental_date` >= ?))',
292                                                            '>'  => '((`rental_date` > ?))',
293                                                            '<=' => '((`rental_date` <= ?))',
294                                                            '<'  => '((`rental_date` < ?))',
295                                                         },
296                                                      },
297                                                      'Alternate index with asc_first on sakila.rental',
298                                                   );
299                                                   
300            1                                 22   is_deeply(
301                                                      $n->generate_asc_stmt(
302                                                         tbl_struct => $t,
303                                                         cols   => $t->{cols},
304                                                         index  => 'rental_date',
305                                                         asc_only => 1,
306                                                      ),
307                                                      {
308                                                         cols  => [qw(rental_id rental_date inventory_id customer_id
309                                                                     return_date staff_id last_update)],
310                                                         index => 'rental_date',
311                                                         where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
312                                                            . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` > ?))',
313                                                         slice => [1, 1, 2, 1, 2, 3],
314                                                         scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
315                                                         boundaries => {
316                                                            '>=' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
317                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
318                                                               . '= ? AND `customer_id` >= ?))',
319                                                            '>' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
320                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
321                                                               . '= ? AND `customer_id` > ?))',
322                                                            '<=' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
323                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
324                                                               . '= ? AND `customer_id` <= ?))',
325                                                            '<' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
326                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
327                                                               . '= ? AND `customer_id` < ?))',
328                                                         },
329                                                      },
330                                                      'Alternate index on sakila.rental with strict ascending',
331                                                   );
332                                                   
333                                                   # ##########################################################################
334                                                   # Switch to the rental table with customer_id nullable
335                                                   # ##########################################################################
336            1                                 20   $t = $tp->parse( load_file('common/t/samples/sakila.rental.null.sql') );
337                                                   
338            1                               1400   is_deeply(
339                                                      $n->generate_asc_stmt(
340                                                         tbl_struct => $t,
341                                                         cols   => $t->{cols},
342                                                         index  => 'rental_date',
343                                                      ),
344                                                      {
345                                                         cols  => [qw(rental_id rental_date inventory_id customer_id
346                                                                     return_date staff_id last_update)],
347                                                         index => 'rental_date',
348                                                         where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
349                                                            . ' OR (`rental_date` = ? AND `inventory_id` = ? AND '
350                                                            . '(? IS NULL OR `customer_id` >= ?)))',
351                                                         slice => [1, 1, 2, 1, 2, 3, 3],
352                                                         scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id customer_id)],
353                                                         boundaries => {
354                                                            '>=' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
355                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
356                                                               . '= ? AND (? IS NULL OR `customer_id` >= ?)))',
357                                                            '>' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
358                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
359                                                               . '= ? AND ((? IS NULL AND `customer_id` IS NOT NULL) '
360                                                               . 'OR (`customer_id` > ?))))',
361                                                            '<=' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
362                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
363                                                               . '= ? AND (? IS NULL OR `customer_id` <= ?)))',
364                                                            '<' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
365                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
366                                                               . '= ? AND ((? IS NOT NULL AND `customer_id` IS NULL) '
367                                                               . 'OR (`customer_id` < ?))))',
368                                                         },
369                                                      },
370                                                      'Alternate index on sakila.rental with nullable customer_id',
371                                                   );
372                                                   
373            1                                 21   is_deeply(
374                                                      $n->generate_del_stmt (
375                                                         tbl_struct => $t,
376                                                         index  => 'rental_date',
377                                                      ),
378                                                      {
379                                                         cols  => [qw(rental_date inventory_id customer_id)],
380                                                         index => 'rental_date',
381                                                         where => '(`rental_date` = ? AND `inventory_id` = ? AND '
382                                                                  . '((? IS NULL AND `customer_id` IS NULL) OR (`customer_id` = ?)))',
383                                                         slice => [0, 1, 2, 2],
384                                                         scols => [qw(rental_date inventory_id customer_id customer_id)],
385                                                      },
386                                                      'Alternate index on sakila.rental delete statement with nullable customer_id',
387                                                   );
388                                                   
389            1                                 18   is_deeply(
390                                                      $n->generate_asc_stmt(
391                                                         tbl_struct => $t,
392                                                         cols   => $t->{cols},
393                                                         index  => 'rental_date',
394                                                         asc_only => 1,
395                                                      ),
396                                                      {
397                                                         cols  => [qw(rental_id rental_date inventory_id customer_id
398                                                                     return_date staff_id last_update)],
399                                                         index => 'rental_date',
400                                                         where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
401                                                            . ' OR (`rental_date` = ? AND `inventory_id` = ? AND '
402                                                            . '((? IS NULL AND `customer_id` IS NOT NULL) OR (`customer_id` > ?))))',
403                                                         slice => [1, 1, 2, 1, 2, 3, 3],
404                                                         scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id customer_id)],
405                                                         boundaries => {
406                                                            '>=' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
407                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
408                                                               . '= ? AND (? IS NULL OR `customer_id` >= ?)))',
409                                                            '>' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
410                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
411                                                               . '= ? AND ((? IS NULL AND `customer_id` IS NOT NULL) '
412                                                               . 'OR (`customer_id` > ?))))',
413                                                            '<=' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
414                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
415                                                               . '= ? AND (? IS NULL OR `customer_id` <= ?)))',
416                                                            '<' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
417                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
418                                                               . '= ? AND ((? IS NOT NULL AND `customer_id` IS NULL) '
419                                                               . 'OR (`customer_id` < ?))))',
420                                                         },
421                                                      },
422                                                      'Alternate index on sakila.rental with nullable customer_id and strict ascending',
423                                                   );
424                                                   
425                                                   # ##########################################################################
426                                                   # Switch to the rental table with inventory_id nullable
427                                                   # ##########################################################################
428            1                                 28   $t = $tp->parse( load_file('common/t/samples/sakila.rental.null2.sql') );
429                                                   
430            1                               1346   is_deeply(
431                                                      $n->generate_asc_stmt(
432                                                         tbl_struct => $t,
433                                                         cols   => $t->{cols},
434                                                         index  => 'rental_date',
435                                                      ),
436                                                      {
437                                                         cols  => [qw(rental_id rental_date inventory_id customer_id
438                                                                     return_date staff_id last_update)],
439                                                         index => 'rental_date',
440                                                         where => '((`rental_date` > ?) OR '
441                                                            . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NOT NULL) OR (`inventory_id` > ?)))'
442                                                            . ' OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
443                                                            . 'OR (`inventory_id` = ?)) AND `customer_id` >= ?))',
444                                                         slice => [1, 1, 2, 2, 1, 2, 2, 3],
445                                                         scols => [qw(rental_date rental_date inventory_id inventory_id
446                                                                      rental_date inventory_id inventory_id customer_id)],
447                                                         boundaries => {
448                                                            '>=' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
449                                                               . '((? IS NULL AND `inventory_id` IS NOT NULL) OR (`inventory_id` '
450                                                               . '> ?))) OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` '
451                                                               . 'IS NULL) OR (`inventory_id` = ?)) AND `customer_id` >= ?))',
452                                                            '>' => '((`rental_date` > ?) OR (`rental_date` = ? AND ((? IS NULL '
453                                                               . 'AND `inventory_id` IS NOT NULL) OR (`inventory_id` > ?))) OR '
454                                                               . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
455                                                               . 'OR (`inventory_id` = ?)) AND `customer_id` > ?))',
456                                                            '<=' => '((`rental_date` < ?) OR (`rental_date` = ? AND ((? IS NOT '
457                                                               . 'NULL AND `inventory_id` IS NULL) OR (`inventory_id` < ?))) OR '
458                                                               . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
459                                                               . 'OR (`inventory_id` = ?)) AND `customer_id` <= ?))',
460                                                            '<' => '((`rental_date` < ?) OR (`rental_date` = ? AND ((? IS NOT '
461                                                               . 'NULL AND `inventory_id` IS NULL) OR (`inventory_id` < ?))) '
462                                                               . 'OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS '
463                                                               . 'NULL) OR (`inventory_id` = ?)) AND `customer_id` < ?))',
464                                                         },
465                                                      },
466                                                      'Alternate index on sakila.rental with nullable inventory_id',
467                                                   );
468                                                   
469            1                                 26   is_deeply(
470                                                      $n->generate_asc_stmt(
471                                                         tbl_struct => $t,
472                                                         cols   => $t->{cols},
473                                                         index  => 'rental_date',
474                                                         asc_only => 1,
475                                                      ),
476                                                      {
477                                                         cols  => [qw(rental_id rental_date inventory_id customer_id
478                                                                     return_date staff_id last_update)],
479                                                         index => 'rental_date',
480                                                         where => '((`rental_date` > ?) OR '
481                                                            . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NOT NULL) OR (`inventory_id` > ?)))'
482                                                            . ' OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
483                                                            . 'OR (`inventory_id` = ?)) AND `customer_id` > ?))',
484                                                         slice => [1, 1, 2, 2, 1, 2, 2, 3],
485                                                         scols => [qw(rental_date rental_date inventory_id inventory_id
486                                                                      rental_date inventory_id inventory_id customer_id)],
487                                                         boundaries => {
488                                                            '>=' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
489                                                               . '((? IS NULL AND `inventory_id` IS NOT NULL) OR (`inventory_id` '
490                                                               . '> ?))) OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` '
491                                                               . 'IS NULL) OR (`inventory_id` = ?)) AND `customer_id` >= ?))',
492                                                            '>' => '((`rental_date` > ?) OR (`rental_date` = ? AND ((? IS NULL '
493                                                               . 'AND `inventory_id` IS NOT NULL) OR (`inventory_id` > ?))) OR '
494                                                               . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
495                                                               . 'OR (`inventory_id` = ?)) AND `customer_id` > ?))',
496                                                            '<=' => '((`rental_date` < ?) OR (`rental_date` = ? AND ((? IS NOT '
497                                                               . 'NULL AND `inventory_id` IS NULL) OR (`inventory_id` < ?))) OR '
498                                                               . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
499                                                               . 'OR (`inventory_id` = ?)) AND `customer_id` <= ?))',
500                                                            '<' => '((`rental_date` < ?) OR (`rental_date` = ? AND ((? IS NOT '
501                                                               . 'NULL AND `inventory_id` IS NULL) OR (`inventory_id` < ?))) '
502                                                               . 'OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS '
503                                                               . 'NULL) OR (`inventory_id` = ?)) AND `customer_id` < ?))',
504                                                         },
505                                                      },
506                                                      'Alternate index on sakila.rental with nullable inventory_id and strict ascending',
507                                                   );
508                                                   
509                                                   # ##########################################################################
510                                                   # Switch to the rental table with cols in a different order.
511                                                   # ##########################################################################
512            1                                 21   $t = $tp->parse( load_file('common/t/samples/sakila.rental.remix.sql') );
513                                                   
514            1                               1386   is_deeply(
515                                                      $n->generate_asc_stmt(
516                                                         tbl_struct => $t,
517                                                         index  => 'rental_date',
518                                                      ),
519                                                      {
520                                                         cols  => [qw(rental_id rental_date customer_id inventory_id
521                                                                     return_date staff_id last_update)],
522                                                         index => 'rental_date',
523                                                         where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
524                                                            . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` >= ?))',
525                                                         slice => [1, 1, 3, 1, 3, 2],
526                                                         scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
527                                                         boundaries => {
528                                                            '>=' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
529                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
530                                                               . '= ? AND `customer_id` >= ?))',
531                                                            '>' => '((`rental_date` > ?) OR (`rental_date` = ? AND '
532                                                               . '`inventory_id` > ?) OR (`rental_date` = ? AND `inventory_id` '
533                                                               . '= ? AND `customer_id` > ?))',
534                                                            '<=' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
535                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
536                                                               . '= ? AND `customer_id` <= ?))',
537                                                            '<' => '((`rental_date` < ?) OR (`rental_date` = ? AND '
538                                                               . '`inventory_id` < ?) OR (`rental_date` = ? AND `inventory_id` '
539                                                               . '= ? AND `customer_id` < ?))',
540                                                         },
541                                                      },
542                                                      'Out-of-order index on sakila.rental',
543                                                   );
544                                                   
545                                                   # ##########################################################################
546                                                   # Switch to table without any indexes
547                                                   # ##########################################################################
548            1                                 21   $t = $tp->parse( load_file('common/t/samples/t1.sql') );
549                                                   
550                                                   # This test is no longer needed because TableSyncNibble shouldn't
551                                                   # ask TableNibbler to asc an indexless table.
552                                                   # throws_ok(
553                                                   #    sub {
554                                                   #       $n->generate_asc_stmt (
555                                                   #          tbl_struct => $t,
556                                                   #       )
557                                                   #    },
558                                                   #    qr/Cannot find an ascendable index in table/,
559                                                   #    'Error when no good index',
560                                                   # );
561                                                   
562            1                                473   is_deeply(
563                                                      $n->generate_cmp_where(
564                                                         cols   => [qw(a b c d)],
565                                                         slice  => [0, 3],
566                                                         is_nullable => {},
567                                                         type   => '>=',
568                                                      ),
569                                                      {
570                                                         scols => [qw(a a d)],
571                                                         slice => [0, 0, 3],
572                                                         where => '((`a` > ?) OR (`a` = ? AND `d` >= ?))',
573                                                      },
574                                                      'WHERE for >=',
575                                                   );
576                                                   
577            1                                 21   is_deeply(
578                                                      $n->generate_cmp_where(
579                                                         cols   => [qw(a b c d)],
580                                                         slice  => [0, 3],
581                                                         is_nullable => {},
582                                                         type   => '>',
583                                                      ),
584                                                      {
585                                                         scols => [qw(a a d)],
586                                                         slice => [0, 0, 3],
587                                                         where => '((`a` > ?) OR (`a` = ? AND `d` > ?))',
588                                                      },
589                                                      'WHERE for >',
590                                                   );
591                                                   
592            1                                 18   is_deeply(
593                                                      $n->generate_cmp_where(
594                                                         cols   => [qw(a b c d)],
595                                                         slice  => [0, 3],
596                                                         is_nullable => {},
597                                                         type   => '<=',
598                                                      ),
599                                                      {
600                                                         scols => [qw(a a d)],
601                                                         slice => [0, 0, 3],
602                                                         where => '((`a` < ?) OR (`a` = ? AND `d` <= ?))',
603                                                      },
604                                                      'WHERE for <=',
605                                                   );
606                                                   
607            1                                 19   is_deeply(
608                                                      $n->generate_cmp_where(
609                                                         cols   => [qw(a b c d)],
610                                                         slice  => [0, 3],
611                                                         is_nullable => {},
612                                                         type   => '<',
613                                                      ),
614                                                      {
615                                                         scols => [qw(a a d)],
616                                                         slice => [0, 0, 3],
617                                                         where => '((`a` < ?) OR (`a` = ? AND `d` < ?))',
618                                                      },
619                                                      'WHERE for <',
620                                                   );
621                                                   
622                                                   
623                                                   # #############################################################################
624                                                   # Done.
625                                                   # #############################################################################
626            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location         
---------- ----- -----------------
BEGIN          1 TableNibbler.t:10
BEGIN          1 TableNibbler.t:11
BEGIN          1 TableNibbler.t:12
BEGIN          1 TableNibbler.t:14
BEGIN          1 TableNibbler.t:15
BEGIN          1 TableNibbler.t:16
BEGIN          1 TableNibbler.t:17
BEGIN          1 TableNibbler.t:4 
BEGIN          1 TableNibbler.t:9 
__ANON__       1 TableNibbler.t:95


