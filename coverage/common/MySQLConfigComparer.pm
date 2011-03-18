---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLConfigComparer.pm   87.3   57.1   32.4   86.7    0.0   49.4   69.7
MySQLConfigComparer.t         100.0   50.0   33.3  100.0    n/a   50.6   95.9
Total                          92.5   56.5   32.5   93.1    0.0  100.0   78.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Mar 18 19:15:07 2011
Finish:       Fri Mar 18 19:15:07 2011

Run:          MySQLConfigComparer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Mar 18 19:15:09 2011
Finish:       Fri Mar 18 19:15:09 2011

/home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010 Percona Inc.
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
18                                                    # MySQLConfigComparer package $Revision: 7354 $
19                                                    # ###########################################################################
20                                                    package MySQLConfigComparer;
21                                                    
22             1                    1             6   use strict;
               1                                  2   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 88   
25             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
26                                                    $Data::Dumper::Indent    = 1;
27                                                    $Data::Dumper::Sortkeys  = 1;
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    
30    ***      1            50      1             5   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 11   
31                                                    
32                                                    # Alternate values because offline/config my-var=ON is shown
33                                                    # online as my_var=TRUE.
34                                                    my %alt_val_for = (
35                                                       ON    => 1,
36                                                       YES   => 1,
37                                                       TRUE  => 1,
38                                                       OFF   => 0,
39                                                       NO    => 0,
40                                                       FALSE => 0,
41                                                       ''    => 0,
42                                                    );
43                                                    
44                                                    # These vars don't interest us so we ignore them.
45                                                    my %ignore_vars = (
46                                                       date_format     => 1,
47                                                       datetime_format => 1,
48                                                       time_format     => 1,
49                                                    );
50                                                    
51                                                    # Special equality tests for certain vars that have varying
52                                                    # values that are actually equal, like ON==1, ''=OFF, etc.
53                                                    my %eq_for = (
54                                                       ft_stopword_file          => sub { return _veq(@_, '(built-in)', 0); },
55                                                    
56                                                       basedir                   => sub { return _patheq(@_);               },
57                                                       language                  => sub { return _patheq(@_);               },
58                                                    
59                                                       log_bin                   => sub { return _eqifon(@_);               },
60                                                       log_slow_queries          => sub { return _eqifon(@_);               },
61                                                    
62                                                       general_log_file          => sub { return _eqifnoconf(@_);           },
63                                                       innodb_data_file_path     => sub { return _eqifnoconf(@_);           },
64                                                       innodb_log_group_home_dir => sub { return _eqifnoconf(@_);           },
65                                                       log_error                 => sub { return _eqifnoconf(@_);           },
66                                                       open_files_limit          => sub { return _eqifnoconf(@_);           },
67                                                       slow_query_log_file       => sub { return _eqifnoconf(@_);           },
68                                                       tmpdir                    => sub { return _eqifnoconf(@_);           },
69                                                       binlog_format             => sub { return _eqifnoconf(@_);           },
70                                                    
71                                                       long_query_time           => sub { return $_[0] == $_[1] ? 1 : 0;    },
72                                                    
73                                                       datadir                   => sub { return _eqdatadir(@_);            },
74                                                    );
75                                                    
76                                                    sub new {
77    ***      1                    1      0      6      my ( $class, %args ) = @_;
78             1                                  3      my $self = {
79                                                       };
80             1                                 10      return bless $self, $class;
81                                                    }
82                                                    
83                                                    # Takes an arrayref of MySQLConfig objects and compares the first to the others.
84                                                    # Returns an arrayref of hashrefs of variables that differ, like:
85                                                    #   {
86                                                    #      var  => max_connections,
87                                                    #      vals => [ 100, 50 ],
88                                                    #   },
89                                                    # The value for each differing var is an arrayref of values corresponding
90                                                    # to the given configs.  So $configs[N] = $differing_var->[N].  Only vars
91                                                    # in the first config are compared, so if $configs[0] has var "foo" but
92                                                    # $configs[1] does not, then the var is skipped.  Similarly, if $configs[1]
93                                                    # has var "bar" but $configs[0] does not, then the var is not compared.
94                                                    # Called missing() to discover which vars are missing in the configs.
95                                                    sub diff {
96    ***      4                    4      0     20      my ( $self, %args ) = @_;
97             4                                 16      my @required_args = qw(configs);
98             4                                 19      foreach my $arg( @required_args ) {
99    ***      4     50                          35         die "I need a $arg argument" unless $args{$arg};
100                                                      }
101            4                                 17      my ($config_objs) = @args{@required_args};
102                                                   
103            4                                 21      my @diffs;
104   ***      4     50                          19      return @diffs if @$config_objs < 2;  # nothing to compare
105            4                                  9      MKDEBUG && _d('diff configs:', Dumper($config_objs));
106                                                   
107            4                                 16      my $vars     = [ map { $_->get_variables() }     @$config_objs ];
               8                                 81   
108            4                                 50      my $versions = [ map { $_->get_mysql_version() } @$config_objs ];
               8                                152   
109                                                   
110                                                      # Get list of vars that exist in all configs (intersection of their keys).
111            4                                 79      my @vars = grep { !$ignore_vars{$_} } $self->key_intersect($vars);
             497                               1773   
112                                                   
113                                                      # Make a list of values from each config for all the common vars.  So,
114                                                      #   %vals = {
115                                                      #     var1 => [ config0-var1-val, config1-var1-val ],
116                                                      #     var2 => [ config0-var2-val, config1-var2-val ],
117                                                      #   }
118          491                               1253      my %vals = map {
119            4                                 93         my $var  = $_;
120          982                               2416         my $vals = [
121                                                            map {
122          491                               1406               my $config = $_;
123   ***    982     50                        4334               my $val    = defined $config->{$var} ? $config->{$var} : '';
124          982    100                        3731               $val       = $alt_val_for{$val} if exists $alt_val_for{$val};
125          982                               3102               $val;
126                                                            } @$vars
127                                                         ];
128          491                               1904         $var => $vals;
129                                                      } @vars;
130                                                   
131                                                      VAR:
132            4                                454      foreach my $var ( sort keys %vals ) {
133          491                               1409         my $vals     = $vals{$var};
134          491                               1439         my $last_val = scalar @$vals - 1;
135                                                   
136          491                               1126         eval {
137                                                            # Compare config0 val to other configs' val.
138                                                            # Stop when a difference is found.
139                                                            VAL:
140          491                               1483            for my $i ( 1..$last_val ) {
141                                                               # First try straight string equality comparison.  If the vals
142                                                               # are equal, stop.  If not, try a special eq_for comparison.
143          491    100                        2623               if ( $vals->[0] ne $vals->[$i] ) {
144           30    100    100                  177                  if (    !$eq_for{$var}
145                                                                       || !$eq_for{$var}->($vals->[0], $vals->[$i], $versions) ) {
146           58                                251                     push @diffs, {
147                                                                        var  => $var,
148           29                                109                        vals => [ map { $_->{$var} } @$vars ],  # original vals
149                                                                     };
150           29                                 90                     last VAL;
151                                                                  }
152                                                               }
153                                                            } # VAL
154                                                         };
155   ***    491     50                        1891         if ( $EVAL_ERROR ) {
156   ***      0      0                           0            my $vals = join(', ', map { defined $_ ? $_ : 'undef' } @$vals);
      ***      0                                  0   
157   ***      0                                  0            warn "Comparing $var values ($vals) caused an error: $EVAL_ERROR";
158                                                         }
159                                                      } # VAR
160                                                   
161            4                                226      return @diffs;
162                                                   }
163                                                   
164                                                   sub missing {
165   ***      3                    3      0     16      my ( $self, %args ) = @_;
166            3                                  9      my @required_args = qw(configs);
167            3                                 18      foreach my $arg( @required_args ) {
168   ***      3     50                          18         die "I need a $arg argument" unless $args{$arg};
169                                                      }
170            3                                 11      my ($config_objs) = @args{@required_args};
171                                                   
172            3                                  8      my @missing;
173   ***      3     50                          15      return @missing if @$config_objs < 2;  # nothing to compare
174            3                                  6      MKDEBUG && _d('missing configs:', Dumper(\@$config_objs));
175                                                   
176            3                                 11      my @configs = map { $_->get_variables() } @$config_objs;
               6                                 57   
177                                                   
178                                                      # Get all unique vars and how many times each exists.
179            3                                 34      my %vars;
180            3                                 21      map { $vars{$_}++ } map { keys %{$configs[$_]} } 0..$#configs;
               6                                 21   
               6                                 15   
               6                                 29   
181                                                   
182                                                      # If a var exists less than the number of configs then it is
183                                                      # missing from at least one of the configs.
184            3                                 11      my $n_configs = scalar @configs;
185            3                                 12      foreach my $var ( keys %vars ) {
186            4    100                          19         if ( $vars{$var} < $n_configs ) {
187            4    100                          27            push @missing, {
188                                                               var     => $var,
189            2                                  8               missing => [ map { exists $_->{$var} ? 0 : 1 } @configs ],
190                                                            };
191                                                         }
192                                                      }
193                                                   
194            3                                 21      return @missing;
195                                                   }
196                                                   
197                                                   # True if x is val1 or val2 and y is val1 or val2.
198                                                   sub _veq { 
199   ***      0                    0             0      my ( $x, $y, $versions, $val1, $val2 ) = @_;
200   ***      0      0      0                    0      return 1 if ( ($x eq $val1 || $x eq $val2) && ($y eq $val1 || $y eq $val2) );
      ***                    0                        
      ***                    0                        
201   ***      0                                  0      return 0;
202                                                   }
203                                                   
204                                                   # True if paths are equal; adds trailing / to x or y if missing.
205                                                   sub _patheq {
206            2                    2            10      my ( $x, $y ) = @_;
207            2    100                          14      $x .= '/' if $x !~ m/\/$/;
208   ***      2     50                          12      $y .= '/' if $y !~ m/\/$/;
209            2                                 16      return $x eq $y;
210                                                   }
211                                                   
212                                                   # True if x=1 (alt val for "ON") and y is true (any value), or vice-versa.
213                                                   # This is for cases like log-bin=file (offline) == log_bin=ON (offline).
214                                                   sub _eqifon { 
215            1                    1             5      my ( $x, $y ) = @_;
216   ***      1     50     33                   15      return 1 if ( ($x && $x eq '1' ) && $y );
      ***                   33                        
217   ***      1     50     33                   10      return 1 if ( ($y && $y eq '1' ) && $x );
      ***                   33                        
218            1                                  7      return 0;
219                                                   }
220                                                   
221                                                   # True if offline value not set/configured (so online vals is
222                                                   # some built-in default).
223                                                   sub _eqifnoconf {
224            1                    1             7      my ( $online_val, $conf_val ) = @_;
225   ***      1     50                          11      return $conf_val == 0 ? 1 : 0;
226                                                   }
227                                                   
228                                                   sub _eqdatadir {
229            1                    1             6      my ( $online_val, $conf_val, $versions ) = @_;
230   ***      1     50     50                   16      if ( ($versions->[0] || '') gt '5.1.0' && (($conf_val || '') eq '.') ) {
      ***                    0                        
      ***                   33                        
231   ***      0                                  0         MKDEBUG && _d('MySQL 5.1 datadir conf val bug;',
232                                                            'online val:', $online_val, 'offline val:', $conf_val);
233   ***      0                                  0         return 1;
234                                                      }
235   ***      1     50     50                   23      return ($online_val || '') eq ($conf_val || '') ? 1 : 0;
      ***                   50                        
236                                                   }
237                                                   
238                                                   # Given an arrayref of hashes, returns an array of keys that
239                                                   # are the intersection of all the hashes' keys.  Example:
240                                                   #   my $foo = { foo=>1, nit=>1   };
241                                                   #   my $bar = { bar=>2, bla=>'', };
242                                                   #   my $zap = { zap=>3, foo=>2,  };
243                                                   #   my @a   = ( $foo, $bar, $zap );
244                                                   # key_intersect(\@a) return ['foo'].
245                                                   sub key_intersect {
246   ***      4                    4      0     15      my ( $self, $hashes ) = @_;
247            4                                 14      my %keys  = map { $_ => 1 } keys %{$hashes->[0]};
             766                               2588   
               4                                104   
248            4                                160      my $n_hashes = (scalar @$hashes) - 1;
249            4                                 23      my @isect = grep { $keys{$_} } map { keys %{$hashes->[$_]} } 1..$n_hashes;
             505                               1577   
               4                                 11   
               4                                 68   
250            4                                222      return @isect;
251                                                   }
252                                                   
253                                                   sub _d {
254   ***      0                    0                    my ($package, undef, $line) = caller 0;
255   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
256   ***      0                                              map { defined $_ ? $_ : 'undef' }
257                                                           @_;
258   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
259                                                   }
260                                                   
261                                                   1;
262                                                   
263                                                   # ###########################################################################
264                                                   # End MySQLConfigComparer package
265                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
99    ***     50      0      4   unless $args{$arg}
104   ***     50      0      4   if @$config_objs < 2
123   ***     50    982      0   defined $$config{$var} ? :
124          100    388    594   if exists $alt_val_for{$val}
143          100     30    461   if ($$vals[0] ne $$vals[$i])
144          100     29      1   if (not $eq_for{$var} or not $eq_for{$var}($$vals[0], $$vals[$i], $versions))
155   ***     50      0    491   if ($EVAL_ERROR)
156   ***      0      0      0   defined $_ ? :
168   ***     50      0      3   unless $args{$arg}
173   ***     50      0      3   if @$config_objs < 2
186          100      2      2   if ($vars{$var} < $n_configs)
187          100      2      2   exists $$_{$var} ? :
200   ***      0      0      0   if $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
207          100      1      1   if not $x =~ m[/$]
208   ***     50      0      2   if not $y =~ m[/$]
216   ***     50      0      1   if $x and $x eq '1' and $y
217   ***     50      0      1   if $y and $y eq '1' and $x
225   ***     50      1      0   $conf_val == 0 ? :
230   ***     50      0      1   if (($$versions[0] || '') gt '5.1.0' and ($conf_val || '') eq '.')
235   ***     50      0      1   ($online_val || '') eq ($conf_val || '') ? :
255   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
200   ***      0      0      0      0   $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
216   ***     33      0      1      0   $x and $x eq '1'
      ***     33      1      0      0   $x and $x eq '1' and $y
217   ***     33      0      1      0   $y and $y eq '1'
      ***     33      1      0      0   $y and $y eq '1' and $x
230   ***     33      1      0      0   ($$versions[0] || '') gt '5.1.0' and ($conf_val || '') eq '.'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0
230   ***     50      0      1   $$versions[0] || ''
      ***      0      0      0   $conf_val || ''
235   ***     50      1      0   $online_val || ''
      ***     50      1      0   $conf_val || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
144          100     25      4      1   not $eq_for{$var} or not $eq_for{$var}($$vals[0], $$vals[$i], $versions)
200   ***      0      0      0      0   $x eq $val1 || $x eq $val2
      ***      0      0      0      0   $y eq $val1 || $y eq $val2


Covered Subroutines
-------------------

Subroutine    Count Pod Location                                                        
------------- ----- --- ----------------------------------------------------------------
BEGIN             1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:22 
BEGIN             1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:23 
BEGIN             1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:24 
BEGIN             1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:25 
BEGIN             1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:30 
_eqdatadir        1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:229
_eqifnoconf       1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:224
_eqifon           1     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:215
_patheq           2     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:206
diff              4   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:96 
key_intersect     4   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:246
missing           3   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:165
new               1   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:77 

Uncovered Subroutines
---------------------

Subroutine    Count Pod Location                                                        
------------- ----- --- ----------------------------------------------------------------
_d                0     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:254
_veq              0     /home/daniel/dev/maatkit/trunk/common/MySQLConfigComparer.pm:199


MySQLConfigComparer.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
12             1                    1            10   use Test::More tests => 7;
               1                                  3   
               1                                 12   
13                                                    
14             1                    1            12   use TextResultSetParser();
               1                                  3   
               1                                  4   
15             1                    1            12   use MySQLConfigComparer;
               1                                  2   
               1                                 11   
16             1                    1            11   use MySQLConfig;
               1                                  2   
               1                                 11   
17             1                    1            11   use DSNParser;
               1                                  3   
               1                                 12   
18             1                    1            13   use Sandbox;
               1                                  2   
               1                                 11   
19             1                    1            11   use MaatkitTest;
               1                                  4   
               1                                 43   
20                                                    
21             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
22             1                                242   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
23             1                                 57   my $dbh = $sb->get_dbh_for('master');
24                                                    
25             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  6   
26             1                                  5   $Data::Dumper::Indent    = 1;
27             1                                  4   $Data::Dumper::Sortkeys  = 1;
28             1                                  3   $Data::Dumper::Quotekeys = 0;
29                                                    
30             1                                 14   my $trp = new TextResultSetParser();
31             1                                 49   my $cc  = new MySQLConfigComparer();
32             1                                  3   my $c1;
33             1                                  3   my $c2;
34                                                    
35             1                                  3   my $diff;
36             1                                 17   my $missing;
37             1                                  3   my $output;
38             1                                  5   my $sample = "common/t/samples/configs/";
39                                                    
40                                                    sub diff {
41             4                    4            19      my ( @configs ) = @_;
42             4                                 29      my @diffs = $cc->diff(
43                                                          configs => \@configs,
44                                                       );
45             4                                 37      return \@diffs;
46                                                    }
47                                                    
48                                                    sub missing {
49             3                    3            14      my ( @configs ) = @_;
50             3                                 22      my @missing= $cc->missing(
51                                                          configs => \@configs,
52                                                       );
53             3                                 14      return \@missing;
54                                                    }
55                                                    
56             1                                 15   $c1 = new MySQLConfig(
57                                                       source              => "$trunk/$sample/mysqldhelp001.txt",
58                                                       TextResultSetParser => $trp,
59                                                    );
60             1                              12560   is_deeply(
61                                                       diff($c1, $c1),
62                                                       [],
63                                                       "mysqld config does not differ with itself"
64                                                    );
65                                                    
66             1                                 18   $c2 = new MySQLConfig(
67                                                       source              => [['query_cache_size', 0]],
68                                                       TextResultSetParser => $trp,
69                                                    );
70             1                                125   is_deeply(
71                                                       diff($c2, $c2),
72                                                       [],
73                                                       "SHOW VARS config does not differ with itself"
74                                                    );
75                                                    
76                                                    
77             1                                 12   $c2 = new MySQLConfig(
78                                                       source              => [['query_cache_size', 1024]],
79                                                       TextResultSetParser => $trp,
80                                                    );
81             1                                106   is_deeply(
82                                                       diff($c1, $c2),
83                                                       [
84                                                          {
85                                                             var   => 'query_cache_size',
86                                                             vals  => [0, 1024],
87                                                          },
88                                                       ],
89                                                       "diff() sees a difference"
90                                                    );
91                                                    
92                                                    # #############################################################################
93                                                    # Compare one config against another.
94                                                    # #############################################################################
95             1                                 17   $c1 = new MySQLConfig(
96                                                       source              => "$trunk/$sample/mysqldhelp001.txt",
97                                                       TextResultSetParser => $trp,
98                                                    );
99             1                              12059   $c2 = new MySQLConfig(
100                                                      source              => "$trunk/$sample/mysqldhelp002.txt",
101                                                      TextResultSetParser => $trp,
102                                                   );
103                                                   
104            1                              11594   $diff = diff($c1, $c2);
105   ***      1     50                          70   is_deeply(
106                                                      $diff,
107                                                      [
108                                                         { var  => 'basedir',
109                                                           vals => [
110                                                             '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23',
111                                                             '/usr/'
112                                                           ],
113                                                         },
114                                                         { var  => 'character_sets_dir',
115                                                           vals => [
116                                                             '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
117                                                             '/usr/share/mysql/charsets/'
118                                                           ],
119                                                         },
120                                                         { var  => 'connect_timeout',
121                                                           vals => ['10','5'],
122                                                         },
123                                                         { var  => 'datadir',
124                                                           vals => ['/tmp/12345/data/', '/mnt/data/mysql/'],
125                                                         },
126                                                         { var  => 'innodb_data_home_dir',
127                                                           vals => ['/tmp/12345/data',''],
128                                                         },
129                                                         { var  => 'innodb_file_per_table',
130                                                           vals => ['FALSE', 'TRUE'],
131                                                         },
132                                                         { var  => 'innodb_flush_log_at_trx_commit',
133                                                           vals => ['1','2'],
134                                                         },
135                                                         { var  => 'innodb_flush_method',
136                                                           vals => ['','O_DIRECT'],
137                                                         },
138                                                         { var  => 'innodb_log_file_size',
139                                                           vals => ['5242880','67108864'],
140                                                         },
141                                                         { var  => 'key_buffer_size',
142                                                           vals => ['16777216','8388600'],
143                                                         },
144                                                         { var  => 'language',
145                                                           vals => [
146                                                             '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
147                                                             '/usr/share/mysql/english/'
148                                                           ],
149                                                         },
150                                                         { var  => 'log_bin',
151                                                           vals => ['mysql-bin', 'sl1-bin'],
152                                                         },
153                                                         { var  => 'log_slave_updates',
154                                                           vals => ['TRUE','FALSE'],
155                                                         },
156                                                         { var  => 'max_binlog_cache_size',
157                                                           vals => ['18446744073709547520','18446744073709551615'],
158                                                         },
159                                                         { var  => 'myisam_max_sort_file_size',
160                                                           vals => ['9223372036853727232', '9223372036854775807'],
161                                                         },
162                                                         { var  => 'old_passwords',
163                                                           vals => ['FALSE','TRUE'],
164                                                         },
165                                                         { var  => 'pid_file',
166                                                           vals => [
167                                                             '/tmp/12345/data/mysql_sandbox12345.pid',
168                                                             '/mnt/data/mysql/sl1.pid'
169                                                           ],
170                                                         },
171                                                         { var  => 'port',
172                                                           vals => ['12345','3306'],
173                                                         },
174                                                         { var  => 'range_alloc_block_size',
175                                                           vals => ['4096','2048'],
176                                                         },
177                                                         { var  => 'relay_log',
178                                                           vals => ['mysql-relay-bin',''],
179                                                         },
180                                                         { var  => 'report_host',
181                                                           vals => ['127.0.0.1', ''],
182                                                         },
183                                                         { var  => 'report_port',
184                                                           vals => ['12345','3306'],
185                                                         },
186                                                         { var  => 'server_id',
187                                                           vals => ['12345','1'],
188                                                         },
189                                                         { var  => 'socket',
190                                                           vals => [
191                                                             '/tmp/12345/mysql_sandbox12345.sock',
192                                                             '/mnt/data/mysql/mysql.sock'
193                                                           ],
194                                                         },
195                                                         { var  => 'ssl',
196                                                           vals => ['FALSE','TRUE'],
197                                                         },
198                                                         { var  => 'ssl_ca',
199                                                           vals => ['','/opt/mysql.pdns/.cert/ca-cert.pem'],
200                                                         },
201                                                         { var  => 'ssl_cert',
202                                                           vals => ['','/opt/mysql.pdns/.cert/server-cert.pem'],
203                                                         },
204                                                         { var  => 'ssl_key',
205                                                           vals => ['','/opt/mysql.pdns/.cert/server-key.pem'],
206                                                         },
207                                                      ],
208                                                      "Diff two different configs"
209                                                   ) or print Dumper($diff);
210                                                   
211                                                   # #############################################################################
212                                                   # Missing vars.
213                                                   # #############################################################################
214            1                                 50   $c1 = new MySQLConfig(
215                                                      source              => [['query_cache_size', 1024]],
216                                                      TextResultSetParser => $trp,
217                                                   );
218            1                                173   $c2 = new MySQLConfig(
219                                                      source              => [],
220                                                      TextResultSetParser => $trp,
221                                                   );
222                                                   
223            1                                236   $missing = missing($c1, $c2);
224            1                                  9   is_deeply(
225                                                      $missing,
226                                                      [
227                                                         { var=>'query_cache_size', missing=>[qw(0 1)] },
228                                                      ],
229                                                      "Missing var, right"
230                                                   );
231                                                   
232            1                                 15   $c2 = new MySQLConfig(
233                                                      source              => [['query_cache_size', 1024]],
234                                                      TextResultSetParser => $trp,
235                                                   );
236            1                                114   $missing = missing($c1, $c2);
237            1                                  8   is_deeply(
238                                                      $missing,
239                                                      [],
240                                                      "No missing vars"
241                                                   );
242                                                   
243            1                                 13   $c2 = new MySQLConfig(
244                                                      source              => [['query_cache_size', 1024], ['foo', 1]],
245                                                      TextResultSetParser => $trp,
246                                                   );
247            1                                107   $missing = missing($c1, $c2);
248            1                                  9   is_deeply(
249                                                      $missing,
250                                                      [
251                                                         { var=>'foo', missing=>[qw(1 0)] },
252                                                      ],
253                                                      "Missing var, left"
254                                                   );
255                                                   
256                                                   # #############################################################################
257                                                   # Done.
258                                                   # #############################################################################
259            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}
105   ***     50      0      1   unless is_deeply($diff, [{'var', 'basedir', 'vals', ['/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23', '/usr/']}, {'var', 'character_sets_dir', 'vals', ['/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/', '/usr/share/mysql/charsets/']}, {'var', 'connect_timeout', 'vals', ['10', '5']}, {'var', 'datadir', 'vals', ['/tmp/12345/data/', '/mnt/data/mysql/']}, {'var', 'innodb_data_home_dir', 'vals', ['/tmp/12345/data', '']}, {'var', 'innodb_file_per_table', 'vals', ['FALSE', 'TRUE']}, {'var', 'innodb_flush_log_at_trx_commit', 'vals', ['1', '2']}, {'var', 'innodb_flush_method', 'vals', ['', 'O_DIRECT']}, {'var', 'innodb_log_file_size', 'vals', ['5242880', '67108864']}, {'var', 'key_buffer_size', 'vals', ['16777216', '8388600']}, {'var', 'language', 'vals', ['/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/', '/usr/share/mysql/english/']}, {'var', 'log_bin', 'vals', ['mysql-bin', 'sl1-bin']}, {'var', 'log_slave_updates', 'vals', ['TRUE', 'FALSE']}, {'var', 'max_binlog_cache_size', 'vals', ['18446744073709547520', '18446744073709551615']}, {'var', 'myisam_max_sort_file_size', 'vals', ['9223372036853727232', '9223372036854775807']}, {'var', 'old_passwords', 'vals', ['FALSE', 'TRUE']}, {'var', 'pid_file', 'vals', ['/tmp/12345/data/mysql_sandbox12345.pid', '/mnt/data/mysql/sl1.pid']}, {'var', 'port', 'vals', ['12345', '3306']}, {'var', 'range_alloc_block_size', 'vals', ['4096', '2048']}, {'var', 'relay_log', 'vals', ['mysql-relay-bin', '']}, {'var', 'report_host', 'vals', ['127.0.0.1', '']}, {'var', 'report_port', 'vals', ['12345', '3306']}, {'var', 'server_id', 'vals', ['12345', '1']}, {'var', 'socket', 'vals', ['/tmp/12345/mysql_sandbox12345.sock', '/mnt/data/mysql/mysql.sock']}, {'var', 'ssl', 'vals', ['FALSE', 'TRUE']}, {'var', 'ssl_ca', 'vals', ['', '/opt/mysql.pdns/.cert/ca-cert.pem']}, {'var', 'ssl_cert', 'vals', ['', '/opt/mysql.pdns/.cert/server-cert.pem']}, {'var', 'ssl_key', 'vals', ['', '/opt/mysql.pdns/.cert/server-key.pem']}], 'Diff two different configs')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}


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
BEGIN          1 MySQLConfigComparer.t:19
BEGIN          1 MySQLConfigComparer.t:25
BEGIN          1 MySQLConfigComparer.t:4 
BEGIN          1 MySQLConfigComparer.t:9 
diff           4 MySQLConfigComparer.t:41
missing        3 MySQLConfigComparer.t:49


