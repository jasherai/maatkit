---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/MockSyncStream.pm   85.7   70.0    n/a   82.4    n/a  100.0   83.5
Total                          85.7   70.0    n/a   82.4    n/a  100.0   83.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MockSyncStream.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:05 2009
Finish:       Sat Aug 29 15:03:05 2009

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
18                                                    # MockSyncStream package $Revision: 4559 $
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
29             1                    1             8   use strict;
               1                                  3   
               1                                  8   
30             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                118   
31                                                    
32             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
33                                                    
34             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
35                                                    
36                                                    sub new {
37             1                    1            28      my ( $class, %args ) = @_;
38             1                                  4      foreach my $arg ( qw(query cols same_row not_in_left not_in_right) ) {
39    ***      5     50                          25         die "I need a $arg argument" unless defined $args{$arg};
40                                                       }
41             1                                 16      return bless { %args }, $class;
42                                                    }
43                                                    
44                                                    sub get_sql {
45             1                    1            10      my ( $self ) = @_;
46             1                                  9      return $self->{query};
47                                                    }
48                                                    
49                                                    sub same_row {
50             2                    2            13      my ( $self, $lr, $rr ) = @_;
51             2                                 15      return $self->{same_row}->($lr, $rr);
52                                                    }
53                                                    
54                                                    sub not_in_right {
55             1                    1             5      my ( $self, $lr ) = @_;
56             1                                  6      return $self->{not_in_right}->($lr);
57                                                    }
58                                                    
59                                                    sub not_in_left {
60             1                    1             5      my ( $self, $rr ) = @_;
61             1                                  4      return $self->{not_in_left}->($rr);
62                                                    }
63                                                    
64                                                    sub done_with_rows {
65             1                    1             4      my ( $self ) = @_;
66             1                                 10      $self->{done} = 1;
67                                                    }
68                                                    
69                                                    sub done {
70             1                    1             5      my ( $self ) = @_;
71             1                                  7      return $self->{done};
72                                                    }
73                                                    
74                                                    sub key_cols {
75             3                    3            10      my ( $self ) = @_;
76             3                                 16      return $self->{cols};
77                                                    }
78                                                    
79                                                    # Do any required setup before executing the SQL (such as setting up user
80                                                    # variables for checksum queries).
81                                                    sub prepare {
82    ***      0                    0             0      my ( $self, $dbh ) = @_;
83    ***      0                                  0      return;
84                                                    }
85                                                    
86                                                    # Return 1 if you have changes yet to make and you don't want the MockSyncer to
87                                                    # commit your transaction or release your locks.
88                                                    sub pending_changes {
89    ***      0                    0             0      my ( $self ) = @_;
90    ***      0                                  0      return;
91                                                    }
92                                                    
93                                                    # RowDiff::key_cmp() requires $tlb and $key_cols but we're syncing query
94                                                    # result sets not tables so we can't use TableParser.  The following sub
95                                                    # uses sth attributes to return a pseudo table struct for the query's columns.
96                                                    sub get_result_set_struct {
97             1                    1           653      my ( $dbh, $sth ) = @_;
98             1                                  4      my @cols     = @{$sth->{NAME}};
               1                                 44   
99             1                                 20      my @types    = map { $dbh->type_info($_)->{TYPE_NAME} } @{$sth->{TYPE}};
               9                                 17   
               1                                  9   
100            1    100                          26      my @nullable = map { $dbh->type_info($_)->{NULLABLE} == 1 ? 1 : 0 } @{$sth->{TYPE}};
               9                                 18   
               1                                  8   
101            1                                 23      my @p = @{$sth->{PRECISION}};
               1                                 11   
102            1                                  7      my @s = @{$sth->{SCALE}};
               1                                  7   
103                                                   
104            1                                 13      my $struct   = {
105                                                         cols => \@cols, 
106                                                         # collation_for => {},  RowDiff::key_cmp() may need this.
107                                                      };
108                                                   
109            1                                  8      for my $i ( 0..$#cols ) {
110            9                                 28         my $col  = $cols[$i];
111            9                                 28         my $type = $types[$i];
112            9                                 39         $struct->{is_col}->{$col}      = 1;
113            9                                 34         $struct->{col_posn}->{$col}    = $i;
114            9                                 35         $struct->{type_for}->{$col}    = $type;
115            9                                 33         $struct->{is_nullable}->{$col} = $nullable[$i];
116            9    100                          72         $struct->{is_numeric}->{$col} 
117                                                            = ($type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ? 1 : 0);
118            9    100                          67         $struct->{precision}->{$col}
119                                                            = ($type =~ m/(?:float|double|decimal)/ ? "($p[$i],$s[$i])" : undef);
120                                                      }
121                                                   
122            1                                 46      return $struct;
123                                                   }
124                                                   
125                                                   # Transforms a row fetched with DBI::fetchrow_hashref() into a
126                                                   # row as if it were fetched with DBI::fetchrow_arrayref().  That is:
127                                                   # the hash values (i.e. column values) are returned as an arrayref
128                                                   # in the correct column order (because hashes are randomly ordered).
129                                                   # This is used in mk-upgrade.
130                                                   sub as_arrayref {
131            1                    1             5      my ( $sth, $row ) = @_;
132            1                                  3      my @cols = @{$sth->{NAME}};
               1                                  7   
133            1                                 10      my @row  = @{$row}{@cols};
               1                                  7   
134            1                                 11      return \@row;
135                                                   }
136                                                   
137                                                   sub _d {
138   ***      0                    0                    my ($package, undef, $line) = caller 0;
139   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
140   ***      0                                              map { defined $_ ? $_ : 'undef' }
141                                                           @_;
142   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
143                                                   }
144                                                   
145                                                   1;
146                                                   
147                                                   # ###########################################################################
148                                                   # End MockSyncStream package
149                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***     50      0      5   unless defined $args{$arg}
100          100      7      2   $dbh->type_info($_)->{'NULLABLE'} == 1 ? :
116          100      4      5   $type =~ /(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ? :
118          100      2      7   $type =~ /(?:float|double|decimal)/ ? :
139   ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine            Count Location                                             
--------------------- ----- -----------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:29 
BEGIN                     1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:30 
BEGIN                     1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:32 
BEGIN                     1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:34 
as_arrayref               1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:131
done                      1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:70 
done_with_rows            1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:65 
get_result_set_struct     1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:97 
get_sql                   1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:45 
key_cols                  3 /home/daniel/dev/maatkit/common/MockSyncStream.pm:75 
new                       1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:37 
not_in_left               1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:60 
not_in_right              1 /home/daniel/dev/maatkit/common/MockSyncStream.pm:55 
same_row                  2 /home/daniel/dev/maatkit/common/MockSyncStream.pm:50 

Uncovered Subroutines
---------------------

Subroutine            Count Location                                             
--------------------- ----- -----------------------------------------------------
_d                        0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:138
pending_changes           0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:89 
prepare                   0 /home/daniel/dev/maatkit/common/MockSyncStream.pm:82 


