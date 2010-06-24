---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Daemon.pm   58.0   33.3   70.0   84.6    0.0    0.1   51.3
Daemon.t                       99.1   50.0   33.3  100.0    n/a   99.9   90.8
Total                          79.7   36.8   56.2   90.5    0.0  100.0   68.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:27 2010
Finish:       Thu Jun 24 19:32:27 2010

Run:          Daemon.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:29 2010
Finish:       Thu Jun 24 19:32:38 2010

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
18                                                    # Daemon package $Revision: 6255 $
19                                                    # ###########################################################################
20                                                    
21                                                    # Daemon - Daemonize and handle daemon-related tasks
22                                                    package Daemon;
23                                                    
24             1                    1             5   use strict;
               1                                  2   
               1                                  7   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
26                                                    
27             1                    1            10   use POSIX qw(setsid);
               1                                  3   
               1                                  7   
28             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
29                                                    
30    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 16   
31                                                    
32                                                    # The required o arg is an OptionParser object.
33                                                    sub new {
34    ***      3                    3      0     41      my ( $class, %args ) = @_;
35             3                                 46      foreach my $arg ( qw(o) ) {
36    ***      3     50                          47         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38             3                                 21      my $o = $args{o};
39             3    100                          28      my $self = {
                    100                               
40                                                          o        => $o,
41                                                          log_file => $o->has('log') ? $o->get('log') : undef,
42                                                          PID_file => $o->has('pid') ? $o->get('pid') : undef,
43                                                       };
44                                                    
45                                                       # undef because we can't call like $self->check_PID_file() yet.
46             3                                 38      check_PID_file(undef, $self->{PID_file});
47                                                    
48             2                                  5      MKDEBUG && _d('Daemonized child will log to', $self->{log_file});
49             2                                 23      return bless $self, $class;
50                                                    }
51                                                    
52                                                    sub daemonize {
53    ***      0                    0      0      0      my ( $self ) = @_;
54                                                    
55    ***      0                                  0      MKDEBUG && _d('About to fork and daemonize');
56    ***      0      0                           0      defined (my $pid = fork()) or die "Cannot fork: $OS_ERROR";
57    ***      0      0                           0      if ( $pid ) {
58    ***      0                                  0         MKDEBUG && _d('I am the parent and now I die');
59    ***      0                                  0         exit;
60                                                       }
61                                                    
62                                                       # I'm daemonized now.
63    ***      0                                  0      $self->{PID_owner} = $PID;
64    ***      0                                  0      $self->{child}     = 1;
65                                                    
66    ***      0      0                           0      POSIX::setsid() or die "Cannot start a new session: $OS_ERROR";
67    ***      0      0                           0      chdir '/'       or die "Cannot chdir to /: $OS_ERROR";
68                                                    
69    ***      0                                  0      $self->_make_PID_file();
70                                                    
71    ***      0                                  0      $OUTPUT_AUTOFLUSH = 1;
72                                                    
73                                                       # Only reopen STDIN to /dev/null if it's a tty.  It may be a pipe,
74                                                       # in which case we don't want to break it.
75    ***      0      0                           0      if ( -t STDIN ) {
76    ***      0                                  0         close STDIN;
77    ***      0      0                           0         open  STDIN, '/dev/null'
78                                                             or die "Cannot reopen STDIN to /dev/null: $OS_ERROR";
79                                                       }
80                                                    
81    ***      0      0                           0      if ( $self->{log_file} ) {
82    ***      0                                  0         close STDOUT;
83    ***      0      0                           0         open  STDOUT, '>>', $self->{log_file}
84                                                             or die "Cannot open log file $self->{log_file}: $OS_ERROR";
85                                                    
86                                                          # If we don't close STDERR explicitly, then prove Daemon.t fails
87                                                          # because STDERR gets written before STDOUT even though we print
88                                                          # to STDOUT first in the tests.  I don't know why, but it's probably
89                                                          # best that we just explicitly close all fds before reopening them.
90    ***      0                                  0         close STDERR;
91    ***      0      0                           0         open  STDERR, ">&STDOUT"
92                                                             or die "Cannot dupe STDERR to STDOUT: $OS_ERROR"; 
93                                                       }
94                                                       else {
95    ***      0      0                           0         if ( -t STDOUT ) {
96    ***      0                                  0            close STDOUT;
97    ***      0      0                           0            open  STDOUT, '>', '/dev/null'
98                                                                or die "Cannot reopen STDOUT to /dev/null: $OS_ERROR";
99                                                          }
100   ***      0      0                           0         if ( -t STDERR ) {
101   ***      0                                  0            close STDERR;
102   ***      0      0                           0            open  STDERR, '>', '/dev/null'
103                                                               or die "Cannot reopen STDERR to /dev/null: $OS_ERROR";
104                                                         }
105                                                      }
106                                                   
107   ***      0                                  0      MKDEBUG && _d('I am the child and now I live daemonized');
108   ***      0                                  0      return;
109                                                   }
110                                                   
111                                                   # The file arg is optional.  It's used when new() calls this sub
112                                                   # because $self hasn't been created yet.
113                                                   sub check_PID_file {
114   ***      4                    4      0     25      my ( $self, $file ) = @_;
115            4    100                          27      my $PID_file = $self ? $self->{PID_file} : $file;
116            4                                 12      MKDEBUG && _d('Checking PID file', $PID_file);
117            4    100    100                  107      if ( $PID_file && -f $PID_file ) {
118            1                                  8         my $pid;
119            1                                  6         eval { chomp($pid = `cat $PID_file`); };
               1                               5108   
120   ***      1     50                          31         die "Cannot cat $PID_file: $OS_ERROR" if $EVAL_ERROR;
121            1                                 10         MKDEBUG && _d('PID file exists; it contains PID', $pid);
122   ***      1     50                          16         if ( $pid ) {
123   ***      0                                  0            my $pid_is_alive = kill 0, $pid;
124   ***      0      0                           0            if ( $pid_is_alive ) {
125   ***      0                                  0               die "The PID file $PID_file already exists "
126                                                                  . " and the PID that it contains, $pid, is running";
127                                                            }
128                                                            else {
129   ***      0                                  0               warn "Overwriting PID file $PID_file because the PID that it "
130                                                                  . "contains, $pid, is not running";
131                                                            }
132                                                         }
133                                                         else {
134                                                            # Be safe and die if we can't check that a process is
135                                                            # or is not already running.
136            1                                 13            die "The PID file $PID_file already exists but it does not "
137                                                               . "contain a PID";
138                                                         }
139                                                      }
140                                                      else {
141            3                                 10         MKDEBUG && _d('No PID file');
142                                                      }
143            3                                 12      return;
144                                                   }
145                                                   
146                                                   # Call this for non-daemonized scripts to make a PID file.
147                                                   sub make_PID_file {
148   ***      1                    1      0      7      my ( $self ) = @_;
149   ***      1     50                          12      if ( exists $self->{child} ) {
150   ***      0                                  0         die "Do not call Daemon::make_PID_file() for daemonized scripts";
151                                                      }
152            1                                 10      $self->_make_PID_file();
153                                                      # This causes the PID file to be auto-removed when this obj is destroyed.
154            1                                 15      $self->{PID_owner} = $PID;
155            1                                  4      return;
156                                                   }
157                                                   
158                                                   # Do not call this sub directly.  For daemonized scripts, it's called
159                                                   # automatically from daemonize() if there's a --pid opt.  For non-daemonized
160                                                   # scripts, call make_PID_file().
161                                                   sub _make_PID_file {
162            1                    1             7      my ( $self ) = @_;
163                                                   
164            1                                  7      my $PID_file = $self->{PID_file};
165   ***      1     50                           7      if ( !$PID_file ) {
166   ***      0                                  0         MKDEBUG && _d('No PID file to create');
167   ***      0                                  0         return;
168                                                      }
169                                                   
170                                                      # We checked this in new() but we'll double check here.
171            1                                  6      $self->check_PID_file();
172                                                   
173   ***      1     50                          86      open my $PID_FH, '>', $PID_file
174                                                         or die "Cannot open PID file $PID_file: $OS_ERROR";
175   ***      1     50                          27      print $PID_FH $PID
176                                                         or die "Cannot print to PID file $PID_file: $OS_ERROR";
177   ***      1     50                          51      close $PID_FH
178                                                         or die "Cannot close PID file $PID_file: $OS_ERROR";
179                                                   
180            1                                  5      MKDEBUG && _d('Created PID file:', $self->{PID_file});
181            1                                  4      return;
182                                                   }
183                                                   
184                                                   sub _remove_PID_file {
185            1                    1             7      my ( $self ) = @_;
186   ***      1     50     33                   35      if ( $self->{PID_file} && -f $self->{PID_file} ) {
187   ***      1     50                          79         unlink $self->{PID_file}
188                                                            or warn "Cannot remove PID file $self->{PID_file}: $OS_ERROR";
189            1                                  4         MKDEBUG && _d('Removed PID file');
190                                                      }
191                                                      else {
192   ***      0                                  0         MKDEBUG && _d('No PID to remove');
193                                                      }
194            1                                  5      return;
195                                                   }
196                                                   
197                                                   sub DESTROY {
198            2                    2            18      my ( $self ) = @_;
199                                                   
200                                                      # Remove the PID file only if we created it.  There's two cases where
201                                                      # it might be removed wrongly.  1) When the obj first daemonizes itself,
202                                                      # the parent's copy of the obj will call this sub when it exits.  We
203                                                      # don't remove it then because the child that continues to run won't
204                                                      # have it.  2) When daemonized code forks its children get copies of
205                                                      # the Daemon obj which will also call this sub when they exit.  We
206                                                      # don't remove it then because the daemonized parent code won't have it.
207                                                      # This trick works because $self->{PID_owner}=$PID is set once to the
208                                                      # owner's $PID then this value is copied on fork.  But the "== $PID"
209                                                      # here is the forked copy's PID which won't match the owner's PID.
210            2    100    100                   57      $self->_remove_PID_file() if ($self->{PID_owner} || 0) == $PID;
211                                                   
212            2                                  8      return;
213                                                   }
214                                                   
215                                                   sub _d {
216   ***      0                    0                    my ($package, undef, $line) = caller 0;
217   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
218   ***      0                                              map { defined $_ ? $_ : 'undef' }
219                                                           @_;
220   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
221                                                   }
222                                                   
223                                                   1;
224                                                   
225                                                   # ###########################################################################
226                                                   # End Daemon package
227                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0      3   unless $args{$arg}
39           100      2      1   $o->has('log') ? :
             100      2      1   $o->has('pid') ? :
56    ***      0      0      0   unless defined(my $pid = fork)
57    ***      0      0      0   if ($pid)
66    ***      0      0      0   unless POSIX::setsid()
67    ***      0      0      0   unless chdir '/'
75    ***      0      0      0   if (-t STDIN)
77    ***      0      0      0   unless open STDIN, '/dev/null'
81    ***      0      0      0   if ($$self{'log_file'}) { }
83    ***      0      0      0   unless open STDOUT, '>>', $$self{'log_file'}
91    ***      0      0      0   unless open STDERR, '>&STDOUT'
95    ***      0      0      0   if (-t STDOUT)
97    ***      0      0      0   unless open STDOUT, '>', '/dev/null'
100   ***      0      0      0   if (-t STDERR)
102   ***      0      0      0   unless open STDERR, '>', '/dev/null'
115          100      1      3   $self ? :
117          100      1      3   if ($PID_file and -f $PID_file) { }
120   ***     50      0      1   if $EVAL_ERROR
122   ***     50      0      1   if ($pid) { }
124   ***      0      0      0   if ($pid_is_alive) { }
149   ***     50      0      1   if (exists $$self{'child'})
165   ***     50      0      1   if (not $PID_file)
173   ***     50      0      1   unless open my $PID_FH, '>', $PID_file
175   ***     50      0      1   unless print $PID_FH $PID
177   ***     50      0      1   unless close $PID_FH
186   ***     50      1      0   if ($$self{'PID_file'} and -f $$self{'PID_file'}) { }
187   ***     50      0      1   unless unlink $$self{'PID_file'}
210          100      1      1   if ($$self{'PID_owner'} || 0) == $PID
217   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
117          100      1      2      1   $PID_file and -f $PID_file
186   ***     33      0      0      1   $$self{'PID_file'} and -f $$self{'PID_file'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0
210          100      1      1   $$self{'PID_owner'} || 0


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                     
---------------- ----- --- ---------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/Daemon.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/Daemon.pm:25 
BEGIN                1     /home/daniel/dev/maatkit/common/Daemon.pm:27 
BEGIN                1     /home/daniel/dev/maatkit/common/Daemon.pm:28 
BEGIN                1     /home/daniel/dev/maatkit/common/Daemon.pm:30 
DESTROY              2     /home/daniel/dev/maatkit/common/Daemon.pm:198
_make_PID_file       1     /home/daniel/dev/maatkit/common/Daemon.pm:162
_remove_PID_file     1     /home/daniel/dev/maatkit/common/Daemon.pm:185
check_PID_file       4   0 /home/daniel/dev/maatkit/common/Daemon.pm:114
make_PID_file        1   0 /home/daniel/dev/maatkit/common/Daemon.pm:148
new                  3   0 /home/daniel/dev/maatkit/common/Daemon.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                     
---------------- ----- --- ---------------------------------------------
_d                   0     /home/daniel/dev/maatkit/common/Daemon.pm:216
daemonize            0   0 /home/daniel/dev/maatkit/common/Daemon.pm:53 


Daemon.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1             9   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 23;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use Daemon;
               1                                  3   
               1                                 16   
15             1                    1            12   use OptionParser;
               1                                  3   
               1                                 14   
16             1                    1            15   use MaatkitTest;
               1                                  4   
               1                                 39   
17                                                    
18             1                                 12   my $o = new OptionParser(
19                                                       description => 'foo',
20                                                    );
21             1                                137   my $d = new Daemon(o=>$o);
22                                                    
23             1                                  4   my $pid_file = '/tmp/daemonizes.pl.pid';
24             1                                  3   my $log_file = '/tmp/daemonizes.output';
25                                                    
26             1                                  7   isa_ok($d, 'Daemon');
27                                                    
28             1                                  8   my $cmd     = "$trunk/common/t/samples/daemonizes.pl";
29             1                             118518   my $ret_val = system("$cmd 2 --daemonize --pid $pid_file");
30    ***      1     50                          14   SKIP: {
31             1                                 16      skip 'Cannot test Daemon.pm because t/daemonizes.pl is not working',
32                                                          18 unless $ret_val == 0;
33                                                    
34             1                              15491      my $output = `ps wx | grep '$cmd 2' | grep -v grep`;
35             1                                 85      like($output, qr/$cmd/, 'Daemonizes');
36             1                                 41      ok(-f $pid_file, 'Creates PID file');
37                                                    
38             1                                 13      my ($pid) = $output =~ /\s*(\d+)\s+/;
39             1                               2768      $output = `cat $pid_file`;
40             1                                 29      is($output, $pid, 'PID file has correct PID');
41                                                    
42             1                             2000277      sleep 2;
43             1                                 53      ok(! -f $pid_file, 'Removes PID file upon exit');
44                                                    
45                                                       # Check that STDOUT can be redirected
46             1                             156617      system("$cmd 2 --daemonize --log /tmp/mk-daemon.log");
47             1                                 55      ok(-f '/tmp/mk-daemon.log', 'Log file exists');
48                                                    
49             1                             2000638      sleep 2;
50             1                               5223      $output = `cat /tmp/mk-daemon.log`;
51             1                                 78      like($output, qr/STDOUT\nSTDERR\n/, 'STDOUT and STDERR went to log file');
52                                                    
53                                                       # Check that the log file is appended to.
54             1                             205699      system("$cmd 0 --daemonize --log /tmp/mk-daemon.log");
55             1                               5091      $output = `cat /tmp/mk-daemon.log`;
56             1                                 75      like(
57                                                          $output,
58                                                          qr/STDOUT\nSTDERR\nSTDOUT\nSTDERR\n/,
59                                                          'Appends to log file'
60                                                       );
61                                                    
62             1                               4996      `rm -f /tmp/mk-daemon.log`;
63                                                    
64                                                       # ##########################################################################
65                                                       # Issue 383: mk-deadlock-logger should die if --pid file specified exists
66                                                       # ##########################################################################
67             1                               5261      diag(`touch $pid_file`);
68             1                                 37      ok(
69                                                          -f  $pid_file,
70                                                          'PID file already exists'
71                                                       );
72                                                       
73             1                             217565      $output = `MKDEBUG=1 $cmd 0 --daemonize --pid $pid_file 2>&1`;
74             1                                 78      like(
75                                                          $output,
76                                                          qr{The PID file /tmp/daemonizes\.pl\.pid already exists},
77                                                          'Dies if PID file already exists'
78                                                       );
79                                                    
80             1                              35904       $output = `ps wx | grep '$cmd 0' | grep -v grep`;
81             1                                121       unlike(
82                                                          $output,
83                                                          qr/$cmd/,
84                                                          'Does not daemonizes'
85                                                       );
86                                                       
87             1                               5421      diag(`rm -rf $pid_file`);  
88                                                    
89                                                       # ##########################################################################
90                                                       # Issue 417: --daemonize doesn't let me log out of terminal cleanly
91                                                       # ##########################################################################
92    ***      1     50                          39      SKIP: {
93             1                                 11         skip 'No /proc', 2 unless -d '/proc';
94    ***      1     50     33                   75         skip 'No fd in /proc', 2 unless -l "/proc/$PID/0" || -l "/proc/$PID/fd/0";
95                                                    
96             1                             148369         system("$cmd 1 --daemonize --pid $pid_file --log $log_file");
97             1                               2695         chomp($pid = `cat $pid_file`);
98    ***      1     50                          59         my $proc_fd_0 = -l "/proc/$pid/0"    ? "/proc/$pid/0"
      ***            50                               
99                                                                        : -l "/proc/$pid/fd/0" ? "/proc/$pid/fd/0"
100                                                                       : die "Cannot find fd 0 symlink in /proc/$pid";
101            1                                 28         my $stdin = readlink $proc_fd_0;
102            1                                 25         is(
103                                                            $stdin,
104                                                            '/dev/null',
105                                                            'Reopens STDIN to /dev/null if not piped',
106                                                         );
107                                                   
108            1                             1000244         sleep 1;
109            1                             173341         system("echo foo | $cmd 1 --daemonize --pid $pid_file --log $log_file");
110            1                               2774         chomp($pid = `cat $pid_file`);
111   ***      1     50                          58         $proc_fd_0 = -l "/proc/$pid/0"    ? "/proc/$pid/0"
      ***            50                               
112                                                                    : -l "/proc/$pid/fd/0" ? "/proc/$pid/fd/0"
113                                                                    : die "Cannot find fd 0 symlink in /proc/$pid";
114            1                                 26         $stdin = readlink $proc_fd_0;
115            1                                 39         like(
116                                                            $stdin,
117                                                            qr/pipe/,
118                                                            'Does not reopen STDIN to /dev/null when piped',
119                                                         );
120                                                   
121                                                      };
122                                                   
123                                                      # ##########################################################################
124                                                      # Issue 419: Daemon should check wether process with pid obtained from
125                                                      # pid-file is still running
126                                                      # ##########################################################################
127            1                             110147      $output = `$cmd 5 --daemonize --pid $pid_file 2>&1`;
128            1                               2682      chomp($pid = `cat $pid_file`);
129            1                               1016      kill 9, $pid;
130            1                              15695      $output = `ps wax | grep $pid | grep -v grep`;
131            1                                 68      unlike(
132                                                         $output,
133                                                         qr/daemonize/,
134                                                         'Kill 9 daemonizes.pl (issue 419)'
135                                                      );
136            1                                 29      ok(
137                                                         -f $pid_file,
138                                                         'PID file remains after kill 9 (issue 419)'
139                                                      );
140                                                   
141            1                               2864      diag(`rm -rf $log_file`);
142            1                             112540      system("$cmd 1 --daemonize --log $log_file --pid $pid_file 2>/tmp/pre-daemonizes");
143            1                              18262      $output = `ps wx | grep '$cmd 1' | grep -v grep`;
144            1                               2695      chomp(my $new_pid = `cat $pid_file`);
145            1                             1000271      sleep 1;
146            1                                132      like(
147                                                         $output,
148                                                         qr/$cmd/,
149                                                         'Runs when PID file exists but old process is dead (issue 419)'
150                                                      );
151            1                               5147      like(
152                                                         `cat /tmp/pre-daemonizes`,
153                                                         qr/$pid, is not running/,
154                                                         'Says that old PID is not running (issue 419)'
155                                                      );
156            1                                 34      ok(
157                                                         $pid != $new_pid,
158                                                         'Overwrites PID file with new PID (issue 419)'
159                                                      );
160            1                                 36      ok(
161                                                         !-f $pid_file,
162                                                         'Re-used PID file still removed (issue 419)'
163                                                      );
164                                                   
165                                                      # Check that it actually checks the running process.
166            1                             161505      system("$cmd 1 --daemonize --log $log_file --pid $pid_file");
167            1                               2811      chomp($pid = `cat $pid_file`);
168            1                             113202      $output = `$cmd 0 --daemonize --pid $pid_file 2>&1`;
169            1                                 67      like(
170                                                         $output,
171                                                         qr/$pid, is running/,
172                                                         'Says that PID is running (issue 419)'
173                                                      );
174                                                   
175            1                             1000251      sleep 1;
176                                                   
177                                                      # Make sure PID file is gone to make subsequent tests happy.
178            1                               5300      diag(`rm -rf $pid_file`);
179            1                               4982      diag(`rm -rf $log_file`);
180            1                               5016      diag(`rm -rf /tmp/pre-daemonizes`);
181                                                   }
182                                                   
183                                                   # #############################################################################
184                                                   # Test auto-PID file removal without having to daemonize (for issue 391).
185                                                   # #############################################################################
186                                                   {
187            1                                 11      @ARGV = qw(--pid /tmp/d2.pid);
               1                                 17   
188            1                                 28      $o->get_specs("$trunk/common/t/samples/daemonizes.pl");
189            1                                 35      $o->get_opts();
190            1                                693      my $d2 = new Daemon(o=>$o);
191            1                                 13      $d2->make_PID_file();
192            1                                 25      ok(
193                                                         -f '/tmp/d2.pid',
194                                                         'PID file for non-daemon exists'
195                                                      );
196                                                   }
197                                                   # Since $d2 was locally scoped, it should have been destoryed by now.
198                                                   # This should have caused the PID file to be automatically removed.
199                                                   ok(
200            1                                 30      !-f '/tmpo/d2.pid',
201                                                      'PID file auto-removed for non-daemon'
202                                                   );
203                                                   
204                                                   # We should still die if the PID file already exists,
205                                                   # even if we're not a daemon.
206                                                   {
207            1                                  6      `touch /tmp/d2.pid`;
               1                               5621   
208            1                                 42      @ARGV = qw(--pid /tmp/d2.pid);
209            1                                 53      $o->get_opts();
210            1                                680      eval {
211            1                                 41         my $d2 = new Daemon(o=>$o);  # should die here actually
212   ***      0                                  0         $d2->make_PID_file();
213                                                      };
214            1                                 48      like(
215                                                         $EVAL_ERROR,
216                                                         qr{PID file /tmp/d2.pid already exists},
217                                                         'Dies if PID file already exists for non-daemon'
218                                                      );
219                                                   
220            1                               5190      `rm -rf /tmp/d2.pid`;
221                                                   }
222                                                   
223                                                   # #############################################################################
224                                                   # Done.
225                                                   # #############################################################################
226            1                              10625   diag(`rm -rf /tmp/daemonizes.*`);
227            1                                  8   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
30    ***     50      0      1   unless $ret_val == 0
92    ***     50      0      1   unless -d '/proc'
94    ***     50      0      1   unless -l "/proc/$PID/0" or -l "/proc/$PID/fd/0"
98    ***     50      1      0   -l "/proc/$pid/fd/0" ? :
      ***     50      0      1   -l "/proc/$pid/0" ? :
111   ***     50      1      0   -l "/proc/$pid/fd/0" ? :
      ***     50      0      1   -l "/proc/$pid/0" ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
94    ***     33      0      1      0   -l "/proc/$PID/0" or -l "/proc/$PID/fd/0"


Covered Subroutines
-------------------

Subroutine Count Location   
---------- ----- -----------
BEGIN          1 Daemon.t:10
BEGIN          1 Daemon.t:11
BEGIN          1 Daemon.t:12
BEGIN          1 Daemon.t:14
BEGIN          1 Daemon.t:15
BEGIN          1 Daemon.t:16
BEGIN          1 Daemon.t:4 
BEGIN          1 Daemon.t:9 


