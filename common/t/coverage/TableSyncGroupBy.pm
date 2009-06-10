---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...ommon/TableSyncGroupBy.pm   85.7   70.0   50.0   80.0    n/a  100.0   82.2
Total                          85.7   70.0   50.0   80.0    n/a  100.0   82.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncGroupBy.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:35 2009
Finish:       Wed Jun 10 17:21:35 2009

/home/daniel/dev/maatkit/common/TableSyncGroupBy.pm

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
18                                                    # TableSyncGroupBy package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    package TableSyncGroupBy;
21                                                    # This package syncs tables without primary keys by doing an all-columns GROUP
22                                                    # BY with a count, and then streaming through the results to see how many of
23                                                    # each group exist.
24                                                    
25             1                    1             9   use strict;
               1                                  3   
               1                                  7   
26             1                    1           187   use warnings FATAL => 'all';
               1                                  3   
               1                                  7   
27                                                    
28             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
29                                                    
30             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
31                                                    
32                                                    # Arguments:
33                                                    # * handler ChangeHandler
34                                                    sub new {
35             3                    3            67      my ( $class, %args ) = @_;
36             3                                 22      foreach my $arg ( qw(handler cols) ) {
37             5    100                          23         die "I need a $arg argument" unless defined $args{$arg};
38                                                       }
39             2                                  8      $args{count_col} = '__maatkit_count';
40             2                                 15      while ( $args{struct}->{is_col}->{$args{count_col}} ) {
41                                                          # Prepend more _ until not a column.
42    ***      0                                  0         $args{count_col} = "_$args{count_col}";
43                                                       }
44             2                                  4      MKDEBUG && _d('COUNT column will be named', $args{count_col});
45             2                                 25      return bless { %args }, $class;
46                                                    }
47                                                    
48                                                    # Arguments:
49                                                    # * quoter   Quoter
50                                                    # * database Database name
51                                                    # * table    Table name
52                                                    # * where    WHERE clause
53                                                    sub get_sql {
54             2                    2            14      my ( $self, %args ) = @_;
55             2                                  9      my $cols = join(', ', map { $args{quoter}->quote($_) } @{$self->{cols}});
               6                                 39   
               2                                  8   
56    ***      2    100     50                   25      return "SELECT"
57                                                          . ($self->{bufferinmysql} ? ' SQL_BUFFER_RESULT' : '')
58                                                          . " $cols, COUNT(*) AS $self->{count_col}"
59                                                          . ' FROM ' . $args{quoter}->quote(@args{qw(database table)})
60                                                          . ' WHERE ' . ( $args{where} || '1=1' )
61                                                          . " GROUP BY $cols ORDER BY $cols";
62                                                    }
63                                                    
64                                                    # The same row means that the key columns are equal, so there are rows with the
65                                                    # same columns in both tables; but there are different numbers of rows.  So we
66                                                    # must either delete or insert the required number of rows to the table.
67                                                    sub same_row {
68             2                    2             8      my ( $self, $lr, $rr ) = @_;
69             2                                  8      my $cc = $self->{count_col};
70             2                                  6      my $lc = $lr->{$cc};
71             2                                  7      my $rc = $rr->{$cc};
72             2                                  6      my $diff = abs($lc - $rc);
73    ***      2     50                           8      return unless $diff;
74             2                                 12      $lr = { %$lr };
75             2                                  8      delete $lr->{$cc};
76             2                                  8      $rr = { %$rr };
77             2                                  7      delete $rr->{$cc};
78             2                                  7      foreach my $i ( 1 .. $diff ) {
79             3    100                          11         if ( $lc > $rc ) {
80             1                                 17            $self->{handler}->change('INSERT', $lr, $self->key_cols());
81                                                          }
82                                                          else {
83             2                                  8            $self->{handler}->change('DELETE', $rr, $self->key_cols());
84                                                          }
85                                                       }
86                                                    }
87                                                    
88                                                    # Insert into the table the specified number of times.
89                                                    sub not_in_right {
90             1                    1             4      my ( $self, $lr ) = @_;
91             1                                  5      $lr = { %$lr };
92             1                                  5      my $cnt = delete $lr->{$self->{count_col}};
93             1                                  4      foreach my $i ( 1 .. $cnt ) {
94             2                                 10         $self->{handler}->change('INSERT', $lr, $self->key_cols());
95                                                       }
96                                                    }
97                                                    
98                                                    # Delete from the table the specified number of times.
99                                                    sub not_in_left {
100            1                    1             4      my ( $self, $rr ) = @_;
101            1                                  6      $rr = { %$rr };
102            1                                  4      my $cnt = delete $rr->{$self->{count_col}};
103            1                                  8      foreach my $i ( 1 .. $cnt ) {
104            1                                  8         $self->{handler}->change('DELETE', $rr, $self->key_cols());
105                                                      }
106                                                   }
107                                                   
108                                                   sub done_with_rows {
109            1                    1             4      my ( $self ) = @_;
110            1                                  6      $self->{done} = 1;
111                                                   }
112                                                   
113                                                   sub done {
114            1                    1             4      my ( $self ) = @_;
115            1                                  6      return $self->{done};
116                                                   }
117                                                   
118                                                   sub key_cols {
119            9                    9            31      my ( $self ) = @_;
120            9                                 53      return $self->{cols};
121                                                   }
122                                                   
123                                                   # Do any required setup before executing the SQL (such as setting up user
124                                                   # variables for checksum queries).
125                                                   sub prepare {
126   ***      0                    0                    my ( $self, $dbh ) = @_;
127                                                   }
128                                                   
129                                                   # Return 1 if you have changes yet to make and you don't want the TableSyncer to
130                                                   # commit your transaction or release your locks.
131                                                   sub pending_changes {
132   ***      0                    0                    my ( $self ) = @_;
133                                                   }
134                                                   
135                                                   sub _d {
136   ***      0                    0                    my ($package, undef, $line) = caller 0;
137   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
138   ***      0                                              map { defined $_ ? $_ : 'undef' }
139                                                           @_;
140   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
141                                                   }
142                                                   
143                                                   1;
144                                                   
145                                                   # ###########################################################################
146                                                   # End TableSyncGroupBy package
147                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
37           100      1      4   unless defined $args{$arg}
56           100      1      1   $$self{'bufferinmysql'} ? :
73    ***     50      0      2   unless $diff
79           100      1      2   if ($lc > $rc) { }
137   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
56    ***     50      2      0   $args{'where'} || '1=1'


Covered Subroutines
-------------------

Subroutine      Count Location                                               
--------------- ----- -------------------------------------------------------
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:25 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:26 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:28 
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:30 
done                1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:114
done_with_rows      1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:109
get_sql             2 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:54 
key_cols            9 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:119
new                 3 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:35 
not_in_left         1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:100
not_in_right        1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:90 
same_row            2 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:68 

Uncovered Subroutines
---------------------

Subroutine      Count Location                                               
--------------- ----- -------------------------------------------------------
_d                  0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:136
pending_changes     0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:132
prepare             0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:126


