---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogWriter.pm   78.8   50.0    n/a   85.7    n/a  100.0   73.1
Total                          78.8   50.0    n/a   85.7    n/a  100.0   73.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlowLogWriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:06 2009
Finish:       Wed Jun 10 17:21:06 2009

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
18                                                    # SlowLogWriter package $Revision: 3405 $
19                                                    # ###########################################################################
20                                                    package SlowLogWriter;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
25                                                    
26             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  8   
27                                                    
28                                                    sub new {
29             1                    1             9      my ( $class ) = @_;
30             1                                  9      bless {}, $class;
31                                                    }
32                                                    
33                                                    # Print out in slow-log format.
34                                                    sub write {
35             2                    2            18      my ( $self, $fh, $event ) = @_;
36    ***      2     50                           9      if ( $event->{ts} ) {
37             2                                 15         print $fh "# Time: $event->{ts}\n";
38                                                       }
39    ***      2     50                           7      if ( $event->{user} ) {
40             2                                 20         printf $fh "# User\@Host: %s[%s] \@ %s []\n",
41                                                             $event->{user}, $event->{user}, $event->{host};
42                                                       }
43             8    100                          56      printf $fh
44                                                          "# Query_time: %d  Lock_time: %d  Rows_sent: %d  Rows_examined: %d\n",
45                                                          # TODO 0  Rows_affected: 0  Rows_read: 1
46             2                                 10         map { $_ || 0 }
47             2                                  7            @{$event}{qw(Query_time Lock_time Rows_sent Rows_examined)};
48    ***      2     50                          10      if ( $event->{db} ) {
49             2                                  9         printf $fh "use %s;\n", $event->{db};
50                                                       }
51    ***      2     50                          10      if ( $event->{arg} =~ m/^administrator command/ ) {
52    ***      0                                  0         print $fh '# ';
53                                                       }
54             2                                 22      print $fh $event->{arg}, ";\n";
55                                                    }
56                                                    
57                                                    sub _d {
58    ***      0                    0                    my ($package, undef, $line) = caller 0;
59    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
60    ***      0                                              map { defined $_ ? $_ : 'undef' }
61                                                            @_;
62    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
63                                                    }
64                                                    
65                                                    1;
66                                                    
67                                                    # ###########################################################################
68                                                    # End SlowLogWriter package
69                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      2      0   if ($$event{'ts'})
39    ***     50      2      0   if ($$event{'user'})
43           100      4      4   unless $_
48    ***     50      2      0   if ($$event{'db'})
51    ***     50      0      2   if ($$event{'arg'} =~ /^administrator command/)
59    ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:22
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:23
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:24
BEGIN          1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:26
new            1 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:29
write          2 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:35

Uncovered Subroutines
---------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:58


