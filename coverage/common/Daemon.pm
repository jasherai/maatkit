---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Daemon.pm   58.6   33.3   66.7   84.6    n/a  100.0   52.5
Total                          58.6   33.3   66.7   84.6    n/a  100.0   52.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Daemon.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:01:32 2009
Finish:       Sat Aug 29 15:01:40 2009

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
18                                                    # Daemon package $Revision: 4565 $
19                                                    # ###########################################################################
20                                                    
21                                                    # Daemon - Daemonize and handle daemon-related tasks
22                                                    package Daemon;
23                                                    
24             1                    1             5   use strict;
               1                                  3   
               1                                  7   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                113   
26                                                    
27             1                    1            10   use POSIX qw(setsid);
               1                                  4   
               1                                  8   
28             1                    1            13   use English qw(-no_match_vars);
               1                                  3   
               1                                 13   
29                                                    
30             1                    1             8   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 13   
31                                                    
32                                                    # The required o arg is an OptionParser object.
33                                                    sub new {
34             3                    3            25      my ( $class, %args ) = @_;
35             3                                 18      foreach my $arg ( qw(o) ) {
36    ***      3     50                          19         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38             3                                 14      my $o = $args{o};
39             3    100                          19      my $self = {
                    100                               
40                                                          o        => $o,
41                                                          log_file => $o->has('log') ? $o->get('log') : undef,
42                                                          PID_file => $o->has('pid') ? $o->get('pid') : undef,
43                                                       };
44                                                    
45                                                       # undef because we can't call like $self->check_PID_file() yet.
46             3                                 22      check_PID_file(undef, $self->{PID_file});
47                                                    
48             2                                  4      MKDEBUG && _d('Daemonized child will log to', $self->{log_file});
49             2                                 14      return bless $self, $class;
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
70    ***      0                                  0      $OUTPUT_AUTOFLUSH = 1;
71                                                    
72                                                       # Only reopen STDIN to /dev/null if it's a tty.  It may be a pipe,
73                                                       # in which case we don't want to break it.
74    ***      0      0                           0      if ( -t STDIN ) {
75    ***      0                                  0         close STDIN;
76    ***      0      0                           0         open  STDIN, '/dev/null'
77                                                             or die "Cannot reopen STDIN to /dev/null: $OS_ERROR";
78                                                       }
79                                                    
80    ***      0      0                           0      if ( $self->{log_file} ) {
81    ***      0                                  0         close STDOUT;
82    ***      0      0                           0         open  STDOUT, '>>', $self->{log_file}
83                                                             or die "Cannot open log file $self->{log_file}: $OS_ERROR";
84                                                    
85                                                          # If we don't close STDERR explicitly, then prove Daemon.t fails
86                                                          # because STDERR gets written before STDOUT even though we print
87                                                          # to STDOUT first in the tests.  I don't know why, but it's probably
88                                                          # best that we just explicitly close all fds before reopening them.
89    ***      0                                  0         close STDERR;
90    ***      0      0                           0         open  STDERR, ">&STDOUT"
91                                                             or die "Cannot dupe STDERR to STDOUT: $OS_ERROR"; 
92                                                       }
93                                                       else {
94    ***      0      0                           0         if ( -t STDOUT ) {
95    ***      0                                  0            close STDOUT;
96    ***      0      0                           0            open  STDOUT, '>', '/dev/null'
97                                                                or die "Cannot reopen STDOUT to /dev/null: $OS_ERROR";
98                                                          }
99    ***      0      0                           0         if ( -t STDERR ) {
100   ***      0                                  0            close STDERR;
101   ***      0      0                           0            open  STDERR, '>', '/dev/null'
102                                                               or die "Cannot reopen STDERR to /dev/null: $OS_ERROR";
103                                                         }
104                                                      }
105                                                   
106   ***      0                                  0      MKDEBUG && _d('I am the child and now I live daemonized');
107   ***      0                                  0      return;
108                                                   }
109                                                   
110                                                   # The file arg is optional.  It's used when new() calls this sub
111                                                   # because $self hasn't been created yet.
112                                                   sub check_PID_file {
113            4                    4            20      my ( $self, $file ) = @_;
114            4    100                          19      my $PID_file = $self ? $self->{PID_file} : $file;
115            4                                  8      MKDEBUG && _d('Checking PID file', $PID_file);
116            4    100    100                   64      if ( $PID_file && -f $PID_file ) {
117            1                                  3         my $pid;
118            1                                  2         eval { chomp($pid = `cat $PID_file`); };
               1                               2682   
119   ***      1     50                          16         die "Cannot cat $PID_file: $OS_ERROR" if $EVAL_ERROR;
120            1                                  6         MKDEBUG && _d('PID file exists; it contains PID', $pid);
121   ***      1     50                           9         if ( $pid ) {
122   ***      0                                  0            my $pid_is_alive = kill 0, $pid;
123   ***      0      0                           0            if ( $pid_is_alive ) {
124   ***      0                                  0               die "The PID file $PID_file already exists "
125                                                                  . " and the PID that it contains, $pid, is running";
126                                                            }
127                                                            else {
128   ***      0                                  0               warn "Overwriting PID file $PID_file because the PID that it "
129                                                                  . "contains, $pid, is not running";
130                                                            }
131                                                         }
132                                                         else {
133                                                            # Be safe and die if we can't check that a process is
134                                                            # or is not already running.
135            1                                  6            die "The PID file $PID_file already exists but it does not "
136                                                               . "contain a PID";
137                                                         }
138                                                      }
139                                                      else {
140            3                                  7         MKDEBUG && _d('No PID file');
141                                                      }
142            3                                  9      return;
143                                                   }
144                                                   
145                                                   # Call this for non-daemonized scripts to make a PID file.
146                                                   sub make_PID_file {
147            1                    1             4      my ( $self ) = @_;
148   ***      1     50                          10      if ( exists $self->{child} ) {
149   ***      0                                  0         die "Do not call Daemon::make_PID_file() for daemonized scripts";
150                                                      }
151            1                                  6      $self->_make_PID_file();
152                                                      # This causes the PID file to be auto-removed when this obj is destroyed.
153            1                                  8      $self->{rm_PID_file} = 1;
154            1                                  3      return;
155                                                   }
156                                                   
157                                                   # Do not call this sub directly.  For daemonized scripts, it's called
158                                                   # automatically from daemonize() if there's a --pid opt.  For non-daemonized
159                                                   # scripts, call make_PID_file().
160                                                   sub _make_PID_file {
161            1                    1             4      my ( $self ) = @_;
162                                                   
163            1                                  4      my $PID_file = $self->{PID_file};
164   ***      1     50                           4      if ( !$PID_file ) {
165   ***      0                                  0         MKDEBUG && _d('No PID file to create');
166   ***      0                                  0         return;
167                                                      }
168                                                   
169                                                      # We checked this in new() but we'll double check here.
170            1                                  4      $self->check_PID_file();
171                                                   
172   ***      1     50                          81      open my $PID_FH, '>', $PID_file
173                                                         or die "Cannot open PID file $PID_file: $OS_ERROR";
174   ***      1     50                          22      print $PID_FH $PID
175                                                         or die "Cannot print to PID file $PID_file: $OS_ERROR";
176   ***      1     50                          32      close $PID_FH
177                                                         or die "Cannot close PID file $PID_file: $OS_ERROR";
178                                                   
179            1                                  2      MKDEBUG && _d('Created PID file:', $self->{PID_file});
180            1                                  3      return;
181                                                   }
182                                                   
183                                                   sub _remove_PID_file {
184            1                    1             4      my ( $self ) = @_;
185   ***      1     50     33                   15      if ( $self->{PID_file} && -f $self->{PID_file} ) {
186   ***      1     50                          46         unlink $self->{PID_file}
187                                                            or warn "Cannot remove PID file $self->{PID_file}: $OS_ERROR";
188            1                                  3         MKDEBUG && _d('Removed PID file');
189                                                      }
190                                                      else {
191   ***      0                                  0         MKDEBUG && _d('No PID to remove');
192                                                      }
193            1                                  3      return;
194                                                   }
195                                                   
196                                                   sub DESTROY {
197            2                    2            13      my ( $self ) = @_;
198                                                      # Remove the PID only if we're the child.
199   ***      2    100     66                   34      $self->_remove_PID_file() if $self->{child} || $self->{rm_PID_file};
200            2                                  7      return;
201                                                   }
202                                                   
203                                                   sub _d {
204   ***      0                    0                    my ($package, undef, $line) = caller 0;
205   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
206   ***      0                                              map { defined $_ ? $_ : 'undef' }
207                                                           @_;
208   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
209                                                   }
210                                                   
211                                                   1;
212                                                   
213                                                   # ###########################################################################
214                                                   # End Daemon package
215                                                   # ###########################################################################


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
74    ***      0      0      0   if (-t STDIN)
76    ***      0      0      0   unless open STDIN, '/dev/null'
80    ***      0      0      0   if ($$self{'log_file'}) { }
82    ***      0      0      0   unless open STDOUT, '>>', $$self{'log_file'}
90    ***      0      0      0   unless open STDERR, '>&STDOUT'
94    ***      0      0      0   if (-t STDOUT)
96    ***      0      0      0   unless open STDOUT, '>', '/dev/null'
99    ***      0      0      0   if (-t STDERR)
101   ***      0      0      0   unless open STDERR, '>', '/dev/null'
114          100      1      3   $self ? :
116          100      1      3   if ($PID_file and -f $PID_file) { }
119   ***     50      0      1   if $EVAL_ERROR
121   ***     50      0      1   if ($pid) { }
123   ***      0      0      0   if ($pid_is_alive) { }
148   ***     50      0      1   if (exists $$self{'child'})
164   ***     50      0      1   if (not $PID_file)
172   ***     50      0      1   unless open my $PID_FH, '>', $PID_file
174   ***     50      0      1   unless print $PID_FH $PID
176   ***     50      0      1   unless close $PID_FH
185   ***     50      1      0   if ($$self{'PID_file'} and -f $$self{'PID_file'}) { }
186   ***     50      0      1   unless unlink $$self{'PID_file'}
199          100      1      1   if $$self{'child'} or $$self{'rm_PID_file'}
205   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
116          100      1      2      1   $PID_file and -f $PID_file
185   ***     33      0      0      1   $$self{'PID_file'} and -f $$self{'PID_file'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
199   ***     66      0      1      1   $$self{'child'} or $$self{'rm_PID_file'}


Covered Subroutines
-------------------

Subroutine       Count Location                                     
---------------- ----- ---------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:24 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:25 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:27 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:28 
BEGIN                1 /home/daniel/dev/maatkit/common/Daemon.pm:30 
DESTROY              2 /home/daniel/dev/maatkit/common/Daemon.pm:197
_make_PID_file       1 /home/daniel/dev/maatkit/common/Daemon.pm:161
_remove_PID_file     1 /home/daniel/dev/maatkit/common/Daemon.pm:184
check_PID_file       4 /home/daniel/dev/maatkit/common/Daemon.pm:113
make_PID_file        1 /home/daniel/dev/maatkit/common/Daemon.pm:147
new                  3 /home/daniel/dev/maatkit/common/Daemon.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Location                                     
---------------- ----- ---------------------------------------------
_d                   0 /home/daniel/dev/maatkit/common/Daemon.pm:204
daemonize            0 /home/daniel/dev/maatkit/common/Daemon.pm:53 


