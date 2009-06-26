---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryExecutor.pm   95.7   41.7    n/a  100.0    n/a  100.0   86.6
Total                          95.7   41.7    n/a  100.0    n/a  100.0   86.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryExecutor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jun 26 14:16:56 2009
Finish:       Fri Jun 26 14:16:57 2009

/home/daniel/dev/maatkit/common/QueryExecutor.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
18                                                    # QueryExecutor package $Revision$
19                                                    # ###########################################################################
20                                                    package QueryExecutor;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                105   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26             1                    1            10   use Time::HiRes qw(time);
               1                                  3   
               1                                  5   
27                                                    
28             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
29                                                    
30                                                    sub new {
31             1                    1            18      my ( $class, %args ) = @_;
32             1                                 11      foreach my $arg ( qw() ) {
33    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
34                                                       }
35             1                                  6      my $self = {
36                                                       };
37             1                                 37      return bless $self, $class;
38                                                    }
39                                                    
40                                                    # Executes the given query on the two given host dbhs.
41                                                    # Returns a hashref with query execution time and number of errors
42                                                    # and warnings produced on each host:
43                                                    #    {
44                                                    #       host1 => {
45                                                    #          Query_time    => 1.123456,  # Query execution time
46                                                    #          warning_count => 3,         # @@warning_count,
47                                                    #          warnings      => [          # SHOW WARNINGS
48                                                    #             [ "Error", "1062", "Duplicate entry '1' for key 1" ],
49                                                    #          ],
50                                                    #       },
51                                                    #       host2 => {
52                                                    #          etc.
53                                                    #       }
54                                                    #    }
55                                                    # If the query cannot be executed on a host, an error string is returned
56                                                    # for that host instead of the hashref of results.
57                                                    sub exec {
58             2                    2            28      my ( $self, %args ) = @_;
59             2                                 13      foreach my $arg ( qw(query host1_dbh host2_dbh) ) {
60    ***      6     50                          38         die "I need a $arg argument" unless $args{$arg};
61                                                       }
62                                                       return {
63             2                                 19         host1 => $self->_exec_query($args{query}, $args{host1_dbh}),
64                                                          host2 => $self->_exec_query($args{query}, $args{host2_dbh}),
65                                                       };
66                                                    }
67                                                    
68                                                    # This sub is called by exec() to do its common work:
69                                                    # execute, time and get warnings for a query on a given host.
70                                                    sub _exec_query {
71             4                    4            28      my ( $self, $query, $dbh ) = @_;
72    ***      4     50                          20      die "I need a query" unless $query;
73    ***      4     50                          19      die "I need a dbh"   unless $dbh;
74                                                    
75             4                                 15      my ( $start, $end, $query_time );
76             4                                 16      eval {
77             4                                 35         $start = time();
78             4                              77559         $dbh->do($query);
79             4                                 46         $end   = time();
80             4                                 97         $query_time = sprintf '%.6f', $end - $start;
81                                                       };
82    ***      4     50                          28      if ( $EVAL_ERROR ) {
83    ***      0                                  0         return $EVAL_ERROR;
84                                                       }
85                                                    
86             4                                 88      my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS', { Slice => {} });
87             4                                 39      my $warning_count = @{$dbh->selectall_arrayref('SELECT @@warning_count',
               4                                 25   
88                                                          { Slice => {} })}[0]->{'@@warning_count'};
89                                                    
90             4                                 76      my $results = {
91                                                          Query_time    => $query_time,
92                                                          warnings      => $warnings,
93                                                          warning_count => $warning_count,
94                                                       };
95                                                    
96             4                                 51      return $results;
97                                                    }   
98                                                    
99                                                    sub _d {
100            1                    1            13      my ($package, undef, $line) = caller 0;
101   ***      2     50                          17      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 19   
102            1                                  9           map { defined $_ ? $_ : 'undef' }
103                                                           @_;
104            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
105                                                   }
106                                                   
107                                                   1;
108                                                   
109                                                   # ###########################################################################
110                                                   # End QueryExecutor package
111                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
33    ***      0      0      0   unless $args{$arg}
60    ***     50      0      6   unless $args{$arg}
72    ***     50      0      4   unless $query
73    ***     50      0      4   unless $dbh
82    ***     50      0      4   if ($EVAL_ERROR)
101   ***     50      2      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine  Count Location                                            
----------- ----- ----------------------------------------------------
BEGIN           1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:22 
BEGIN           1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:23 
BEGIN           1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:25 
BEGIN           1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:26 
BEGIN           1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:28 
_d              1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:100
_exec_query     4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:71 
exec            2 /home/daniel/dev/maatkit/common/QueryExecutor.pm:58 
new             1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:31 


