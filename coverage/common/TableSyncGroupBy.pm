---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...ommon/TableSyncGroupBy.pm   81.7   66.7   50.0   65.0    0.0   47.4   67.7
TableSyncGroupBy.t            100.0   50.0   33.3  100.0    n/a   52.6   95.5
Total                          88.5   64.3   42.9   78.8    0.0  100.0   76.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:18 2010
Finish:       Thu Jun 24 19:38:18 2010

Run:          TableSyncGroupBy.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:19 2010
Finish:       Thu Jun 24 19:38:19 2010

/home/daniel/dev/maatkit/common/TableSyncGroupBy.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2010 Baron Schwartz.
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
18                                                    # TableSyncGroupBy package $Revision: 5697 $
19                                                    # ###########################################################################
20                                                    package TableSyncGroupBy;
21                                                    # This package syncs tables without primary keys by doing an all-columns GROUP
22                                                    # BY with a count, and then streaming through the results to see how many of
23                                                    # each group exist.
24                                                    
25             1                    1             4   use strict;
               1                                  2   
               1                                  7   
26             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  4   
27                                                    
28             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
29                                                    
30    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 15   
31                                                    
32                                                    sub new {
33    ***      2                    2      0     12      my ( $class, %args ) = @_;
34             2                                  9      foreach my $arg ( qw(Quoter) ) {
35             2    100                           9         die "I need a $arg argument" unless $args{$arg};
36                                                       }
37             1                                  7      my $self = { %args };
38             1                                 16      return bless $self, $class;
39                                                    }
40                                                    
41                                                    sub name {
42    ***      0                    0      0      0      return 'GroupBy';
43                                                    }
44                                                    
45                                                    sub can_sync {
46    ***      0                    0      0      0      return 1;  # We can sync anything.
47                                                    }
48                                                    
49                                                    sub prepare_to_sync {
50    ***      2                    2      0     14      my ( $self, %args ) = @_;
51             2                                 13      my @required_args = qw(tbl_struct cols ChangeHandler);
52             2                                  8      foreach my $arg ( @required_args ) {
53    ***      6     50                          41         die "I need a $arg argument" unless defined $args{$arg};
54                                                       }
55                                                    
56             2                                 10      $self->{cols}            = $args{cols};
57             2                                  8      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
58             2                                  8      $self->{ChangeHandler}   = $args{ChangeHandler};
59                                                    
60             2                                  8      $self->{count_col} = '__maatkit_count';
61             2                                 20      while ( $args{tbl_struct}->{is_col}->{$self->{count_col}} ) {
62                                                          # Prepend more _ until not a column.
63    ***      0                                  0         $self->{count_col} = "_$self->{count_col}";
64                                                       }
65             2                                  5      MKDEBUG && _d('COUNT column will be named', $self->{count_col});
66                                                    
67             2                                  8      $self->{done} = 0;
68                                                    
69             2                                303      return;
70                                                    }
71                                                    
72                                                    sub uses_checksum {
73    ***      0                    0      0      0      return 0;  # We don't need checksum queries.
74                                                    }
75                                                    
76                                                    sub set_checksum_queries {
77    ***      0                    0      0      0      return;  # This shouldn't be called, but just in case.
78                                                    }
79                                                    
80                                                    sub prepare_sync_cycle {
81    ***      0                    0      0      0      my ( $self, $host ) = @_;
82    ***      0                                  0      return;
83                                                    }
84                                                    
85                                                    sub get_sql {
86    ***      2                    2      0     17      my ( $self, %args ) = @_;
87             2                                  8      my $cols = join(', ', map { $self->{Quoter}->quote($_) } @{$self->{cols}});
               6                                125   
               2                                 10   
88    ***      2    100     50                   68      return "SELECT"
89                                                          . ($self->{buffer_in_mysql} ? ' SQL_BUFFER_RESULT' : '')
90                                                          . " $cols, COUNT(*) AS $self->{count_col}"
91                                                          . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
92                                                          . ' WHERE ' . ( $args{where} || '1=1' )
93                                                          . " GROUP BY $cols ORDER BY $cols";
94                                                    }
95                                                    
96                                                    # The same row means that the key columns are equal, so there are rows with the
97                                                    # same columns in both tables; but there are different numbers of rows.  So we
98                                                    # must either delete or insert the required number of rows to the table.
99                                                    sub same_row {
100   ***      2                    2      0    507      my ( $self, %args ) = @_;
101            2                                 11      my ($lr, $rr) = @args{qw(lr rr)};
102            2                                  7      my $cc   = $self->{count_col};
103            2                                  7      my $lc   = $lr->{$cc};
104            2                                  7      my $rc   = $rr->{$cc};
105            2                                  8      my $diff = abs($lc - $rc);
106   ***      2     50                          20      return unless $diff;
107            2                                 11      $lr = { %$lr };
108            2                                  7      delete $lr->{$cc};
109            2                                  9      $rr = { %$rr };
110            2                                  6      delete $rr->{$cc};
111            2                                 10      foreach my $i ( 1 .. $diff ) {
112            3    100                          22         if ( $lc > $rc ) {
113            1                                  6            $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
114                                                         }
115                                                         else {
116            2                                 11            $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
117                                                         }
118                                                      }
119                                                   }
120                                                   
121                                                   # Insert into the table the specified number of times.
122                                                   sub not_in_right {
123   ***      1                    1      0    218      my ( $self, %args ) = @_;
124            1                                  5      my $lr = $args{lr};
125            1                                  5      $lr = { %$lr };
126            1                                  5      my $cnt = delete $lr->{$self->{count_col}};
127            1                                  4      foreach my $i ( 1 .. $cnt ) {
128            2                                 21         $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
129                                                      }
130                                                   }
131                                                   
132                                                   # Delete from the table the specified number of times.
133                                                   sub not_in_left {
134   ***      1                    1      0     82      my ( $self, %args ) = @_;
135            1                                  5      my $rr = $args{rr};
136            1                                  5      $rr = { %$rr };
137            1                                  4      my $cnt = delete $rr->{$self->{count_col}};
138            1                                  4      foreach my $i ( 1 .. $cnt ) {
139            1                                  5         $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
140                                                      }
141                                                   }
142                                                   
143                                                   sub done_with_rows {
144   ***      1                    1      0     74      my ( $self ) = @_;
145            1                                  6      $self->{done} = 1;
146                                                   }
147                                                   
148                                                   sub done {
149   ***      1                    1      0      5      my ( $self ) = @_;
150            1                                  7      return $self->{done};
151                                                   }
152                                                   
153                                                   sub key_cols {
154   ***      7                    7      0     77      my ( $self ) = @_;
155            7                                 39      return $self->{cols};
156                                                   }
157                                                   
158                                                   # Return 1 if you have changes yet to make and you don't want the TableSyncer to
159                                                   # commit your transaction or release your locks.
160                                                   sub pending_changes {
161   ***      0                    0      0             my ( $self ) = @_;
162   ***      0                                         return;
163                                                   }
164                                                   
165                                                   sub _d {
166   ***      0                    0                    my ($package, undef, $line) = caller 0;
167   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
168   ***      0                                              map { defined $_ ? $_ : 'undef' }
169                                                           @_;
170   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
171                                                   }
172                                                   
173                                                   1;
174                                                   
175                                                   # ###########################################################################
176                                                   # End TableSyncGroupBy package
177                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
35           100      1      1   unless $args{$arg}
53    ***     50      0      6   unless defined $args{$arg}
88           100      1      1   $$self{'buffer_in_mysql'} ? :
106   ***     50      0      2   unless $diff
112          100      1      2   if ($lc > $rc) { }
167   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0
88    ***     50      2      0   $args{'where'} || '1=1'


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                               
-------------------- ----- --- -------------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:25 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:26 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:28 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:30 
done                     1   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:149
done_with_rows           1   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:144
get_sql                  2   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:86 
key_cols                 7   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:154
new                      2   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:33 
not_in_left              1   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:134
not_in_right             1   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:123
prepare_to_sync          2   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:50 
same_row                 2   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:100

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                               
-------------------- ----- --- -------------------------------------------------------
_d                       0     /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:166
can_sync                 0   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:46 
name                     0   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:42 
pending_changes          0   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:161
prepare_sync_cycle       0   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:81 
set_checksum_queries     0   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:77 
uses_checksum            0   0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:73 


TableSyncGroupBy.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            11   use Test::More tests => 5;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use TableSyncGroupBy;
               1                                  3   
               1                                 11   
15             1                    1            10   use Quoter;
               1                                  4   
               1                                 10   
16             1                    1            11   use MockSth;
               1                                  3   
               1                                  8   
17             1                    1            11   use RowDiff;
               1                                  3   
               1                                 10   
18             1                    1            10   use ChangeHandler;
               1                                  3   
               1                                 12   
19             1                    1            12   use MaatkitTest;
               1                                  3   
               1                                 38   
20                                                    
21             1                                 11   my $q = new Quoter();
22             1                                 59   my $tbl_struct = { is_col => {} };  # fake tbl_struct
23             1                                  4   my @rows;
24                                                    
25                                                    throws_ok(
26             1                    1            18      sub { new TableSyncGroupBy() },
27             1                                 24      qr/I need a Quoter/,
28                                                       'Quoter required'
29                                                    );
30             1                                 16   my $t = new TableSyncGroupBy(
31                                                       Quoter => $q,
32                                                    );
33                                                    
34                                                    my $ch = new ChangeHandler(
35                                                       Quoter    => $q,
36                                                       right_db  => 'test',
37                                                       right_tbl => 'foo',
38                                                       left_db   => 'test',
39                                                       left_tbl  => 'foo',
40                                                       replace   => 0,
41             1                    6            22      actions   => [ sub { push @rows, $_[0] }, ],
               6                               1456   
42                                                       queue     => 0,
43                                                    );
44                                                    
45             1                                217   $t->prepare_to_sync(
46                                                       ChangeHandler => $ch,
47                                                       cols          => [qw(a b c)],
48                                                       tbl_struct    => $tbl_struct,
49                                                       buffer_in_mysql => 1,
50                                                    );
51             1                                 10   is(
52                                                       $t->get_sql(
53                                                          where    => 'foo=1',
54                                                          database => 'test',
55                                                          table    => 'foo',
56                                                       ),
57                                                       'SELECT SQL_BUFFER_RESULT `a`, `b`, `c`, COUNT(*) AS __maatkit_count FROM `test`.`foo` '
58                                                          . 'WHERE foo=1 GROUP BY `a`, `b`, `c` ORDER BY `a`, `b`, `c`',
59                                                       'Got SQL with SQL_BUFFER_RESULT',
60                                                    );
61                                                    
62             1                                 13   $t->prepare_to_sync(
63                                                       ChangeHandler => $ch,
64                                                       cols          => [qw(a b c)],
65                                                       tbl_struct    => $tbl_struct,
66                                                    );
67             1                                  6   is(
68                                                       $t->get_sql(
69                                                          where    => 'foo=1',
70                                                          database => 'test',
71                                                          table    => 'foo',
72                                                       ),
73                                                       'SELECT `a`, `b`, `c`, COUNT(*) AS __maatkit_count FROM `test`.`foo` '
74                                                          . 'WHERE foo=1 GROUP BY `a`, `b`, `c` ORDER BY `a`, `b`, `c`',
75                                                       'Got SQL OK',
76                                                    );
77                                                    
78                                                    # Changed from undef to 0 due to r4802.
79             1                                  7   is( $t->done, 0, 'Not done yet' );
80                                                    
81             1                                 11   my $d = new RowDiff( dbh => 1 );
82             1                                 50   $d->compare_sets(
83                                                       left_sth => new MockSth(
84                                                          { a => 1, b => 2, c => 3, __maatkit_count => 4 },
85                                                          { a => 2, b => 2, c => 3, __maatkit_count => 4 },
86                                                          { a => 3, b => 2, c => 3, __maatkit_count => 2 },
87                                                          # { a => 4, b => 2, c => 3, __maatkit_count => 2 },
88                                                       ),
89                                                       right_sth => new MockSth(
90                                                          { a => 1, b => 2, c => 3, __maatkit_count => 3 },
91                                                          { a => 2, b => 2, c => 3, __maatkit_count => 6 },
92                                                          # { a => 3, b => 2, c => 3, __maatkit_count => 2 },
93                                                          { a => 4, b => 2, c => 3, __maatkit_count => 1 },
94                                                       ),
95                                                       syncer     => $t,
96                                                       tbl_struct => {},
97                                                    );
98                                                    
99             1                                 19   is_deeply(
100                                                      \@rows,
101                                                      [
102                                                      "INSERT INTO `test`.`foo`(`a`, `b`, `c`) VALUES ('1', '2', '3')",
103                                                      "DELETE FROM `test`.`foo` WHERE `a`='2' AND `b`='2' AND `c`='3' LIMIT 1",
104                                                      "DELETE FROM `test`.`foo` WHERE `a`='2' AND `b`='2' AND `c`='3' LIMIT 1",
105                                                      "INSERT INTO `test`.`foo`(`a`, `b`, `c`) VALUES ('3', '2', '3')",
106                                                      "INSERT INTO `test`.`foo`(`a`, `b`, `c`) VALUES ('3', '2', '3')",
107                                                      "DELETE FROM `test`.`foo` WHERE `a`='4' AND `b`='2' AND `c`='3' LIMIT 1",
108                                                      ],
109                                                      'rows from handler',
110                                                   );


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
---------- ----- ---------------------
BEGIN          1 TableSyncGroupBy.t:10
BEGIN          1 TableSyncGroupBy.t:11
BEGIN          1 TableSyncGroupBy.t:12
BEGIN          1 TableSyncGroupBy.t:14
BEGIN          1 TableSyncGroupBy.t:15
BEGIN          1 TableSyncGroupBy.t:16
BEGIN          1 TableSyncGroupBy.t:17
BEGIN          1 TableSyncGroupBy.t:18
BEGIN          1 TableSyncGroupBy.t:19
BEGIN          1 TableSyncGroupBy.t:4 
BEGIN          1 TableSyncGroupBy.t:9 
__ANON__       1 TableSyncGroupBy.t:26
__ANON__       6 TableSyncGroupBy.t:41


