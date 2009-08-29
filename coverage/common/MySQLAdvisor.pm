---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/MySQLAdvisor.pm   68.6   30.0    n/a   87.5    n/a  100.0   64.2
Total                          68.6   30.0    n/a   87.5    n/a  100.0   64.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLAdvisor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:07 2009
Finish:       Sat Aug 29 15:03:07 2009

/home/daniel/dev/maatkit/common/MySQLAdvisor.pm

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
18                                                    # MySQLAdvisor package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    
21                                                    # MySQLAdvisor - Check MySQL system variables and status values for problems
22                                                    package MySQLAdvisor;
23                                                    
24             1                    1             6   use strict;
               1                                  2   
               1                                  7   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
26                                                    
27             1                    1            19   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
28             1                    1             7   use List::Util qw(max);
               1                                  2   
               1                                 11   
29                                                    
30             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 15   
31                                                    
32                                                    # These check subs return 0 if the check passes or a string describing what
33                                                    # failed. If a check can't be tested (e.g. no Innodb_ status values), return 0.
34                                                    my %checks = (
35                                                       innodb_flush_method =>
36                                                          sub {
37                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
38                                                             return "innodb_flush_method is not set to O_DIRECT"
39                                                                if $sys_vars->{innodb_flush_method} ne 'O_DIRECT';
40                                                             return 0;
41                                                          },
42                                                       log_slow_queries =>
43                                                          sub {
44                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
45                                                             return "Slow query logging is disabled (log_slow_queries = OFF)"
46                                                                if $sys_vars->{log_slow_queries} eq 'OFF';
47                                                             return 0;
48                                                          },
49                                                       max_connections =>
50                                                          sub {
51                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
52                                                             return "max_connections has been modified from its default (100): "
53                                                                    . $sys_vars->{max_connections}
54                                                                if $sys_vars->{max_connections} != 100;
55                                                             return 0;
56                                                          },
57                                                       thread_cache_size =>
58                                                          sub {
59                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
60                                                             return "Zero thread cache (thread_cache_size = 0)"
61                                                                if $sys_vars->{thread_cache_size} == 0;
62                                                             return 0;
63                                                          },
64                                                       'socket' =>
65                                                          sub {
66                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
67                                                             if ( ! (-e $sys_vars->{'socket'} && -S $sys_vars->{'socket'}) ) {
68                                                                return "Socket is missing ($sys_vars->{socket})";
69                                                             }
70                                                             return 0;
71                                                          },
72                                                       'query_cache' =>
73                                                          sub {
74                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
75                                                             if ( exists $sys_vars->{query_cache_type} ) {
76                                                                if (    $sys_vars->{query_cache_type} eq 'ON'
77                                                                     && $sys_vars->{query_cache_size} == 0) {
78                                                                   return "Query caching is enabled but query_cache_size is zero";
79                                                                }
80                                                             }
81                                                             return 0;
82                                                          },
83                                                       'Innodb_buffer_pool_pages_free' =>
84                                                          sub {
85                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
86                                                             if ( exists $status_vals->{Innodb_buffer_pool_pages_free} ) {
87                                                                if ( $status_vals->{Innodb_buffer_pool_pages_free} == 0 ) {
88                                                                   return "InnoDB: zero free buffer pool pages";
89                                                                }
90                                                             }
91                                                             return 0;
92                                                          },
93                                                       'skip_name_resolve' =>
94                                                          sub {
95                                                             my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
96                                                             if ( !exists $sys_vars->{skip_name_resolve} ) {
97                                                                return "skip-name-resolve is not set";
98                                                             }
99                                                             return 0;
100                                                         },
101                                                      'key_buffer too large' =>
102                                                         sub {
103                                                            my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
104                                                            return "Key buffer may be too large"
105                                                               if $sys_vars->{key_buffer_size}
106                                                                  > max($counts->{engines}->{MyISAM}->{data_size}, 33554432); # 32M
107                                                            return 0;
108                                                         },
109                                                      'InnoDB buffer pool too small' =>
110                                                         sub {
111                                                            my ( $sys_vars, $status_vals, $schema, $counts ) = @_;
112                                                            if (    exists $sys_vars->{innodb_buffer_pool_size} 
113                                                                 && exists $counts->{engines}->{InnoDB} ) {
114                                                               return "InnoDB: buffer pool too small"
115                                                                  if $counts->{engines}->{InnoDB}->{data_size}
116                                                                     >= $sys_vars->{innodb_buffer_pool_size};
117                                                            }
118                                                         },
119                                                   );
120                                                   
121                                                   sub new {
122            1                    1             6      my ( $class, $MySQLInstance, $SchemaDiscover ) = @_;
123            1                                 11      my $self = {
124                                                         sys_vars    => $MySQLInstance->{online_sys_vars},
125                                                         status_vals => $MySQLInstance->{status_vals},
126                                                         schema      => $SchemaDiscover->{dbs},
127                                                         counts      => $SchemaDiscover->{counts},
128                                                      };
129            1                                 27      return bless $self, $class;
130                                                   }
131                                                   
132                                                   # run_checks() returns a hash of checks that fail:
133                                                   #    key   = name of check
134                                                   #    value = description of failure
135                                                   # $check_name is optional: if given, only that check is ran, otherwise
136                                                   # all checks are ran. If the given check name does not exist, the returned
137                                                   # hash will have only one key = ERROR => value = error msg
138                                                   sub run_checks {
139            1                    1             5      my ( $self, $check_name ) = @_;
140            1                                  5      my %problems;
141   ***      1     50                           6      if ( defined $check_name ) {
142   ***      0      0                           0         if ( exists $checks{$check_name} ) {
143   ***      0      0                           0            if ( my $problem = $checks{$check_name}->($self->{sys_vars},
144                                                                                                      $self->{status_vals},
145                                                                                                      $self->{schema},
146                                                                                                      $self->{counts}) ) {
147   ***      0                                  0               $problems{$check_name} = $problem;
148                                                            }
149                                                         }
150                                                         else {
151   ***      0                                  0            $problems{ERROR} = "No check named $check_name exists.";
152                                                         }
153                                                      }
154                                                      else {
155            1                                 13         foreach my $check_name ( keys %checks ) {
156            7    100                          54            if ( my $problem = $checks{$check_name}->($self->{sys_vars},
157                                                                                                      $self->{status_vals},
158                                                                                                      $self->{schema},
159                                                                                                      $self->{counts}) ) {
160            3                                 13               $problems{$check_name} = $problem;
161                                                            }
162                                                         }
163                                                      }
164   ***      0                                         return \%problems;
165                                                   }
166                                                   
167                                                   sub _d {
168   ***      0                    0                    my ($package, undef, $line) = caller 0;
169   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
170   ***      0                                              map { defined $_ ? $_ : 'undef' }
171                                                           @_;
172   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
173                                                   }
174                                                   
175                                                   1;
176                                                   
177                                                   # ###########################################################################
178                                                   # End MySQLAdvisor package
179                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
141   ***     50      0      1   if (defined $check_name) { }
142   ***      0      0      0   if (exists $checks{$check_name}) { }
143   ***      0      0      0   if (my $problem = $checks{$check_name}($$self{'sys_vars'}, $$self{'status_vals'}, $$self{'schema'}, $$self{'counts'}))
156          100      3      3   if (my $problem = $checks{$check_name}($$self{'sys_vars'}, $$self{'status_vals'}, $$self{'schema'}, $$self{'counts'}))
169   ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
BEGIN          1 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:24 
BEGIN          1 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:25 
BEGIN          1 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:27 
BEGIN          1 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:28 
BEGIN          1 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:30 
new            1 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:122
run_checks     1 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:139

Uncovered Subroutines
---------------------

Subroutine Count Location                                           
---------- ----- ---------------------------------------------------
_d             0 /home/daniel/dev/maatkit/common/MySQLAdvisor.pm:168


