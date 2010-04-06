---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLConfigComparer.pm   87.1   69.4   38.5   90.9    0.0   84.2   72.3
MySQLConfigComparer.t         100.0   50.0   33.3  100.0    n/a   15.8   94.5
Total                          93.2   67.5   37.9   95.5    0.0  100.0   80.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Apr  6 16:27:42 2010
Finish:       Tue Apr  6 16:27:42 2010

Run:          MySQLConfigComparer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Apr  6 16:27:43 2010
Finish:       Tue Apr  6 16:27:44 2010

/home/daniel/dev/maatkit/common/MySQLConfigComparer.pm

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
18                                                    # MySQLConfigComparer package $Revision: 6094 $
19                                                    # ###########################################################################
20                                                    package MySQLConfigComparer;
21                                                    
22             1                    1             4   use strict;
               1                                  2   
               1                                  8   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25                                                    
26    ***      1            50      1            10   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
27                                                    
28                                                    # Alternate values because offline/config my-var=ON is shown
29                                                    # online as my_var=TRUE.
30                                                    my %alt_val_for = (
31                                                       ON    => 1,
32                                                       YES   => 1,
33                                                       TRUE  => 1,
34                                                       OFF   => 0,
35                                                       NO    => 0,
36                                                       FALSE => 0,
37                                                       ''    => 0,
38                                                    );
39                                                    
40                                                    # These vars don't interest us so we ignore them.
41                                                    my %ignore_vars = (
42                                                       date_format     => 1,
43                                                       datetime_format => 1,
44                                                       time_format     => 1,
45                                                    );
46                                                    
47                                                    # Special equality tests for certain vars that have varying
48                                                    # values that are actually equal, like ON==1, ''=OFF, etc.
49                                                    my %eq_for = (
50                                                       ft_stopword_file          => sub { return _veq(@_, '(built-in)', 0); },
51                                                    
52                                                       basedir                   => sub { return _patheq(@_);               },
53                                                       language                  => sub { return _patheq(@_);               },
54                                                    
55                                                       log_bin                   => sub { return _eqifon(@_);               },
56                                                       log_slow_queries          => sub { return _eqifon(@_);               },
57                                                    
58                                                       general_log_file          => sub { return _eqifnoconf(@_);           },
59                                                       innodb_data_file_path     => sub { return _eqifnoconf(@_);           },
60                                                       innodb_log_group_home_dir => sub { return _eqifnoconf(@_);           },
61                                                       log_error                 => sub { return _eqifnoconf(@_);           },
62                                                       open_files_limit          => sub { return _eqifnoconf(@_);           },
63                                                       slow_query_log_file       => sub { return _eqifnoconf(@_);           },
64                                                       tmpdir                    => sub { return _eqifnoconf(@_);           },
65                                                    
66                                                       long_query_time           => sub { return $_[0] == $_[1] ? 1 : 0;    },
67                                                    );
68                                                    
69                                                    sub new {
70    ***      1                    1      0      5      my ( $class, %args ) = @_;
71             1                                  4      my $self = {
72                                                       };
73             1                                 14      return bless $self, $class;
74                                                    }
75                                                    
76                                                    # Returns an arrayref of hashrefs for each variable whose online
77                                                    # value is different from it's config/offline value.
78                                                    sub get_stale_variables {
79    ***      4                    4      0     19      my ( $self, $config ) = @_;
80    ***      4     50                          18      return unless $config;
81                                                    
82             4                                 12      my @stale;
83             4                                 20      my $offline = $config->get_config(offline=>1);
84             4                                 90      my $online  = $config->get_config();
85                                                    
86             4    100                          95      if ( !keys %$online ) {
87             1                                  3         MKDEBUG && _d("Cannot check for stale vars without online config");
88             1                                  7         return;
89                                                       }
90                                                    
91             3                                 98      foreach my $var ( keys %$offline  ) {
92           765    100                        2667         next if exists $ignore_vars{$var};
93           756    100                        3045         next unless exists $online->{$var};
94           179                                402         MKDEBUG && _d('var:', $var);
95                                                    
96           179                                707         my $online_val  = $config->get($var);
97           179                               3347         my $offline_val = $config->get($var, offline=>1);
98           179                               3168         my $stale       = 0;
99           179                                374         MKDEBUG && _d('real val online:', $online_val, 'offline:', $offline_val);
100                                                   
101                                                         # Normalize values: ON|YES|TRUE==1, OFF|NO|FALSE==0.
102          179    100                         700         $online_val  = $alt_val_for{$online_val}
103                                                            if exists $alt_val_for{$online_val};
104          179    100                         653         $offline_val = $alt_val_for{$offline_val}
105                                                            if exists $alt_val_for{$offline_val};
106          179                                371         MKDEBUG && _d('alt val online:', $online_val, 'offline:', $offline_val);
107                                                   
108                                                         # Caller should eval us and catch this because although we try
109                                                         # to handle special cases for all sys vars, there's a lot of
110                                                         # sys vars and you may encounter one we've not dealt with before.
111   ***    179     50                         613         die "Offline value for $var is undefined" unless defined $offline_val;
112   ***    179     50                         627         die "Online value for $var is undefined"  unless defined $online_val;
113                                                   
114                                                         # Var is stale if the two values are not equal.  First try straight
115                                                         # string equality comparison.  If the vals are equal, stop.  If not,
116                                                         # try a special eq_for comparison if possible.
117          179    100                         669         if ( $offline_val ne $online_val ) {
118   ***      6    100     66                   48            if ( !$eq_for{$var} || !$eq_for{$var}->($offline_val, $online_val) ) {
119            1                                  3               MKDEBUG && _d('stale:', $var);
120            1                                  3               $stale = 1;
121                                                            }
122                                                         }
123                                                   
124          179    100                         680         if ( $stale ) {
125            1                                  5            push @stale, {
126                                                               var         => $var,
127                                                               online_val  => $config->get($var),
128                                                               offline_val => $config->get($var, offline=>1),
129                                                            }
130                                                         }
131                                                      }
132                                                   
133            3                                 63      return \@stale;
134                                                   }
135                                                   
136                                                   # True if x is val1 or val2 and y is val1 or val2.
137                                                   sub _veq { 
138            1                    1             6      my ( $x, $y, $val1, $val2 ) = @_;
139   ***      1     50     33                   22      return 1 if ( ($x eq $val1 || $x eq $val2) && ($y eq $val1 || $y eq $val2) );
      ***                   33                        
      ***                   33                        
140   ***      0                                  0      return 0;
141                                                   }
142                                                   
143                                                   # True if paths are equal; adds trailing / to x or y if missing.
144                                                   sub _patheq {
145            1                    1             6      my ( $x, $y ) = @_;
146   ***      1     50                          10      $x .= '/' if $x !~ m/\/$/;
147   ***      1     50                           6      $y .= '/' if $y !~ m/\/$/;
148            1                                  9      return $x eq $y;
149                                                   }
150                                                   
151                                                   # True if x=1 (alt val for "ON") and y is true (any value), or vice-versa.
152                                                   # This is for cases like log-bin=file (offline) == log_bin=ON (offline).
153                                                   sub _eqifon { 
154            1                    1             7      my ( $x, $y ) = @_;
155   ***      1     50     33                   15      return 1 if ( ($x && $x eq '1' ) && $y );
      ***                   33                        
156   ***      1     50     33                   35      return 1 if ( ($y && $y eq '1' ) && $x );
      ***                   33                        
157   ***      0                                  0      return 0;
158                                                   }
159                                                   
160                                                   # True if offline value not set/configured (so online vals is
161                                                   # some built-in default).
162                                                   sub _eqifnoconf {
163            2                    2            11      my ( $conf_val, $online_val ) = @_;
164   ***      2     50                          23      return $conf_val == 0 ? 1 : 0;
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
178                                                   # End MySQLConfigComparer package
179                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
80    ***     50      0      4   unless $config
86           100      1      3   if (not keys %$online)
92           100      9    756   if exists $ignore_vars{$var}
93           100    577    179   unless exists $$online{$var}
102          100     51    128   if exists $alt_val_for{$online_val}
104          100     50    129   if exists $alt_val_for{$offline_val}
111   ***     50      0    179   unless defined $offline_val
112   ***     50      0    179   unless defined $online_val
117          100      6    173   if ($offline_val ne $online_val)
118          100      1      5   if (not $eq_for{$var} or not $eq_for{$var}($offline_val, $online_val))
124          100      1    178   if ($stale)
139   ***     50      1      0   if $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
146   ***     50      1      0   if not $x =~ m[/$]
147   ***     50      0      1   if not $y =~ m[/$]
155   ***     50      0      1   if $x and $x eq '1' and $y
156   ***     50      1      0   if $y and $y eq '1' and $x
164   ***     50      2      0   $conf_val == 0 ? :
169   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
139   ***     33      0      0      1   $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
155   ***     33      0      1      0   $x and $x eq '1'
      ***     33      1      0      0   $x and $x eq '1' and $y
156   ***     33      0      0      1   $y and $y eq '1'
      ***     33      0      0      1   $y and $y eq '1' and $x

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
118   ***     66      1      0      5   not $eq_for{$var} or not $eq_for{$var}($offline_val, $online_val)
139   ***     33      0      1      0   $x eq $val1 || $x eq $val2
      ***     33      1      0      0   $y eq $val1 || $y eq $val2


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                                  
------------------- ----- --- ----------------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:22 
BEGIN                   1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:23 
BEGIN                   1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:24 
BEGIN                   1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:26 
_eqifnoconf             2     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:163
_eqifon                 1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:154
_patheq                 1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:145
_veq                    1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:138
get_stale_variables     4   0 /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:79 
new                     1   0 /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:70 

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                                  
------------------- ----- --- ----------------------------------------------------------
_d                      0     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:168


MySQLConfigComparer.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  3   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            10   use Test::More tests => 4;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            15   use MySQLConfigComparer;
               1                                  3   
               1                                 18   
15             1                    1            11   use MySQLConfig;
               1                                  3   
               1                                 11   
16             1                    1            11   use DSNParser;
               1                                  4   
               1                                 12   
17             1                    1            13   use Sandbox;
               1                                  3   
               1                                 10   
18             1                    1            11   use MaatkitTest;
               1                                  3   
               1                                 11   
19                                                    
20             1                                  8   my $dp  = new DSNParser(opts=>$dsn_opts);
21             1                                233   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
22             1                                 53   my $dbh = $sb->get_dbh_for('master');
23                                                    
24             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  4   
25             1                                203   $Data::Dumper::Indent    = 1;
26             1                                  3   $Data::Dumper::Sortkeys  = 1;
27             1                                  4   $Data::Dumper::Quotekeys = 0;
28                                                    
29             1                                 12   my $cc = new MySQLConfigComparer();
30             1                                  9   my $c1 = new MySQLConfig();
31                                                    
32             1                                 42   my $output;
33             1                                  3   my $sample = "common/t/samples/configs/";
34                                                    
35             1                                 10   $c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
36                                                    
37             1                                 28   is(
38                                                       $cc->get_stale_variables($c1),
39                                                       undef,
40                                                       "Can't check for stale vars without online config"
41                                                    );
42                                                    
43             1                                  8   $c1->set_config(from=>'show_variables', rows=>[['query_cache_size', 0]]);
44                                                    
45             1                                 75   is_deeply(
46                                                       $cc->get_stale_variables($c1),
47                                                       [],
48                                                       "No stale vars"
49                                                    );
50                                                    
51             1                                 14   $c1->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);
52                                                    
53             1                                 67   is_deeply(
54                                                       $cc->get_stale_variables($c1),
55                                                       [
56                                                          {
57                                                             var         => 'query_cache_size',
58                                                             offline_val => 0,
59                                                             online_val  => 1024,
60                                                          },
61                                                       ],
62                                                       "A stale vars"
63                                                    );
64                                                    
65                                                    # #############################################################################
66                                                    # Online tests.
67                                                    # #############################################################################
68    ***      1     50                           5   SKIP: {
69             1                                 10      skip 'Cannot connect to sandbox master', 1 unless $dbh;
70                                                    
71             1                                  9      $c1 = new MySQLConfig();
72             1                                 89      $c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
73             1                                 23      $c1->set_config(from=>'show_variables', dbh=>$dbh);
74                                                    
75                                                       # If the sandbox master isn't borked then all its vars should be fresh.
76             1                               2344      is_deeply(
77                                                          $cc->get_stale_variables($c1),
78                                                          [],
79                                                          "Sandbox has no stale vars"
80                                                       );
81                                                    }
82                                                    
83                                                    # #############################################################################
84                                                    # Done.
85                                                    # #############################################################################
86             1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
68    ***     50      0      1   unless $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location                
---------- ----- ------------------------
BEGIN          1 MySQLConfigComparer.t:10
BEGIN          1 MySQLConfigComparer.t:11
BEGIN          1 MySQLConfigComparer.t:12
BEGIN          1 MySQLConfigComparer.t:14
BEGIN          1 MySQLConfigComparer.t:15
BEGIN          1 MySQLConfigComparer.t:16
BEGIN          1 MySQLConfigComparer.t:17
BEGIN          1 MySQLConfigComparer.t:18
BEGIN          1 MySQLConfigComparer.t:24
BEGIN          1 MySQLConfigComparer.t:4 
BEGIN          1 MySQLConfigComparer.t:9 


