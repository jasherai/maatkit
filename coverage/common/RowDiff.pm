---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/RowDiff.pm   91.4   87.0   80.4   88.9    n/a  100.0   87.7
Total                          91.4   87.0   80.4   88.9    n/a  100.0   87.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          RowDiff.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:43 2009
Finish:       Sat Aug 29 15:03:43 2009

/home/daniel/dev/maatkit/common/RowDiff.pm

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
18                                                    # RowDiff package $Revision: 4561 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  2   
               1                                  8   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
22                                                    
23                                                    package RowDiff;
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
28                                                    
29                                                    # Optional args:
30                                                    #   * same_row      Callback when rows are identical
31                                                    #   * not_in_left   Callback when right row is not in the left
32                                                    #   * not_in_right  Callback when left row is not in the right
33                                                    #   * key_cmp       Callback when a column value differs
34                                                    #   * done          Callback that stops compare_sets() if it returns true
35                                                    #   * trf           Callback to transform numeric values before comparison
36                                                    sub new {
37             7                    7           119      my ( $class, %args ) = @_;
38             7    100                          35      die "I need a dbh" unless $args{dbh};
39             6                                 22      my $self = \%args;
40             6                                 45      return bless $self, $class;
41                                                    }
42                                                    
43                                                    # Iterates through two sets of rows and finds differences.  Calls various
44                                                    # methods on the $syncer object when it finds differences.  $left and $right
45                                                    # should be DBI $sth, or should at least behave like them.  $tbl
46                                                    # is a struct from TableParser.
47                                                    sub compare_sets {
48            14                   14         66420      my ( $self, %args ) = @_;
49            14                                 89      my ( $left, $right, $syncer, $tbl )
50                                                          = @args{qw(left right syncer tbl)};
51                                                    
52            14                                 41      my ($lr, $rr);  # Current row from the left/right sources.
53            14                                 51      my $done = $self->{done};
54                                                    
55                                                       # We have to manually track if the left or right sth is done
56                                                       # fetching rows because sth->{Active} is always true with
57                                                       # DBD::mysql v3. And we cannot simply while ( $lr || $rr )
58                                                       # because in the case where left and right have the same key,
59                                                       # we do this:
60                                                       #    $lr = $rr = undef; # Fetch another row from each side.
61                                                       # Unsetting both $lr and $rr there would cause while () to
62                                                       # terminate. (And while ( $lr && $rr ) is not what we want
63                                                       # either.) Furthermore, we need to avoid trying to fetch more
64                                                       # rows if there are none to fetch because doing this would
65                                                       # cause a DBI error ("fetch without execute"). That's why we
66                                                       # make these checks:
67                                                       #    if ( !$lr && !$left_done )
68                                                       #    if ( !$rr && !$right_done )
69                                                       # If you make changes here, be sure to test both RowDiff.t
70                                                       # and RowDiff-custom.t. Look inside the later to see what
71                                                       # is custom about it.
72            14                                 47      my ($left_done, $right_done) = (0, 0);
73                                                    
74            14           100                   41      do {
75    ***     34    100     66                  289         if ( !$lr && !$left_done ) {
76            30                                 75            MKDEBUG && _d('Fetching row from left');
77            30                                 78            eval { $lr = $left->fetchrow_hashref(); };
              30                                160   
78            30                                132            MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
79    ***     30    100     66                  211            $left_done = !$lr || $EVAL_ERROR ? 1 : 0;
80                                                          }
81                                                          elsif ( MKDEBUG ) {
82                                                             _d('Left still has rows');
83                                                          }
84                                                    
85            34    100    100                  243         if ( !$rr && !$right_done ) {
86            29                                 64            MKDEBUG && _d('Fetching row from right');
87            29                                 76            eval { $rr = $right->fetchrow_hashref(); };
              29                                123   
88            29                                110            MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
89    ***     29    100     66                  197            $right_done = !$rr || $EVAL_ERROR ? 1 : 0;
90                                                          }
91                                                          elsif ( MKDEBUG ) {
92                                                             _d('Right still has rows');
93                                                          }
94                                                    
95            34                                 76         my $cmp;
96            34    100    100                  213         if ( $lr && $rr ) {
97            15                                 76            $cmp = $self->key_cmp($lr, $rr, $syncer->key_cols(), $tbl);
98            15                                 40            MKDEBUG && _d('Key comparison on left and right:', $cmp);
99                                                          }
100           34    100    100                  217         if ( $lr || $rr ) {
101                                                            # If the current row is the "same row" on both sides, meaning the two
102                                                            # rows have the same key, check the contents of the row to see if
103                                                            # they're the same.
104           21    100    100                  348            if ( $lr && $rr && defined $cmp && $cmp == 0 ) {
      ***           100     66                        
                           100                        
      ***                   66                        
                           100                        
105           12                                 27               MKDEBUG && _d('Left and right have the same key');
106           12                                 69               $syncer->same_row($lr, $rr);
107           12    100                         192               $self->{same_row}->($lr, $rr) if $self->{same_row};
108           12                                 61               $lr = $rr = undef; # Fetch another row from each side.
109                                                            }
110                                                            # The row in the left doesn't exist in the right.
111                                                            elsif ( !$rr || ( defined $cmp && $cmp < 0 ) ) {
112            5                                 13               MKDEBUG && _d('Left is not in right');
113            5                                 28               $syncer->not_in_right($lr);
114            5    100                          87               $self->{not_in_right}->($lr) if $self->{not_in_right};
115            5                                 22               $lr = undef;
116                                                            }
117                                                            # Symmetric to the above.
118                                                            else {
119            4                                  8               MKDEBUG && _d('Right is not in left');
120            4                                 22               $syncer->not_in_left($rr);
121            4    100                          63               $self->{not_in_left}->($rr) if $self->{not_in_left};
122            4                                 16               $rr = undef;
123                                                            }
124                                                         }
125           34    100    100                  307         $left_done = $right_done = 1 if $done && $done->($left, $right);
126                                                      } while ( !($left_done && $right_done) );
127           14                                 47      MKDEBUG && _d('No more rows');
128           14                                 70      $syncer->done_with_rows();
129                                                   }
130                                                   
131                                                   # Compare two rows to determine how they should be ordered.  NULL sorts before
132                                                   # defined values in MySQL, so I consider undef "less than." Numbers are easy to
133                                                   # compare.  Otherwise string comparison is tricky.  This function must match
134                                                   # MySQL exactly or the merge algorithm runs off the rails, so when in doubt I
135                                                   # ask MySQL to compare strings for me.  I can handle numbers and "normal" latin1
136                                                   # characters without asking MySQL.  See
137                                                   # http://dev.mysql.com/doc/refman/5.0/en/charset-literal.html.  $r1 and $r2 are
138                                                   # row hashrefs.  $key_cols is an arrayref of the key columns to compare.  $tbl is the
139                                                   # structure returned by TableParser.  The result matches Perl's cmp or <=>
140                                                   # operators:
141                                                   # 1 cmp 0 =>  1
142                                                   # 1 cmp 1 =>  0
143                                                   # 1 cmp 2 => -1
144                                                   # TODO: must generate the comparator function dynamically for speed, so we don't
145                                                   # have to check the type of columns constantly
146                                                   sub key_cmp {
147           26                   26           221      my ( $self, $lr, $rr, $key_cols, $tbl ) = @_;
148           26                                 64      MKDEBUG && _d('Comparing keys using columns:', join(',', @$key_cols));
149           26                                 82      my $callback = $self->{key_cmp};
150           26                                 89      my $trf      = $self->{trf};
151           26                                 95      foreach my $col ( @$key_cols ) {
152           30                                112         my $l = $lr->{$col};
153           30                                 88         my $r = $rr->{$col};
154           30    100    100                  229         if ( !defined $l || !defined $r ) {
155            6                                 15            MKDEBUG && _d($col, 'is not defined in both rows');
156            6    100                          46            return defined $l ? 1 : defined $r ? -1 : 0;
                    100                               
157                                                         }
158                                                         else {
159           24    100                         163            if ($tbl->{is_numeric}->{$col} ) {   # Numeric column
                    100                               
160            4                                 13               MKDEBUG && _d($col, 'is numeric');
161            4    100                          26               ($l, $r) = $trf->($l, $r, $tbl, $col) if $trf;
162            4                                 34               my $cmp = $l <=> $r;
163   ***      4     50                          24               if ( $cmp ) {
164   ***      0                                  0                  MKDEBUG && _d('Column', $col, 'differs:', $l, '!=', $r);
165   ***      0      0                           0                  $callback->($col, $l, $r) if $callback;
166   ***      0                                  0                  return $cmp;
167                                                               }
168                                                            }
169                                                            # Do case-sensitive cmp, expecting most will be eq.  If that fails, try
170                                                            # a case-insensitive cmp if possible; otherwise ask MySQL how to sort.
171                                                            elsif ( $l ne $r ) {
172            8                                 20               my $cmp;
173            8                                 35               my $coll = $tbl->{collation_for}->{$col};
174   ***      8    100     33                   62               if ( $coll && ( $coll ne 'latin1_swedish_ci'
      ***                   33                        
      ***                   66                        
175                                                                              || $l =~ m/[^\040-\177]/ || $r =~ m/[^\040-\177]/) ) {
176            1                                  2                  MKDEBUG && _d('Comparing', $col, 'via MySQL');
177            1                                  6                  $cmp = $self->db_cmp($coll, $l, $r);
178                                                               }
179                                                               else {
180            7                                 16                  MKDEBUG && _d('Comparing', $col, 'in lowercase');
181            7                                 34                  $cmp = lc $l cmp lc $r;
182                                                               }
183            8    100                          38               if ( $cmp ) {
184            7                                 15                  MKDEBUG && _d('Column', $col, 'differs:', $l, 'ne', $r);
185            7    100                          29                  $callback->($col, $l, $r) if $callback;
186            7                                 62                  return $cmp;
187                                                               }
188                                                            }
189                                                         }
190                                                      }
191           13                                 55      return 0;
192                                                   }
193                                                   
194                                                   sub db_cmp {
195            1                    1            10      my ( $self, $collation, $l, $r ) = @_;
196   ***      1     50                           8      if ( !$self->{sth}->{$collation} ) {
197   ***      1     50                           5         if ( !$self->{charset_for} ) {
198            1                                  7            MKDEBUG && _d('Fetching collations from MySQL');
199            1                                  2            my @collations = @{$self->{dbh}->selectall_arrayref(
               1                                 26   
200                                                               'SHOW COLLATION', {Slice => { collation => 1, charset => 1 }})};
201            1                                 50            foreach my $collation ( @collations ) {
202          126                                696               $self->{charset_for}->{$collation->{collation}}
203                                                                  = $collation->{charset};
204                                                            }
205                                                         }
206            1                                 13         my $sql = "SELECT STRCMP(_$self->{charset_for}->{$collation}? COLLATE $collation, "
207                                                            . "_$self->{charset_for}->{$collation}? COLLATE $collation) AS res";
208            1                                  3         MKDEBUG && _d($sql);
209            1                                  2         $self->{sth}->{$collation} = $self->{dbh}->prepare($sql);
210                                                      }
211            1                                 10      my $sth = $self->{sth}->{$collation};
212            1                                295      $sth->execute($l, $r);
213            1                                 28      return $sth->fetchall_arrayref()->[0]->[0];
214                                                   }
215                                                   
216                                                   sub _d {
217   ***      0                    0                    my ($package, undef, $line) = caller 0;
218   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
219   ***      0                                              map { defined $_ ? $_ : 'undef' }
220                                                           @_;
221   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
222                                                   }
223                                                   
224                                                   1;
225                                                   
226                                                   # ###########################################################################
227                                                   # End RowDiff package
228                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
38           100      1      6   unless $args{'dbh'}
75           100     30      4   !$lr && !$left_done ? :
79           100     13     17   !$lr || $EVAL_ERROR ? :
85           100     29      5   !$rr && !$right_done ? :
89           100     13     16   !$rr || $EVAL_ERROR ? :
96           100     15     19   if ($lr and $rr)
100          100     21     13   if ($lr or $rr)
104          100     12      9   if ($lr and $rr and defined $cmp and $cmp == 0) { }
             100      5      4   elsif (not $rr or defined $cmp and $cmp < 0) { }
107          100      6      6   if $$self{'same_row'}
114          100      2      3   if $$self{'not_in_right'}
121          100      1      3   if $$self{'not_in_left'}
125          100      1     33   if $done and &$done($left, $right)
154          100      6     24   if (not defined $l or not defined $r) { }
156          100      2      1   defined $r ? :
             100      3      3   defined $l ? :
159          100      4     20   if ($$tbl{'is_numeric'}{$col}) { }
             100      8     12   elsif ($l ne $r) { }
161          100      2      2   if $trf
163   ***     50      0      4   if ($cmp)
165   ***      0      0      0   if $callback
174          100      1      7   if ($coll and $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/) { }
183          100      7      1   if ($cmp)
185          100      2      5   if $callback
196   ***     50      1      0   if (not $$self{'sth'}{$collation})
197   ***     50      1      0   if (not $$self{'charset_for'})
218   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
74           100     16      4     14   $left_done && $right_done
75    ***     66      0      4     30   !$lr && !$left_done
85           100      3      2     29   !$rr && !$right_done
96           100     17      2     15   $lr and $rr
104          100      4      2     15   $lr and $rr
      ***     66      6      0     15   $lr and $rr and defined $cmp
             100      6      3     12   $lr and $rr and defined $cmp and $cmp == 0
      ***     66      4      0      3   defined $cmp and $cmp < 0
125          100     31      2      1   $done and &$done($left, $right)
174   ***     66      7      0      1   $coll and $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
79    ***     66     13      0     17   !$lr || $EVAL_ERROR
89    ***     66     13      0     16   !$rr || $EVAL_ERROR
100          100     17      4     13   $lr or $rr
104          100      2      3      4   not $rr or defined $cmp and $cmp < 0
154          100      3      3     24   not defined $l or not defined $r
174   ***     33      1      0      0   $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/
      ***     33      1      0      0   $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/


Covered Subroutines
-------------------

Subroutine   Count Location                                      
------------ ----- ----------------------------------------------
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:20 
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:21 
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:25 
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:27 
compare_sets    14 /home/daniel/dev/maatkit/common/RowDiff.pm:48 
db_cmp           1 /home/daniel/dev/maatkit/common/RowDiff.pm:195
key_cmp         26 /home/daniel/dev/maatkit/common/RowDiff.pm:147
new              7 /home/daniel/dev/maatkit/common/RowDiff.pm:37 

Uncovered Subroutines
---------------------

Subroutine   Count Location                                      
------------ ----- ----------------------------------------------
_d               0 /home/daniel/dev/maatkit/common/RowDiff.pm:217


