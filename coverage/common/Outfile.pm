---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/Outfile.pm   81.2   62.5   50.0   88.9    0.0    1.2   74.1
Outfile.t                     100.0   50.0   33.3  100.0    n/a   98.8   93.1
Total                          91.8   58.3   40.0   94.7    0.0  100.0   83.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:30 2010
Finish:       Thu Jun 24 19:35:30 2010

Run:          Outfile.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:32 2010
Finish:       Thu Jun 24 19:35:32 2010

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
18                                                    # Outfile package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package Outfile;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  6   
               1                                  7   
25                                                    
26             1                    1             7   use List::Util qw(min);
               1                                  2   
               1                                 10   
27                                                    
28    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 20   
29                                                    
30                                                    sub new {
31    ***      1                    1      0      5      my ( $class, %args ) = @_;
32             1                                  4      my $self = {};
33             1                                 16      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # Print out in SELECT INTO OUTFILE format.
37                                                    # $rows is an arrayref from DBI::selectall_arrayref().
38                                                    sub write {
39    ***      1                    1      0      6      my ( $self, $fh, $rows ) = @_;
40             1                                  5      foreach my $row ( @$rows ) {
41    ***      2     50                          11         print $fh escape($row), "\n"
42                                                             or die "Cannot write to outfile: $OS_ERROR\n";
43                                                       }
44             1                                  4      return;
45                                                    }
46                                                    
47                                                    # Formats a row the same way SELECT INTO OUTFILE does by default.  This is
48                                                    # described in the LOAD DATA INFILE section of the MySQL manual,
49                                                    # http://dev.mysql.com/doc/refman/5.0/en/load-data.html
50                                                    sub escape {
51    ***      2                    2      0      7      my ( $row ) = @_;
52            16    100                          59      return join("\t", map {
53             2                                  9         s/([\t\n\\])/\\$1/g if defined $_;  # Escape tabs etc
54            16    100                          78         defined $_ ? $_ : '\N';             # NULL = \N
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


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
28    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine Count Pod Location                                     
---------- ----- --- ---------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/common/Outfile.pm:22
BEGIN          1     /home/daniel/dev/maatkit/common/Outfile.pm:23
BEGIN          1     /home/daniel/dev/maatkit/common/Outfile.pm:24
BEGIN          1     /home/daniel/dev/maatkit/common/Outfile.pm:26
BEGIN          1     /home/daniel/dev/maatkit/common/Outfile.pm:28
escape         2   0 /home/daniel/dev/maatkit/common/Outfile.pm:51
new            1   0 /home/daniel/dev/maatkit/common/Outfile.pm:31
write          1   0 /home/daniel/dev/maatkit/common/Outfile.pm:39

Uncovered Subroutines
---------------------

Subroutine Count Pod Location                                     
---------- ----- --- ---------------------------------------------
_d             0     /home/daniel/dev/maatkit/common/Outfile.pm:59


Outfile.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            10   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 1;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use Outfile;
               1                                  3   
               1                                 11   
15             1                    1            10   use DSNParser;
               1                                  3   
               1                                 13   
16             1                    1            13   use Sandbox;
               1                                  2   
               1                                 10   
17             1                    1            11   use MaatkitTest;
               1                                  6   
               1                                 38   
18                                                    
19                                                    # This is just for grabbing stuff from fetchrow_arrayref()
20                                                    # instead of writing test rows by hand.
21             1                                 12   my $dp  = new DSNParser(opts=>$dsn_opts);
22             1                                237   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
23             1                                 53   my $dbh = $sb->get_dbh_for('master');
24                                                    
25             1                                383   my $outfile = new Outfile();
26                                                    
27                                                    sub test_outfile {
28             1                    1             5      my ( $rows, $expected_output ) = @_;
29             1                                  3      my $tmp_file = '/tmp/Outfile-output.txt';
30    ***      1     50                          82      open my $fh, '>', $tmp_file or die "Cannot open $tmp_file: $OS_ERROR";
31             1                                  6      $outfile->write($fh, $rows);
32             1                                 38      close $fh;
33             1                              19527      my $retval = system("diff $tmp_file $expected_output");
34             1                               2907      `rm -rf $tmp_file`;
35             1                                 14      $retval = $retval >> 8;
36             1                                 11      return !$retval;
37                                                    }
38                                                    
39                                                    
40             1                                 15   ok(
41                                                       test_outfile(
42                                                          [
43                                                             [
44                                                              '1',
45                                                              'a',
46                                                              'some text',
47                                                              '3.14',
48                                                              '5.08',
49                                                              'Here\'s more complex text that has "quotes", and maybe a comma.',
50                                                              '2009-08-19 08:48:08',
51                                                              '2009-08-19 08:48:08'
52                                                             ],
53                                                             [
54                                                              '2',
55                                                              '',
56                                                              'the char and text are blank, the',
57                                                              undef,
58                                                              '5.09',
59                                                              '',
60                                                              '2009-08-19 08:49:17',
61                                                              '2009-08-19 08:49:17'
62                                                             ]
63                                                          ],
64                                                          "$trunk/common/t/samples/outfile001.txt",
65                                                       ),
66                                                       'outfile001.txt'
67                                                    );
68                                                    
69                                                    # #############################################################################
70                                                    # Done.
71                                                    # #############################################################################
72             1                                  5   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
30    ***     50      0      1   unless open my $fh, '>', $tmp_file


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine   Count Location    
------------ ----- ------------
BEGIN            1 Outfile.t:10
BEGIN            1 Outfile.t:11
BEGIN            1 Outfile.t:12
BEGIN            1 Outfile.t:14
BEGIN            1 Outfile.t:15
BEGIN            1 Outfile.t:16
BEGIN            1 Outfile.t:17
BEGIN            1 Outfile.t:4 
BEGIN            1 Outfile.t:9 
test_outfile     1 Outfile.t:28


