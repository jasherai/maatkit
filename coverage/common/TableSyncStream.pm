---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncStream.pm   75.0   62.5   50.0   65.0    0.0   55.2   60.2
TableSyncStream.t             100.0   50.0   33.3  100.0    n/a   44.8   95.4
Total                          86.4   60.0   42.9   78.8    0.0  100.0   73.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:29 2010
Finish:       Thu Jun 24 19:38:29 2010

Run:          TableSyncStream.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:31 2010
Finish:       Thu Jun 24 19:38:31 2010

/home/daniel/dev/maatkit/common/TableSyncStream.pm

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
18                                                    # TableSyncStream package $Revision: 5697 $
19                                                    # ###########################################################################
20                                                    package TableSyncStream;
21                                                    # This package implements the simplest possible table-sync algorithm: read every
22                                                    # row from the tables and compare them.
23                                                    
24             1                    1             5   use strict;
               1                                  2   
               1                                 13   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  6   
               1                                  5   
26                                                    
27             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
28                                                    
29    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
30                                                    
31                                                    sub new {
32    ***      2                    2      0     10      my ( $class, %args ) = @_;
33             2                                  8      foreach my $arg ( qw(Quoter) ) {
34             2    100                           9         die "I need a $arg argument" unless $args{$arg};
35                                                       }
36             1                                  5      my $self = { %args };
37             1                                 14      return bless $self, $class;
38                                                    }
39                                                    
40                                                    sub name {
41    ***      0                    0      0      0      return 'Stream';
42                                                    }
43                                                    
44                                                    sub can_sync {
45    ***      0                    0      0      0      return 1;  # We can sync anything.
46                                                    }
47                                                    
48                                                    sub prepare_to_sync {
49    ***      2                    2      0     13      my ( $self, %args ) = @_;
50             2                                  8      my @required_args = qw(cols ChangeHandler);
51             2                                  7      foreach my $arg ( @required_args ) {
52    ***      4     50                          21         die "I need a $arg argument" unless $args{$arg};
53                                                       }
54             2                                 15      $self->{cols}            = $args{cols};
55             2                                 10      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
56             2                                  8      $self->{ChangeHandler}   = $args{ChangeHandler};
57                                                    
58             2                                  6      $self->{done}  = 0;
59                                                    
60             2                                  9      return;
61                                                    }
62                                                    
63                                                    sub uses_checksum {
64    ***      0                    0      0      0      return 0;  # We don't need checksum queries.
65                                                    }
66                                                    
67                                                    sub set_checksum_queries {
68    ***      0                    0      0      0      return;  # This shouldn't be called, but just in case.
69                                                    }
70                                                    
71                                                    sub prepare_sync_cycle {
72    ***      0                    0      0      0      my ( $self, $host ) = @_;
73    ***      0                                  0      return;
74                                                    }
75                                                    
76                                                    sub get_sql {
77    ***      2                    2      0     18      my ( $self, %args ) = @_;
78             6                                116      return "SELECT "
79                                                          . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
80    ***      2    100     50                  253         . join(', ', map { $self->{Quoter}->quote($_) } @{$self->{cols}})
               2                                 11   
81                                                          . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
82                                                          . ' WHERE ' . ( $args{where} || '1=1' );
83                                                    }
84                                                    
85                                                    sub same_row {
86    ***      2                    2      0    394      my ( $self, %args ) = @_;
87             2                                 11      return;
88                                                    }
89                                                    
90                                                    sub not_in_right {
91    ***      1                    1      0    227      my ( $self, %args ) = @_;
92             1                                  7      $self->{ChangeHandler}->change('INSERT', $args{lr}, $self->key_cols());
93                                                    }
94                                                    
95                                                    sub not_in_left {
96    ***      1                    1      0    100      my ( $self, %args ) = @_;
97             1                                  6      $self->{ChangeHandler}->change('DELETE', $args{rr}, $self->key_cols());
98                                                    }
99                                                    
100                                                   sub done_with_rows {
101   ***      1                    1      0     72      my ( $self ) = @_;
102            1                                  6      $self->{done} = 1;
103                                                   }
104                                                   
105                                                   sub done {
106   ***      1                    1      0      5      my ( $self ) = @_;
107            1                                  6      return $self->{done};
108                                                   }
109                                                   
110                                                   sub key_cols {
111   ***      3                    3      0     61      my ( $self ) = @_;
112            3                                 18      return $self->{cols};
113                                                   }
114                                                   
115                                                   # Return 1 if you have changes yet to make and you don't want the TableSyncer to
116                                                   # commit your transaction or release your locks.
117                                                   sub pending_changes {
118   ***      0                    0      0             my ( $self ) = @_;
119   ***      0                                         return;
120                                                   }
121                                                   
122                                                   sub _d {
123   ***      0                    0                    my ($package, undef, $line) = caller 0;
124   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
125   ***      0                                              map { defined $_ ? $_ : 'undef' }
126                                                           @_;
127   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
128                                                   }
129                                                   
130                                                   1;
131                                                   
132                                                   # ###########################################################################
133                                                   # End TableSyncStream package
134                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
34           100      1      1   unless $args{$arg}
52    ***     50      0      4   unless $args{$arg}
80           100      1      1   $$self{'buffer_in_mysql'} ? :
124   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
29    ***     50      0      1   $ENV{'MKDEBUG'} || 0
80    ***     50      2      0   $args{'where'} || '1=1'


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                              
-------------------- ----- --- ------------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncStream.pm:24 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncStream.pm:25 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncStream.pm:27 
BEGIN                    1     /home/daniel/dev/maatkit/common/TableSyncStream.pm:29 
done                     1   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:106
done_with_rows           1   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:101
get_sql                  2   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:77 
key_cols                 3   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:111
new                      2   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:32 
not_in_left              1   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:96 
not_in_right             1   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:91 
prepare_to_sync          2   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:49 
same_row                 2   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:86 

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                              
-------------------- ----- --- ------------------------------------------------------
_d                       0     /home/daniel/dev/maatkit/common/TableSyncStream.pm:123
can_sync                 0   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:45 
name                     0   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:41 
pending_changes          0   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:118
prepare_sync_cycle       0   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:72 
set_checksum_queries     0   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:68 
uses_checksum            0   0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:64 


TableSyncStream.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 5;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use TableSyncStream;
               1                                  3   
               1                                 11   
15             1                    1            10   use Quoter;
               1                                  3   
               1                                 10   
16             1                    1            11   use MockSth;
               1                                  3   
               1                                  9   
17             1                    1             9   use RowDiff;
               1                                  3   
               1                                 10   
18             1                    1            10   use ChangeHandler;
               1                                  3   
               1                                 10   
19             1                    1            11   use MaatkitTest;
               1                                  4   
               1                                 41   
20                                                    
21             1                                 11   my $q = new Quoter();
22             1                                 23   my @rows;
23                                                    
24                                                    throws_ok(
25             1                    1            18      sub { new TableSyncStream() },
26             1                                 22      qr/I need a Quoter/,
27                                                       'Quoter required'
28                                                    );
29             1                                 14   my $t = new TableSyncStream(
30                                                       Quoter => $q,
31                                                    );
32                                                    
33                                                    my $ch = new ChangeHandler(
34                                                       Quoter    => $q,
35                                                       right_db  => 'test',
36                                                       right_tbl => 'foo',
37                                                       left_db   => 'test',
38                                                       left_tbl  => 'foo',
39                                                       replace   => 0,
40             1                    2            20      actions   => [ sub { push @rows, $_[0] }, ],
               2                                526   
41                                                       queue     => 0,
42                                                    );
43                                                    
44             1                                219   $t->prepare_to_sync(
45                                                       ChangeHandler   => $ch,
46                                                       cols            => [qw(a b c)],
47                                                       buffer_in_mysql => 1,
48                                                    );
49             1                                  6   is(
50                                                       $t->get_sql(
51                                                          where    => 'foo=1',
52                                                          database => 'test',
53                                                          table    => 'foo',
54                                                       ),
55                                                       "SELECT SQL_BUFFER_RESULT `a`, `b`, `c` FROM `test`.`foo` WHERE foo=1",
56                                                       'Got SQL with SQL_BUFFER_RESULT OK',
57                                                    );
58                                                    
59                                                    
60             1                                 10   $t->prepare_to_sync(
61                                                       ChangeHandler   => $ch,
62                                                       cols            => [qw(a b c)],
63                                                    );
64             1                                  6   is(
65                                                       $t->get_sql(
66                                                          where    => 'foo=1',
67                                                          database => 'test',
68                                                          table    => 'foo',
69                                                       ),
70                                                       "SELECT `a`, `b`, `c` FROM `test`.`foo` WHERE foo=1",
71                                                       'Got SQL OK',
72                                                    );
73                                                    
74                                                    # Changed from undef to 0 due to r4802.
75             1                                  6   is( $t->done, 0, 'Not done yet' );
76                                                    
77             1                                  8   my $d = new RowDiff( dbh => 1 );
78             1                                 44   $d->compare_sets(
79                                                       left_sth => new MockSth(
80                                                          { a => 1, b => 2, c => 3 },
81                                                          { a => 2, b => 2, c => 3 },
82                                                          { a => 3, b => 2, c => 3 },
83                                                          # { a => 4, b => 2, c => 3 },
84                                                       ),
85                                                       right_sth => new MockSth(
86                                                          # { a => 1, b => 2, c => 3 },
87                                                          { a => 2, b => 2, c => 3 },
88                                                          { a => 3, b => 2, c => 3 },
89                                                          { a => 4, b => 2, c => 3 },
90                                                       ),
91                                                       syncer     => $t,
92                                                       tbl_struct => {},
93                                                    );
94                                                    
95             1                                 17   is_deeply(
96                                                       \@rows,
97                                                       [
98                                                       "INSERT INTO `test`.`foo`(`a`, `b`, `c`) VALUES ('1', '2', '3')",
99                                                       "DELETE FROM `test`.`foo` WHERE `a`='4' AND `b`='2' AND `c`='3' LIMIT 1",
100                                                      ],
101                                                      'rows from handler',
102                                                   );


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
---------- ----- --------------------
BEGIN          1 TableSyncStream.t:10
BEGIN          1 TableSyncStream.t:11
BEGIN          1 TableSyncStream.t:12
BEGIN          1 TableSyncStream.t:14
BEGIN          1 TableSyncStream.t:15
BEGIN          1 TableSyncStream.t:16
BEGIN          1 TableSyncStream.t:17
BEGIN          1 TableSyncStream.t:18
BEGIN          1 TableSyncStream.t:19
BEGIN          1 TableSyncStream.t:4 
BEGIN          1 TableSyncStream.t:9 
__ANON__       1 TableSyncStream.t:25
__ANON__       2 TableSyncStream.t:40


