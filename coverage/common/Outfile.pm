---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/Outfile.pm   81.2   62.5    n/a   88.9    n/a  100.0   79.6
Total                          81.2   62.5    n/a   88.9    n/a  100.0   79.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Outfile.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:24 2009
Finish:       Sat Aug 29 15:03:25 2009

/home/daniel/dev/maatkit/common/Outfile.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009 Percona Inc.
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
18                                                    # Outfile package $Revision: 4510 $
19                                                    # ###########################################################################
20                                                    package Outfile;
21                                                    
22             1                    1             6   use strict;
               1                                  3   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  4   
25                                                    
26             1                    1             7   use List::Util qw(min);
               1                                  3   
               1                                 11   
27                                                    
28             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
29                                                    
30                                                    sub new {
31             1                    1            16      my ( $class, %args ) = @_;
32             1                                  3      my $self = {};
33             1                                 16      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # Print out in SELECT INTO OUTFILE format.
37                                                    # $rows is an arrayref from DBI::selectall_arrayref().
38                                                    sub write {
39             1                    1           114      my ( $self, $fh, $rows ) = @_;
40             1                                  5      foreach my $row ( @$rows ) {
41    ***      2     50                           9         print $fh escape($row), "\n"
42                                                             or die "Cannot write to outfile: $OS_ERROR\n";
43                                                       }
44             1                                  4      return;
45                                                    }
46                                                    
47                                                    # Formats a row the same way SELECT INTO OUTFILE does by default.  This is
48                                                    # described in the LOAD DATA INFILE section of the MySQL manual,
49                                                    # http://dev.mysql.com/doc/refman/5.0/en/load-data.html
50                                                    sub escape {
51             2                    2             8      my ( $row ) = @_;
52            16    100                          58      return join("\t", map {
53             2                                  7         s/([\t\n\\])/\\$1/g if defined $_;  # Escape tabs etc
54            16    100                          81         defined $_ ? $_ : '\N';             # NULL = \N
55                                                       } @$row);
56                                                    }
57                                                    
58                                                    sub _d {
59    ***      0                    0                    my ($package, undef, $line) = caller 0;
60    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
61    ***      0                                              map { defined $_ ? $_ : 'undef' }
62                                                            @_;
63    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
64                                                    }
65                                                    
66                                                    1;
67                                                    # ###########################################################################
68                                                    # End Outfile package
69                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
41    ***     50      0      2   unless print $fh escape($row), "\n"
52           100     15      1   if defined $_
54           100     15      1   defined $_ ? :
60    ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine Count Location                                     
---------- ----- ---------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/Outfile.pm:22
BEGIN          1 /home/daniel/dev/maatkit/common/Outfile.pm:23
BEGIN          1 /home/daniel/dev/maatkit/common/Outfile.pm:24
BEGIN          1 /home/daniel/dev/maatkit/common/Outfile.pm:26
BEGIN          1 /home/daniel/dev/maatkit/common/Outfile.pm:28
escape         2 /home/daniel/dev/maatkit/common/Outfile.pm:51
new            1 /home/daniel/dev/maatkit/common/Outfile.pm:31
write          1 /home/daniel/dev/maatkit/common/Outfile.pm:39

Uncovered Subroutines
---------------------

Subroutine Count Location                                     
---------- ----- ---------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/Outfile.pm:59


