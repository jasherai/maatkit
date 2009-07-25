---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/MaatkitCommon.pm  100.0   71.4   42.1  100.0    n/a  100.0   80.5
Total                         100.0   71.4   42.1  100.0    n/a  100.0   80.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MaatkitCommon.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Jul 25 21:55:00 2009
Finish:       Sat Jul 25 21:55:00 2009

/home/daniel/dev/maatkit/common/MaatkitCommon.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
18                                                    # MaatkitCommon package $Revision: 4248 $
19                                                    # ###########################################################################
20                                                    package MaatkitCommon;
21                                                    
22                                                    # These are common subs used in Maatkit scripts.
23                                                    
24             1                    1             6   use strict;
               1                                  2   
               1                                  5   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  4   
26                                                    
27             1                    1             5   use English qw(-no_match_vars);
               1                                 12   
               1                                  5   
28                                                    
29                                                    require Exporter;
30                                                    our @ISA         = qw(Exporter);
31                                                    our %EXPORT_TAGS = ();
32                                                    our @EXPORT      = qw();
33                                                    our @EXPORT_OK   = qw(
34                                                       _d
35                                                       get_number_of_cpus
36                                                    );
37                                                    
38             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
39                                                    
40                                                    # Eventually _d() will be exported by default.  We can't do this until
41                                                    # we remove it from all other modules else we'll get a "redefined" error.
42                                                    sub _d {
43             6                    6           162      my ($package, undef, $line) = caller 0;
44            10    100                          42      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
              10                                 38   
              10                                 44   
45             6                                 23           map { defined $_ ? $_ : 'undef' }
46                                                            @_;
47             6                                 56      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
48                                                    }
49                                                    
50                                                    # Returns the number of CPUs.  If no sys info is given, then it's gotten
51                                                    # from /proc/cpuinfo, sysctl or whatever method will work.  If sys info
52                                                    # is given, then we try to parse the number of CPUs from it.
53                                                    sub get_number_of_cpus {
54             4                    4           267      my ( $sys_info ) = @_;
55             4                                  9      my $n_cpus; 
56                                                    
57                                                       # Try to read the number of CPUs in /proc/cpuinfo.
58                                                       # This only works on GNU/Linux.
59             4                                  9      my $cpuinfo;
60    ***      4     50     33                   23      if ( $sys_info || (open $cpuinfo, "<", "/proc/cpuinfo") ) {
61             4                                 18         local $INPUT_RECORD_SEPARATOR = undef;
62    ***      4            33                   14         my $contents = $sys_info || <$cpuinfo>;
63             4                                  9         MKDEBUG && _d('sys info:', $contents);
64    ***      4     50                          16         close $cpuinfo if $cpuinfo;
65             4                                 17         $n_cpus = scalar( map { $_ } $contents =~ m/(processor)/g );
               2                                  7   
66             4                                  8         MKDEBUG && _d('Got', $n_cpus, 'from /proc/cpuinf');
67             4    100                          22         return $n_cpus if $n_cpus;
68                                                       }
69                                                    
70                                                       # Alternatives to /proc/cpuinfo:
71                                                    
72                                                       # FreeBSD and Mac OS X
73    ***      3     50     33                   18      if ( $sys_info || ($OSNAME =~ m/freebsd/i) || ($OSNAME =~ m/darwin/i) ) { 
      ***                   33                        
74    ***      3            33                   11         my $contents = $sys_info || `sysctl hw.ncpu`;
75             3                                  7         MKDEBUG && _d('sys info:', $contents);
76    ***      3     50                          16         ($n_cpus) = $contents =~ m/(\d)/ if $contents;
77             3                                  6         MKDEBUG && _d('Got', $n_cpus, 'from sysctl hw.ncpu');
78             3    100                          28         return $n_cpus if $n_cpus;
79                                                       } 
80                                                    
81                                                       # Windows   
82    ***      2            50                   10      $n_cpus ||= $ENV{NUMBER_OF_PROCESSORS};
83                                                    
84             2           100                   19      return $n_cpus || 1; # There has to be at least 1 CPU.
85                                                    }
86                                                    
87                                                    1;
88                                                    
89                                                    # ###########################################################################
90                                                    # End MaatkitCommon package
91                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
44           100      9      1   defined $_ ? :
60    ***     50      4      0   if ($sys_info or open $cpuinfo, '<', '/proc/cpuinfo')
64    ***     50      0      4   if $cpuinfo
67           100      1      3   if $n_cpus
73    ***     50      3      0   if ($sys_info or $OSNAME =~ /freebsd/i or $OSNAME =~ /darwin/i)
76    ***     50      3      0   if $contents
78           100      1      2   if $n_cpus


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
82    ***     50      0      2   $n_cpus ||= $ENV{'NUMBER_OF_PROCESSORS'}
84           100      1      1   $n_cpus || 1

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
60    ***     33      4      0      0   $sys_info or open $cpuinfo, '<', '/proc/cpuinfo'
62    ***     33      4      0      0   $sys_info || <$cpuinfo>
73    ***     33      3      0      0   $sys_info or $OSNAME =~ /freebsd/i
      ***     33      3      0      0   $sys_info or $OSNAME =~ /freebsd/i or $OSNAME =~ /darwin/i
74    ***     33      3      0      0   $sys_info || `sysctl hw.ncpu`


Covered Subroutines
-------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/MaatkitCommon.pm:24
BEGIN                  1 /home/daniel/dev/maatkit/common/MaatkitCommon.pm:25
BEGIN                  1 /home/daniel/dev/maatkit/common/MaatkitCommon.pm:27
BEGIN                  1 /home/daniel/dev/maatkit/common/MaatkitCommon.pm:38
_d                     6 /home/daniel/dev/maatkit/common/MaatkitCommon.pm:43
get_number_of_cpus     4 /home/daniel/dev/maatkit/common/MaatkitCommon.pm:54


