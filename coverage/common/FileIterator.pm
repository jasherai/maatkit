---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/FileIterator.pm   79.6   62.5   40.0   88.9    0.0   53.6   72.8
FileIterator.t                100.0   50.0   40.0  100.0    n/a   46.4   94.1
Total                          90.1   61.1   40.0   94.4    0.0  100.0   82.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Jun  8 16:19:25 2010
Finish:       Tue Jun  8 16:19:25 2010

Run:          FileIterator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Jun  8 16:19:26 2010
Finish:       Tue Jun  8 16:19:26 2010

/home/daniel/dev/maatkit/common/FileIterator.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010-@CURRENTYEAR@ Percona Inc.
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
18                                                    # FileIterator package $Revision: 6326 $
19                                                    # ###########################################################################
20                                                    package FileIterator;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                 13   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1             8   use Data::Dumper;
               1                                  2   
               1                                  8   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
32                                                    
33                                                    sub new {
34    ***      1                    1      0      5      my ( $class, %args ) = @_;
35             1                                  4      my $self = {
36                                                          %args,
37                                                       };
38             1                                 13      return bless $self, $class;
39                                                    }
40                                                    
41                                                    # get_file_itr() returns an iterator over the filenames passed in, which are
42                                                    # typically from @ARGV on the command-line.  The special filename '-' is a
43                                                    # synonym for STDIN, and an empty array is equivalent to reading only from
44                                                    # STDIN.  Any non-readable files are warned about and skipped.  The iterator
45                                                    # actually returns a tuple:
46                                                    #   * A filehandle on the file, opened for reading.
47                                                    #   * The file name, or undef for STDIN.
48                                                    #   * The file size, or undef for STDIN.
49                                                    # You should use it like this:
50                                                    #  ( $fh, $name, $size ) = $next_fh->();
51                                                    # At the time of requesting the next file from the iterator, the code will skip
52                                                    # files that can't be opened, and just return the next one that can be.  This
53                                                    # way the calling code doesn't have to do any error handling: it either gets a
54                                                    # valid filehandle to work on next, or it's done.
55                                                    sub get_file_itr {
56    ***      3                    3      0     13      my ( $self, @filenames ) = @_;
57                                                    
58             3                                  9      my @final_filenames;
59                                                       FILENAME:
60             3                                 11      foreach my $fn ( @filenames ) {
61    ***      3     50                          13         if ( !defined $fn ) {
62    ***      0                                  0            warn "Skipping undefined filename";
63    ***      0                                  0            next FILENAME;
64                                                          }
65             3    100                          11         if ( $fn ne '-' ) {
66    ***      2     50     33                   41            if ( !-e $fn || !-r $fn ) {
67    ***      0                                  0               warn "$fn does not exist or is not readable";
68    ***      0                                  0               next FILENAME;
69                                                             }
70                                                          }
71             3                                 14         push @final_filenames, $fn;
72                                                       }
73                                                    
74                                                       # If the list of files is empty, read from STDIN.
75             3    100                          12      if ( !@filenames ) {
76             1                                  4         push @final_filenames, '-';
77             1                                  7         MKDEBUG && _d('Auto-adding "-" to the list of filenames');
78                                                       }
79                                                    
80             3                                  7      MKDEBUG && _d('Final filenames:', @final_filenames);
81                                                       return sub {
82             5                    5            25         while ( @final_filenames ) {
83             4                                 13            my $fn = shift @final_filenames;
84             4                                  8            MKDEBUG && _d('Filename:', $fn);
85             4    100                          17            if ( $fn eq '-' ) { # Magical STDIN filename.
86             2                                 20               return (*STDIN, undef, undef);
87                                                             }
88    ***      2     50                          62            open my $fh, '<', $fn or warn "Cannot open $fn: $OS_ERROR";
89    ***      2     50                           9            if ( $fh ) {
90             2                                 21               return ( $fh, $fn, -s $fn );
91                                                             }
92                                                          }
93             1                                  4         return (); # Avoids $f being set to 0 in list context.
94             3                                 25      };
95                                                    }
96                                                    
97                                                    sub _d {
98    ***      0                    0                    my ($package, undef, $line) = caller 0;
99    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
100   ***      0                                              map { defined $_ ? $_ : 'undef' }
101                                                           @_;
102   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
103                                                   }
104                                                   
105                                                   1;
106                                                   
107                                                   # ###########################################################################
108                                                   # End FileIterator package
109                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
61    ***     50      0      3   if (not defined $fn)
65           100      2      1   if ($fn ne '-')
66    ***     50      0      2   if (not -e $fn or not -r $fn)
75           100      1      2   if (not @filenames)
85           100      2      2   if ($fn eq '-')
88    ***     50      0      2   unless open my $fh, '<', $fn
89    ***     50      2      0   if ($fh)
99    ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
66    ***     33      0      0      2   not -e $fn or not -r $fn


Covered Subroutines
-------------------

Subroutine   Count Pod Location                                          
------------ ----- --- --------------------------------------------------
BEGIN            1     /home/daniel/dev/maatkit/common/FileIterator.pm:22
BEGIN            1     /home/daniel/dev/maatkit/common/FileIterator.pm:23
BEGIN            1     /home/daniel/dev/maatkit/common/FileIterator.pm:25
BEGIN            1     /home/daniel/dev/maatkit/common/FileIterator.pm:26
BEGIN            1     /home/daniel/dev/maatkit/common/FileIterator.pm:31
__ANON__         5     /home/daniel/dev/maatkit/common/FileIterator.pm:82
get_file_itr     3   0 /home/daniel/dev/maatkit/common/FileIterator.pm:56
new              1   0 /home/daniel/dev/maatkit/common/FileIterator.pm:34

Uncovered Subroutines
---------------------

Subroutine   Count Pod Location                                          
------------ ----- --- --------------------------------------------------
_d               0     /home/daniel/dev/maatkit/common/FileIterator.pm:98


FileIterator.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1             9   use Test::More tests => 12;
               1                                  4   
               1                                 11   
13                                                    
14             1                    1            12   use FileIterator;
               1                                  2   
               1                                 13   
15             1                    1            12   use MaatkitTest;
               1                                  4   
               1                                 38   
16                                                    
17    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 21   
18                                                    
19             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  5   
20             1                                  5   $Data::Dumper::Indent    = 1;
21             1                                  3   $Data::Dumper::Sortkeys  = 1;
22             1                                  4   $Data::Dumper::Quotekeys = 0;
23                                                    
24             1                                  4   my ($next_fh, $fh, $name, $size);
25             1                                  7   my $fi = new FileIterator();
26             1                                 10   isa_ok($fi, 'FileIterator');
27                                                    
28                                                    # #############################################################################
29                                                    # Empty list of filenames.
30                                                    # #############################################################################
31             1                                 10   $next_fh = $fi->get_file_itr(qw());
32             1                                  7   is( ref $next_fh, 'CODE', 'get_file_itr() returns a subref' );
33             1                                  5   ( $fh, $name, $size ) = $next_fh->();
34             1                                  8   is( "$fh", '*main::STDIN', 'Got STDIN for empty list' );
35             1                                  6   is( $name, undef, 'STDIN has no name' );
36             1                                  4   is( $size, undef, 'STDIN has no size' );
37                                                    
38                                                    # #############################################################################
39                                                    # Magical '-' filename.
40                                                    # #############################################################################
41             1                                  5   $next_fh = $fi->get_file_itr(qw(-));
42             1                                  9   ( $fh, $name, $size ) = $next_fh->();
43             1                                  7   is( "$fh", '*main::STDIN', 'Got STDIN for "-"' );
44                                                    
45                                                    # #############################################################################
46                                                    # Real filenames.
47                                                    # #############################################################################
48             1                                  5   $next_fh = $fi->get_file_itr(qw(samples/memc_tcpdump009.txt samples/empty));
49             1                                  9   ( $fh, $name, $size ) = $next_fh->();
50             1                                  6   is( ref $fh, 'GLOB', 'Open filehandle' );
51             1                                  7   is( $name, 'samples/memc_tcpdump009.txt', "Got filename for $name");
52             1                                  6   is( $size, 587, "Got size for $name");
53             1                                  5   ( $fh, $name, $size ) = $next_fh->();
54             1                                  2   is( $name, 'samples/empty', "Got filename for $name");
55             1                                  7   is( $size, 0, "Got size for $name");
56             1                                  5   ( $fh, $name, $size ) = $next_fh->();
57             1                                  2   is( $fh, undef, 'Ran off the end of the list' );
58                                                    
59                                                    # #############################################################################
60                                                    # Done.
61                                                    # #############################################################################
62             1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
17    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine Count Location         
---------- ----- -----------------
BEGIN          1 FileIterator.t:10
BEGIN          1 FileIterator.t:11
BEGIN          1 FileIterator.t:12
BEGIN          1 FileIterator.t:14
BEGIN          1 FileIterator.t:15
BEGIN          1 FileIterator.t:17
BEGIN          1 FileIterator.t:19
BEGIN          1 FileIterator.t:4 
BEGIN          1 FileIterator.t:9 


