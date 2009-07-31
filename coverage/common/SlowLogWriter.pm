---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogWriter.pm   84.0   76.9    n/a   85.7    n/a  100.0   81.9
Total                          84.0   76.9    n/a   85.7    n/a  100.0   81.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlowLogWriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:57:42 2009
Finish:       Fri Jul 31 18:57:42 2009

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
18                                                    # SlowLogWriter package $Revision: 4227 $
19                                                    # ###########################################################################
20                                                    package SlowLogWriter;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  4   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
27                                                    
28                                                    sub new {
29             1                    1             9      my ( $class ) = @_;
30             1                                  8      bless {}, $class;
31                                                    }
32                                                    
33                                                    # Print out in slow-log format.
34                                                    sub write {
35             3                    3            26      my ( $self, $fh, $event ) = @_;
36             3    100                          15      if ( $event->{ts} ) {
37             2                                 15         print $fh "# Time: $event->{ts}\n";
38                                                       }
39    ***      3     50                          13      if ( $event->{user} ) {
40             3                                 30         printf $fh "# User\@Host: %s[%s] \@ %s []\n",
41                                                             $event->{user}, $event->{user}, $event->{host};
42                                                       }
43             3    100                          18      if ( $event->{Thread_id} ) {
44             1                                  5         printf $fh "# Thread_id: $event->{Thread_id}\n";
45                                                       }
46                                                    
47                                                       # Tweak output according to log type: either classic or Percona-patched.
48             3    100                          16      my $percona_patched = exists $event->{QC_Hit} ? 1 : 0;
49             3                                  6      my $df;  # Decimal/microsecond or integer format.
50             3    100                          10      if ( $percona_patched ) {
51             1                                  3         $df = '.6f';
52                                                       }
53                                                       else {
54             2                                  7         $df = 'd';
55                                                       }
56                                                    
57                                                       # Classic slow log attribs.
58            12    100                         109      printf $fh
59                                                          "# Query_time: %$df  Lock_time: %$df  Rows_sent: %d  Rows_examined: %d\n",
60                                                          # TODO 0  Rows_affected: 0  Rows_read: 1
61             3                                 18         map { $_ || 0 }
62             3                                 17            @{$event}{qw(Query_time Lock_time Rows_sent Rows_examined)};
63                                                    
64             3    100                          12      if ( $percona_patched ) {
65                                                          # First 2 lines of Percona-patched attribs.
66             8    100                          43         printf $fh
67                                                             "# QC_Hit: %s  Full_scan: %s  Full_join: %s  Tmp_table: %s  Disk_tmp_table: %s\n# Filesort: %s  Disk_filesort: %s  Merge_passes: %d\n",
68             1                                  6            map { $_ || 0 }
69             1                                  4               @{$event}{qw(QC_Hit Full_scan Full_join Tmp_table Disk_tmp_table Filesort Disk_filesort Merge_passes)};
70                                                    
71    ***      1     50                           5         if ( exists $event->{InnoDB_IO_r_ops} ) {
72                                                             # Optional 3 lines of Percona-patched InnoDB attribs.
73    ***      6     50                          38            printf $fh
74                                                                "#   InnoDB_IO_r_ops: %d  InnoDB_IO_r_bytes: %d  InnoDB_IO_r_wait: %$df\n#   InnoDB_rec_lock_wait: %$df  InnoDB_queue_wait: %$df\n#   InnoDB_pages_distinct: %d\n",
75             1                                  4               map { $_ || 0 }
76             1                                  7                  @{$event}{qw(InnoDB_IO_r_ops InnoDB_IO_r_bytes InnoDB_IO_r_wait InnoDB_rec_lock_wait InnoDB_queue_wait InnoDB_pages_distinct)};
77                                                    
78                                                          } 
79                                                          else {
80    ***      0                                  0            printf $fh "# No InnoDB statistics available for this query\n";
81                                                          }
82                                                       }
83                                                    
84             3    100                          15      if ( $event->{db} ) {
85             2                                 10         printf $fh "use %s;\n", $event->{db};
86                                                       }
87    ***      3     50                          13      if ( $event->{arg} =~ m/^administrator command/ ) {
88    ***      0                                  0         print $fh '# ';
89                                                       }
90             3                                 12      print $fh $event->{arg}, ";\n";
91                                                    
92             3                                 35      return;
93                                                    }
94                                                    
95                                                    sub _d {
96    ***      0                    0                    my ($package, undef, $line) = caller 0;
97    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
98    ***      0                                              map { defined $_ ? $_ : 'undef' }
99                                                            @_;
100   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
101                                                   }
102                                                   
103                                                   1;
104                                                   
105                                                   # ###########################################################################
106                                                   # End SlowLogWriter package
107                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36           100      2      1   if ($$event{'ts'})
39    ***     50      3      0   if ($$event{'user'})
43           100      1      2   if ($$event{'Thread_id'})
48           100      1      2   exists $$event{'QC_Hit'} ? :
50           100      1      2   if ($percona_patched) { }
58           100      6      6   unless $_
64           100      1      2   if ($percona_patched)
66           100      1      7   unless $_
71    ***     50      1      0   if (exists $$event{'InnoDB_IO_r_ops'}) { }
73    ***     50      0      6   unless $_
84           100      2      1   if ($$event{'db'})
87    ***     50      0      3   if ($$event{'arg'} =~ /^administrator command/)
97    ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:22
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:23
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:24
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:26
new            1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:29
write          3 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:35

Uncovered Subroutines
---------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:96


