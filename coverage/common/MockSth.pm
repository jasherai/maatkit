---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/MockSth.pm  100.0  100.0    n/a  100.0    n/a  100.0  100.0
Total                         100.0  100.0    n/a  100.0    n/a  100.0  100.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MockSth.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:04 2009
Finish:       Sat Aug 29 15:03:04 2009

/home/daniel/dev/maatkit/common/MockSth.pm

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
17             1                    1             8   use strict;
               1                                  3   
               1                                 10   
18             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
19                                                    
20                                                    # A package to mock up a $sth.
21                                                    package MockSth;
22                                                    
23             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 12   
24                                                    
25                                                    sub new {
26             2                    2            18      my ( $class, @rows ) = @_;
27             2                                 11      my $self = {
28                                                          cursor => 0,
29                                                          Active => scalar(@rows),
30                                                          rows   => \@rows,
31                                                       };
32             2                                 19      return bless $self, $class;
33                                                    }
34                                                    
35                                                    sub fetchrow_hashref {
36             3                    3            21      my ( $self ) = @_;
37             3                                  6      my $row;
38             3    100                          12      if ( $self->{cursor} < @{$self->{rows}} ) {
               3                                 14   
39             1                                  5         $row = $self->{rows}->[$self->{cursor}++];
40                                                       }
41             3                                  9      $self->{Active} = $self->{cursor} < @{$self->{rows}};
               3                                 14   
42             3                                 18      return $row;
43                                                    }
44                                                    
45                                                    1;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
38           100      1      2   if ($$self{'cursor'} < @{$$self{'rows'};})


Covered Subroutines
-------------------

Subroutine       Count Location                                     
---------------- ----- ---------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/MockSth.pm:17
BEGIN                1 /home/daniel/dev/maatkit/common/MockSth.pm:18
BEGIN                1 /home/daniel/dev/maatkit/common/MockSth.pm:23
fetchrow_hashref     3 /home/daniel/dev/maatkit/common/MockSth.pm:36
new                  2 /home/daniel/dev/maatkit/common/MockSth.pm:26


