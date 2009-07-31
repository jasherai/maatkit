---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Daemon.pm   63.0   38.5   66.7   84.6    n/a  100.0   57.2
Total                          63.0   38.5   66.7   84.6    n/a  100.0   57.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Daemon.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:27 2009
Finish:       Fri Jul 31 18:51:35 2009

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
18                                                    # Daemon package $Revision: 3976 $
19                                                    # ###########################################################################
20                                                    
21                                                    # Daemon - Daemonize and handle daemon-related tasks
22                                                    package Daemon;
23                                                    
24             1                    1             5   use strict;
               1                                  3   
               1                                103   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
26                                                    
27             1                    1             9   use POSIX qw(setsid);
               1                                  3   
               1                                  7   
28             1                    1            10   use English qw(-no_match_vars);
               1                                  2   
               1                                 10   
29                                                    
30             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 12   
31                                                    
32                                                    # The required o arg is an OptionParser object.
33                                                    sub new {
34             3                    3            20      my ( $class, %args ) = @_;
35             3                                 16      foreach my $arg ( qw(o) ) {
36    ***      3     50                          20         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38             3                                 13      my $o = $args{o};
39             3    100                          16      my $self = {
                    100                               
40                                                          o        => $o,
41                                                          log_file => $o->has('log') ? $o->get('log') : undef,
42                                                          PID_file => $o->has('pid') ? $o->get('pid') : undef,
43                                                       };
44                                                    
45                                                       # undef because we can't call like $self->check_PID_file() yet.
46             3                                 27      check_PID_file(undef, $self->{PID_file});
47                                                    
48             2                                  5      MKDEBUG && _d('Daemonized child will log to', $self->{log_file});
49             2                                 15      return bless $self, $class;
50                                                    }
51                                                    
52                                                    sub daemonize {
53    ***      0                    0             0      my ( $self ) = @_;
54                                                    
55    ***      0                                  0      MKDEBUG && _d('About to fork and daemonize');
56    ***      0      0                           0      defined (my $pid = fork()) or die "Cannot fork: $OS_ERROR";
57    ***      0      0                           0      if ( $pid ) {
58    ***      0                                  0         MKDEBUG && _d('I am the parent and now I die');
59    ***      0                                  0         exit;
60                                                       }
61                                                    
62                                                       # I'm daemonized now.
63    ***      0                                  0      $self->{child} = 1;
64                                                    
65    ***      0      0                           0      POSIX::setsid() or die "Cannot start a new session: $OS_ERROR";
66    ***      0      0                           0      chdir '/'       or die "Cannot chdir to /: $OS_ERROR";
67                                                    
68    ***      0                                  0      $self->_make_PID_file();
69                                                    
70                                                       # Only reopen STDIN to /dev/null if it's a tty.  It may be a pipe,
71                                                       # in which case we don't want to break it.
72    ***      0      0                           0      if ( -t STDIN ) {
73    ***      0                                  0         close STDIN;
74    ***      0      0                           0         open  STDIN, '/dev/null'
75                                                             or die "Cannot reopen STDIN to /dev/null";
76                                                       }
77                                                    
78    ***      0      0                           0      if ( $self->{log_file} ) {
79    ***      0                                  0         close STDOUT;
80    ***      0      0                           0         open  STDOUT, '>>', $self->{log_file}
81                                                             or die "Cannot open log file $self->{log_file}: $OS_ERROR";
82                                                    
83                                                          # If we don't close STDERR explicitly, then prove Daemon.t fails
84                                                          # because STDERR gets written before STDOUT even though we print
85                                                          # to STDOUT first in the tests.  I don't know why, but it's probably
86                                                          # best that we just explicitly close all fds before reopening them.
87    ***      0                                  0         close STDERR;
88    ***      0      0                           0         open  STDERR, ">&STDOUT"
89                                                             or die "Cannot dupe STDERR to STDOUT: $OS_ERROR";
90                                                       }
91                                                    
92    ***      0                                  0      MKDEBUG && _d('I am the child and now I live daemonized');
93    ***      0                                  0      return;
94                                                    }
95                                                    
96                                                    # The file arg is optional.  It's used when new() calls this sub
97                                                    # because $self hasn't been created yet.
98                                                    sub check_PID_file {
99             4                    4            16      my ( $self, $file ) = @_;
100            4    100                          18      my $PID_file = $self ? $self->{PID_file} : $file;
101            4                                 11      MKDEBUG && _d('Checking PID file', $PID_file);
102            4    100    100                   62      if ( $PID_file && -f $PID_file ) {
103            1                                  4         my $pid;
104            1                                  3         eval { chomp($pid = `cat $PID_file`); };
               1                               2616   
105   ***      1     50                          16         die "Cannot cat $PID_file: $OS_ERROR" if $EVAL_ERROR;
106            1                                  3         MKDEBUG && _d('PID file exists; it contains PID', $pid);
107   ***      1     50                           9         if ( $pid ) {
108   ***      0                                  0            my $pid_is_alive = kill 0, $pid;
109   ***      0      0                           0            if ( $pid_is_alive ) {
110   ***      0                                  0               die "The PID file $PID_file already exists "
111                                                                  . " and the PID that it contains, $pid, is running";
112                                                            }
113                                                            else {
114   ***      0                                  0               warn "Overwriting PID file $PID_file because the PID that it "
115                                                                  . "contains, $pid, is not running";
116                                                            }
117                                                         }
118                                                         else {
119                                                            # Be safe and die if we can't check that a process is
120                                                            # or is not already running.
121            1                                  6            die "The PID file $PID_file already exists but it does not "
122                                                               . "contain a PID";
123                                                         }
124                                                      }
125                                                      else {
126            3                                  8         MKDEBUG && _d('No PID file');
127                                                      }
128            3                                  9      return;
129                                                   }
130                                                   
131                                                   # Call this for non-daemonized scripts to make a PID file.
132                                                   sub make_PID_file {
133            1                    1             4      my ( $self ) = @_;
134   ***      1     50                           5      if ( exists $self->{child} ) {
135   ***      0                                  0         die "Do not call Daemon::make_PID_file() for daemonized scripts";
136                                                      }
137            1                                  7      $self->_make_PID_file();
138                                                      # This causes the PID file to be auto-removed when this obj is destroyed.
139            1                                  8      $self->{rm_PID_file} = 1;
140            1                                  2      return;
141                                                   }
142                                                   
143                                                   # Do not call this sub directly.  For daemonized scripts, it's called
144                                                   # automatically from daemonize() if there's a --pid opt.  For non-daemonized
145                                                   # scripts, call make_PID_file().
146                                                   sub _make_PID_file {
147            1                    1             3      my ( $self ) = @_;
148                                                   
149            1                                  4      my $PID_file = $self->{PID_file};
150   ***      1     50                           4      if ( !$PID_file ) {
151   ***      0                                  0         MKDEBUG && _d('No PID file to create');
152   ***      0                                  0         return;
153                                                      }
154                                                   
155                                                      # We checked this in new() but we'll double check here.
156            1                                  8      $self->check_PID_file();
157                                                   
158   ***      1     50                          60      open my $PID_FH, '>', $PID_file
159                                                         or die "Cannot open PID file $PID_file: $OS_ERROR";
160   ***      1     50                          19      print $PID_FH $PID
161                                                         or die "Cannot print to PID file $PID_file: $OS_ERROR";
162   ***      1     50                          34      close $PID_FH
163                                                         or die "Cannot close PID file $PID_file: $OS_ERROR";
164                                                   
165            1                                  3      MKDEBUG && _d('Created PID file:', $self->{PID_file});
166            1                                  3      return;
167                                                   }
168                                                   
169                                                   sub _remove_PID_file {
170            1                    1             4      my ( $self ) = @_;
171   ***      1     50     33                   31      if ( $self->{PID_file} && -f $self->{PID_file} ) {
172   ***      1     50                          40         unlink $self->{PID_file}
173                                                            or warn "Cannot remove PID file $self->{PID_file}: $OS_ERROR";
174            1                                  3         MKDEBUG && _d('Removed PID file');
175                                                      }
176                                                      else {
177   ***      0                                  0         MKDEBUG && _d('No PID to remove');
178                                                      }
179            1                                  3      return;
180                                                   }
181                                                   
182                                                   sub DESTROY {
183            2                    2            12      my ( $self ) = @_;
184                                                      # Remove the PID only if we're the child.
185   ***      2    100     66                   38      $self->_remove_PID_file() if $self->{child} || $self->{rm_PID_file};
186            2                                  6      return;
187                                                   }
188                                                   
189                                                   sub _d {
190   ***      0                    0                    my ($package, undef, $line) = caller 0;
191   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
192   ***      0                                              map { defined $_ ? $_ : 'undef' }
193                                                           @_;
194   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
195                                                   }
196                                                   
197                                                   1;
198                                                   
199                                                   # ###########################################################################
200                                                   # End Daemon package
201                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0      3   unless $args{$arg}
39           100      2      1   $o->has('log') ? :
             100      2      1   $o->has('pid') ? :
56    ***      0      0      0   unless defined(my $pid = fork)
57    ***      0      0      0   if ($pid)
65    ***      0      0      0   unless POSIX::setsid()
66    ***      0      0      0   unless chdir '/'
72    ***      0      0      0   if (-t STDIN)
74    ***      0      0      0   unless open STDIN, '/dev/null'
78    ***      0      0      0   if ($$self{'log_file'})
80    ***      0      0      0   unless open STDOUT, '>>', $$self{'log_file'}
88    ***      0      0      0   unless open STDERR, '>&STDOUT'
100          100      1      3   $self ? :
102          100      1      3   if ($PID_file and -f $PID_file) { }
105   ***     50      0      1   if $EVAL_ERROR
107   ***     50      0      1   if ($pid) { }
109   ***      0      0      0   if ($pid_is_alive) { }
134   ***     50      0      1   if (exists $$self{'child'})
150   ***     50      0      1   if (not $PID_file)
158   ***     50      0      1   unless open my $PID_FH, '>', $PID_file
160   ***     50      0      1   unless print $PID_FH $PID
162   ***     50      0      1   unless close $PID_FH
171   ***     50      1      0   if ($$self{'PID_file'} and -f $$self{'PID_file'}) { }
172   ***     50      0      1   unless unlink $$self{'PID_file'}
185          100      1      1   if $$self{'child'} or $$self{'rm_PID_file'}
191   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
102          100      1      2      1   $PID_file and -f $PID_file
171   ***     33      0      0      1   $$self{'PID_file'} and -f $$self{'PID_file'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
185   ***     66      0      1      1   $$self{'child'} or $$self{'rm_PID_file'}


Covered Subroutines
-------------------

Subroutine       Count Location                                     
---------------- ----- ---------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:24 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:25 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:27 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:28 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:30 
DESTROY              2 /home/daniel/dev/maatkit/common/Daemon.pm:183
_make_PID_file       1 /home/daniel/dev/maatkit/common/Daemon.pm:147
_remove_PID_file     1 /home/daniel/dev/maatkit/common/Daemon.pm:170
check_PID_file       4 /home/daniel/dev/maatkit/common/Daemon.pm:99 
make_PID_file        1 /home/daniel/dev/maatkit/common/Daemon.pm:133
new                  3 /home/daniel/dev/maatkit/common/Daemon.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Location                                     
---------------- ----- ---------------------------------------------
_d                   0 /home/daniel/dev/maatkit/common/Daemon.pm:190
daemonize            0 /home/daniel/dev/maatkit/common/Daemon.pm:53 


