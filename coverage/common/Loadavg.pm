---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/Loadavg.pm   69.1   41.2   25.0   85.7    0.0   93.0   56.8
Loadavg.t                     100.0   50.0   33.3  100.0    n/a    7.0   93.2
Total                          80.4   42.5   26.1   92.0    0.0  100.0   67.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:43 2010
Finish:       Thu Jun 24 19:33:43 2010

Run:          Loadavg.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:45 2010
Finish:       Thu Jun 24 19:33:45 2010

/home/daniel/dev/maatkit/common/Loadavg.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Baron Schwartz.
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
18                                                    # Loadavg package $Revision: 5401 $
19                                                    # ###########################################################################
20                                                    package Loadavg;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  8   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             6   use List::Util qw(sum);
               1                                  2   
               1                                 11   
26             1                    1             9   use Time::HiRes qw(time);
               1                                  3   
               1                                  5   
27             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
28                                                    
29    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
30                                                    
31                                                    sub new {
32    ***      1                    1      0      5      my ( $class ) = @_;
33             1                                 15      return bless {}, $class;
34                                                    }
35                                                    
36                                                    # Calculates average query time by the Trevor Price method.
37                                                    sub trevorprice {
38    ***      0                    0      0      0      my ( $self, $dbh, %args ) = @_;
39    ***      0      0                           0      die "I need a dbh argument" unless $dbh;
40    ***      0             0                    0      my $num_samples = $args{samples} || 100;
41    ***      0                                  0      my $num_running = 0;
42    ***      0                                  0      my $start = time();
43    ***      0                                  0      my (undef, $status1)
44                                                          = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
45    ***      0                                  0      for ( 1 .. $num_samples ) {
46    ***      0                                  0         my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
47    ***      0             0                    0         my $running = grep { ($_->{Command} || '') eq 'Query' } @$pl;
      ***      0                                  0   
48    ***      0                                  0         $num_running += $running - 1;
49                                                       }
50    ***      0                                  0      my $time = time() - $start;
51    ***      0      0                           0      return 0 unless $time;
52    ***      0                                  0      my (undef, $status2)
53                                                          = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
54    ***      0                                  0      my $qps = ($status2 - $status1) / $time;
55    ***      0      0                           0      return 0 unless $qps;
56    ***      0                                  0      return ($num_running / $num_samples) / $qps;
57                                                    }
58                                                    
59                                                    # Calculates number of locked queries in the processlist.
60                                                    sub num_locked {
61    ***      0                    0      0      0      my ( $self, $dbh ) = @_;
62    ***      0      0                           0      die "I need a dbh argument" unless $dbh;
63    ***      0                                  0      my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
64    ***      0             0                    0      my $locked = grep { ($_->{State} || '') eq 'Locked' } @$pl;
      ***      0                                  0   
65    ***      0             0                    0      return $locked || 0;
66                                                    }
67                                                    
68                                                    # Calculates loadavg from the uptime command.
69                                                    sub loadavg {
70    ***      1                    1      0      4      my ( $self ) = @_;
71             1                              15768      my $str = `uptime`;
72             1                                 12      chomp $str;
73    ***      1     50                          15      return 0 unless $str;
74             1                                 33      my ( $one ) = $str =~ m/load average:\s+(\S[^,]*),/;
75    ***      1            50                   61      return $one || 0;
76                                                    }
77                                                    
78                                                    # Calculates slave lag.  If the slave is not running, returns 0.
79                                                    sub slave_lag {
80    ***      1                    1      0      8      my ( $self, $dbh ) = @_;
81    ***      1     50                           5      die "I need a dbh argument" unless $dbh;
82             1                                 51      my $sl = $dbh->selectall_arrayref('SHOW SLAVE STATUS', { Slice => {} });
83    ***      1     50                           9      if ( $sl ) {
84             1                                  5         $sl = $sl->[0];
85             1                                  9         my ( $key ) = grep { m/behind_master/i } keys %$sl;
              38                                116   
86    ***      1     50     50                   32         return $key ? $sl->{$key} || 0 : 0;
87                                                       }
88    ***      0                                  0      return 0;
89                                                    }
90                                                    
91                                                    # Calculates any metric from SHOW STATUS, either absolute or over a 1-second
92                                                    # interval.
93                                                    sub status {
94    ***      1                    1      0     12      my ( $self, $dbh, %args ) = @_;
95    ***      1     50                           6      die "I need a dbh argument" unless $dbh;
96             1                                  3      my (undef, $status1)
97                                                          = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
98    ***      1     50                         503      if ( $args{incstatus} ) {
99    ***      0                                  0         sleep(1);
100   ***      0                                  0         my (undef, $status2)
101                                                            = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
102   ***      0                                  0         return $status2 - $status1;
103                                                      }
104                                                      else {
105            1                                 14         return $status1;
106                                                      }
107                                                   }
108                                                   
109                                                   # Returns the highest value for a given section and var, like transactions
110                                                   # and lock_wait_time.
111                                                   sub innodb {
112   ***      2                    2      0     23      my ( $self, $dbh, %args ) = @_;
113   ***      2     50                          10      die "I need a dbh argument" unless $dbh;
114            2                                 10      foreach my $arg ( qw(InnoDBStatusParser section var) ) {
115   ***      6     50                          28         die "I need a $arg argument" unless $args{$arg};
116                                                      }
117            2                                  7      my $is      = $args{InnoDBStatusParser};
118            2                                  7      my $section = $args{section};
119            2                                  5      my $var     = $args{var};
120                                                   
121                                                      # Get and parse SHOW INNODB STATUS text.
122            2                                  5      my @status_text = $dbh->selectrow_array("SHOW INNODB STATUS");
123   ***      2     50     33                 2358      if ( !$status_text[0] || !$status_text[2] ) {
124   ***      0                                  0         MKDEBUG && _d('SHOW INNODB STATUS failed');
125   ***      0                                  0         return 0;
126                                                      }
127   ***      2     50                          27      my $idb_stats = $is->parse($status_text[2] ? $status_text[2] : $status_text[0]);
128                                                   
129            2    100                        4932      if ( !exists $idb_stats->{$section} ) {
130            1                                  3         MKDEBUG && _d('idb status section', $section, 'does not exist');
131            1                                 39         return 0;
132                                                      }
133                                                   
134                                                      # Each section should be an arrayref.  Go through each set of vars
135                                                      # and find the highest var that we're checking.
136            1                                  3      my $value = 0;
137            1                                  4      foreach my $vars ( @{$idb_stats->{$section}} ) {
               1                                  4   
138            1                                 10         MKDEBUG && _d($var, '=', $vars->{$var});
139   ***      1     50     33                   18         $value = $vars->{$var} && $vars->{$var} > $value ? $vars->{$var} : $value;
140                                                      }
141                                                   
142            1                                  3      MKDEBUG && _d('Highest', $var, '=', $value);
143            1                                 42      return $value;
144                                                   }
145                                                   
146                                                   sub _d {
147            1                    1             7      my ($package, undef, $line) = caller 0;
148   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
149            1                                  5           map { defined $_ ? $_ : 'undef' }
150                                                           @_;
151            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
152                                                   }
153                                                   
154                                                   1;
155                                                   
156                                                   # ###########################################################################
157                                                   # End Loadavg package
158                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***      0      0      0   unless $dbh
51    ***      0      0      0   unless $time
55    ***      0      0      0   unless $qps
62    ***      0      0      0   unless $dbh
73    ***     50      0      1   unless $str
81    ***     50      0      1   unless $dbh
83    ***     50      1      0   if ($sl)
86    ***     50      1      0   $key ? :
95    ***     50      0      1   unless $dbh
98    ***     50      0      1   if ($args{'incstatus'}) { }
113   ***     50      0      2   unless $dbh
115   ***     50      0      6   unless $args{$arg}
123   ***     50      0      2   if (not $status_text[0] or not $status_text[2])
127   ***     50      2      0   $status_text[2] ? :
129          100      1      1   if (not exists $$idb_stats{$section})
139   ***     50      1      0   $$vars{$var} && $$vars{$var} > $value ? :
148   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
139   ***     33      0      0      1   $$vars{$var} && $$vars{$var} > $value

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
29    ***     50      0      1   $ENV{'MKDEBUG'} || 0
40    ***      0      0      0   $args{'samples'} || 100
47    ***      0      0      0   $$_{'Command'} || ''
64    ***      0      0      0   $$_{'State'} || ''
65    ***      0      0      0   $locked || 0
75    ***     50      1      0   $one || 0
86    ***     50      0      1   $$sl{$key} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
123   ***     33      0      0      2   not $status_text[0] or not $status_text[2]


Covered Subroutines
-------------------

Subroutine  Count Pod Location                                      
----------- ----- --- ----------------------------------------------
BEGIN           1     /home/daniel/dev/maatkit/common/Loadavg.pm:22 
BEGIN           1     /home/daniel/dev/maatkit/common/Loadavg.pm:23 
BEGIN           1     /home/daniel/dev/maatkit/common/Loadavg.pm:25 
BEGIN           1     /home/daniel/dev/maatkit/common/Loadavg.pm:26 
BEGIN           1     /home/daniel/dev/maatkit/common/Loadavg.pm:27 
BEGIN           1     /home/daniel/dev/maatkit/common/Loadavg.pm:29 
_d              1     /home/daniel/dev/maatkit/common/Loadavg.pm:147
innodb          2   0 /home/daniel/dev/maatkit/common/Loadavg.pm:112
loadavg         1   0 /home/daniel/dev/maatkit/common/Loadavg.pm:70 
new             1   0 /home/daniel/dev/maatkit/common/Loadavg.pm:32 
slave_lag       1   0 /home/daniel/dev/maatkit/common/Loadavg.pm:80 
status          1   0 /home/daniel/dev/maatkit/common/Loadavg.pm:94 

Uncovered Subroutines
---------------------

Subroutine  Count Pod Location                                      
----------- ----- --- ----------------------------------------------
num_locked      0   0 /home/daniel/dev/maatkit/common/Loadavg.pm:61 
trevorprice     0   0 /home/daniel/dev/maatkit/common/Loadavg.pm:38 


Loadavg.t

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
               1                                  3   
               1                                  5   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            10   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            11   use Test::More tests => 7;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use Loadavg;
               1                                  4   
               1                                 11   
15             1                    1            16   use DSNParser;
               1                                  4   
               1                                 55   
16             1                    1            14   use Sandbox;
               1                                  3   
               1                                 10   
17             1                    1            12   use InnoDBStatusParser;
               1                                 18   
               1                                 17   
18             1                    1            13   use MaatkitTest;
               1                                  5   
               1                                 38   
19                                                    
20             1                                  9   my $is  = new InnoDBStatusParser();
21             1                                 29   my $dp  = new DSNParser(opts=>$dsn_opts);
22             1                                231   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
23    ***      1     50                          53   my $dbh = $sb->get_dbh_for('master')
24                                                       or BAIL_OUT('Cannot connect to sandbox master');
25             1                                380   my $slave_dbh = $sb->get_dbh_for('slave1');
26                                                    
27             1                                285   my $la = new Loadavg();
28                                                    
29             1                                 13   isa_ok($la, 'Loadavg');
30                                                    
31             1                                 10   like(
32                                                       $la->loadavg(),
33                                                       qr/[\d\.]+/,
34                                                       'system loadavg'
35                                                    );
36                                                    
37             1                                 25   like(
38                                                       $la->status($dbh, metric=>'Uptime'),
39                                                       qr/\d+/,
40                                                       'status Uptime'
41                                                    );
42                                                    
43             1                                 17   like(
44                                                       $la->innodb(
45                                                          $dbh,
46                                                          InnoDBStatusParser => $is,
47                                                          section            => 'status',
48                                                          var                => 'Innodb_data_fsyncs',
49                                                       ),
50                                                       qr/\d+/,
51                                                       'InnoDB stats'
52                                                    );
53                                                    
54             1                                 11   is(
55                                                       $la->innodb(
56                                                          $dbh,
57                                                          InnoDBStatusParser => $is,
58                                                          section            => 'this section does not exist',
59                                                          var                => 'foo',
60                                                       ),
61                                                       0,
62                                                       'InnoDB stats for nonexistent section'
63                                                    );
64                                                    
65    ***      1     50                           5   SKIP: {
66             1                                  3      skip 'Cannot connect to sandbox slave1', 1 unless $slave_dbh;
67                                                    
68             1                                  9      like(
69                                                          $la->slave_lag($slave_dbh),
70                                                          qr/\d+/,
71                                                          'slave lag'
72                                                       );
73                                                    };
74                                                    
75                                                    # #############################################################################
76                                                    # Done.
77                                                    # #############################################################################
78             1                                  7   my $output = '';
79                                                    {
80             1                                  4      local *STDERR;
               1                                 11   
81             1                    1             3      open STDERR, '>', \$output;
               1                                313   
               1                                  3   
               1                                  7   
82             1                                 20      $la->_d('Complete test coverage');
83                                                    }
84                                                    like(
85             1                                 17      $output,
86                                                       qr/Complete test coverage/,
87                                                       '_d() works'
88                                                    );
89             1                                 14   $sb->wipe_clean($dbh);
90             1                                  5   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
23    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')
65    ***     50      0      1   unless $slave_dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location    
---------- ----- ------------
BEGIN          1 Loadavg.t:10
BEGIN          1 Loadavg.t:11
BEGIN          1 Loadavg.t:12
BEGIN          1 Loadavg.t:14
BEGIN          1 Loadavg.t:15
BEGIN          1 Loadavg.t:16
BEGIN          1 Loadavg.t:17
BEGIN          1 Loadavg.t:18
BEGIN          1 Loadavg.t:4 
BEGIN          1 Loadavg.t:81
BEGIN          1 Loadavg.t:9 


