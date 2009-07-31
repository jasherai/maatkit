---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/RowDiff.pm   93.1   87.5   81.0   88.9    n/a  100.0   88.8
Total                          93.1   87.5   81.0   88.9    n/a  100.0   88.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          RowDiff.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:20 2009
Finish:       Fri Jul 31 18:53:21 2009

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
18                                                    # RowDiff package $Revision: 3249 $
19                                                    # ###########################################################################
20             1                    1             8   use strict;
               1                                  3   
               1                                  8   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  1   
               1                                  9   
22                                                    
23                                                    package RowDiff;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
28                                                    
29                                                    sub new {
30             3                    3            71      my ( $class, %args ) = @_;
31             3    100                          13      die "I need a dbh" unless $args{dbh};
32             2                                  8      my $self = \%args;
33             2                                 19      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # Iterates through two sets of rows and finds differences.  Calls various
37                                                    # methods on the $syncer object when it finds differences.  $left and $right
38                                                    # should be DBI $sth, or should at least behave like them.  $tbl
39                                                    # is a struct from TableParser.
40                                                    sub compare_sets {
41            11                   11         66180      my ( $self, %args ) = @_;
42            11                                 65      my ( $left, $right, $syncer, $tbl )
43                                                          = @args{qw(left right syncer tbl)};
44                                                    
45            11                                 34      my ($lr, $rr);  # Current row from the left/right sources.
46                                                    
47                                                       # We have to manually track if the left or right sth is done
48                                                       # fetching rows because sth->{Active} is always true with
49                                                       # DBD::mysql v3. And we cannot simply while ( $lr || $rr )
50                                                       # because in the case where left and right have the same key,
51                                                       # we do this:
52                                                       #    $lr = $rr = undef; # Fetch another row from each side.
53                                                       # Unsetting both $lr and $rr there would cause while () to
54                                                       # terminate. (And while ( $lr && $rr ) is not what we want
55                                                       # either.) Furthermore, we need to avoid trying to fetch more
56                                                       # rows if there are none to fetch because doing this would
57                                                       # cause a DBI error ("fetch without execute"). That's why we
58                                                       # make these checks:
59                                                       #    if ( !$lr && !$left_done )
60                                                       #    if ( !$rr && !$right_done )
61                                                       # If you make changes here, be sure to test both RowDiff.t
62                                                       # and RowDiff-custom.t. Look inside the later to see what
63                                                       # is custom about it.
64            11                                 38      my ($left_done, $right_done) = (0, 0);
65                                                    
66            11           100                   30      do {
67    ***     23    100     66                  191         if ( !$lr && !$left_done ) {
68            20                                 41            MKDEBUG && _d('Fetching row from left');
69            20                                106            $lr = $left->fetchrow_hashref();
70            20    100                         133            $left_done = ($lr ? 0 : 1);
71                                                          }
72                                                          elsif ( MKDEBUG ) {
73                                                             _d('Left still has rows');
74                                                          }
75                                                    
76            23    100    100                  172         if ( !$rr && !$right_done ) {
77            20                                 42            MKDEBUG && _d('Fetching row from right');
78            20                                 85            $rr = $right->fetchrow_hashref();
79            20    100                         127            $right_done = ($rr ? 0 : 1);
80                                                          }
81                                                          elsif ( MKDEBUG ) {
82                                                             _d('Right still has rows');
83                                                          }
84                                                    
85            23                                 50         my $cmp;
86            23    100    100                  133         if ( $lr && $rr ) {
87             7                                 37            $cmp = $self->key_cmp($lr, $rr, $syncer->key_cols(), $tbl);
88             7                                 21            MKDEBUG && _d('Key comparison on left and right:', $cmp);
89                                                          }
90            23    100    100                  211         if ( $lr || $rr ) {
91                                                             # If the current row is the "same row" on both sides, meaning the two
92                                                             # rows have the same key, check the contents of the row to see if
93                                                             # they're the same.
94            12    100    100                  183            if ( $lr && $rr && defined $cmp && $cmp == 0 ) {
      ***           100     66                        
                           100                        
      ***                   66                        
                           100                        
95             6                                 13               MKDEBUG && _d('Left and right have the same key');
96             6                                 28               $syncer->same_row($lr, $rr);
97             6                                 97               $lr = $rr = undef; # Fetch another row from each side.
98                                                             }
99                                                             # The row in the left doesn't exist in the right.
100                                                            elsif ( !$rr || ( defined $cmp && $cmp < 0 ) ) {
101            3                                  7               MKDEBUG && _d('Left is not in right');
102            3                                 15               $syncer->not_in_right($lr);
103            3                                 53               $lr = undef;
104                                                            }
105                                                            # Symmetric to the above.
106                                                            else {
107            3                                  6               MKDEBUG && _d('Right is not in left');
108            3                                 15               $syncer->not_in_left($rr);
109            3                                 59               $rr = undef;
110                                                            }
111                                                         }
112                                                      } while ( !($left_done && $right_done) );
113           11                                 22      MKDEBUG && _d('No more rows');
114           11                                 51      $syncer->done_with_rows();
115                                                   }
116                                                   
117                                                   # Compare two rows to determine how they should be ordered.  NULL sorts before
118                                                   # defined values in MySQL, so I consider undef "less than." Numbers are easy to
119                                                   # compare.  Otherwise string comparison is tricky.  This function must match
120                                                   # MySQL exactly or the merge algorithm runs off the rails, so when in doubt I
121                                                   # ask MySQL to compare strings for me.  I can handle numbers and "normal" latin1
122                                                   # characters without asking MySQL.  See
123                                                   # http://dev.mysql.com/doc/refman/5.0/en/charset-literal.html.  $r1 and $r2 are
124                                                   # row hashrefs.  $key_cols is an arrayref of the key columns to compare.  $tbl is the
125                                                   # structure returned by TableParser.  The result matches Perl's cmp or <=>
126                                                   # operators:
127                                                   # 1 cmp 0 =>  1
128                                                   # 1 cmp 1 =>  0
129                                                   # 1 cmp 2 => -1
130                                                   # TODO: must generate the comparator function dynamically for speed, so we don't
131                                                   # have to check the type of columns constantly
132                                                   sub key_cmp {
133           18                   18           135      my ( $self, $lr, $rr, $key_cols, $tbl ) = @_;
134           18                                 43      MKDEBUG && _d('Comparing keys using columns:', join(',', @$key_cols));
135           18                                 64      foreach my $col ( @$key_cols ) {
136           22                                 68         my $l = $lr->{$col};
137           22                                 63         my $r = $rr->{$col};
138           22    100    100                  165         if ( !defined $l || !defined $r ) {
139            6                                 12            MKDEBUG && _d($col, 'is not defined in both rows');
140            6    100                          45            return defined $l ? 1 : defined $r ? -1 : 0;
                    100                               
141                                                         }
142                                                         else {
143           16    100                         109            if ($tbl->{is_numeric}->{$col} ) {   # Numeric column
                    100                               
144            2                                  8               MKDEBUG && _d($col, 'is numeric');
145            2                                  8               my $cmp = $l <=> $r;
146   ***      2     50                          14               return $cmp unless $cmp == 0;
147                                                            }
148                                                            # Do case-sensitive cmp, expecting most will be eq.  If that fails, try
149                                                            # a case-insensitive cmp if possible; otherwise ask MySQL how to sort.
150                                                            elsif ( $l ne $r ) {
151            6                                 22               my $cmp;
152            6                                 22               my $coll = $tbl->{collation_for}->{$col};
153   ***      6    100     33                   42               if ( $coll && ( $coll ne 'latin1_swedish_ci'
      ***                   33                        
      ***                   66                        
154                                                                              || $l =~ m/[^\040-\177]/ || $r =~ m/[^\040-\177]/) ) {
155            1                                  3                  MKDEBUG && _d('Comparing', $col, 'via MySQL');
156            1                                  6                  $cmp = $self->db_cmp($coll, $l, $r);
157                                                               }
158                                                               else {
159            5                                 10                  MKDEBUG && _d('Comparing', $col, 'in lowercase');
160            5                                 25                  $cmp = lc $l cmp lc $r;
161                                                               }
162            6    100                          45               return $cmp unless $cmp == 0;
163                                                            }
164                                                         }
165                                                      }
166            7                                 30      return 0;
167                                                   }
168                                                   
169                                                   sub db_cmp {
170            1                    1             5      my ( $self, $collation, $l, $r ) = @_;
171   ***      1     50                           7      if ( !$self->{sth}->{$collation} ) {
172   ***      1     50                           5         if ( !$self->{charset_for} ) {
173            1                                  2            MKDEBUG && _d('Fetching collations from MySQL');
174            1                                  3            my @collations = @{$self->{dbh}->selectall_arrayref(
               1                                 28   
175                                                               'SHOW COLLATION', {Slice => { collation => 1, charset => 1 }})};
176            1                                 37            foreach my $collation ( @collations ) {
177          126                                683               $self->{charset_for}->{$collation->{collation}}
178                                                                  = $collation->{charset};
179                                                            }
180                                                         }
181            1                                 13         my $sql = "SELECT STRCMP(_$self->{charset_for}->{$collation}? COLLATE $collation, "
182                                                            . "_$self->{charset_for}->{$collation}? COLLATE $collation) AS res";
183            1                                  2         MKDEBUG && _d($sql);
184            1                                  3         $self->{sth}->{$collation} = $self->{dbh}->prepare($sql);
185                                                      }
186            1                                  9      my $sth = $self->{sth}->{$collation};
187            1                                231      $sth->execute($l, $r);
188            1                                 23      return $sth->fetchall_arrayref()->[0]->[0];
189                                                   }
190                                                   
191                                                   sub _d {
192   ***      0                    0                    my ($package, undef, $line) = caller 0;
193   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
194   ***      0                                              map { defined $_ ? $_ : 'undef' }
195                                                           @_;
196   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
197                                                   }
198                                                   
199                                                   1;
200                                                   
201                                                   # ###########################################################################
202                                                   # End RowDiff package
203                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
31           100      1      2   unless $args{'dbh'}
67           100     20      3   !$lr && !$left_done ? :
70           100      9     11   $lr ? :
76           100     20      3   !$rr && !$right_done ? :
79           100      9     11   $rr ? :
86           100      7     16   if ($lr and $rr)
90           100     12     11   if ($lr or $rr)
94           100      6      6   if ($lr and $rr and defined $cmp and $cmp == 0) { }
             100      3      3   elsif (not $rr or defined $cmp and $cmp < 0) { }
138          100      6     16   if (not defined $l or not defined $r) { }
140          100      2      1   defined $r ? :
             100      3      3   defined $l ? :
143          100      2     14   if ($$tbl{'is_numeric'}{$col}) { }
             100      6      8   elsif ($l ne $r) { }
146   ***     50      0      2   unless $cmp == 0
153          100      1      5   if ($coll and $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/) { }
162          100      5      1   unless $cmp == 0
171   ***     50      1      0   if (not $$self{'sth'}{$collation})
172   ***     50      1      0   if (not $$self{'charset_for'})
193   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
66           100      9      3     11   $left_done && $right_done
67    ***     66      0      3     20   !$lr && !$left_done
76           100      1      2     20   !$rr && !$right_done
86           100     14      2      7   $lr and $rr
94           100      3      2      7   $lr and $rr
      ***     66      5      0      7   $lr and $rr and defined $cmp
             100      5      1      6   $lr and $rr and defined $cmp and $cmp == 0
      ***     66      3      0      1   defined $cmp and $cmp < 0
153   ***     66      5      0      1   $coll and $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
90           100      9      3     11   $lr or $rr
94           100      2      1      3   not $rr or defined $cmp and $cmp < 0
138          100      3      3     16   not defined $l or not defined $r
153   ***     33      1      0      0   $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/
      ***     33      1      0      0   $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/


Covered Subroutines
-------------------

Subroutine   Count Location                                      
------------ ----- ----------------------------------------------
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:20 
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:21 
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:25 
BEGIN            1 /home/daniel/dev/maatkit/common/RowDiff.pm:27 
compare_sets    11 /home/daniel/dev/maatkit/common/RowDiff.pm:41 
db_cmp           1 /home/daniel/dev/maatkit/common/RowDiff.pm:170
key_cmp         18 /home/daniel/dev/maatkit/common/RowDiff.pm:133
new              3 /home/daniel/dev/maatkit/common/RowDiff.pm:30 

Uncovered Subroutines
---------------------

Subroutine   Count Location                                      
------------ ----- ----------------------------------------------
_d               0 /home/daniel/dev/maatkit/common/RowDiff.pm:192


