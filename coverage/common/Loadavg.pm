---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/Loadavg.pm   62.5   31.8   16.7   84.6    n/a  100.0   54.6
Total                          62.5   31.8   16.7   84.6    n/a  100.0   54.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Loadavg.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Jul  7 16:06:11 2009
Finish:       Tue Jul  7 16:06:11 2009

/home/daniel/dev/maatkit/common/Loadavg.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Baron Schwartz.
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
18                                                    # Loadavg package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    package Loadavg;
21                                                    
22             1                    1             6   use strict;
               1                                  2   
               1                                  7   
23             1                    1           107   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24                                                    
25             1                    1             5   use List::Util qw(sum);
               1                                  3   
               1                                 11   
26             1                    1            10   use Time::HiRes qw(time);
               1                                  3   
               1                                  5   
27             1                    1             7   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
28                                                    
29             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
30                                                    
31                                                    sub new {
32             1                    1             5      my ( $class ) = @_;
33             1                                 16      return bless {}, $class;
34                                                    }
35                                                    
36                                                    # Calculates average query time by the Trevor Price method.
37                                                    sub trevorprice {
38    ***      0                    0             0      my ( $self, $dbh, %args ) = @_;
39    ***      0      0                           0      die "I need a dbh argument" unless $dbh;
40    ***      0             0                    0      my $num_samples = $args{samples} || 100;
41    ***      0                                  0      my $num_running = 0;
42    ***      0                                  0      my $start = time();
43    ***      0                                  0      my (undef, $status1)
44                                                          = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
45    ***      0                                  0      for ( 1 .. $num_samples ) {
46    ***      0                                  0         my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
47    ***      0             0                    0         my $running = grep { ($_->{Command} || '') eq 'Query' } @$pl;
      ***      0                                  0   
48    ***      0                                  0         $num_running += $running - 1;
49                                                       }
50    ***      0                                  0      my $time = time() - $start;
51    ***      0      0                           0      return 0 unless $time;
52    ***      0                                  0      my (undef, $status2)
53                                                          = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
54    ***      0                                  0      my $qps = ($status2 - $status1) / $time;
55    ***      0      0                           0      return 0 unless $qps;
56    ***      0                                  0      return ($num_running / $num_samples) / $qps;
57                                                    }
58                                                    
59                                                    # Calculates number of locked queries in the processlist.
60                                                    sub num_locked {
61    ***      0                    0             0      my ( $self, $dbh ) = @_;
62    ***      0      0                           0      die "I need a dbh argument" unless $dbh;
63    ***      0                                  0      my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
64    ***      0             0                    0      my $locked = grep { ($_->{State} || '') eq 'Locked' } @$pl;
      ***      0                                  0   
65    ***      0             0                    0      return $locked || 0;
66                                                    }
67                                                    
68                                                    # Calculates loadavg from the uptime command.
69                                                    sub loadavg {
70             1                    1             5      my ( $self ) = @_;
71             1                               2910      my $str = `uptime`;
72             1                                 11      chomp $str;
73    ***      1     50                          11      return 0 unless $str;
74             1                                 36      my ( $one ) = $str =~ m/load average:\s+(\S[^,]*),/;
75    ***      1            50                   67      return $one || 0;
76                                                    }
77                                                    
78                                                    # Calculates slave lag.  If the slave is not running, returns 0.
79                                                    sub slave_lag {
80             1                    1             5      my ( $self, $dbh ) = @_;
81    ***      1     50                           4      die "I need a dbh argument" unless $dbh;
82             1                                 43      my $sl = $dbh->selectall_arrayref('SHOW SLAVE STATUS', { Slice => {} });
83    ***      1     50                           9      if ( $sl ) {
84             1                                  3         $sl = $sl->[0];
85             1                                 10         my ( $key ) = grep { m/behind_master/i } keys %$sl;
              33                                105   
86    ***      1     50     50                   26         return $key ? $sl->{$key} || 0 : 0;
87                                                       }
88    ***      0                                  0      return 0;
89                                                    }
90                                                    
91                                                    # Calculates any metric from SHOW STATUS, either absolute or over a 1-second
92                                                    # interval.
93                                                    sub status {
94             1                    1            13      my ( $self, $dbh, %args ) = @_;
95    ***      1     50                           5      die "I need a dbh argument" unless $dbh;
96             1                                  4      my (undef, $status1)
97                                                          = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
98    ***      1     50                         431      if ( $args{incstatus} ) {
99    ***      0                                  0         sleep(1);
100   ***      0                                  0         my (undef, $status2)
101                                                            = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
102   ***      0                                  0         return $status2 - $status1;
103                                                      }
104                                                      else {
105            1                                 16         return $status1;
106                                                      }
107                                                   }
108                                                   
109                                                   sub _d {
110            1                    1             7      my ($package, undef, $line) = caller 0;
111   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
112            1                                  6           map { defined $_ ? $_ : 'undef' }
113                                                           @_;
114            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
115                                                   }
116                                                   
117                                                   1;
118                                                   
119                                                   # ###########################################################################
120                                                   # End Loadavg package
121                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***      0      0      0   unless $dbh
51    ***      0      0      0   unless $time
55    ***      0      0      0   unless $qps
62    ***      0      0      0   unless $dbh
73    ***     50      0      1   unless $str
81    ***     50      0      1   unless $dbh
83    ***     50      1      0   if ($sl)
86    ***     50      1      0   $key ? :
95    ***     50      0      1   unless $dbh
98    ***     50      0      1   if ($args{'incstatus'}) { }
111   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
40    ***      0      0      0   $args{'samples'} || 100
47    ***      0      0      0   $$_{'Command'} || ''
64    ***      0      0      0   $$_{'State'} || ''
65    ***      0      0      0   $locked || 0
75    ***     50      1      0   $one || 0
86    ***     50      0      1   $$sl{$key} || 0


Covered Subroutines
-------------------

Subroutine  Count Location                                      
----------- ----- ----------------------------------------------
BEGIN           1 /home/daniel/dev/maatkit/common/Loadavg.pm:22 
BEGIN           1 /home/daniel/dev/maatkit/common/Loadavg.pm:23 
BEGIN           1 /home/daniel/dev/maatkit/common/Loadavg.pm:25 
BEGIN           1 /home/daniel/dev/maatkit/common/Loadavg.pm:26 
BEGIN           1 /home/daniel/dev/maatkit/common/Loadavg.pm:27 
BEGIN           1 /home/daniel/dev/maatkit/common/Loadavg.pm:29 
_d              1 /home/daniel/dev/maatkit/common/Loadavg.pm:110
loadavg         1 /home/daniel/dev/maatkit/common/Loadavg.pm:70 
new             1 /home/daniel/dev/maatkit/common/Loadavg.pm:32 
slave_lag       1 /home/daniel/dev/maatkit/common/Loadavg.pm:80 
status          1 /home/daniel/dev/maatkit/common/Loadavg.pm:94 

Uncovered Subroutines
---------------------

Subroutine  Count Location                                      
----------- ----- ----------------------------------------------
num_locked      0 /home/daniel/dev/maatkit/common/Loadavg.pm:61 
trevorprice     0 /home/daniel/dev/maatkit/common/Loadavg.pm:38 


