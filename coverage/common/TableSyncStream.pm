---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/TableSyncStream.pm   74.5   62.5   50.0   65.0    n/a  100.0   70.6
Total                          74.5   62.5   50.0   65.0    n/a  100.0   70.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncStream.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Sep 24 23:37:34 2009
Finish:       Thu Sep 24 23:37:34 2009

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
18                                                    # TableSyncStream package $Revision: 4743 $
19                                                    # ###########################################################################
20                                                    package TableSyncStream;
21                                                    # This package implements the simplest possible table-sync algorithm: read every
22                                                    # row from the tables and compare them.
23                                                    
24             1                    1             9   use strict;
               1                                  3   
               1                                  6   
25             1                    1           112   use warnings FATAL => 'all';
               1                                  3   
               1                                  9   
26                                                    
27             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
28                                                    
29             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
30                                                    
31                                                    sub new {
32             2                    2            63      my ( $class, %args ) = @_;
33             2                                 10      foreach my $arg ( qw(Quoter) ) {
34             2    100                           9         die "I need a $arg argument" unless $args{$arg};
35                                                       }
36             1                                  6      my $self = { %args };
37             1                                 17      return bless $self, $class;
38                                                    }
39                                                    
40                                                    sub name {
41    ***      0                    0             0      return 'Stream';
42                                                    }
43                                                    
44                                                    sub can_sync {
45    ***      0                    0             0      return 1;  # We can sync anything.
46                                                    }
47                                                    
48                                                    sub prepare_to_sync {
49             2                    2            22      my ( $self, %args ) = @_;
50             2                                  8      my @required_args = qw(cols ChangeHandler);
51             2                                  7      foreach my $arg ( @required_args ) {
52    ***      4     50                          21         die "I need a $arg argument" unless $args{$arg};
53                                                       }
54             2                                  9      $self->{cols}            = $args{cols};
55             2                                 12      $self->{buffer_in_mysql} = $args{buffer_in_mysql};
56             2                                  7      $self->{ChangeHandler}   = $args{ChangeHandler};
57             2                                  9      return;
58                                                    }
59                                                    
60                                                    sub uses_checksum {
61    ***      0                    0             0      return 0;  # We don't need checksum queries.
62                                                    }
63                                                    
64                                                    sub set_checksum_queries {
65    ***      0                    0             0      return;  # This shouldn't be called, but just in case.
66                                                    }
67                                                    
68                                                    sub prepare_sync_cycle {
69    ***      0                    0             0      my ( $self, $host ) = @_;
70    ***      0                                  0      return;
71                                                    }
72                                                    
73                                                    sub get_sql {
74             2                    2            33      my ( $self, %args ) = @_;
75             6                                 26      return "SELECT "
76                                                          . ($self->{buffer_in_mysql} ? 'SQL_BUFFER_RESULT ' : '')
77    ***      2    100     50                   14         . join(', ', map { $self->{Quoter}->quote($_) } @{$self->{cols}})
               2                                  8   
78                                                          . ' FROM ' . $self->{Quoter}->quote(@args{qw(database table)})
79                                                          . ' WHERE ' . ( $args{where} || '1=1' );
80                                                    }
81                                                    
82                                                    sub same_row {
83             2                    2             8      my ( $self, $lr, $rr ) = @_;
84             2                                  7      return;
85                                                    }
86                                                    
87                                                    sub not_in_right {
88             1                    1             5      my ( $self, $lr ) = @_;
89             1                                  6      $self->{ChangeHandler}->change('INSERT', $lr, $self->key_cols());
90                                                    }
91                                                    
92                                                    sub not_in_left {
93             1                    1             4      my ( $self, $rr ) = @_;
94             1                                  5      $self->{ChangeHandler}->change('DELETE', $rr, $self->key_cols());
95                                                    }
96                                                    
97                                                    sub done_with_rows {
98             1                    1             5      my ( $self ) = @_;
99             1                                  9      $self->{done} = 1;
100                                                   }
101                                                   
102                                                   sub done {
103            1                    1             4      my ( $self ) = @_;
104            1                                  6      return $self->{done};
105                                                   }
106                                                   
107                                                   sub key_cols {
108            5                    5            18      my ( $self ) = @_;
109            5                                 27      return $self->{cols};
110                                                   }
111                                                   
112                                                   # Return 1 if you have changes yet to make and you don't want the TableSyncer to
113                                                   # commit your transaction or release your locks.
114                                                   sub pending_changes {
115   ***      0                    0                    my ( $self ) = @_;
116   ***      0                                         return;
117                                                   }
118                                                   
119                                                   sub _d {
120   ***      0                    0                    my ($package, undef, $line) = caller 0;
121   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
122   ***      0                                              map { defined $_ ? $_ : 'undef' }
123                                                           @_;
124   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
125                                                   }
126                                                   
127                                                   1;
128                                                   
129                                                   # ###########################################################################
130                                                   # End TableSyncStream package
131                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
34           100      1      1   unless $args{$arg}
52    ***     50      0      4   unless $args{$arg}
77           100      1      1   $$self{'buffer_in_mysql'} ? :
121   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
77    ***     50      2      0   $args{'where'} || '1=1'


Covered Subroutines
-------------------

Subroutine           Count Location                                              
-------------------- ----- ------------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:24 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:25 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:27 
BEGIN                    1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:29 
done                     1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:103
done_with_rows           1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:98 
get_sql                  2 /home/daniel/dev/maatkit/common/TableSyncStream.pm:74 
key_cols                 5 /home/daniel/dev/maatkit/common/TableSyncStream.pm:108
new                      2 /home/daniel/dev/maatkit/common/TableSyncStream.pm:32 
not_in_left              1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:93 
not_in_right             1 /home/daniel/dev/maatkit/common/TableSyncStream.pm:88 
prepare_to_sync          2 /home/daniel/dev/maatkit/common/TableSyncStream.pm:49 
same_row                 2 /home/daniel/dev/maatkit/common/TableSyncStream.pm:83 

Uncovered Subroutines
---------------------

Subroutine           Count Location                                              
-------------------- ----- ------------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:120
can_sync                 0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:45 
name                     0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:41 
pending_changes          0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:115
prepare_sync_cycle       0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:69 
set_checksum_queries     0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:65 
uses_checksum            0 /home/daniel/dev/maatkit/common/TableSyncStream.pm:61 


