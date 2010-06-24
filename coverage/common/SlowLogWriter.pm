---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogWriter.pm   83.3   80.8   60.0   85.7    0.0    1.0   79.5
SlowLogWriter.t               100.0   50.0   33.3  100.0    n/a   99.0   92.3
Total                          92.2   73.5   50.0   94.7    0.0  100.0   85.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:21 2010
Finish:       Thu Jun 24 19:37:21 2010

Run:          SlowLogWriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:23 2010
Finish:       Thu Jun 24 19:37:23 2010

/home/daniel/dev/maatkit/common/SlowLogWriter.pm

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
18                                                    # SlowLogWriter package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package SlowLogWriter;
21                                                    
22             1                    1             6   use strict;
               1                                  2   
               1                                  5   
23             1                    1             9   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 11   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      5      my ( $class ) = @_;
30             1                                 21      bless {}, $class;
31                                                    }
32                                                    
33                                                    # Print out in slow-log format.
34                                                    sub write {
35    ***      5                    5      0     41      my ( $self, $fh, $event ) = @_;
36             5    100                          37      if ( $event->{ts} ) {
37             2                                 18         print $fh "# Time: $event->{ts}\n";
38                                                       }
39             5    100                          28      if ( $event->{user} ) {
40             3                                 40         printf $fh "# User\@Host: %s[%s] \@ %s []\n",
41                                                             $event->{user}, $event->{user}, $event->{host};
42                                                       }
43    ***      5    100     66                   51      if ( $event->{ip} && $event->{port} ) {
44             1                                 20         printf $fh "# Client: $event->{ip}:$event->{port}\n";
45                                                       }
46             5    100                          29      if ( $event->{Thread_id} ) {
47             1                                  7         printf $fh "# Thread_id: $event->{Thread_id}\n";
48                                                       }
49                                                    
50                                                       # Tweak output according to log type: either classic or Percona-patched.
51             5    100                          30      my $percona_patched = exists $event->{QC_Hit} ? 1 : 0;
52                                                    
53                                                       # Classic slow log attribs.
54            20    100                         268      printf $fh
55                                                          "# Query_time: %.6f  Lock_time: %.6f  Rows_sent: %d  Rows_examined: %d\n",
56                                                          # TODO 0  Rows_affected: 0  Rows_read: 1
57             5                                 28         map { $_ || 0 }
58             5                                 25            @{$event}{qw(Query_time Lock_time Rows_sent Rows_examined)};
59                                                    
60             5    100                          29      if ( $percona_patched ) {
61                                                          # First 2 lines of Percona-patched attribs.
62             8    100                          44         printf $fh
63                                                             "# QC_Hit: %s  Full_scan: %s  Full_join: %s  Tmp_table: %s  Disk_tmp_table: %s\n# Filesort: %s  Disk_filesort: %s  Merge_passes: %d\n",
64             1                                  5            map { $_ || 0 }
65             1                                  6               @{$event}{qw(QC_Hit Full_scan Full_join Tmp_table Disk_tmp_table Filesort Disk_filesort Merge_passes)};
66                                                    
67    ***      1     50                           6         if ( exists $event->{InnoDB_IO_r_ops} ) {
68                                                             # Optional 3 lines of Percona-patched InnoDB attribs.
69    ***      6     50                          46            printf $fh
70                                                                "#   InnoDB_IO_r_ops: %d  InnoDB_IO_r_bytes: %d  InnoDB_IO_r_wait: %s\n#   InnoDB_rec_lock_wait: %s  InnoDB_queue_wait: %s\n#   InnoDB_pages_distinct: %d\n",
71             1                                  5               map { $_ || 0 }
72             1                                  5                  @{$event}{qw(InnoDB_IO_r_ops InnoDB_IO_r_bytes InnoDB_IO_r_wait InnoDB_rec_lock_wait InnoDB_queue_wait InnoDB_pages_distinct)};
73                                                    
74                                                          } 
75                                                          else {
76    ***      0                                  0            printf $fh "# No InnoDB statistics available for this query\n";
77                                                          }
78                                                       }
79                                                    
80             5    100                          35      if ( $event->{db} ) {
81             2                                 11         printf $fh "use %s;\n", $event->{db};
82                                                       }
83    ***      5     50                          38      if ( $event->{arg} =~ m/^administrator command/ ) {
84    ***      0                                  0         print $fh '# ';
85                                                       }
86             5                                 24      print $fh $event->{arg}, ";\n";
87                                                    
88             5                                 40      return;
89                                                    }
90                                                    
91                                                    sub _d {
92    ***      0                    0                    my ($package, undef, $line) = caller 0;
93    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
94    ***      0                                              map { defined $_ ? $_ : 'undef' }
95                                                            @_;
96    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
97                                                    }
98                                                    
99                                                    1;
100                                                   
101                                                   # ###########################################################################
102                                                   # End SlowLogWriter package
103                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36           100      2      3   if ($$event{'ts'})
39           100      3      2   if ($$event{'user'})
43           100      1      4   if ($$event{'ip'} and $$event{'port'})
46           100      1      4   if ($$event{'Thread_id'})
51           100      1      4   exists $$event{'QC_Hit'} ? :
54           100     11      9   unless $_
60           100      1      4   if ($percona_patched)
62           100      1      7   unless $_
67    ***     50      1      0   if (exists $$event{'InnoDB_IO_r_ops'}) { }
69    ***     50      0      6   unless $_
80           100      2      3   if ($$event{'db'})
83    ***     50      0      5   if ($$event{'arg'} =~ /^administrator command/)
93    ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
43    ***     66      4      0      1   $$event{'ip'} and $$event{'port'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine Count Pod Location                                           
---------- ----- --- ---------------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/common/SlowLogWriter.pm:22
BEGIN          1     /home/daniel/dev/maatkit/common/SlowLogWriter.pm:23
BEGIN          1     /home/daniel/dev/maatkit/common/SlowLogWriter.pm:24
BEGIN          1     /home/daniel/dev/maatkit/common/SlowLogWriter.pm:26
new            1   0 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:29
write          5   0 /home/daniel/dev/maatkit/common/SlowLogWriter.pm:35

Uncovered Subroutines
---------------------

Subroutine Count Pod Location                                           
---------- ----- --- ---------------------------------------------------
_d             0     /home/daniel/dev/maatkit/common/SlowLogWriter.pm:92


SlowLogWriter.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            31      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            22   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            10   use Test::More tests => 4;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use SlowLogParser;
               1                                  2   
               1                                 10   
15             1                    1            45   use SlowLogWriter;
               1                                  3   
               1                                  9   
16             1                    1             9   use MaatkitTest;
               1                                  3   
               1                                 38   
17                                                    
18             1                                 11   my $p = new SlowLogParser;
19             1                                 36   my $w = new SlowLogWriter;
20                                                    
21                                                    sub __no_diff {
22             2                    2            16      my ( $filename, $expected ) = @_;
23                                                    
24                                                       # Parse and rewrite the original file.
25             2                                  9      my $tmp_file = '/tmp/SlowLogWriter-test.txt';
26    ***      2     50                         143      open my $rewritten_fh, '>', $tmp_file
27                                                          or die "Cannot write to $tmp_file: $OS_ERROR";
28    ***      2     50                          62      open my $fh, "<", "$trunk/$filename"
29                                                          or die "Cannot open $trunk/$filename: $OS_ERROR";
30                                                       my %args = (
31             5                    5           116         next_event => sub { return <$fh>;    },
32             8                    8           269         tell       => sub { return tell $fh; },
33             2                                 46      );
34             2                                 26      while ( my $e = $p->parse_event(%args) ) {
35             3                               1087         $w->write($rewritten_fh, $e);
36                                                       }
37             2                                 48      close $fh;
38             2                                 61      close $rewritten_fh;
39                                                    
40                                                       # Compare the contents of the two files.
41             2                              38239      my $retval = system("diff $tmp_file $trunk/$expected");
42             2                               7064      `rm -rf $tmp_file`;
43             2                                 34      $retval = $retval >> 8;
44             2                                 21      return !$retval;
45                                                    }
46                                                    
47                                                    sub write_event {
48             2                    2            20      my ( $event, $expected_output ) = @_;
49             2                                 12      my $tmp_file = '/tmp/SlowLogWriter-output.txt';
50    ***      2     50                         142      open my $fh, '>', $tmp_file or die "Cannot open $tmp_file: $OS_ERROR";
51             2                                 49      $w->write($fh, $event);
52             2                                 84      close $fh;
53             2                              33467      my $retval = system("diff $tmp_file $trunk/$expected_output");
54             2                               8244      `rm -rf $tmp_file`;
55             2                                 39      $retval = $retval >> 8;
56             2                                 22      return !$retval;
57                                                    }
58                                                    
59                                                    # Check that I can write a slow log in the default slow log format.
60             1                                  8   ok(
61                                                       __no_diff('common/t/samples/slow001.txt', 'common/t/samples/slow001-rewritten.txt'),
62                                                       'slow001.txt rewritten'
63                                                    );
64                                                    
65                                                    # Test writing a Percona-patched slow log with Thread_id and hi-res Query_time.
66             1                                  7   ok(
67                                                       __no_diff('common/t/samples/slow032.txt', 'common/t/samples/slow032-rewritten.txt'),
68                                                       'slow032.txt rewritten'
69                                                    );
70                                                    
71             1                                 36   ok(
72                                                       write_event(
73                                                          {
74                                                             Query_time => '1',
75                                                             arg        => 'select * from foo',
76                                                             ip         => '127.0.0.1',
77                                                             port       => '12345',
78                                                          },
79                                                          'common/t/samples/slowlogwriter001.txt',
80                                                       ),
81                                                       'Writes Client attrib from tcpdump',
82                                                    );
83                                                    
84             1                                 59   ok(
85                                                       write_event(
86                                                          {
87                                                             Query_time => '1.123456',
88                                                             Lock_time  => '0.000001',
89                                                             arg        => 'select * from foo',
90                                                          },
91                                                          'common/t/samples/slowlogwriter002.txt',
92                                                       ),
93                                                       'Writes microsecond times'
94                                                    );
95                                                    
96                                                    # #############################################################################
97                                                    # Done.
98                                                    # #############################################################################
99             1                               8438   diag(`rm -rf SlowLogWriter-test.txt >/dev/null 2>&1`);
100            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
26    ***     50      0      2   unless open my $rewritten_fh, '>', $tmp_file
28    ***     50      0      2   unless open my $fh, '<', "$trunk/$filename"
50    ***     50      0      2   unless open my $fh, '>', $tmp_file


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine  Count Location          
----------- ----- ------------------
BEGIN           1 SlowLogWriter.t:10
BEGIN           1 SlowLogWriter.t:11
BEGIN           1 SlowLogWriter.t:12
BEGIN           1 SlowLogWriter.t:14
BEGIN           1 SlowLogWriter.t:15
BEGIN           1 SlowLogWriter.t:16
BEGIN           1 SlowLogWriter.t:4 
BEGIN           1 SlowLogWriter.t:9 
__ANON__        5 SlowLogWriter.t:31
__ANON__        8 SlowLogWriter.t:32
__no_diff       2 SlowLogWriter.t:22
write_event     2 SlowLogWriter.t:48


