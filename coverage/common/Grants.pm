---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Grants.pm   76.9   50.0   50.0   85.7    0.0    0.8   70.7
Grants.t                      100.0   50.0   33.3  100.0    n/a   99.2   92.9
Total                          90.9   50.0   40.0   93.8    0.0  100.0   83.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:23 2010
Finish:       Thu Jun 24 19:33:23 2010

Run:          Grants.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:25 2010
Finish:       Thu Jun 24 19:33:25 2010

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
18                                                    # Grants package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package Grants;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                 13   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 10   
25                                                    
26    ***      1            50      1             5   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 15   
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
40    ***      1                    1      0      6      my ( $class, %args ) = @_;
41             1                                  4      my $self = {};
42             1                                 12      return bless $self, $class;
43                                                    }
44                                                    
45                                                    sub have_priv {
46    ***      3                    3      0     21      my ( $self, $dbh, $priv ) = @_;
47             3                                 13      $priv = uc $priv;
48             3    100                          17      if ( !exists $check_for_priv{$priv} ) {
49             1                                  3         die "There is no check for privilege $priv";
50                                                       }
51             2                                 20      return $check_for_priv{$priv}->($dbh);
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


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine Count Pod Location                                    
---------- ----- --- --------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/common/Grants.pm:22
BEGIN          1     /home/daniel/dev/maatkit/common/Grants.pm:23
BEGIN          1     /home/daniel/dev/maatkit/common/Grants.pm:24
BEGIN          1     /home/daniel/dev/maatkit/common/Grants.pm:26
have_priv      3   0 /home/daniel/dev/maatkit/common/Grants.pm:46
new            1   0 /home/daniel/dev/maatkit/common/Grants.pm:40

Uncovered Subroutines
---------------------

Subroutine Count Pod Location                                    
---------- ----- --- --------------------------------------------
_d             0     /home/daniel/dev/maatkit/common/Grants.pm:55


Grants.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  2   
               1                                  5   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            13   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            11   use Test::More tests => 4;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            13   use Grants;
               1                                  2   
               1                                 11   
15             1                    1            10   use DSNParser;
               1                                  3   
               1                                 12   
16             1                    1            15   use Sandbox;
               1                                  2   
               1                                 10   
17             1                    1            11   use MaatkitTest;
               1                                  6   
               1                                 47   
18                                                    
19             1                                 13   my $dp = new DSNParser(opts=>$dsn_opts);
20             1                                235   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
21                                                    
22    ***      1     50                          55   my $dbh = $sb->get_dbh_for('master')
23                                                       or BAIL_OUT('Cannot connect to sandbox master');
24                                                    
25             1                                379   my $gr = new Grants;
26             1                                 11   isa_ok($gr, 'Grants');
27                                                    
28             1                              10467   diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO ''\@'%'"`);
29             1                                 22   my $anon_dbh = DBI->connect(
30                                                       "DBI:mysql:;host=127.0.0.1;port=12345", undef, undef,
31                                                       { PrintError => 0, RaiseError => 1 });
32             1                                 15   ok(!$gr->have_priv($anon_dbh, 'process'), 'Anonymous user does not have PROCESS priv');
33                                                    
34             1                              10788   diag(`/tmp/12345/use -uroot -umsandbox -e "DROP USER ''\@'%'"`);
35                                                    
36             1                                 23   ok($gr->have_priv($dbh, 'PROCESS'), 'Normal user does have PROCESS priv');
37                                                    
38             1                                  8   eval {
39             1                                  8      $gr->have_priv($dbh, 'foo');
40                                                    };
41             1                                 27   like($EVAL_ERROR, qr/no check for privilege/, 'Dies if privilege has no check');
42                                                    
43             1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
22    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location   
---------- ----- -----------
BEGIN          1 Grants.t:10
BEGIN          1 Grants.t:11
BEGIN          1 Grants.t:12
BEGIN          1 Grants.t:14
BEGIN          1 Grants.t:15
BEGIN          1 Grants.t:16
BEGIN          1 Grants.t:17
BEGIN          1 Grants.t:4 
BEGIN          1 Grants.t:9 


