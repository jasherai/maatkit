---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogWriter.pm   84.6   82.1   66.7   85.7    n/a  100.0   83.3
Total                          84.6   82.1   66.7   85.7    n/a  100.0   83.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlowLogWriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:53 2009
Finish:       Sat Aug 29 15:03:53 2009

/home/daniel/dev/maatkit/common/SlowLogWriter.pm

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
18                                                    # SlowLogWriter package $Revision: 4461 $
19                                                    # ###########################################################################
20                                                    package SlowLogWriter;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
27                                                    
28                                                    sub new {
29             1                    1             9      my ( $class ) = @_;
30             1                                  9      bless {}, $class;
31                                                    }
32                                                    
33                                                    # Print out in slow-log format.
34                                                    sub write {
35             4                    4           137      my ( $self, $fh, $event ) = @_;
36             4    100                          21      if ( $event->{ts} ) {
37             2                                 18         print $fh "# Time: $event->{ts}\n";
38                                                       }
39             4    100                          18      if ( $event->{user} ) {
40             3                                 33         printf $fh "# User\@Host: %s[%s] \@ %s []\n",
41                                                             $event->{user}, $event->{user}, $event->{host};
42                                                       }
43    ***      4    100     66                   34      if ( $event->{ip} && $event->{port} ) {
44             1                                 12         printf $fh "# Client: $event->{ip}:$event->{port}\n";
45                                                       }
46             4    100                          20      if ( $event->{Thread_id} ) {
47             1                                  7         printf $fh "# Thread_id: $event->{Thread_id}\n";
48                                                       }
49                                                    
50                                                       # Tweak output according to log type: either classic or Percona-patched.
51             4    100                          19      my $percona_patched = exists $event->{QC_Hit} ? 1 : 0;
52             4                                  8      my $df;  # Decimal/microsecond or integer format.
53             4    100                          15      if ( $percona_patched ) {
54             1                                  4         $df = '.6f';
55                                                       }
56                                                       else {
57             3                                  9         $df = 'd';
58                                                       }
59                                                    
60                                                       # Classic slow log attribs.
61            16    100                         163      printf $fh
62                                                          "# Query_time: %$df  Lock_time: %$df  Rows_sent: %d  Rows_examined: %d\n",
63                                                          # TODO 0  Rows_affected: 0  Rows_read: 1
64             4                                 19         map { $_ || 0 }
65             4                                 23            @{$event}{qw(Query_time Lock_time Rows_sent Rows_examined)};
66                                                    
67             4    100                          19      if ( $percona_patched ) {
68                                                          # First 2 lines of Percona-patched attribs.
69             8    100                          44         printf $fh
70                                                             "# QC_Hit: %s  Full_scan: %s  Full_join: %s  Tmp_table: %s  Disk_tmp_table: %s\n# Filesort: %s  Disk_filesort: %s  Merge_passes: %d\n",
71             1                                  5            map { $_ || 0 }
72             1                                  5               @{$event}{qw(QC_Hit Full_scan Full_join Tmp_table Disk_tmp_table Filesort Disk_filesort Merge_passes)};
73                                                    
74    ***      1     50                           6         if ( exists $event->{InnoDB_IO_r_ops} ) {
75                                                             # Optional 3 lines of Percona-patched InnoDB attribs.
76    ***      6     50                          36            printf $fh
77                                                                "#   InnoDB_IO_r_ops: %d  InnoDB_IO_r_bytes: %d  InnoDB_IO_r_wait: %$df\n#   InnoDB_rec_lock_wait: %$df  InnoDB_queue_wait: %$df\n#   InnoDB_pages_distinct: %d\n",
78             1                                  6               map { $_ || 0 }
79             1                                  8                  @{$event}{qw(InnoDB_IO_r_ops InnoDB_IO_r_bytes InnoDB_IO_r_wait InnoDB_rec_lock_wait InnoDB_queue_wait InnoDB_pages_distinct)};
80                                                    
81                                                          } 
82                                                          else {
83    ***      0                                  0            printf $fh "# No InnoDB statistics available for this query\n";
84                                                          }
85                                                       }
86                                                    
87             4    100                          18      if ( $event->{db} ) {
88             2                                 11         printf $fh "use %s;\n", $event->{db};
89                                                       }
90    ***      4     50                          22      if ( $event->{arg} =~ m/^administrator command/ ) {
91    ***      0                                  0         print $fh '# ';
92                                                       }
93             4                                 17      print $fh $event->{arg}, ";\n";
94                                                    
95             4                                 25      return;
96                                                    }
97                                                    
98                                                    sub _d {
99    ***      0                    0                    my ($package, undef, $line) = caller 0;
100   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
101   ***      0                                              map { defined $_ ? $_ : 'undef' }
102                                                           @_;
103   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
104                                                   }
105                                                   
106                                                   1;
107                                                   
108                                                   # ###########################################################################
109                                                   # End SlowLogWriter package
110                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36           100      2      2   if ($$event{'ts'})
39           100      3      1   if ($$event{'user'})
43           100      1      3   if ($$event{'ip'} and $$event{'port'})
46           100      1      3   if ($$event{'Thread_id'})
51           100      1      3   exists $$event{'QC_Hit'} ? :
53           100      1      3   if ($percona_patched) { }
61           100      9      7   unless $_
67           100      1      3   if ($percona_patched)
69           100      1      7   unless $_
74    ***     50      1      0   if (exists $$event{'InnoDB_IO_r_ops'}) { }
76    ***     50      0      6   unless $_
87           100      2      2   if ($$event{'db'})
90    ***     50      0      4   if ($$event{'arg'} =~ /^administrator command/)
100   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
43    ***     66      3      0      1   $$event{'ip'} and $$event{'port'}


Covered Subroutines
-------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:22
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:23
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:24
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:26
new            1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:29
write          4 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:35

Uncovered Subroutines
---------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:99


