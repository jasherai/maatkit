---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Daemon.pm   59.7   37.0   66.7   83.3    n/a  100.0   54.9
Total                          59.7   37.0   66.7   83.3    n/a  100.0   54.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Daemon.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:29 2009
Finish:       Wed Jun 10 17:19:35 2009

/home/daniel/dev/maatkit/common/Daemon.pm

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
18                                                    # Daemon package $Revision: 3694 $
19                                                    # ###########################################################################
20                                                    
21                                                    # Daemon - Daemonize and handle daemon-related tasks
22                                                    package Daemon;
23                                                    
24             1                    1             5   use strict;
               1                                  2   
               1                                106   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
26                                                    
27             1                    1             9   use POSIX qw(setsid);
               1                                  3   
               1                                  7   
28             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                 11   
29                                                    
30             1                    1             8   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 14   
31                                                    
32                                                    # The required o arg is an OptionParser object.
33                                                    sub new {
34             3                    3            34      my ( $class, %args ) = @_;
35             3                                 18      foreach my $arg ( qw(o) ) {
36    ***      3     50                          25         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38             3                                 19      my $o = $args{o};
39             3    100                          22      my $self = {
                    100                               
40                                                          o        => $o,
41                                                          log_file => $o->has('log') ? $o->get('log') : undef,
42                                                          PID_file => $o->has('pid') ? $o->get('pid') : undef,
43                                                       };
44                                                    
45             3    100    100                   93      if ( $self->{PID_file} && -f $self->{PID_file} ) {
46             1                                  5         die "The PID file $self->{PID_file} already exists"
47                                                       }
48                                                    
49             2                                  5      MKDEBUG && _d('Daemonized child will log to', $self->{log_file});
50             2                                 19      return bless $self, $class;
51                                                    }
52                                                    
53                                                    sub daemonize {
54    ***      0                    0             0      my ( $self ) = @_;
55                                                    
56    ***      0                                  0      MKDEBUG && _d('About to fork and daemonize');
57    ***      0      0                           0      defined (my $pid = fork()) or die "Cannot fork: $OS_ERROR";
58    ***      0      0                           0      if ( $pid ) {
59    ***      0                                  0         MKDEBUG && _d('I am the parent and now I die');
60    ***      0                                  0         exit;
61                                                       }
62                                                    
63                                                       # I'm daemonized now.
64    ***      0                                  0      $self->{child} = 1;
65                                                    
66    ***      0      0                           0      POSIX::setsid() or die "Cannot start a new session: $OS_ERROR";
67    ***      0      0                           0      chdir '/'       or die "Cannot chdir to /: $OS_ERROR";
68                                                    
69    ***      0                                  0      $self->_make_PID_file();
70                                                    
71                                                       # Only reopen STDIN to /dev/null if it's a tty.  It may be a pipe,
72                                                       # in which case we don't want to break it.
73    ***      0      0                           0      if ( -t STDIN ) {
74    ***      0                                  0         close STDIN;
75    ***      0      0                           0         open  STDIN, '/dev/null'
76                                                             or die "Cannot reopen STDIN to /dev/null";
77                                                       }
78                                                    
79    ***      0      0                           0      if ( $self->{log_file} ) {
80    ***      0                                  0         close STDOUT;
81    ***      0      0                           0         open  STDOUT, '>>', $self->{log_file}
82                                                             or die "Cannot open log file $self->{log_file}: $OS_ERROR";
83                                                    
84                                                          # If we don't close STDERR explicitly, then prove Daemon.t fails
85                                                          # because STDERR gets written before STDOUT even though we print
86                                                          # to STDOUT first in the tests.  I don't know why, but it's probably
87                                                          # best that we just explicitly close all fds before reopening them.
88    ***      0                                  0         close STDERR;
89    ***      0      0                           0         open  STDERR, ">&STDOUT"
90                                                             or die "Cannot dupe STDERR to STDOUT: $OS_ERROR";
91                                                       }
92                                                    
93    ***      0                                  0      MKDEBUG && _d('I am the child and now I live daemonized');
94    ***      0                                  0      return;
95                                                    }
96                                                    
97                                                    # Call this for non-daemonized scripts to make a PID file.
98                                                    sub make_PID_file {
99             1                    1             9      my ( $self ) = @_;
100   ***      1     50                           8      if ( exists $self->{child} ) {
101   ***      0                                  0         die "Do not call Daemon::make_PID_file() for daemonized scripts";
102                                                      }
103            1                                 10      $self->_make_PID_file();
104                                                      # This causes the PID file to be auto-removed when this obj is destroyed.
105            1                                 13      $self->{rm_PID_file} = 1;
106            1                                  5      return;
107                                                   }
108                                                   
109                                                   # Do not call this sub directly.  For daemonized scripts, it's called
110                                                   # automatically from daemonize() if there's a --pid opt.  For non-daemonized
111                                                   # scripts, call make_PID_file().
112                                                   sub _make_PID_file {
113            1                    1             5      my ( $self ) = @_;
114                                                   
115            1                                  6      my $PID_file = $self->{PID_file};
116   ***      1     50                           7      if ( !$PID_file ) {
117   ***      0                                  0         MKDEBUG && _d('No PID file to create');
118   ***      0                                  0         return;
119                                                      }
120                                                   
121                                                      # We checked this in new() but we'll double check here.
122   ***      1     50                          13      if ( -f $self->{PID_file} ) {
123   ***      0                                  0         die "The PID file $self->{PID_file} already exists"
124                                                      }
125                                                   
126   ***      1     50                         102      open my $PID_FH, '>', $PID_file
127                                                         or die "Cannot open PID file $PID_file: $OS_ERROR";
128   ***      1     50                          36      print $PID_FH $PID
129                                                         or die "Cannot print to PID file $PID_file: $OS_ERROR";
130   ***      1     50                          53      close $PID_FH
131                                                         or die "Cannot close PID file $PID_file: $OS_ERROR";
132                                                   
133            1                                  3      MKDEBUG && _d('Created PID file:', $self->{PID_file});
134            1                                  5      return;
135                                                   }
136                                                   
137                                                   sub _remove_PID_file {
138            1                    1             6      my ( $self ) = @_;
139   ***      1     50     33                   28      if ( $self->{PID_file} && -f $self->{PID_file} ) {
140   ***      1     50                          76         unlink $self->{PID_file}
141                                                            or warn "Cannot remove PID file $self->{PID_file}: $OS_ERROR";
142            1                                  4         MKDEBUG && _d('Removed PID file');
143                                                      }
144                                                      else {
145   ***      0                                  0         MKDEBUG && _d('No PID to remove');
146                                                      }
147            1                                  5      return;
148                                                   }
149                                                   
150                                                   sub DESTROY {
151            2                    2            16      my ( $self ) = @_;
152                                                      # Remove the PID only if we're the child.
153   ***      2    100     66                   55      $self->_remove_PID_file() if $self->{child} || $self->{rm_PID_file};
154            2                                  8      return;
155                                                   }
156                                                   
157                                                   sub _d {
158   ***      0                    0                    my ($package, undef, $line) = caller 0;
159   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
160   ***      0                                              map { defined $_ ? $_ : 'undef' }
161                                                           @_;
162   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
163                                                   }
164                                                   
165                                                   1;
166                                                   
167                                                   # ###########################################################################
168                                                   # End Daemon package
169                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0      3   unless $args{$arg}
39           100      2      1   $o->has('log') ? :
             100      2      1   $o->has('pid') ? :
45           100      1      2   if ($$self{'PID_file'} and -f $$self{'PID_file'})
57    ***      0      0      0   unless defined(my $pid = fork)
58    ***      0      0      0   if ($pid)
66    ***      0      0      0   unless POSIX::setsid()
67    ***      0      0      0   unless chdir '/'
73    ***      0      0      0   if (-t STDIN)
75    ***      0      0      0   unless open STDIN, '/dev/null'
79    ***      0      0      0   if ($$self{'log_file'})
81    ***      0      0      0   unless open STDOUT, '>>', $$self{'log_file'}
89    ***      0      0      0   unless open STDERR, '>&STDOUT'
100   ***     50      0      1   if (exists $$self{'child'})
116   ***     50      0      1   if (not $PID_file)
122   ***     50      0      1   if (-f $$self{'PID_file'})
126   ***     50      0      1   unless open my $PID_FH, '>', $PID_file
128   ***     50      0      1   unless print $PID_FH $PID
130   ***     50      0      1   unless close $PID_FH
139   ***     50      1      0   if ($$self{'PID_file'} and -f $$self{'PID_file'}) { }
140   ***     50      0      1   unless unlink $$self{'PID_file'}
153          100      1      1   if $$self{'child'} or $$self{'rm_PID_file'}
159   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
45           100      1      1      1   $$self{'PID_file'} and -f $$self{'PID_file'}
139   ***     33      0      0      1   $$self{'PID_file'} and -f $$self{'PID_file'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
153   ***     66      0      1      1   $$self{'child'} or $$self{'rm_PID_file'}


Covered Subroutines
-------------------

Subroutine       Count Location                                     
---------------- ----- ---------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:24 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:25 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:27 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:28 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:30 
DESTROY              2 /home/daniel/dev/maatkit/common/Daemon.pm:151
_make_PID_file       1 /home/daniel/dev/maatkit/common/Daemon.pm:113
_remove_PID_file     1 /home/daniel/dev/maatkit/common/Daemon.pm:138
make_PID_file        1 /home/daniel/dev/maatkit/common/Daemon.pm:99 
new                  3 /home/daniel/dev/maatkit/common/Daemon.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Location                                     
---------------- ----- ---------------------------------------------
_d                   0 /home/daniel/dev/maatkit/common/Daemon.pm:158
daemonize            0 /home/daniel/dev/maatkit/common/Daemon.pm:54 


