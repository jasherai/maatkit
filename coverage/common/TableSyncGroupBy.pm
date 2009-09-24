---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...ommon/TableSyncGroupBy.pm   80.8   66.7   50.0   65.0    n/a  100.0   75.9
Total                          80.8   66.7   50.0   65.0    n/a  100.0   75.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncGroupBy.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Sep 24 23:37:33 2009
Finish:       Thu Sep 24 23:37:33 2009

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
18                                                    # TableSyncGroupBy package $Revision: 4741 $
19                                                    # ###########################################################################
20                                                    package TableSyncGroupBy;
21                                                    # This package syncs tables without primary keys by doing an all-columns GROUP
22                                                    # BY with a count, and then streaming through the results to see how many of
23                                                    # each group exist.
24                                                    
25             1                    1             9   use strict;
               1                                  3   
               1                                  6   
26             1                    1           100   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
27                                                    
28             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
29                                                    
30             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
31                                                    
32                                                    sub new {
33             2                    2            68      my ( $class, %args ) = @_;
34             2                                  9      foreach my $arg ( qw(Quoter) ) {
35             2    100                          10         die "I need a $arg argument" unless $args{$arg};
36                                                       }
37             1                                  6      my $self = { %args };
38             1                                 15      return bless $self, $class;
39                                                    }
40                                                    
41                                                    sub name {
42    ***      0                    0             0      return 'GroupBy';
43                                                    }
44                                                    
45                                                    sub can_sync {
46    ***      0                    0             0      return 1;  # We can sync anything.
47                                                    }
48                                                    
49                                                    sub prepare_to_sync {
50             2                    2            26      my ( $self, %args ) = @_;
51             2                                 11      my @required_args = qw(tbl_struct cols ChangeHandler);
52             2                                  6      foreach my $arg ( @required_args ) {
53    ***      6     50                          36         die "I need a $arg argument" unless defined $args{$arg};
54                                                       }
55                                                    
56             2                                  8      $self->{cols}            = $args{cols};
57             2                                  8      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
58             2                                  7      $self->{ChangeHandler}   = $args{ChangeHandler};
59                                                    
60             2                                 10      $self->{count_col} = '__maatkit_count';
61             2                                 13      while ( $args{tbl_struct}->{is_col}->{$self->{count_col}} ) {
62                                                          # Prepend more _ until not a column.
63    ***      0                                  0         $self->{count_col} = "_$self->{count_col}";
64                                                       }
65             2                                  6      MKDEBUG && _d('COUNT column will be named', $self->{count_col});
66                                                    
67             2                                  9      return;
68                                                    }
69                                                    
70                                                    sub uses_checksum {
71    ***      0                    0             0      return 0;  # We don't need checksum queries.
72                                                    }
73                                                    
74                                                    sub set_checksum_queries {
75    ***      0                    0             0      return;  # This shouldn't be called, but just in case.
76                                                    }
77                                                    
78                                                    sub prepare_sync_cycle {
79    ***      0                    0             0      my ( $self, $host ) = @_;
80    ***      0                                  0      return;
81                                                    }
82                                                    
83                                                    sub get_sql {
84             2                    2            20      my ( $self, %args ) = @_;
85             2                                  8      my $cols = join(', ', map { $self->{Quoter}->quote($_) } @{$self->{cols}});
               6                                 25   
               2                                  9   
86    ***      2    100     50                   26      return "SELECT"
87                                                          . ($self->{buffer_in_mysql} ? ' SQL_BUFFER_RESULT' : '')
88                                                          . " $cols, COUNT(*) AS $self->{count_col}"
89                                                          . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
90                                                          . ' WHERE ' . ( $args{where} || '1=1' )
91                                                          . " GROUP BY $cols ORDER BY $cols";
92                                                    }
93                                                    
94                                                    # The same row means that the key columns are equal, so there are rows with the
95                                                    # same columns in both tables; but there are different numbers of rows.  So we
96                                                    # must either delete or insert the required number of rows to the table.
97                                                    sub same_row {
98             2                    2             9      my ( $self, $lr, $rr ) = @_;
99             2                                  7      my $cc = $self->{count_col};
100            2                                  6      my $lc = $lr->{$cc};
101            2                                  7      my $rc = $rr->{$cc};
102            2                                  7      my $diff = abs($lc - $rc);
103   ***      2     50                           7      return unless $diff;
104            2                                 12      $lr = { %$lr };
105            2                                 10      delete $lr->{$cc};
106            2                                  9      $rr = { %$rr };
107            2                                  6      delete $rr->{$cc};
108            2                                  9      foreach my $i ( 1 .. $diff ) {
109            3    100                          12         if ( $lc > $rc ) {
110            1                                  5            $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
111                                                         }
112                                                         else {
113            2                                 10            $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
114                                                         }
115                                                      }
116                                                   }
117                                                   
118                                                   # Insert into the table the specified number of times.
119                                                   sub not_in_right {
120            1                    1             4      my ( $self, $lr ) = @_;
121            1                                  6      $lr = { %$lr };
122            1                                  7      my $cnt = delete $lr->{$self->{count_col}};
123            1                                  5      foreach my $i ( 1 .. $cnt ) {
124            2                                  8         $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
125                                                      }
126                                                   }
127                                                   
128                                                   # Delete from the table the specified number of times.
129                                                   sub not_in_left {
130            1                    1             4      my ( $self, $rr ) = @_;
131            1                                  6      $rr = { %$rr };
132            1                                  5      my $cnt = delete $rr->{$self->{count_col}};
133            1                                  4      foreach my $i ( 1 .. $cnt ) {
134            1                                  5         $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
135                                                      }
136                                                   }
137                                                   
138                                                   sub done_with_rows {
139            1                    1             4      my ( $self ) = @_;
140            1                                  6      $self->{done} = 1;
141                                                   }
142                                                   
143                                                   sub done {
144            1                    1             4      my ( $self ) = @_;
145            1                                  6      return $self->{done};
146                                                   }
147                                                   
148                                                   sub key_cols {
149            9                    9            29      my ( $self ) = @_;
150            9                                 47      return $self->{cols};
151                                                   }
152                                                   
153                                                   # Return 1 if you have changes yet to make and you don't want the TableSyncer to
154                                                   # commit your transaction or release your locks.
155                                                   sub pending_changes {
156   ***      0                    0                    my ( $self ) = @_;
157   ***      0                                         return;
158                                                   }
159                                                   
160                                                   sub _d {
161   ***      0                    0                    my ($package, undef, $line) = caller 0;
162   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
163   ***      0                                              map { defined $_ ? $_ : 'undef' }
164                                                           @_;
165   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
166                                                   }
167                                                   
168                                                   1;
169                                                   
170                                                   # ###########################################################################
171                                                   # End TableSyncGroupBy package
172                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
35           100      1      1   unless $args{$arg}
53    ***     50      0      6   unless defined $args{$arg}
86           100      1      1   $$self{'buffer_in_mysql'} ? :
103   ***     50      0      2   unless $diff
109          100      1      2   if ($lc > $rc) { }
162   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
86    ***     50      2      0   $args{'where'} || '1=1'


Covered Subroutines
-------------------

Subroutine           Count Location                                               
-------------------- ----- -------------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:25 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:26 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:28 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:30 
done                     1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:144
done_with_rows           1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:139
get_sql                  2 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:84 
key_cols                 9 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:149
new                      2 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:33 
not_in_left              1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:130
not_in_right             1 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:120
prepare_to_sync          2 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:50 
same_row                 2 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:98 

Uncovered Subroutines
---------------------

Subroutine           Count Location                                               
-------------------- ----- -------------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:161
can_sync                 0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:46 
name                     0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:42 
pending_changes          0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:156
prepare_sync_cycle       0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:79 
set_checksum_queries     0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:75 
uses_checksum            0 /home/daniel/dev/maatkit/common/TableSyncGroupBy.pm:71 


