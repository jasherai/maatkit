---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Grants.pm   76.9   50.0    n/a   85.7    n/a  100.0   75.7
Total                          76.9   50.0    n/a   85.7    n/a  100.0   75.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Grants.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:49 2009
Finish:       Wed Jun 10 17:19:49 2009

/home/daniel/dev/maatkit/common/Grants.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Percona Inc.
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
18                                                    # Grants package $Revision: 3464 $
19                                                    # ###########################################################################
20                                                    package Grants;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                114   
23             1                    1            23   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
27                                                    
28                                                    my %check_for_priv = (
29                                                       'PROCESS' => sub {
30                                                          my ( $dbh ) = @_;
31                                                          my $priv =
32                                                             grep { m/ALL PRIVILEGES.*?\*\.\*|PROCESS/ }
33                                                             @{$dbh->selectcol_arrayref('SHOW GRANTS')};
34                                                             return 0 if !$priv;
35                                                             return 1;
36                                                       },
37                                                    );
38                                                          
39                                                    sub new {
40             1                    1             6      my ( $class, %args ) = @_;
41             1                                  3      my $self = {};
42             1                                 13      return bless $self, $class;
43                                                    }
44                                                    
45                                                    sub have_priv {
46             3                    3            23      my ( $self, $dbh, $priv ) = @_;
47             3                                 12      $priv = uc $priv;
48             3    100                          20      if ( !exists $check_for_priv{$priv} ) {
49             1                                  5         die "There is no check for privilege $priv";
50                                                       }
51             2                                 16      return $check_for_priv{$priv}->($dbh);
52                                                    }
53                                                    
54                                                    sub _d {
55    ***      0                    0                    my ($package, undef, $line) = caller 0;
56    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
57    ***      0                                              map { defined $_ ? $_ : 'undef' }
58                                                            @_;
59    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
60                                                    }
61                                                    
62                                                    1;
63                                                    
64                                                    # ###########################################################################
65                                                    # End Grants package
66                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
48           100      1      2   if (not exists $check_for_priv{$priv})
56    ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine Count Location                                    
---------- ----- --------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/Grants.pm:22
BEGIN          1 /home/daniel/dev/maatkit/common/Grants.pm:23
BEGIN          1 /home/daniel/dev/maatkit/common/Grants.pm:24
BEGIN          1 /home/daniel/dev/maatkit/common/Grants.pm:26
have_priv      3 /home/daniel/dev/maatkit/common/Grants.pm:46
new            1 /home/daniel/dev/maatkit/common/Grants.pm:40

Uncovered Subroutines
---------------------

Subroutine Count Location                                    
---------- ----- --------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/Grants.pm:55


