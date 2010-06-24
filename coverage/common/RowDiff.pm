---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/RowDiff.pm   92.3   84.5   79.2   88.9    0.0    1.2   85.9
RowDiff.t                      99.4   60.0   40.0  100.0    n/a   98.8   96.0
Total                          96.4   80.9   75.9   96.8    0.0  100.0   90.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:21 2010
Finish:       Thu Jun 24 19:36:21 2010

Run:          RowDiff.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:23 2010
Finish:       Thu Jun 24 19:36:24 2010

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
18                                                    # RowDiff package $Revision: 5697 $
19                                                    # ###########################################################################
20                                                    package RowDiff;
21                                                    
22             1                    1             9   use strict;
               1                                  3   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                 13   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 15   
27                                                    
28                                                    # Required args:
29                                                    #   * dbh           obj: dbh used for collation-specific string comparisons
30                                                    # Optional args:
31                                                    #   * same_row      Callback when rows are identical
32                                                    #   * not_in_left   Callback when right row is not in the left
33                                                    #   * not_in_right  Callback when left row is not in the right
34                                                    #   * key_cmp       Callback when a column value differs
35                                                    #   * done          Callback that stops compare_sets() if it returns true
36                                                    #   * trf           Callback to transform numeric values before comparison
37                                                    sub new {
38    ***      7                    7      0     51      my ( $class, %args ) = @_;
39             7    100                          33      die "I need a dbh" unless $args{dbh};
40             6                                 33      my $self = { %args };
41             6                                 50      return bless $self, $class;
42                                                    }
43                                                    
44                                                    # Arguments:
45                                                    #   * left_sth    obj: sth
46                                                    #   * right_sth   obj: sth
47                                                    #   * syncer      obj: TableSync* module
48                                                    #   * tbl_struct  hashref: table struct from TableParser::parser()
49                                                    # Iterates through two sets of rows and finds differences.  Calls various
50                                                    # methods on the $syncer object when it finds differences, passing these
51                                                    # args and hashrefs to the differing rows ($lr and $rr).
52                                                    sub compare_sets {
53    ***     14                   14      0    151      my ( $self, %args ) = @_;
54            14                                106      my @required_args = qw(left_sth right_sth syncer tbl_struct);
55            14                                 69      foreach my $arg ( @required_args ) {
56    ***     56     50                         318         die "I need a $arg argument" unless defined $args{$arg};
57                                                       }
58            14                                 56      my $left_sth   = $args{left_sth};
59            14                                 48      my $right_sth  = $args{right_sth};
60            14                                 50      my $syncer     = $args{syncer};
61            14                                 47      my $tbl_struct = $args{tbl_struct};
62                                                    
63            14                                 47      my ($lr, $rr);    # Current row from the left/right sths.
64            14                                 87      $args{key_cols} = $syncer->key_cols();  # for key_cmp()
65                                                    
66                                                       # We have to manually track if the left or right sth is done
67                                                       # fetching rows because sth->{Active} is always true with
68                                                       # DBD::mysql v3. And we cannot simply while ( $lr || $rr )
69                                                       # because in the case where left and right have the same key,
70                                                       # we do this:
71                                                       #    $lr = $rr = undef; # Fetch another row from each side.
72                                                       # Unsetting both $lr and $rr there would cause while () to
73                                                       # terminate. (And while ( $lr && $rr ) is not what we want
74                                                       # either.) Furthermore, we need to avoid trying to fetch more
75                                                       # rows if there are none to fetch because doing this would
76                                                       # cause a DBI error ("fetch without execute"). That's why we
77                                                       # make these checks:
78                                                       #    if ( !$lr && !$left_done )
79                                                       #    if ( !$rr && !$right_done )
80                                                       # If you make changes here, be sure to test both RowDiff.t
81                                                       # and RowDiff-custom.t. Look inside the later to see what
82                                                       # is custom about it.
83            14                                153      my $left_done  = 0;
84            14                                 42      my $right_done = 0;
85            14                                 59      my $done       = $self->{done};
86                                                    
87            14           100                   45      do {
88    ***     34    100     66                  438         if ( !$lr && !$left_done ) {
89            30                                 75            MKDEBUG && _d('Fetching row from left');
90            30                                 89            eval { $lr = $left_sth->fetchrow_hashref(); };
              30                                197   
91            30                                769            MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
92    ***     30    100     66                  239            $left_done = !$lr || $EVAL_ERROR ? 1 : 0;
93                                                          }
94                                                          elsif ( MKDEBUG ) {
95                                                             _d('Left still has rows');
96                                                          }
97                                                    
98            34    100    100                  298         if ( !$rr && !$right_done ) {
99            29                                 69            MKDEBUG && _d('Fetching row from right');
100           29                                 79            eval { $rr = $right_sth->fetchrow_hashref(); };
              29                                207   
101           29                                782            MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
102   ***     29    100     66                  231            $right_done = !$rr || $EVAL_ERROR ? 1 : 0;
103                                                         }
104                                                         elsif ( MKDEBUG ) {
105                                                            _d('Right still has rows');
106                                                         }
107                                                   
108           34                                 87         my $cmp;
109           34    100    100                  299         if ( $lr && $rr ) {
110           15                                 96            $cmp = $self->key_cmp(%args, lr => $lr, rr => $rr);
111           15                                 44            MKDEBUG && _d('Key comparison on left and right:', $cmp);
112                                                         }
113           34    100    100                  267         if ( $lr || $rr ) {
114                                                            # If the current row is the "same row" on both sides, meaning the two
115                                                            # rows have the same key, check the contents of the row to see if
116                                                            # they're the same.
117           21    100    100                  368            if ( $lr && $rr && defined $cmp && $cmp == 0 ) {
      ***           100     66                        
                           100                        
      ***                   66                        
                           100                        
118           12                                 27               MKDEBUG && _d('Left and right have the same key');
119           12                                 86               $syncer->same_row(%args, lr => $lr, rr => $rr);
120           12    100                         335               $self->{same_row}->(%args, lr => $lr, rr => $rr)
121                                                                  if $self->{same_row};
122           12                                 44               $lr = $rr = undef; # Fetch another row from each side.
123                                                            }
124                                                            # The row in the left doesn't exist in the right.
125                                                            elsif ( !$rr || ( defined $cmp && $cmp < 0 ) ) {
126            5                                 14               MKDEBUG && _d('Left is not in right');
127            5                                 43               $syncer->not_in_right(%args, lr => $lr, rr => $rr);
128            5    100                         146               $self->{not_in_right}->(%args, lr => $lr, rr => $rr)
129                                                                  if $self->{not_in_right};
130            5                                 19               $lr = undef;
131                                                            }
132                                                            # Symmetric to the above.
133                                                            else {
134            4                                 13               MKDEBUG && _d('Right is not in left');
135            4                                 40               $syncer->not_in_left(%args, lr => $lr, rr => $rr);
136            4    100                         115               $self->{not_in_left}->(%args, lr => $lr, rr => $rr)
137                                                                  if $self->{not_in_left};
138            4                                 14               $rr = undef;
139                                                            }
140                                                         }
141           34    100    100                  360         $left_done = $right_done = 1 if $done && $done->(%args);
142                                                      } while ( !($left_done && $right_done) );
143           14                                 34      MKDEBUG && _d('No more rows');
144           14                                 83      $syncer->done_with_rows();
145                                                   }
146                                                   
147                                                   # Compare two rows to determine how they should be ordered.  NULL sorts before
148                                                   # defined values in MySQL, so I consider undef "less than." Numbers are easy to
149                                                   # compare.  Otherwise string comparison is tricky.  This function must match
150                                                   # MySQL exactly or the merge algorithm runs off the rails, so when in doubt I
151                                                   # ask MySQL to compare strings for me.  I can handle numbers and "normal" latin1
152                                                   # characters without asking MySQL.  See
153                                                   # http://dev.mysql.com/doc/refman/5.0/en/charset-literal.html.  $r1 and $r2 are
154                                                   # row hashrefs.  $key_cols is an arrayref of the key columns to compare.  $tbl is the
155                                                   # structure returned by TableParser.  The result matches Perl's cmp or <=>
156                                                   # operators:
157                                                   # 1 cmp 0 =>  1
158                                                   # 1 cmp 1 =>  0
159                                                   # 1 cmp 2 => -1
160                                                   # TODO: must generate the comparator function dynamically for speed, so we don't
161                                                   # have to check the type of columns constantly
162                                                   sub key_cmp {
163   ***     26                   26      0    178      my ( $self, %args ) = @_;
164           26                                140      my @required_args = qw(lr rr key_cols tbl_struct);
165           26                                105      foreach my $arg ( @required_args ) {
166   ***    104     50                         454         die "I need a $arg argument" unless exists $args{$arg};
167                                                      }
168           26                                123      my ($lr, $rr, $key_cols, $tbl_struct) = @args{@required_args};
169           26                                 54      MKDEBUG && _d('Comparing keys using columns:', join(',', @$key_cols));
170                                                   
171                                                      # Optional callbacks.
172           26                                 87      my $callback = $self->{key_cmp};
173           26                                 81      my $trf      = $self->{trf};
174                                                   
175           26                                 82      foreach my $col ( @$key_cols ) {
176           30                                 93         my $l = $lr->{$col};
177           30                                 88         my $r = $rr->{$col};
178           30    100    100                  253         if ( !defined $l || !defined $r ) {
179            6                                 13            MKDEBUG && _d($col, 'is not defined in both rows');
180            6    100                          54            return defined $l ? 1 : defined $r ? -1 : 0;
                    100                               
181                                                         }
182                                                         else {
183           24    100                         163            if ( $tbl_struct->{is_numeric}->{$col} ) {   # Numeric column
                    100                               
184            4                                 11               MKDEBUG && _d($col, 'is numeric');
185            4    100                          25               ($l, $r) = $trf->($l, $r, $tbl_struct, $col) if $trf;
186            4                                 18               my $cmp = $l <=> $r;
187   ***      4     50                          25               if ( $cmp ) {
188   ***      0                                  0                  MKDEBUG && _d('Column', $col, 'differs:', $l, '!=', $r);
189   ***      0      0                           0                  $callback->($col, $l, $r) if $callback;
190   ***      0                                  0                  return $cmp;
191                                                               }
192                                                            }
193                                                            # Do case-sensitive cmp, expecting most will be eq.  If that fails, try
194                                                            # a case-insensitive cmp if possible; otherwise ask MySQL how to sort.
195                                                            elsif ( $l ne $r ) {
196            8                                 23               my $cmp;
197            8                                 29               my $coll = $tbl_struct->{collation_for}->{$col};
198   ***      8    100     33                   48               if ( $coll && ( $coll ne 'latin1_swedish_ci'
      ***                   33                        
      ***                   66                        
199                                                                              || $l =~ m/[^\040-\177]/ || $r =~ m/[^\040-\177]/) )
200                                                               {
201            1                                  3                  MKDEBUG && _d('Comparing', $col, 'via MySQL');
202            1                                  6                  $cmp = $self->db_cmp($coll, $l, $r);
203                                                               }
204                                                               else {
205            7                                 15                  MKDEBUG && _d('Comparing', $col, 'in lowercase');
206            7                                 34                  $cmp = lc $l cmp lc $r;
207                                                               }
208            8    100                          33               if ( $cmp ) {
209            7                                 14                  MKDEBUG && _d('Column', $col, 'differs:', $l, 'ne', $r);
210            7    100                          29                  $callback->($col, $l, $r) if $callback;
211            7                                 48                  return $cmp;
212                                                               }
213                                                            }
214                                                         }
215                                                      }
216           13                                 77      return 0;
217                                                   }
218                                                   
219                                                   sub db_cmp {
220   ***      1                    1      0      7      my ( $self, $collation, $l, $r ) = @_;
221   ***      1     50                           7      if ( !$self->{sth}->{$collation} ) {
222   ***      1     50                           5         if ( !$self->{charset_for} ) {
223            1                                  3            MKDEBUG && _d('Fetching collations from MySQL');
224            1                                  3            my @collations = @{$self->{dbh}->selectall_arrayref(
               1                                 32   
225                                                               'SHOW COLLATION', {Slice => { collation => 1, charset => 1 }})};
226            1                                 39            foreach my $collation ( @collations ) {
227          127                                695               $self->{charset_for}->{$collation->{collation}}
228                                                                  = $collation->{charset};
229                                                            }
230                                                         }
231            1                                 13         my $sql = "SELECT STRCMP(_$self->{charset_for}->{$collation}? COLLATE $collation, "
232                                                            . "_$self->{charset_for}->{$collation}? COLLATE $collation) AS res";
233            1                                  2         MKDEBUG && _d($sql);
234            1                                  2         $self->{sth}->{$collation} = $self->{dbh}->prepare($sql);
235                                                      }
236            1                                  9      my $sth = $self->{sth}->{$collation};
237            1                                210      $sth->execute($l, $r);
238            1                                 24      return $sth->fetchall_arrayref()->[0]->[0];
239                                                   }
240                                                   
241                                                   sub _d {
242   ***      0                    0                    my ($package, undef, $line) = caller 0;
243   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
244   ***      0                                              map { defined $_ ? $_ : 'undef' }
245                                                           @_;
246   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
247                                                   }
248                                                   
249                                                   1;
250                                                   
251                                                   # ###########################################################################
252                                                   # End RowDiff package
253                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39           100      1      6   unless $args{'dbh'}
56    ***     50      0     56   unless defined $args{$arg}
88           100     30      4   !$lr && !$left_done ? :
92           100     13     17   !$lr || $EVAL_ERROR ? :
98           100     29      5   !$rr && !$right_done ? :
102          100     13     16   !$rr || $EVAL_ERROR ? :
109          100     15     19   if ($lr and $rr)
113          100     21     13   if ($lr or $rr)
117          100     12      9   if ($lr and $rr and defined $cmp and $cmp == 0) { }
             100      5      4   elsif (not $rr or defined $cmp and $cmp < 0) { }
120          100      6      6   if $$self{'same_row'}
128          100      2      3   if $$self{'not_in_right'}
136          100      1      3   if $$self{'not_in_left'}
141          100      1     33   if $done and &$done(%args)
166   ***     50      0    104   unless exists $args{$arg}
178          100      6     24   if (not defined $l or not defined $r) { }
180          100      2      1   defined $r ? :
             100      3      3   defined $l ? :
183          100      4     20   if ($$tbl_struct{'is_numeric'}{$col}) { }
             100      8     12   elsif ($l ne $r) { }
185          100      2      2   if $trf
187   ***     50      0      4   if ($cmp)
189   ***      0      0      0   if $callback
198          100      1      7   if ($coll and $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/) { }
208          100      7      1   if ($cmp)
210          100      2      5   if $callback
221   ***     50      1      0   if (not $$self{'sth'}{$collation})
222   ***     50      1      0   if (not $$self{'charset_for'})
243   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
87           100     16      4     14   $left_done && $right_done
88    ***     66      0      4     30   !$lr && !$left_done
98           100      3      2     29   !$rr && !$right_done
109          100     17      2     15   $lr and $rr
117          100      4      2     15   $lr and $rr
      ***     66      6      0     15   $lr and $rr and defined $cmp
             100      6      3     12   $lr and $rr and defined $cmp and $cmp == 0
      ***     66      4      0      3   defined $cmp and $cmp < 0
141          100     31      2      1   $done and &$done(%args)
198   ***     66      7      0      1   $coll and $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
92    ***     66     13      0     17   !$lr || $EVAL_ERROR
102   ***     66     13      0     16   !$rr || $EVAL_ERROR
113          100     17      4     13   $lr or $rr
117          100      2      3      4   not $rr or defined $cmp and $cmp < 0
178          100      3      3     24   not defined $l or not defined $r
198   ***     33      1      0      0   $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/
      ***     33      1      0      0   $coll ne 'latin1_swedish_ci' || $l =~ /[^\040-\177]/ || $r =~ /[^\040-\177]/


Covered Subroutines
-------------------

Subroutine   Count Pod Location                                      
------------ ----- --- ----------------------------------------------
BEGIN            1     /home/daniel/dev/maatkit/common/RowDiff.pm:22 
BEGIN            1     /home/daniel/dev/maatkit/common/RowDiff.pm:23 
BEGIN            1     /home/daniel/dev/maatkit/common/RowDiff.pm:24 
BEGIN            1     /home/daniel/dev/maatkit/common/RowDiff.pm:26 
compare_sets    14   0 /home/daniel/dev/maatkit/common/RowDiff.pm:53 
db_cmp           1   0 /home/daniel/dev/maatkit/common/RowDiff.pm:220
key_cmp         26   0 /home/daniel/dev/maatkit/common/RowDiff.pm:163
new              7   0 /home/daniel/dev/maatkit/common/RowDiff.pm:38 

Uncovered Subroutines
---------------------

Subroutine   Count Pod Location                                      
------------ ----- --- ----------------------------------------------
_d               0     /home/daniel/dev/maatkit/common/RowDiff.pm:242


RowDiff.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/env perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            34      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  4   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 26;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use MockSync;
               1                                  3   
               1                                  9   
15             1                    1            12   use RowDiff;
               1                                  3   
               1                                 99   
16             1                    1            10   use MockSth;
               1                                  3   
               1                                 11   
17             1                    1            11   use Sandbox;
               1                                  3   
               1                                  9   
18             1                    1            10   use DSNParser;
               1                                  2   
               1                                 11   
19             1                    1            14   use TableParser;
               1                                  3   
               1                                 15   
20             1                    1            12   use MySQLDump;
               1                                  3   
               1                                 11   
21             1                    1            10   use Quoter;
               1                                  3   
               1                                  9   
22             1                    1            10   use MaatkitTest;
               1                                  4   
               1                                 38   
23                                                    
24             1                                  5   my ($d, $s);
25                                                    
26             1                                  9   my $q  = new Quoter();
27             1                                 30   my $du = new MySQLDump();
28             1                                 33   my $tp = new TableParser(Quoter => $q);
29             1                                 49   my $dp = new DSNParser(opts=>$dsn_opts);
30                                                    
31                                                    # Connect to sandbox now to make sure it's running.
32             1                                245   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
33             1                                 62   my $master_dbh = $sb->get_dbh_for('master');
34             1                                384   my $slave_dbh  = $sb->get_dbh_for('slave1');
35                                                    
36                                                    
37             1                    1           401   throws_ok( sub { new RowDiff() }, qr/I need a dbh/, 'DBH required' );
               1                                 21   
38             1                                 17   $d = new RowDiff(dbh => 1);
39                                                    
40                                                    
41                                                    # #############################################################################
42                                                    # Test key_cmp().
43                                                    # #############################################################################
44                                                    
45             1                                  7   my %args = (
46                                                       key_cols   => [qw(a)],
47                                                       tbl_struct => {},
48                                                    );
49                                                    
50             1                                  9   is(
51                                                       $d->key_cmp(
52                                                          lr => { a => 1 },
53                                                          rr => { a => 1 },
54                                                          %args,
55                                                       ),
56                                                       0,
57                                                       'Equal keys',
58                                                    );
59                                                    
60             1                                 12   is(
61                                                       $d->key_cmp(
62                                                          lr => { a => undef },
63                                                          rr => { a => undef },
64                                                          %args,
65                                                       ),
66                                                       0,
67                                                       'Equal null keys',
68                                                    );
69                                                    
70             1                                 11   is(
71                                                       $d->key_cmp(
72                                                          lr => undef,
73                                                          rr => { a => 1 },
74                                                          %args,
75                                                       ),
76                                                       -1,
77                                                       'Left key missing',
78                                                    );
79                                                    
80             1                                 10   is(
81                                                       $d->key_cmp(
82                                                          lr => { a => 1 },
83                                                          rr => undef,
84                                                          %args,
85                                                       ),
86                                                       1,
87                                                       'Right key missing',
88                                                    );
89                                                    
90             1                                 12   is(
91                                                       $d->key_cmp(
92                                                          lr => { a => 2 },
93                                                          rr => { a => 1 },
94                                                          %args,
95                                                       ),
96                                                       1,
97                                                       'Right key smaller',
98                                                    );
99                                                    
100            1                                 11   is(
101                                                      $d->key_cmp(
102                                                         lr => { a => 2 },
103                                                         rr => { a => 3 },
104                                                         %args,
105                                                      ),
106                                                      -1,
107                                                      'Right key larger',
108                                                   );
109                                                   
110            1                                  6   $args{key_cols} = [qw(a b)];
111                                                   
112            1                                 10   is(
113                                                      $d->key_cmp(
114                                                         lr => { a => 1, b => 2, },
115                                                         rr => { a => 1, b => 1  },
116                                                         %args,
117                                                      ),
118                                                      1,
119                                                      'Right two-part key smaller',
120                                                   );
121                                                   
122            1                                 12   is(
123                                                      $d->key_cmp(
124                                                         lr => { a => 1, b => 0, },
125                                                         rr => { a => 1, b => 1  },
126                                                         %args,
127                                                      ),
128                                                      -1,
129                                                      'Right two-part key larger',
130                                                   );
131                                                   
132            1                                 12   is(
133                                                      $d->key_cmp(
134                                                         lr => { a => 1, b => undef, },
135                                                         rr => { a => 1, b => 1      },
136                                                         %args,
137                                                      ),
138                                                      -1,
139                                                      'Right two-part key larger because of null',
140                                                   );
141                                                   
142            1                                 12   is(
143                                                      $d->key_cmp(
144                                                         lr => { a => 1, b => 0,    },
145                                                         rr => { a => 1, b => undef },
146                                                         %args,
147                                                      ),
148                                                      1,
149                                                      'Left two-part key larger because of null',
150                                                   );
151                                                   
152            1                                 13   is(
153                                                      $d->key_cmp(
154                                                         lr => { a => 1,     b => 0, },
155                                                         rr => { a => undef, b => 1  },
156                                                         %args,
157                                                      ),
158                                                      1,
159                                                      'Left two-part key larger because of null in first key part',
160                                                   );
161                                                   
162                                                   
163                                                   # #############################################################################
164                                                   # Test compare_sets() using a mock syncer.
165                                                   # #############################################################################
166                                                   
167            1                                 13   $s = new MockSync();
168            1                                 30   $d->compare_sets(
169                                                      left_sth   => new MockSth(),
170                                                      right_sth  => new MockSth(),
171                                                      syncer     => $s,
172                                                      tbl_struct => {},
173                                                   );
174            1                                 24   is_deeply(
175                                                      $s,
176                                                      [
177                                                         'done',
178                                                      ],
179                                                      'no rows',
180                                                   );
181                                                   
182            1                                 10   $s = new MockSync();
183            1                                 18   $d->compare_sets(
184                                                      left_sth   => new MockSth(
185                                                      ),
186                                                      right_sth  => new MockSth(
187                                                         { a => 1, b => 2, c => 3 },
188                                                      ),
189                                                      syncer     => $s,
190                                                      tbl_struct => {},
191                                                   );
192            1                                 22   is_deeply(
193                                                      $s,
194                                                      [
195                                                         [ 'not in left', { a => 1, b => 2, c => 3 },],
196                                                         'done',
197                                                      ],
198                                                      'right only',
199                                                   );
200                                                   
201            1                                 11   $s = new MockSync();
202            1                                 16   $d->compare_sets(
203                                                      left_sth   => new MockSth(
204                                                         { a => 1, b => 2, c => 3 },
205                                                      ),
206                                                      right_sth  => new MockSth(
207                                                      ),
208                                                      syncer     => $s,
209                                                      tbl_struct => {},
210                                                   );
211            1                                 21   is_deeply(
212                                                      $s,
213                                                      [
214                                                         [ 'not in right', { a => 1, b => 2, c => 3 },],
215                                                         'done',
216                                                      ],
217                                                      'left only',
218                                                   );
219                                                   
220            1                                 12   $s = new MockSync();
221            1                                 17   $d->compare_sets(
222                                                      left_sth   => new MockSth(
223                                                         { a => 1, b => 2, c => 3 },
224                                                      ),
225                                                      right_sth  => new MockSth(
226                                                         { a => 1, b => 2, c => 3 },
227                                                      ),
228                                                      syncer     => $s,
229                                                      tbl_struct => {},
230                                                   );
231            1                                 20   is_deeply(
232                                                      $s,
233                                                      [
234                                                         'same',
235                                                         'done',
236                                                      ],
237                                                      'one identical row',
238                                                   );
239                                                   
240            1                                 10   $s = new MockSync();
241            1                                 19   $d->compare_sets(
242                                                      left_sth  => new MockSth(
243                                                         { a => 1, b => 2, c => 3 },
244                                                         { a => 2, b => 2, c => 3 },
245                                                         { a => 3, b => 2, c => 3 },
246                                                         # { a => 4, b => 2, c => 3 },
247                                                      ),
248                                                      right_sth  => new MockSth(
249                                                         # { a => 1, b => 2, c => 3 },
250                                                         { a => 2, b => 2, c => 3 },
251                                                         { a => 3, b => 2, c => 3 },
252                                                         { a => 4, b => 2, c => 3 },
253                                                      ),
254                                                      syncer     => $s,
255                                                      tbl_struct => {},
256                                                   );
257            1                                 36   is_deeply(
258                                                      $s,
259                                                      [
260                                                         [ 'not in right',  { a => 1, b => 2, c => 3 }, ],
261                                                         'same',
262                                                         'same',
263                                                         [ 'not in left', { a => 4, b => 2, c => 3 }, ],
264                                                         'done',
265                                                      ],
266                                                      'differences in basic set of rows',
267                                                   );
268                                                   
269            1                                 16   $s = new MockSync();
270            1                                 22   $d->compare_sets(
271                                                      left_sth   => new MockSth(
272                                                         { a => 1, b => 2, c => 3 },
273                                                      ),
274                                                      right_sth  => new MockSth(
275                                                         { a => 1, b => 2, c => 3 },
276                                                      ),
277                                                      syncer     => $s,
278                                                      tbl_struct => { is_numeric => { a => 1 } },
279                                                   );
280            1                                 21   is_deeply(
281                                                      $s,
282                                                      [
283                                                         'same',
284                                                         'done',
285                                                      ],
286                                                      'Identical with numeric columns',
287                                                   );
288                                                   
289            1                                 11   $d = new RowDiff(dbh => $master_dbh);
290            1                                  6   $s = new MockSync();
291            1                                 15   $d->compare_sets(
292                                                      left_sth   => new MockSth(
293                                                         { a => 'A', b => 2, c => 3 },
294                                                      ),
295                                                      right_sth  => new MockSth(
296                                                         # The difference is the lowercase 'a', which in a _ci collation will
297                                                         # sort the same.  So the rows are really identical, from MySQL's point
298                                                         # of view.
299                                                         { a => 'a', b => 2, c => 3 },
300                                                      ),
301                                                      syncer     => $s,
302                                                      tbl_struct => { collation_for => { a => 'utf8_general_ci' } },
303                                                   );
304            1                                 25   is_deeply(
305                                                      $s,
306                                                      [
307                                                         'same',
308                                                         'done',
309                                                      ],
310                                                      'Identical with utf8 columns',
311                                                   );
312                                                   
313                                                   # #############################################################################
314                                                   # Test that the callbacks work.
315                                                   # #############################################################################
316            1                                  8   my @rows;
317                                                   my $same_row     = sub {
318            6                    6            23      push @rows, 'same row';
319            1                                  8   };
320                                                   my $not_in_left  = sub {
321            1                    1             5      push @rows, 'not in left';
322            1                                  5   };
323                                                   my $not_in_right = sub {
324            2                    2             8      push @rows, 'not in right';
325            1                                  6   };
326                                                   my $key_cmp = sub {
327            2                    2            10      my ( $col, $lr, $rr ) = @_;
328            2                                 10      push @rows, "col $col differs";
329            1                                  7   };
330                                                   
331            1                                  6   $s = new MockSync();
332            1                                 16   $d = new RowDiff(
333                                                      dbh          => 1,
334                                                      key_cmp      => $key_cmp,
335                                                      same_row     => $same_row,
336                                                      not_in_left  => $not_in_left,
337                                                      not_in_right => $not_in_right,
338                                                   );
339            1                                 53   @rows = ();
340            1                                 12   $d->compare_sets(
341                                                      left_sth => new MockSth(
342                                                         { a => 1, b => 2, c => 3 },
343                                                         { a => 2, b => 2, c => 3 },
344                                                         { a => 3, b => 2, c => 3 },
345                                                         # { a => 4, b => 2, c => 3 },
346                                                      ),
347                                                      right_sth => new MockSth(
348                                                         # { a => 1, b => 2, c => 3 },
349                                                         { a => 2, b => 2, c => 3 },
350                                                         { a => 3, b => 2, c => 3 },
351                                                         { a => 4, b => 2, c => 3 },
352                                                      ),
353                                                      syncer     => $s,
354                                                      tbl_struct => {},
355                                                   );
356            1                                 22   is_deeply(
357                                                      \@rows,
358                                                      [
359                                                         'col a differs',
360                                                         'not in right',
361                                                         'same row',
362                                                         'same row',
363                                                         'not in left',
364                                                      ],
365                                                      'callbacks'
366                                                   );
367                                                   
368            1                                  9   my $i = 0;
369                                                   $d = new RowDiff(
370                                                      dbh          => 1,
371                                                      key_cmp      => $key_cmp,
372                                                      same_row     => $same_row,
373                                                      not_in_left  => $not_in_left,
374                                                      not_in_right => $not_in_right,
375            3    100             3            37      done         => sub { return ++$i > 2 ? 1 : 0; },
376            1                                 11   );
377            1                                  5   @rows = ();
378            1                                 12   $d->compare_sets(
379                                                      left_sth => new MockSth(
380                                                         { a => 1, b => 2, c => 3 },
381                                                         { a => 2, b => 2, c => 3 },
382                                                         { a => 3, b => 2, c => 3 },
383                                                         # { a => 4, b => 2, c => 3 },
384                                                      ),
385                                                      right_sth => new MockSth(
386                                                         # { a => 1, b => 2, c => 3 },
387                                                         { a => 2, b => 2, c => 3 },
388                                                         { a => 3, b => 2, c => 3 },
389                                                         { a => 4, b => 2, c => 3 },
390                                                      ),
391                                                      syncer     => $s,
392                                                      tbl_struct => {},
393                                                   );
394            1                                 22   is_deeply(
395                                                      \@rows,
396                                                      [
397                                                         'col a differs',
398                                                         'not in right',
399                                                         'same row',
400                                                         'same row',
401                                                      ],
402                                                      'done callback'
403                                                   );
404                                                   
405                                                   $d = new RowDiff(
406                                                      dbh          => 1,
407                                                      key_cmp      => $key_cmp,
408                                                      same_row     => $same_row,
409                                                      not_in_left  => $not_in_left,
410                                                      not_in_right => $not_in_right,
411                                                      trf          => sub {
412            2                    2             8         my ( $l, $r, $tbl, $col ) = @_;
413            2                                 10         return 1, 1;  # causes all rows to look like they're identical
414                                                      },
415            1                                 17   );
416            1                                  7   @rows = ();
417            1                                 10   $d->compare_sets(
418                                                      left_sth => new MockSth(
419                                                         { a => 1, b => 2, c => 3 },
420                                                         { a => 4, b => 5, c => 6 },
421                                                      ),
422                                                      right_sth => new MockSth(
423                                                         { a => 7,  b => 8,  c => 9  },
424                                                         { a => 10, b => 11, c => 12 },
425                                                      ),
426                                                      syncer     => $s,
427                                                      tbl_struct => { is_numeric => { a => 1, b => 1, c => 1 } },
428                                                   );
429            1                                 21   is_deeply(
430                                                      \@rows,
431                                                      [
432                                                         'same row',
433                                                         'same row',
434                                                      ],
435                                                      'trf callback'
436                                                   );
437                                                   
438                                                   # #############################################################################
439                                                   # The following tests use "real" (sandbox) servers and real statement handles.
440                                                   # #############################################################################
441                                                   
442   ***      1     50                           5   SKIP: {
443            1                                  8      skip 'Cannot connect to sandbox master', 4 unless $master_dbh;
444   ***      1     50                           5      skip 'Cannot connect to sandbox slave',  4 unless $slave_dbh;
445                                                   
446            1                                  6      $d = new RowDiff(dbh => $master_dbh);
447                                                   
448            1                             560096      diag(`$trunk/sandbox/mk-test-env reset >/dev/null 2>&1`);
449            1                                 31      $sb->create_dbs($master_dbh, [qw(test)]);
450            1                                899      $sb->load_file('master', 'common/t/samples/issue_11.sql');
451                                                      MaatkitTest::wait_until(
452                                                         sub {
453            1                    1            76            my $r;
454            1                                  5            eval {
455            1                                  8               $r = $slave_dbh->selectrow_arrayref('SHOW TABLES FROM test LIKE "issue_11"');
456                                                            };
457   ***      1     50     50                 2751            return 1 if ($r->[0] || '') eq 'issue_11';
458   ***      0                                  0            return 0;
459                                                         },
460            1                             212213         0.25,
461                                                         30,
462                                                      );
463                                                   
464            1                                 48      my $tbl = $tp->parse(
465                                                         $du->get_create_table($master_dbh, $q, 'test', 'issue_11'));
466                                                   
467            1                                  4      my $left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
468            1                                  7      my $right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
469            1                                245      $left_sth->execute();
470            1                              81530      $right_sth->execute();
471            1                                 39      $s = new MockSync();
472            1                                 88      $d->compare_sets(
473                                                         left_sth   => $left_sth,
474                                                         right_sth  => $right_sth,
475                                                         syncer     => $s,
476                                                         tbl_struct => $tbl,
477                                                      );
478            1                                 50      is_deeply(
479                                                         $s,
480                                                         ['done',],
481                                                         'no rows (real DBI sth)',
482                                                      );
483                                                   
484            1                                408      $slave_dbh->do('INSERT INTO test.issue_11 VALUES (1,2,3)');
485            1                                  4      $left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
486            1                                  4      $right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
487            1                                319      $left_sth->execute();
488            1                                219      $right_sth->execute();
489            1                                 12      $s = new MockSync();
490            1                                 32      $d->compare_sets(
491                                                         left_sth   => $left_sth,
492                                                         right_sth  => $right_sth,
493                                                         syncer     => $s,
494                                                         tbl_struct => $tbl,
495                                                      );
496            1                                 39      is_deeply(
497                                                         $s,
498                                                         [
499                                                            ['not in left', { a => 1, b => 2, c => 3 },],
500                                                            'done',
501                                                         ],
502                                                         'right only (real DBI sth)',
503                                                      );
504                                                   
505            1                                689      $slave_dbh->do('TRUNCATE TABLE test.issue_11');
506            1                                209      $master_dbh->do('SET SQL_LOG_BIN=0;');
507            1                                797      $master_dbh->do('INSERT INTO test.issue_11 VALUES (1,2,3)');
508            1                                  8      $left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
509            1                                  4      $right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
510            1                                347      $left_sth->execute();
511            1                                429      $right_sth->execute();
512            1                                 18      $s = new MockSync();
513            1                                 45      $d->compare_sets(
514                                                         left_sth   => $left_sth,
515                                                         right_sth  => $right_sth,
516                                                         syncer     => $s,
517                                                         tbl_struct => $tbl,
518                                                      );
519            1                                 41      is_deeply(
520                                                         $s,
521                                                         [
522                                                            [ 'not in right', { a => 1, b => 2, c => 3 },],
523                                                            'done',
524                                                         ],
525                                                         'left only (real DBI sth)',
526                                                      );
527                                                   
528            1                                577      $slave_dbh->do('INSERT INTO test.issue_11 VALUES (1,2,3)');
529            1                                  6      $left_sth  = $master_dbh->prepare('SELECT * FROM test.issue_11');
530            1                                  4      $right_sth = $slave_dbh->prepare('SELECT * FROM test.issue_11');
531            1                                345      $left_sth->execute();
532            1                                239      $right_sth->execute();
533            1                                 16      $s = new MockSync();
534            1                                 41      $d->compare_sets(
535                                                         left_sth   => $left_sth,
536                                                         right_sth  => $right_sth,
537                                                         syncer     => $s,
538                                                         tbl_struct => $tbl,
539                                                      );
540            1                                 51      is_deeply(
541                                                         $s,
542                                                         [
543                                                            'same',
544                                                            'done',
545                                                         ],
546                                                         'one identical row (real DBI sth)',
547                                                      );
548                                                   
549            1                                 33      $sb->wipe_clean($master_dbh);
550            1                               2150      $sb->wipe_clean($slave_dbh);
551                                                   }
552                                                   
553            1                                  9   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
375          100      1      2   ++$i > 2 ? :
442   ***     50      0      1   unless $master_dbh
444   ***     50      0      1   unless $slave_dbh
457   ***     50      1      0   if ($$r[0] || '') eq 'issue_11'


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
457   ***     50      1      0   $$r[0] || ''


Covered Subroutines
-------------------

Subroutine Count Location     
---------- ----- -------------
BEGIN          1 RowDiff.t:10 
BEGIN          1 RowDiff.t:11 
BEGIN          1 RowDiff.t:12 
BEGIN          1 RowDiff.t:14 
BEGIN          1 RowDiff.t:15 
BEGIN          1 RowDiff.t:16 
BEGIN          1 RowDiff.t:17 
BEGIN          1 RowDiff.t:18 
BEGIN          1 RowDiff.t:19 
BEGIN          1 RowDiff.t:20 
BEGIN          1 RowDiff.t:21 
BEGIN          1 RowDiff.t:22 
BEGIN          1 RowDiff.t:4  
BEGIN          1 RowDiff.t:9  
__ANON__       6 RowDiff.t:318
__ANON__       1 RowDiff.t:321
__ANON__       2 RowDiff.t:324
__ANON__       2 RowDiff.t:327
__ANON__       1 RowDiff.t:37 
__ANON__       3 RowDiff.t:375
__ANON__       2 RowDiff.t:412
__ANON__       1 RowDiff.t:453


