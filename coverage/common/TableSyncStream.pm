---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncStream.pm   79.5   66.7   50.0   80.0    n/a  100.0   77.4
Total                          79.5   66.7   50.0   80.0    n/a  100.0   77.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncStream.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:54:04 2009
Finish:       Fri Jul 31 18:54:04 2009

/home/daniel/dev/maatkit/common/TableSyncStream.pm

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
18                                                    # TableSyncStream package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    package TableSyncStream;
21                                                    # This package implements the simplest possible table-sync algorithm: read every
22                                                    # row from the tables and compare them.
23                                                    
24             1                    1            12   use strict;
               1                                  3   
               1                                  7   
25             1                    1           110   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
26                                                    
27             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
28                                                    
29             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
30                                                    
31                                                    # Arguments:
32                                                    # * handler ChangeHandler
33                                                    sub new {
34             3                    3            58      my ( $class, %args ) = @_;
35             3                                 13      foreach my $arg ( qw(handler cols) ) {
36             5    100                          22         die "I need a $arg argument" unless defined $args{$arg};
37                                                       }
38             2                                 33      return bless { %args }, $class;
39                                                    }
40                                                    
41                                                    # Arguments:
42                                                    # * quoter   Quoter
43                                                    # * database Database name
44                                                    # * table    Table name
45                                                    # * where    WHERE clause
46                                                    sub get_sql {
47             2                    2            12      my ( $self, %args ) = @_;
48             6                                 25      return "SELECT "
49                                                          . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
50    ***      2    100     50                   14         . join(', ', map { $args{quoter}->quote($_) } @{$self->{cols}})
               2                                  8   
51                                                          . ' FROM ' . $args{quoter}->quote(@args{qw(database table)})
52                                                          . ' WHERE ' . ( $args{where} || '1=1' );
53                                                    }
54                                                    
55                                                    sub same_row {
56             2                    2             8      my ( $self, $lr, $rr ) = @_;
57                                                    }
58                                                    
59                                                    sub not_in_right {
60             1                    1             4      my ( $self, $lr ) = @_;
61             1                                  5      $self->{handler}->change('INSERT', $lr, $self->key_cols());
62                                                    }
63                                                    
64                                                    sub not_in_left {
65             1                    1             4      my ( $self, $rr ) = @_;
66             1                                  7      $self->{handler}->change('DELETE', $rr, $self->key_cols());
67                                                    }
68                                                    
69                                                    sub done_with_rows {
70             1                    1             3      my ( $self ) = @_;
71             1                                  6      $self->{done} = 1;
72                                                    }
73                                                    
74                                                    sub done {
75             1                    1             5      my ( $self ) = @_;
76             1                                  5      return $self->{done};
77                                                    }
78                                                    
79                                                    sub key_cols {
80             5                    5            16      my ( $self ) = @_;
81             5                                 25      return $self->{cols};
82                                                    }
83                                                    
84                                                    # Do any required setup before executing the SQL (such as setting up user
85                                                    # variables for checksum queries).
86                                                    sub prepare {
87    ***      0                    0                    my ( $self, $dbh ) = @_;
88                                                    }
89                                                    
90                                                    # Return 1 if you have changes yet to make and you don't want the TableSyncer to
91                                                    # commit your transaction or release your locks.
92                                                    sub pending_changes {
93    ***      0                    0                    my ( $self ) = @_;
94                                                    }
95                                                    
96                                                    sub _d {
97    ***      0                    0                    my ($package, undef, $line) = caller 0;
98    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
99    ***      0                                              map { defined $_ ? $_ : 'undef' }
100                                                           @_;
101   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
102                                                   }
103                                                   
104                                                   1;
105                                                   
106                                                   # ###########################################################################
107                                                   # End TableSyncStream package
108                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36           100      1      4   unless defined $args{$arg}
50           100      1      1   $$self{'bufferinmysql'} ? :
98    ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
50    ***     50      2      0   $args{'where'} || '1=1'


Covered Subroutines
-------------------

Subroutine      Count Location                                             
--------------- ----- -----------------------------------------------------
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:24
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:25
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:27
BEGIN               1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:29
done                1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:75
done_with_rows      1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:70
get_sql             2 /home/daniel/dev/maatkit/common/TableSyncStream.pm:47
key_cols            5 /home/daniel/dev/maatkit/common/TableSyncStream.pm:80
new                 3 /home/daniel/dev/maatkit/common/TableSyncStream.pm:34
not_in_left         1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:65
not_in_right        1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:60
same_row            2 /home/daniel/dev/maatkit/common/TableSyncStream.pm:56

Uncovered Subroutines
---------------------

Subroutine      Count Location                                             
--------------- ----- -----------------------------------------------------
_d                  0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:97
pending_changes     0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:93
prepare             0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:87


