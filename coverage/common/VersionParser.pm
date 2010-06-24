---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/VersionParser.pm   80.0   33.3   50.0   87.5    0.0   26.1   69.4
VersionParser.t               100.0   50.0   33.3  100.0    n/a   73.9   92.2
Total                          90.8   40.0   40.0   94.1    0.0  100.0   81.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:49 2010
Finish:       Thu Jun 24 19:38:49 2010

Run:          VersionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:50 2010
Finish:       Thu Jun 24 19:38:50 2010

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
18                                                    # VersionParser package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package VersionParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  8   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
28                                                    
29                                                    sub new {
30    ***      1                    1      0      9      my ( $class ) = @_;
31             1                                 12      bless {}, $class;
32                                                    }
33                                                    
34                                                    sub parse {
35    ***      3                    3      0    139      my ( $self, $str ) = @_;
36             3                                 42      my $result = sprintf('%03d%03d%03d', $str =~ m/(\d+)/g);
37             3                                  9      MKDEBUG && _d($str, 'parses to', $result);
38             3                                 22      return $result;
39                                                    }
40                                                    
41                                                    # Compares versions like 5.0.27 and 4.1.15-standard-log.  Caches version number
42                                                    # for each DBH for later use.
43                                                    sub version_ge {
44    ***      1                    1      0      5      my ( $self, $dbh, $target ) = @_;
45    ***      1     50                           7      if ( !$self->{$dbh} ) {
46             1                                  2         $self->{$dbh} = $self->parse(
47                                                             $dbh->selectrow_array('SELECT VERSION()'));
48                                                       }
49    ***      1     50                          17      my $result = $self->{$dbh} ge $self->parse($target) ? 1 : 0;
50             1                                  3      MKDEBUG && _d($self->{$dbh}, 'ge', $target, ':', $result);
51             1                                  7      return $result;
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
45    ***     50      1      0   if (not $$self{$dbh})
49    ***     50      1      0   $$self{$dbh} ge $self->parse($target) ? :
56    ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine Count Pod Location                                           
---------- ----- --- ---------------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/common/VersionParser.pm:22
BEGIN          1     /home/daniel/dev/maatkit/common/VersionParser.pm:23
BEGIN          1     /home/daniel/dev/maatkit/common/VersionParser.pm:25
BEGIN          1     /home/daniel/dev/maatkit/common/VersionParser.pm:27
new            1   0 /home/daniel/dev/maatkit/common/VersionParser.pm:30
parse          3   0 /home/daniel/dev/maatkit/common/VersionParser.pm:35
version_ge     1   0 /home/daniel/dev/maatkit/common/VersionParser.pm:44

Uncovered Subroutines
---------------------

Subroutine Count Pod Location                                           
---------- ----- --- ---------------------------------------------------
_d             0     /home/daniel/dev/maatkit/common/VersionParser.pm:55


VersionParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            10   use Test::More tests => 2;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use VersionParser;
               1                                  3   
               1                                  9   
15             1                    1            11   use MaatkitTest;
               1                                 12   
               1                                 40   
16                                                    
17             1                                  9   my $p = new VersionParser;
18                                                    
19             1                                  5   is(
20                                                       $p->parse('5.0.38-Ubuntu_0ubuntu1.1-log'),
21                                                       '005000038',
22                                                       'Parser works on ordinary version',
23                                                    );
24                                                    
25                                                    # Open a connection to MySQL, or skip the rest of the tests.
26             1                    1            10   use DSNParser;
               1                                  3   
               1                                 13   
27             1                    1            14   use Sandbox;
               1                                  3   
               1                                 13   
28             1                                  9   my $dp  = new DSNParser(opts=>$dsn_opts);
29             1                                237   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
30             1                                 56   my $dbh = $sb->get_dbh_for('master');
31    ***      1     50                           6   SKIP: {
32             1                                367      skip 'Cannot connect to MySQL', 1 unless $dbh;
33             1                                  8      ok($p->version_ge($dbh, '3.23.00'), 'Version is > 3.23');
34                                                    }
35                                                    
36                                                    # #############################################################################
37                                                    # Done.
38                                                    # #############################################################################
39             1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
31    ***     50      0      1   unless $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location          
---------- ----- ------------------
BEGIN          1 VersionParser.t:10
BEGIN          1 VersionParser.t:11
BEGIN          1 VersionParser.t:12
BEGIN          1 VersionParser.t:14
BEGIN          1 VersionParser.t:15
BEGIN          1 VersionParser.t:26
BEGIN          1 VersionParser.t:27
BEGIN          1 VersionParser.t:4 
BEGIN          1 VersionParser.t:9 


