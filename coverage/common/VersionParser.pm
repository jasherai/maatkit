---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/VersionParser.pm   60.0    0.0    n/a   75.0    n/a  100.0   54.5
Total                          60.0    0.0    n/a   75.0    n/a  100.0   54.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          VersionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:44 2009
Finish:       Wed Jun 10 17:21:44 2009

/home/daniel/dev/maatkit/common/VersionParser.pm

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
18                                                    # VersionParser package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    package VersionParser;
21                                                    
22             1                    1             6   use strict;
               1                                  2   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
28                                                    
29                                                    sub new {
30             1                    1             5      my ( $class ) = @_;
31             1                                 13      bless {}, $class;
32                                                    }
33                                                    
34                                                    sub parse {
35             1                    1             4      my ( $self, $str ) = @_;
36             1                                 17      my $result = sprintf('%03d%03d%03d', $str =~ m/(\d+)/g);
37             1                                  3      MKDEBUG && _d($str, 'parses to', $result);
38             1                                  6      return $result;
39                                                    }
40                                                    
41                                                    # Compares versions like 5.0.27 and 4.1.15-standard-log.  Caches version number
42                                                    # for each DBH for later use.
43                                                    sub version_ge {
44    ***      0                    0                    my ( $self, $dbh, $target ) = @_;
45    ***      0      0                                  if ( !$self->{$dbh} ) {
46    ***      0                                            $self->{$dbh} = $self->parse(
47                                                             $dbh->selectrow_array('SELECT VERSION()'));
48                                                       }
49    ***      0      0                                  my $result = $self->{$dbh} ge $self->parse($target) ? 1 : 0;
50    ***      0                                         MKDEBUG && _d($self->{$dbh}, 'ge', $target, ':', $result);
51    ***      0                                         return $result;
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
65                                                    # End VersionParser package
66                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***      0      0      0   if (not $$self{$dbh})
49    ***      0      0      0   $$self{$dbh} ge $self->parse($target) ? :
56    ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/VersionParser.pm:22
BEGIN          1 /home/daniel/dev/maatkit/common/VersionParser.pm:23
BEGIN          1 /home/daniel/dev/maatkit/common/VersionParser.pm:25
BEGIN          1 /home/daniel/dev/maatkit/common/VersionParser.pm:27
new            1 /home/daniel/dev/maatkit/common/VersionParser.pm:30
parse          1 /home/daniel/dev/maatkit/common/VersionParser.pm:35

Uncovered Subroutines
---------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/VersionParser.pm:55
version_ge     0 /home/daniel/dev/maatkit/common/VersionParser.pm:44


