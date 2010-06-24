---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/SchemaFindText.pm   86.7   80.0   50.0   88.9    0.0   96.8   80.0
SchemaFindText.t              100.0   50.0   33.3  100.0    n/a    3.2   91.5
Total                          92.3   71.4   40.0   93.8    0.0  100.0   84.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:26 2010
Finish:       Thu Jun 24 19:36:26 2010

Run:          SchemaFindText.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:27 2010
Finish:       Thu Jun 24 19:36:27 2010

/home/daniel/dev/maatkit/common/SchemaFindText.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-2010 Baron Schwartz.
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
18                                                    # SchemaFindText package $Revision: 5754 $
19                                                    # ###########################################################################
20                                                    package SchemaFindText;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                 11   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
27                                                    
28                                                    # Arguments:
29                                                    # * fh => filehandle
30                                                    sub new {
31    ***      1                    1      0      6      my ( $class, %args ) = @_;
32             1                                  8      my $self = {
33                                                          %args,
34                                                          last_tbl_ddl => undef,
35                                                          queued_db    => undef,
36                                                       };
37             1                                 12      return bless $self, $class;
38                                                    }
39                                                    
40                                                    sub next_db {
41    ***      2                    2      0      9      my ( $self ) = @_;
42             2    100                          12      if ( $self->{queued_db} ) {
43             1                                  5         my $db = $self->{queued_db};
44             1                                  4         $self->{queued_db} = undef;
45             1                                 12         return $db;
46                                                       }
47             1                                  6      local $RS = "";
48             1                                  4      my $fh = $self->{fh};
49             1                               9824      while ( defined (my $text = <$fh>) ) {
50             5                                 38         my ($db) = $text =~ m/^USE `([^`]+)`/;
51             5    100                          79         return $db if $db;
52                                                       }
53                                                    }
54                                                    
55                                                    sub next_tbl {
56    ***     20                   20      0     77      my ( $self ) = @_;
57            20                                 95      local $RS = "";
58            20                                 64      my $fh = $self->{fh};
59            20                                236      while ( defined (my $text = <$fh>) ) {
60            43    100                         197         if ( my ($db) = $text =~ m/^USE `([^`]+)`/ ) {
61             1                                  4            $self->{queued_db} = $db;
62             1                                  6            return undef;
63                                                          }
64            42                                726         my ($ddl) = $text =~ m/^(CREATE TABLE.*?^\)[^\n]*);\n/sm;
65            42    100                         302         if ( $ddl ) {
66            19                                 66            $self->{last_tbl_ddl} = $ddl;
67            19                                118            my ( $tbl ) = $ddl =~ m/CREATE TABLE `([^`]+)`/;
68            19                                123            return $tbl;
69                                                          }
70                                                       }
71                                                    }
72                                                    
73                                                    sub last_tbl_ddl {
74    ***      2                    2      0      8      my ( $self ) = @_;
75             2                                 32      return $self->{last_tbl_ddl};
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


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine   Count Pod Location                                            
------------ ----- --- ----------------------------------------------------
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaFindText.pm:22
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaFindText.pm:23
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaFindText.pm:24
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaFindText.pm:26
last_tbl_ddl     2   0 /home/daniel/dev/maatkit/common/SchemaFindText.pm:74
new              1   0 /home/daniel/dev/maatkit/common/SchemaFindText.pm:31
next_db          2   0 /home/daniel/dev/maatkit/common/SchemaFindText.pm:41
next_tbl        20   0 /home/daniel/dev/maatkit/common/SchemaFindText.pm:56

Uncovered Subroutines
---------------------

Subroutine   Count Pod Location                                            
------------ ----- --- ----------------------------------------------------
_d               0     /home/daniel/dev/maatkit/common/SchemaFindText.pm:79


SchemaFindText.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/env perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 23;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use SchemaFindText;
               1                                  3   
               1                                 10   
15             1                    1            15   use MaatkitTest;
               1                                 11   
               1                                 37   
16                                                    
17    ***      1     50                          49   open my $fh, "<", "$trunk/common/t/samples/schemas/schema-dump.sql"
18                                                       or die $OS_ERROR;
19                                                    
20             1                                  8   my $sft = new SchemaFindText(fh => $fh);
21                                                    
22             1                                  5   is($sft->next_db(), 'mysql', 'got mysql DB');
23             1                                  6   is($sft->next_tbl(), 'columns_priv', 'got columns_priv table');
24             1                                  6   like($sft->last_tbl_ddl(), qr/CREATE TABLE `columns_priv`/, 'got columns_priv ddl');
25                                                    
26                                                    # At the "end" of the db, we should get undef for next_tbl()
27             1                                 15   foreach my $tbl (
28                                                       qw( db func help_category help_keyword help_relation help_topic
29                                                          host proc procs_priv tables_priv time_zone time_zone_leap_second
30                                                          time_zone_name time_zone_transition time_zone_transition_type user)
31                                                    ) {
32            16                                 74      is($sft->next_tbl(), $tbl, $tbl);
33                                                    }
34             1                                  6   is($sft->next_tbl(), undef, 'end of mysql schema');
35                                                    
36             1                                  6   is($sft->next_db(), 'sakila', 'got sakila DB');
37             1                                  7   $sft->next_tbl();
38             1                                  4   is($sft->next_tbl(), 'address', 'got address table');
39             1                                  6   like($sft->last_tbl_ddl(), qr/CREATE TABLE `address`/, 'got address ddl');
40                                                    
41                                                    
42                                                    # #############################################################################
43                                                    # Done.
44                                                    # #############################################################################
45             1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
17    ***     50      0      1   unless open my $fh, '<', "$trunk/common/t/samples/schemas/schema-dump.sql"


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location           
---------- ----- -------------------
BEGIN          1 SchemaFindText.t:10
BEGIN          1 SchemaFindText.t:11
BEGIN          1 SchemaFindText.t:12
BEGIN          1 SchemaFindText.t:14
BEGIN          1 SchemaFindText.t:15
BEGIN          1 SchemaFindText.t:4 
BEGIN          1 SchemaFindText.t:9 


