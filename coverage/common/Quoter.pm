---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Quoter.pm  100.0  100.0  100.0  100.0    n/a  100.0  100.0
Total                         100.0  100.0  100.0  100.0    n/a  100.0  100.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Quoter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:19 2009
Finish:       Fri Jul 31 18:53:19 2009

/home/daniel/dev/maatkit/common/Quoter.pm

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
18                                                    # Quoter package $Revision: 3186 $
19                                                    # ###########################################################################
20             1                    1             5   use strict;
               1                                  3   
               1                                105   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
22                                                    
23                                                    package Quoter;
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 12   
28                                                    
29                                                    sub new {
30             1                    1             4      my ( $class ) = @_;
31             1                                 12      bless {}, $class;
32                                                    }
33                                                    
34                                                    sub quote {
35             5                    5            23      my ( $self, @vals ) = @_;
36             5                                 17      foreach my $val ( @vals ) {
37             7                                 33         $val =~ s/`/``/g;
38                                                       }
39             5                                 17      return join('.', map { '`' . $_ . '`' } @vals);
               7                                 45   
40                                                    }
41                                                    
42                                                    sub quote_val {
43             8                    8            34      my ( $self, @vals ) = @_;
44                                                       return join(', ',
45                                                          map {
46             8    100                          27            if ( defined $_ ) {
              10                                 33   
47             9                                 38               $_ =~ s/(['\\])/\\$1/g;
48             9    100    100                  115               $_ eq '' || $_ =~ m/^0|\D/ ? "'$_'" : $_;
49                                                             }
50                                                             else {
51             1                                  7               'NULL';
52                                                             }
53                                                          } @vals
54                                                       );
55                                                    }
56                                                    
57                                                    sub split_unquote {
58             4                    4            18      my ( $self, $db_tbl, $default_db ) = @_;
59             4                                 16      $db_tbl =~ s/`//g;
60             4                                 19      my ( $db, $tbl ) = split(/[.]/, $db_tbl);
61             4    100                          16      if ( !$tbl ) {
62             2                                  6         $tbl = $db;
63             2                                  4         $db  = $default_db;
64                                                       }
65             4                                 29      return ($db, $tbl);
66                                                    }
67                                                    
68                                                    1;
69                                                    
70                                                    # ###########################################################################
71                                                    # End Quoter package
72                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
46           100      9      1   if (defined $_) { }
48           100      5      4   $_ eq '' || $_ =~ /^0|\D/ ? :
61           100      2      2   if (not $tbl)


Conditions
----------

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
48           100      1      4      4   $_ eq '' || $_ =~ /^0|\D/


Covered Subroutines
-------------------

Subroutine    Count Location                                    
------------- ----- --------------------------------------------
BEGIN             1 /home/daniel/dev/maatkit/common/Quoter.pm:20
BEGIN             1 /home/daniel/dev/maatkit/common/Quoter.pm:21
BEGIN             1 /home/daniel/dev/maatkit/common/Quoter.pm:25
BEGIN             1 /home/daniel/dev/maatkit/common/Quoter.pm:27
new               1 /home/daniel/dev/maatkit/common/Quoter.pm:30
quote             5 /home/daniel/dev/maatkit/common/Quoter.pm:35
quote_val         8 /home/daniel/dev/maatkit/common/Quoter.pm:43
split_unquote     4 /home/daniel/dev/maatkit/common/Quoter.pm:58


