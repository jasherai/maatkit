---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/SchemaFindText.pm   86.4   80.0    n/a   88.9    n/a  100.0   85.7
Total                          86.4   80.0    n/a   88.9    n/a  100.0   85.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SchemaFindText.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:24 2009
Finish:       Fri Jul 31 18:53:24 2009

/home/daniel/dev/maatkit/common/SchemaFindText.pm

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
18                                                    # SchemaFindText package $Revision: 3186 $
19                                                    # ###########################################################################
20             1                    1             6   use strict;
               1                                  2   
               1                                112   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
22                                                    
23                                                    package SchemaFindText;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 12   
28                                                    
29                                                    # Arguments:
30                                                    # * fh => filehandle
31                                                    sub new {
32             1                    1             6      my ( $class, %args ) = @_;
33             1                                 18      bless {
34                                                          %args,
35                                                          last_tbl_ddl => undef,
36                                                          queued_db    => undef,
37                                                       }, $class;
38                                                    }
39                                                    
40                                                    sub next_db {
41             2                    2             7      my ( $self ) = @_;
42             2    100                          10      if ( $self->{queued_db} ) {
43             1                                  4         my $db = $self->{queued_db};
44             1                                  3         $self->{queued_db} = undef;
45             1                                  5         return $db;
46                                                       }
47             1                                  5      local $RS = "";
48             1                                  3      my $fh = $self->{fh};
49             1                                 24      while ( defined (my $text = <$fh>) ) {
50             5                                 21         my ($db) = $text =~ m/^USE `([^`]+)`/;
51             5    100                          52         return $db if $db;
52                                                       }
53                                                    }
54                                                    
55                                                    sub next_tbl {
56            20                   20            68      my ( $self ) = @_;
57            20                                 93      local $RS = "";
58            20                                 62      my $fh = $self->{fh};
59            20                                156      while ( defined (my $text = <$fh>) ) {
60            43    100                         193         if ( my ($db) = $text =~ m/^USE `([^`]+)`/ ) {
61             1                                  4            $self->{queued_db} = $db;
62             1                                  7            return undef;
63                                                          }
64            42                                739         my ($ddl) = $text =~ m/^(CREATE TABLE.*?^\)[^\n]*);\n/sm;
65            42    100                         309         if ( $ddl ) {
66            19                                 64            $self->{last_tbl_ddl} = $ddl;
67            19                                115            my ( $tbl ) = $ddl =~ m/CREATE TABLE `([^`]+)`/;
68            19                                121            return $tbl;
69                                                          }
70                                                       }
71                                                    }
72                                                    
73                                                    sub last_tbl_ddl {
74             2                    2             7      my ( $self ) = @_;
75             2                                 29      return $self->{last_tbl_ddl};
76                                                    }
77                                                    
78                                                    sub _d {
79    ***      0                    0                    my ($package, undef, $line) = caller 0;
80    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
81    ***      0                                              map { defined $_ ? $_ : 'undef' }
82                                                            @_;
83    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
84                                                    }
85                                                    
86                                                    1;
87                                                    
88                                                    # ###########################################################################
89                                                    # End SchemaFindText package
90                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
42           100      1      1   if ($$self{'queued_db'})
51           100      1      4   if $db
60           100      1     42   if (my($db) = $text =~ /^USE `([^`]+)`/)
65           100     19     23   if ($ddl)
80    ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine   Count Location                                            
------------ ----- ----------------------------------------------------
BEGIN            1 /home/daniel/dev/maatkit/common/SchemaFindText.pm:20
BEGIN            1 /home/daniel/dev/maatkit/common/SchemaFindText.pm:21
BEGIN            1 /home/daniel/dev/maatkit/common/SchemaFindText.pm:25
BEGIN            1 /home/daniel/dev/maatkit/common/SchemaFindText.pm:27
last_tbl_ddl     2 /home/daniel/dev/maatkit/common/SchemaFindText.pm:74
new              1 /home/daniel/dev/maatkit/common/SchemaFindText.pm:32
next_db          2 /home/daniel/dev/maatkit/common/SchemaFindText.pm:41
next_tbl        20 /home/daniel/dev/maatkit/common/SchemaFindText.pm:56

Uncovered Subroutines
---------------------

Subroutine   Count Location                                            
------------ ----- ----------------------------------------------------
_d               0 /home/daniel/dev/maatkit/common/SchemaFindText.pm:79


