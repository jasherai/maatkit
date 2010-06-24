---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/MockSyncStream.pm   85.7   78.6   60.0   82.4    0.0    1.0   74.6
MockSyncStream.t              100.0   50.0   33.3  100.0    n/a   99.0   95.3
Total                          92.5   72.2   50.0   90.6    0.0  100.0   83.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:05 2010
Finish:       Thu Jun 24 19:35:05 2010

Run:          MockSyncStream.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:07 2010
Finish:       Thu Jun 24 19:35:08 2010

/home/daniel/dev/maatkit/common/MockSyncStream.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009 Percona Inc.
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
18                                                    # MockSyncStream package $Revision: 5697 $
19                                                    # ###########################################################################
20                                                    package MockSyncStream;
21                                                    
22                                                    # This package implements a special, mock version of TableSyncStream.
23                                                    # It's used by mk-upgrade to quickly compare result sets for any differences.
24                                                    # If any are found, mk-upgrade writes all remaining rows to an outfile.
25                                                    # This causes RowDiff::compare_sets() to terminate early.  So we don't actually
26                                                    # sync anything.  Unlike TableSyncStream, we're not working with a table but an
27                                                    # arbitrary query executed on two servers.
28                                                    
29             1                    1             5   use strict;
               1                                  2   
               1                                 11   
30             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
31                                                    
32             1                    1             9   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
33                                                    
34    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 18   
35                                                    
36                                                    sub new {
37    ***      1                    1      0     10      my ( $class, %args ) = @_;
38             1                                  6      foreach my $arg ( qw(query cols same_row not_in_left not_in_right) ) {
39    ***      5     50                          24         die "I need a $arg argument" unless defined $args{$arg};
40                                                       }
41             1                                 15      return bless { %args }, $class;
42                                                    }
43                                                    
44                                                    sub get_sql {
45    ***      1                    1      0      4      my ( $self ) = @_;
46             1                                 10      return $self->{query};
47                                                    }
48                                                    
49                                                    sub same_row {
50    ***      2                    2      0    405      my ( $self, %args ) = @_;
51             2                                 15      return $self->{same_row}->($args{lr}, $args{rr});
52                                                    }
53                                                    
54                                                    sub not_in_right {
55    ***      1                    1      0    250      my ( $self, %args ) = @_;
56             1                                  9      return $self->{not_in_right}->($args{lr});
57                                                    }
58                                                    
59                                                    sub not_in_left {
60    ***      1                    1      0    107      my ( $self, %args ) = @_;
61             1                                 20      return $self->{not_in_left}->($args{rr});
62                                                    }
63                                                    
64                                                    sub done_with_rows {
65    ***      1                    1      0     65      my ( $self ) = @_;
66             1                                  7      $self->{done} = 1;
67                                                    }
68                                                    
69                                                    sub done {
70    ***      1                    1      0      5      my ( $self ) = @_;
71             1                                  7      return $self->{done};
72                                                    }
73                                                    
74                                                    sub key_cols {
75    ***      1                    1      0     59      my ( $self ) = @_;
76             1                                  6      return $self->{cols};
77                                                    }
78                                                    
79                                                    # Do any required setup before executing the SQL (such as setting up user
80                                                    # variables for checksum queries).
81                                                    sub prepare {
82    ***      0                    0      0      0      my ( $self, $dbh ) = @_;
83    ***      0                                  0      return;
84                                                    }
85                                                    
86                                                    # Return 1 if you have changes yet to make and you don't want the MockSyncer to
87                                                    # commit your transaction or release your locks.
88                                                    sub pending_changes {
89    ***      0                    0      0      0      my ( $self ) = @_;
90    ***      0                                  0      return;
91                                                    }
92                                                    
93                                                    # RowDiff::key_cmp() requires $tlb and $key_cols but we're syncing query
94                                                    # result sets not tables so we can't use TableParser.  The following sub
95                                                    # uses sth attributes to return a pseudo table struct for the query's columns.
96                                                    sub get_result_set_struct {
97    ***      1                    1      0     10      my ( $dbh, $sth ) = @_;
98             1                                  8      my @cols     = @{$sth->{NAME}};
               1                                112   
99             1                                 31      my @types    = map { $dbh->type_info($_)->{TYPE_NAME} } @{$sth->{TYPE}};
              10                                 35   
               1                                 20   
100            1    100                         915      my @nullable = map { $dbh->type_info($_)->{NULLABLE} == 1 ? 1 : 0 } @{$sth->{TYPE}};
              10                                 31   
               1                                 20   
101            1                                904      my @p = @{$sth->{PRECISION}};
               1                                 27   
102            1                                 23      my @s = @{$sth->{SCALE}};
               1                                 14   
103                                                   
104            1                                 17      my $struct   = {
105                                                         cols => \@cols, 
106                                                         # collation_for => {},  RowDiff::key_cmp() may need this.
107                                                      };
108                                                   
109            1                                 17      for my $i ( 0..$#cols ) {
110           10                                 51         my $col  = $cols[$i];
111           10                                 51         my $type = $types[$i];
112           10                                 80         $struct->{is_col}->{$col}      = 1;
113           10                                 62         $struct->{col_posn}->{$col}    = $i;
114           10                                 65         $struct->{type_for}->{$col}    = $type;
115           10                                 67         $struct->{is_nullable}->{$col} = $nullable[$i];
116           10    100                         140         $struct->{is_numeric}->{$col} 
117                                                            = ($type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ? 1 : 0);
118   ***     10    100     66                  259         $struct->{size}->{$col}
                    100                               
                    100                               
119                                                            = ($type =~ m/(?:float|double)/)           ? "($s[$i],$p[$i])"
120                                                            : ($type =~ m/(?:decimal)/)                ? "($p[$i],$s[$i])"
121                                                            : ($type =~ m/(?:char|varchar)/ && $p[$i]) ? "($p[$i])"
122                                                            :                                            undef;
123                                                      }
124                                                   
125            1                                101      return $struct;
126                                                   }
127                                                   
128                                                   # Transforms a row fetched with DBI::fetchrow_hashref() into a
129                                                   # row as if it were fetched with DBI::fetchrow_arrayref().  That is:
130                                                   # the hash values (i.e. column values) are returned as an arrayref
131                                                   # in the correct column order (because hashes are randomly ordered).
132                                                   # This is used in mk-upgrade.
133                                                   sub as_arrayref {
134   ***      1                    1      0      9      my ( $sth, $row ) = @_;
135            1                                  8      my @cols = @{$sth->{NAME}};
               1                                 12   
136            1                                 21      my @row  = @{$row}{@cols};
               1                                 14   
137            1                                 27      return \@row;
138                                                   }
139                                                   
140                                                   sub _d {
141   ***      0                    0                    my ($package, undef, $line) = caller 0;
142   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
143   ***      0                                              map { defined $_ ? $_ : 'undef' }
144                                                           @_;
145   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
146                                                   }
147                                                   
148                                                   1;
149                                                   
150                                                   # ###########################################################################
151                                                   # End MockSyncStream package
152                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***     50      0      5   unless defined $args{$arg}
100          100      8      2   $dbh->type_info($_)->{'NULLABLE'} == 1 ? :
116          100      4      6   $type =~ /(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ? :
118          100      3      5   $type =~ /(?:char|varchar)/ && $p[$i] ? :
             100      1      8   $type =~ /(?:decimal)/ ? :
             100      1      9   $type =~ /(?:float|double)/ ? :
142   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
118   ***     66      5      0      3   $type =~ /(?:char|varchar)/ && $p[$i]

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
34    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine            Count Pod Location                                             
--------------------- ----- --- -----------------------------------------------------
BEGIN                     1     /home/daniel/dev/maatkit/common/MockSyncStream.pm:29 
BEGIN                     1     /home/daniel/dev/maatkit/common/MockSyncStream.pm:30 
BEGIN                     1     /home/daniel/dev/maatkit/common/MockSyncStream.pm:32 
BEGIN                     1     /home/daniel/dev/maatkit/common/MockSyncStream.pm:34 
as_arrayref               1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:134
done                      1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:70 
done_with_rows            1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:65 
get_result_set_struct     1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:97 
get_sql                   1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:45 
key_cols                  1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:75 
new                       1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:37 
not_in_left               1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:60 
not_in_right              1   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:55 
same_row                  2   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:50 

Uncovered Subroutines
---------------------

Subroutine            Count Pod Location                                             
--------------------- ----- --- -----------------------------------------------------
_d                        0     /home/daniel/dev/maatkit/common/MockSyncStream.pm:141
pending_changes           0   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:89 
prepare                   0   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:82 


MockSyncStream.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            43      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                 10      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            15   use strict;
               1                                  2   
               1                                  8   
10             1                    1             9   use warnings FATAL => 'all';
               1                                  3   
               1                                  7   
11             1                    1            16   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
12             1                    1            10   use Test::More tests => 5;
               1                                  4   
               1                                 12   
13                                                    
14             1                    1            11   use MockSyncStream;
               1                                  3   
               1                                 11   
15             1                    1            10   use Quoter;
               1                                  3   
               1                                100   
16             1                    1             9   use MockSth;
               1                                  3   
               1                                  9   
17             1                    1            10   use RowDiff;
               1                                  4   
               1                                 14   
18             1                    1            14   use MaatkitTest;
               1                                  4   
               1                                 40   
19                                                    
20             1                                 14   my $rd = new RowDiff( dbh => 1 );
21             1                                 42   my @rows;
22                                                    
23                                                    sub same_row {
24             2                    2            10      push @rows, 'same';
25                                                    }
26                                                    sub not_in_left {
27             1                    1             7      push @rows, 'not in left';
28                                                    }
29                                                    sub not_in_right {
30             1                    1             7      push @rows, 'not in right';
31                                                    }
32                                                    
33             1                                 18   my $mss = new MockSyncStream(
34                                                       query        => 'SELECT a, b, c FROM foo WHERE id = 1',
35                                                       cols         => [qw(a b c)],
36                                                       same_row     => \&same_row,
37                                                       not_in_left  => \&not_in_left,
38                                                       not_in_right => \&not_in_right,
39                                                    );
40                                                    
41             1                                  6   is(
42                                                       $mss->get_sql(),
43                                                       'SELECT a, b, c FROM foo WHERE id = 1',
44                                                       'get_sql()',
45                                                    );
46                                                    
47             1                                  9   is( $mss->done(), undef, 'Not done yet' );
48                                                    
49             1                                  4   @rows = ();
50             1                                 20   $rd->compare_sets(
51                                                       left_sth => new MockSth(
52                                                          { a => 1, b => 2, c => 3 },
53                                                          { a => 2, b => 2, c => 3 },
54                                                          { a => 3, b => 2, c => 3 },
55                                                          # { a => 4, b => 2, c => 3 },
56                                                       ),
57                                                       right_sth => new MockSth(
58                                                          # { a => 1, b => 2, c => 3 },
59                                                          { a => 2, b => 2, c => 3 },
60                                                          { a => 3, b => 2, c => 3 },
61                                                          { a => 4, b => 2, c => 3 },
62                                                       ),
63                                                       syncer     => $mss,
64                                                       tbl_struct => {},
65                                                    );
66             1                                 23   is_deeply(
67                                                       \@rows,
68                                                       [
69                                                          'not in right',
70                                                          'same',
71                                                          'same',
72                                                          'not in left',
73                                                       ],
74                                                       'rows from handler',
75                                                    );
76                                                    
77                                                    # #############################################################################
78                                                    # Test online stuff, e.g. get_cols_and_struct().
79                                                    # #############################################################################
80             1                    1            23   use DSNParser;
               1                                  3   
               1                                 12   
81             1                    1            13   use Sandbox;
               1                                  3   
               1                                 13   
82             1                                 17   my $dp  = new DSNParser(opts=>$dsn_opts);
83             1                                238   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
84             1                                 58   my $dbh = $sb->get_dbh_for('master');
85                                                    
86    ***      1     50                           7   SKIP: {
87             1                                435      skip 'Cannot connect to sandbox mater', 1
88                                                          unless $dbh;
89                                                    
90             1                              14974      diag(`/tmp/12345/use -e 'CREATE DATABASE test' 2>/dev/null`);
91             1                             270938      diag(`/tmp/12345/use < $trunk/common/t/samples/col_types.sql`);
92                                                    
93             1                                  8      my $sth = $dbh->prepare('SELECT * FROM test.col_types_1');
94             1                                444      $sth->execute();
95             1                                 25      is_deeply(
96                                                          MockSyncStream::get_result_set_struct($dbh, $sth),
97                                                          {
98                                                             cols => [
99                                                                'id',
100                                                               'i',
101                                                               'f',
102                                                               'd',
103                                                               'dt',
104                                                               'ts',
105                                                               'c',
106                                                               'c2',
107                                                               'v',
108                                                               't',
109                                                            ],
110                                                            type_for => {
111                                                               id => 'integer',
112                                                               i  => 'integer',
113                                                               f  => 'float',
114                                                               d  => 'decimal',
115                                                               dt => 'timestamp',
116                                                               ts => 'timestamp',
117                                                               c  => 'char',
118                                                               c2 => 'char',
119                                                               v  => 'varchar',
120                                                               t  => 'blob',
121                                                            },
122                                                            is_numeric => {
123                                                               id => 1,
124                                                               i  => 1,
125                                                               f  => 1,
126                                                               d  => 1,
127                                                               dt => 0,
128                                                               ts => 0,
129                                                               c  => 0,
130                                                               c2 => 0,
131                                                               v  => 0,
132                                                               t  => 0,
133                                                            },
134                                                            is_col => {
135                                                               id => 1,
136                                                               i  => 1,
137                                                               f  => 1,
138                                                               d  => 1,
139                                                               dt => 1,
140                                                               ts => 1,
141                                                               c  => 1,
142                                                               c2 => 1,
143                                                               v  => 1,
144                                                               t  => 1,
145                                                            },
146                                                            col_posn => {
147                                                               id => 0,
148                                                               i  => 1,
149                                                               f  => 2,
150                                                               d  => 3,
151                                                               dt => 4,
152                                                               ts => 5,
153                                                               c  => 6,
154                                                               c2 => 7,
155                                                               v  => 8,
156                                                               t  => 9,
157                                                            },
158                                                            is_nullable => {
159                                                               id => 1,
160                                                               i  => 1,
161                                                               f  => 1,
162                                                               d  => 1,
163                                                               dt => 0,
164                                                               ts => 0,
165                                                               c  => 1,
166                                                               c2 => 1,  # it's really not but this is a sth limitation
167                                                               v  => 1,
168                                                               t  => 1,
169                                                            },
170                                                            size => {
171                                                               id => undef,
172                                                               i  => undef,
173                                                               f  => '(31,12)',
174                                                               d  => '(7,2)',
175                                                               dt => undef,
176                                                               ts => undef,
177                                                               c  => '(1)',
178                                                               c2 => '(15)',
179                                                               v  => '(32)',
180                                                               t  => undef,
181                                                            },
182                                                         },
183                                                         'Gets result set struct from sth attribs'
184                                                      );
185                                                   
186            1                                  5      $sth = $dbh->prepare('SELECT v, c, t, id, i, f, d FROM test.col_types_1');
187            1                               9222      $sth->execute();
188            1                                 27      my $row = $sth->fetchrow_hashref();
189            1                                 64      is_deeply(
190                                                         MockSyncStream::as_arrayref($sth, $row),
191                                                         ['hello world','c','this is text',1,1,3.14,5.08,],
192                                                         'as_arrayref()'
193                                                      );
194                                                   
195            1                                 42      $sth->finish();
196            1                                 21      $sb->wipe_clean($dbh);
197            1                             106538      $dbh->disconnect();
198                                                   };
199                                                   
200                                                   # #############################################################################
201                                                   # Done.
202                                                   # #############################################################################
203            1                                  5   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
86    ***     50      0      1   unless $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine   Count Location           
------------ ----- -------------------
BEGIN            1 MockSyncStream.t:10
BEGIN            1 MockSyncStream.t:11
BEGIN            1 MockSyncStream.t:12
BEGIN            1 MockSyncStream.t:14
BEGIN            1 MockSyncStream.t:15
BEGIN            1 MockSyncStream.t:16
BEGIN            1 MockSyncStream.t:17
BEGIN            1 MockSyncStream.t:18
BEGIN            1 MockSyncStream.t:4 
BEGIN            1 MockSyncStream.t:80
BEGIN            1 MockSyncStream.t:81
BEGIN            1 MockSyncStream.t:9 
not_in_left      1 MockSyncStream.t:27
not_in_right     1 MockSyncStream.t:30
same_row         2 MockSyncStream.t:24


