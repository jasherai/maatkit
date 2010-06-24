---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLConfigComparer.pm   90.9   66.7   54.1   93.3    0.0   92.8   77.9
MySQLConfigComparer.t         100.0   50.0   33.3  100.0    n/a    7.2   93.6
Total                          94.8   63.5   52.5   96.4    0.0  100.0   83.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:09 2010
Finish:       Thu Jun 24 19:35:09 2010

Run:          MySQLConfigComparer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:11 2010
Finish:       Thu Jun 24 19:35:11 2010

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
18                                                    # MySQLConfigComparer package $Revision: 6397 $
19                                                    # ###########################################################################
20                                                    package MySQLConfigComparer;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  9   
23             1                    1             7   use warnings FATAL => 'all';
               1                                  6   
               1                                  7   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  8   
26                                                    $Data::Dumper::Indent    = 1;
27                                                    $Data::Dumper::Sortkeys  = 1;
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    
30    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 16   
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
77    ***      1                    1      0      5      my ( $class, %args ) = @_;
78             1                                  3      my $self = {
79                                                       };
80             1                                 14      return bless $self, $class;
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
96    ***      5                    5      0     36      my ( $self, %args ) = @_;
97             5                                 24      my @required_args = qw(configs);
98             5                                 22      foreach my $arg( @required_args ) {
99    ***      5     50                          35         die "I need a $arg argument" unless $args{$arg};
100                                                      }
101            5                                 22      my ($config_objs) = @args{@required_args};
102                                                   
103            5                                 13      my @diffs;
104   ***      5     50                          25      return @diffs if @$config_objs < 2;  # nothing to compare
105            5                                 12      MKDEBUG && _d('diff configs:', Dumper($config_objs));
106                                                   
107            5                                 19      my $configs  = [ map { $_->get_config() } @$config_objs ];
              10                                104   
108            5                                 68      my $versions = [ map { $_->version() }    @$config_objs ];
              10                                 94   
109                                                   
110                                                      # Get list of vars that exist in all configs (intersection of their keys).
111            5                                 77      my @vars = grep { !$ignore_vars{$_} } $self->key_intersect($configs);
             689                               2554   
112                                                   
113                                                      # Make a list of values from each config for all the common vars.  So,
114                                                      #   %vals = {
115                                                      #     var1 => [ config0-var1-val, config1-var1-val ],
116                                                      #     var2 => [ config0-var2-val, config1-var2-val ],
117                                                      #   }
118          680                               1841      my %vals = map {
119            5                                136         my $var  = $_;
120         1360                               3514         my $vals = [
121                                                            map {
122          680                               2060               my $config = $_;
123   ***   1360     50                        6315               my $val    = defined $config->{$var} ? $config->{$var} : '';
124         1360    100                        5403               $val       = $alt_val_for{$val} if exists $alt_val_for{$val};
125         1360                               4610               $val;
126                                                            } @$configs 
127                                                         ];
128          680                               2846         $var => $vals;
129                                                      } @vars;
130                                                   
131                                                      VAR:
132            5                                694      foreach my $var ( sort keys %vals ) {
133          680                               2197         my $vals     = $vals{$var};
134          680                               2394         my $last_val = scalar @$vals - 1;
135                                                   
136          680                               1747         eval {
137                                                            # Compare config0 val to other configs' val.
138                                                            # Stop when a difference is found.
139                                                            VAL:
140          680                               2354            for my $i ( 1..$last_val ) {
141                                                               # First try straight string equality comparison.  If the vals
142                                                               # are equal, stop.  If not, try a special eq_for comparison.
143          680    100                        4314               if ( $vals->[0] ne $vals->[$i] ) {
144           40    100    100                  306                  if (    !$eq_for{$var}
145                                                                       || !$eq_for{$var}->($vals->[0], $vals->[$i], $versions) ) {
146           58                                328                     push @diffs, {
147                                                                        var  => $var,
148           29                                142                        vals => [ map { $_->{$var} } @$configs ],  # original vals
149                                                                     };
150           29                                116                     last VAL;
151                                                                  }
152                                                               }
153                                                            } # VAL
154                                                         };
155   ***    680     50                        3086         if ( $EVAL_ERROR ) {
156   ***      0      0                           0            my $vals = join(', ', map { defined $_ ? $_ : 'undef' } @$vals);
      ***      0                                  0   
157   ***      0                                  0            warn "Comparing $var values ($vals) caused an error: $EVAL_ERROR";
158                                                         }
159                                                      } # VAR
160                                                   
161            5                                386      return @diffs;
162                                                   }
163                                                   
164                                                   sub missing {
165   ***      3                    3      0     17      my ( $self, %args ) = @_;
166            3                                 12      my @required_args = qw(configs);
167            3                                 20      foreach my $arg( @required_args ) {
168   ***      3     50                          20         die "I need a $arg argument" unless $args{$arg};
169                                                      }
170            3                                 14      my ($config_objs) = @args{@required_args};
171                                                   
172            3                                  9      my @missing;
173   ***      3     50                          16      return @missing if @$config_objs < 2;  # nothing to compare
174            3                                  7      MKDEBUG && _d('missing configs:', Dumper(\@$config_objs));
175                                                   
176            3                                 13      my @configs = map { $_->get_config() } @$config_objs;
               6                                102   
177                                                   
178                                                      # Get all unique vars and how many times each exists.
179            3                                 45      my %vars;
180            3                                 22      map { $vars{$_}++ } map { keys %{$configs[$_]} } 0..$#configs;
               6                                 25   
               6                                 15   
               6                                 35   
181                                                   
182                                                      # If a var exists less than the number of configs then it is
183                                                      # missing from at least one of the configs.
184            3                                 13      my $n_configs = scalar @configs;
185            3                                 13      foreach my $var ( keys %vars ) {
186            4    100                          24         if ( $vars{$var} < $n_configs ) {
187            4    100                          31            push @missing, {
188                                                               var     => $var,
189            2                                  9               missing => [ map { exists $_->{$var} ? 0 : 1 } @configs ],
190                                                            };
191                                                         }
192                                                      }
193                                                   
194            3                                 25      return @missing;
195                                                   }
196                                                   
197                                                   # True if x is val1 or val2 and y is val1 or val2.
198                                                   sub _veq { 
199            1                    1             6      my ( $x, $y, $versions, $val1, $val2 ) = @_;
200   ***      1     50     33                   21      return 1 if ( ($x eq $val1 || $x eq $val2) && ($y eq $val1 || $y eq $val2) );
      ***                   33                        
      ***                   33                        
201   ***      0                                  0      return 0;
202                                                   }
203                                                   
204                                                   # True if paths are equal; adds trailing / to x or y if missing.
205                                                   sub _patheq {
206            3                    3            17      my ( $x, $y ) = @_;
207            3    100                          23      $x .= '/' if $x !~ m/\/$/;
208            3    100                          17      $y .= '/' if $y !~ m/\/$/;
209            3                                 30      return $x eq $y;
210                                                   }
211                                                   
212                                                   # True if x=1 (alt val for "ON") and y is true (any value), or vice-versa.
213                                                   # This is for cases like log-bin=file (offline) == log_bin=ON (offline).
214                                                   sub _eqifon { 
215            2                    2            11      my ( $x, $y ) = @_;
216   ***      2    100     66                   34      return 1 if ( ($x && $x eq '1' ) && $y );
      ***                   66                        
217   ***      1     50     33                   26      return 1 if ( ($y && $y eq '1' ) && $x );
      ***                   33                        
218            1                                 10      return 0;
219                                                   }
220                                                   
221                                                   # True if offline value not set/configured (so online vals is
222                                                   # some built-in default).
223                                                   sub _eqifnoconf {
224            6                    6            28      my ( $online_val, $conf_val ) = @_;
225   ***      6     50                          59      return $conf_val == 0 ? 1 : 0;
226                                                   }
227                                                   
228                                                   sub _eqdatadir {
229            2                    2            11      my ( $online_val, $conf_val, $versions ) = @_;
230            2    100    100                   36      if ( ($versions->[0] || '') gt '5.1.0' && (($conf_val || '') eq '.') ) {
      ***                   50                        
      ***                   66                        
231            1                                  2         MKDEBUG && _d('MySQL 5.1 datadir conf val bug;',
232                                                            'online val:', $online_val, 'offline val:', $conf_val);
233            1                                  9         return 1;
234                                                      }
235   ***      1     50     50                   26      return ($online_val || '') eq ($conf_val || '') ? 1 : 0;
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
246   ***      5                    5      0     19      my ( $self, $hashes ) = @_;
247            5                                 16      my %keys  = map { $_ => 1 } keys %{$hashes->[0]};
            1036                               3652   
               5                                223   
248            5                                239      my $n_hashes = (scalar @$hashes) - 1;
249            5                                 34      my @isect = grep { $keys{$_} } map { keys %{$hashes->[$_]} } 1..$n_hashes;
             764                               2489   
               5                                 14   
               5                                107   
250            5                                326      return @isect;
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
99    ***     50      0      5   unless $args{$arg}
104   ***     50      0      5   if @$config_objs < 2
123   ***     50   1360      0   defined $$config{$var} ? :
124          100    495    865   if exists $alt_val_for{$val}
143          100     40    640   if ($$vals[0] ne $$vals[$i])
144          100     29     11   if (not $eq_for{$var} or not $eq_for{$var}($$vals[0], $$vals[$i], $versions))
155   ***     50      0    680   if ($EVAL_ERROR)
156   ***      0      0      0   defined $_ ? :
168   ***     50      0      3   unless $args{$arg}
173   ***     50      0      3   if @$config_objs < 2
186          100      2      2   if ($vars{$var} < $n_configs)
187          100      2      2   exists $$_{$var} ? :
200   ***     50      1      0   if $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
207          100      1      2   if not $x =~ m[/$]
208          100      1      2   if not $y =~ m[/$]
216          100      1      1   if $x and $x eq '1' and $y
217   ***     50      0      1   if $y and $y eq '1' and $x
225   ***     50      6      0   $conf_val == 0 ? :
230          100      1      1   if (($$versions[0] || '') gt '5.1.0' and ($conf_val || '') eq '.')
235   ***     50      0      1   ($online_val || '') eq ($conf_val || '') ? :
255   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
200   ***     33      0      0      1   $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
216   ***     66      0      1      1   $x and $x eq '1'
      ***     66      1      0      1   $x and $x eq '1' and $y
217   ***     33      0      1      0   $y and $y eq '1'
      ***     33      1      0      0   $y and $y eq '1' and $x
230   ***     66      1      0      1   ($$versions[0] || '') gt '5.1.0' and ($conf_val || '') eq '.'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0
230          100      1      1   $$versions[0] || ''
      ***     50      1      0   $conf_val || ''
235   ***     50      1      0   $online_val || ''
      ***     50      1      0   $conf_val || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
144          100     25      4     11   not $eq_for{$var} or not $eq_for{$var}($$vals[0], $$vals[$i], $versions)
200   ***     33      1      0      0   $x eq $val1 || $x eq $val2
      ***     33      0      1      0   $y eq $val1 || $y eq $val2


Covered Subroutines
-------------------

Subroutine    Count Pod Location                                                  
------------- ----- --- ----------------------------------------------------------
BEGIN             1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:22 
BEGIN             1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:23 
BEGIN             1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:24 
BEGIN             1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:25 
BEGIN             1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:30 
_eqdatadir        2     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:229
_eqifnoconf       6     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:224
_eqifon           2     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:215
_patheq           3     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:206
_veq              1     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:199
diff              5   0 /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:96 
key_intersect     5   0 /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:246
missing           3   0 /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:165
new               1   0 /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:77 

Uncovered Subroutines
---------------------

Subroutine    Count Pod Location                                                  
------------- ----- --- ----------------------------------------------------------
_d                0     /home/daniel/dev/maatkit/common/MySQLConfigComparer.pm:254


MySQLConfigComparer.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            34      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            12   use Test::More tests => 9;
               1                                  3   
               1                                 11   
13                                                    
14             1                    1            16   use MySQLConfigComparer;
               1                                149   
               1                                 17   
15             1                    1            14   use MySQLConfig;
               1                                  3   
               1                                 16   
16             1                    1            13   use DSNParser;
               1                                  4   
               1                                 14   
17             1                    1            21   use Sandbox;
               1                                  3   
               1                                 16   
18             1                    1            18   use MaatkitTest;
               1                                360   
               1                                 39   
19                                                    
20             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
21             1                                231   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
22             1                                 55   my $dbh = $sb->get_dbh_for('master');
23                                                    
24             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  5   
25             1                                384   $Data::Dumper::Indent    = 1;
26             1                                  3   $Data::Dumper::Sortkeys  = 1;
27             1                                  4   $Data::Dumper::Quotekeys = 0;
28                                                    
29             1                                 16   my $cc = new MySQLConfigComparer();
30             1                                 11   my $c1 = new MySQLConfig();
31             1                                 35   my $c2 = new MySQLConfig();
32                                                    
33             1                                 22   my $diff;
34             1                                  3   my $missing;
35             1                                  2   my $output;
36             1                                  4   my $sample = "common/t/samples/configs/";
37                                                    
38                                                    sub diff {
39             5                    5            27      my ( @configs ) = @_;
40             5                                 38      my @diffs = $cc->diff(
41                                                          configs => \@configs,
42                                                       );
43             5                                 46      return \@diffs;
44                                                    }
45                                                    
46                                                    sub missing {
47             3                    3            16      my ( @configs ) = @_;
48             3                                 21      my @missing= $cc->missing(
49                                                          configs => \@configs,
50                                                       );
51             3                                 14      return \@missing;
52                                                    }
53                                                    
54             1                                  9   $c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
55             1                                 31   is_deeply(
56                                                       diff($c1, $c1),
57                                                       [],
58                                                       "mysqld config does not differ with itself"
59                                                    );
60                                                    
61             1                                 15   $c2->set_config(from=>'show_variables', rows=>[['query_cache_size', 0]]);
62             1                                 73   is_deeply(
63                                                       diff($c2, $c2),
64                                                       [],
65                                                       "SHOW VARS config does not differ with itself"
66                                                    );
67                                                    
68                                                    
69             1                                 14   $c2->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);
70             1                                 68   is_deeply(
71                                                       diff($c1, $c2),
72                                                       [
73                                                          {
74                                                             var   => 'query_cache_size',
75                                                             vals  => [0, 1024],
76                                                          },
77                                                       ],
78                                                       "diff() sees a difference"
79                                                    );
80                                                    
81                                                    # #############################################################################
82                                                    # Compare one config against another.
83                                                    # #############################################################################
84             1                                 18   $c1->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
85             1                                 32   $c2->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp002.txt");
86                                                    
87             1                                 25   $diff = diff($c1, $c2);
88    ***      1     50                          98   is_deeply(
89                                                       $diff,
90                                                       [
91                                                          { var  => 'basedir',
92                                                            vals => [
93                                                              '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23',
94                                                              '/usr/'
95                                                            ],
96                                                          },
97                                                          { var  => 'character_sets_dir',
98                                                            vals => [
99                                                              '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
100                                                             '/usr/share/mysql/charsets/'
101                                                           ],
102                                                         },
103                                                         { var  => 'connect_timeout',
104                                                           vals => ['10','5'],
105                                                         },
106                                                         { var  => 'datadir',
107                                                           vals => ['/tmp/12345/data/', '/mnt/data/mysql/'],
108                                                         },
109                                                         { var  => 'innodb_data_home_dir',
110                                                           vals => ['/tmp/12345/data',''],
111                                                         },
112                                                         { var  => 'innodb_file_per_table',
113                                                           vals => ['FALSE', 'TRUE'],
114                                                         },
115                                                         { var  => 'innodb_flush_log_at_trx_commit',
116                                                           vals => ['1','2'],
117                                                         },
118                                                         { var  => 'innodb_flush_method',
119                                                           vals => ['','O_DIRECT'],
120                                                         },
121                                                         { var  => 'innodb_log_file_size',
122                                                           vals => ['5242880','67108864'],
123                                                         },
124                                                         { var  => 'key_buffer_size',
125                                                           vals => ['16777216','8388600'],
126                                                         },
127                                                         { var  => 'language',
128                                                           vals => [
129                                                             '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
130                                                             '/usr/share/mysql/english/'
131                                                           ],
132                                                         },
133                                                         { var  => 'log_bin',
134                                                           vals => ['mysql-bin', 'sl1-bin'],
135                                                         },
136                                                         { var  => 'log_slave_updates',
137                                                           vals => ['TRUE','FALSE'],
138                                                         },
139                                                         { var  => 'max_binlog_cache_size',
140                                                           vals => ['18446744073709547520','18446744073709551615'],
141                                                         },
142                                                         { var  => 'myisam_max_sort_file_size',
143                                                           vals => ['9223372036853727232', '9223372036854775807'],
144                                                         },
145                                                         { var  => 'old_passwords',
146                                                           vals => ['FALSE','TRUE'],
147                                                         },
148                                                         { var  => 'pid_file',
149                                                           vals => [
150                                                             '/tmp/12345/data/mysql_sandbox12345.pid',
151                                                             '/mnt/data/mysql/sl1.pid'
152                                                           ],
153                                                         },
154                                                         { var  => 'port',
155                                                           vals => ['12345','3306'],
156                                                         },
157                                                         { var  => 'range_alloc_block_size',
158                                                           vals => ['4096','2048'],
159                                                         },
160                                                         { var  => 'relay_log',
161                                                           vals => ['mysql-relay-bin',''],
162                                                         },
163                                                         { var  => 'report_host',
164                                                           vals => ['127.0.0.1', ''],
165                                                         },
166                                                         { var  => 'report_port',
167                                                           vals => ['12345','3306'],
168                                                         },
169                                                         { var  => 'server_id',
170                                                           vals => ['12345','1'],
171                                                         },
172                                                         { var  => 'socket',
173                                                           vals => [
174                                                             '/tmp/12345/mysql_sandbox12345.sock',
175                                                             '/mnt/data/mysql/mysql.sock'
176                                                           ],
177                                                         },
178                                                         { var  => 'ssl',
179                                                           vals => ['FALSE','TRUE'],
180                                                         },
181                                                         { var  => 'ssl_ca',
182                                                           vals => ['','/opt/mysql.pdns/.cert/ca-cert.pem'],
183                                                         },
184                                                         { var  => 'ssl_cert',
185                                                           vals => ['','/opt/mysql.pdns/.cert/server-cert.pem'],
186                                                         },
187                                                         { var  => 'ssl_key',
188                                                           vals => ['','/opt/mysql.pdns/.cert/server-key.pem'],
189                                                         },
190                                                      ],
191                                                      "Diff two different configs"
192                                                   ) or print Dumper($diff);
193                                                   
194                                                   # #############################################################################
195                                                   # Missing vars.
196                                                   # #############################################################################
197            1                                 70   $c1 = new MySQLConfig();
198            1                                116   $c2 = new MySQLConfig();
199                                                   
200            1                                120   $c1->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);
201            1                                 87   $missing = missing($c1, $c2);
202            1                                 11   is_deeply(
203                                                      $missing,
204                                                      [
205                                                         { var=>'query_cache_size', missing=>[qw(0 1)] },
206                                                      ],
207                                                      "Missing var, right"
208                                                   );
209                                                   
210            1                                 18   $c2->set_config(from=>'show_variables', rows=>[['query_cache_size', 1024]]);
211            1                                 82   $missing = missing($c1, $c2);
212            1                                 11   is_deeply(
213                                                      $missing,
214                                                      [],
215                                                      "No missing vars"
216                                                   );
217                                                   
218            1                                 13   $c2->set_config(
219                                                      from =>'show_variables',
220                                                      rows => [
221                                                       ['query_cache_size', 1024],
222                                                       ['foo', 1],
223                                                      ]
224                                                   );
225            1                                 59   $missing = missing($c1, $c2);
226            1                                  9   is_deeply(
227                                                      $missing,
228                                                      [
229                                                         { var=>'foo', missing=>[qw(1 0)] },
230                                                      ],
231                                                      "Missing var, left"
232                                                   );
233                                                   
234                                                   # #############################################################################
235                                                   # Online tests.
236                                                   # #############################################################################
237   ***      1     50                           6   SKIP: {
238            1                                  8      skip 'Cannot connect to sandbox master', 2 unless $dbh;
239                                                   
240            1                                  5      $c1 = new MySQLConfig();
241            1                                 29      $c2 = new MySQLConfig();
242                                                   
243   ***      1     50                          31      my $file = "$trunk/$sample/"
244                                                               . ($sandbox_version eq '5.0' ? 'mysqldhelp001.txt'
245                                                                                            : 'mysqldhelp003.txt');
246            1                                  5      $c1->set_config(from=>'show_variables', dbh=>$dbh);
247            1                               1417      $c2->set_config(from=>'mysqld',         file=>$file);
248                                                   
249            1                                 25      like(
250                                                         $c1->version(),
251                                                         qr/\d+.\d+.\d+/,
252                                                         "Got version",
253                                                      );
254                                                   
255                                                      # If the sandbox master isn't borked then all its vars should be fresh.
256            1                                 15      $diff = diff($c1, $c2);
257   ***      1     50                          35      is_deeply(
258                                                         $diff,
259                                                         [],
260                                                         "Sandbox has no different vars"
261                                                      ) or print Dumper($diff);
262                                                   }
263                                                   
264                                                   # #############################################################################
265                                                   # Done.
266                                                   # #############################################################################
267            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
88    ***     50      0      1   unless is_deeply($diff, [{'var', 'basedir', 'vals', ['/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23', '/usr/']}, {'var', 'character_sets_dir', 'vals', ['/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/', '/usr/share/mysql/charsets/']}, {'var', 'connect_timeout', 'vals', ['10', '5']}, {'var', 'datadir', 'vals', ['/tmp/12345/data/', '/mnt/data/mysql/']}, {'var', 'innodb_data_home_dir', 'vals', ['/tmp/12345/data', '']}, {'var', 'innodb_file_per_table', 'vals', ['FALSE', 'TRUE']}, {'var', 'innodb_flush_log_at_trx_commit', 'vals', ['1', '2']}, {'var', 'innodb_flush_method', 'vals', ['', 'O_DIRECT']}, {'var', 'innodb_log_file_size', 'vals', ['5242880', '67108864']}, {'var', 'key_buffer_size', 'vals', ['16777216', '8388600']}, {'var', 'language', 'vals', ['/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/', '/usr/share/mysql/english/']}, {'var', 'log_bin', 'vals', ['mysql-bin', 'sl1-bin']}, {'var', 'log_slave_updates', 'vals', ['TRUE', 'FALSE']}, {'var', 'max_binlog_cache_size', 'vals', ['18446744073709547520', '18446744073709551615']}, {'var', 'myisam_max_sort_file_size', 'vals', ['9223372036853727232', '9223372036854775807']}, {'var', 'old_passwords', 'vals', ['FALSE', 'TRUE']}, {'var', 'pid_file', 'vals', ['/tmp/12345/data/mysql_sandbox12345.pid', '/mnt/data/mysql/sl1.pid']}, {'var', 'port', 'vals', ['12345', '3306']}, {'var', 'range_alloc_block_size', 'vals', ['4096', '2048']}, {'var', 'relay_log', 'vals', ['mysql-relay-bin', '']}, {'var', 'report_host', 'vals', ['127.0.0.1', '']}, {'var', 'report_port', 'vals', ['12345', '3306']}, {'var', 'server_id', 'vals', ['12345', '1']}, {'var', 'socket', 'vals', ['/tmp/12345/mysql_sandbox12345.sock', '/mnt/data/mysql/mysql.sock']}, {'var', 'ssl', 'vals', ['FALSE', 'TRUE']}, {'var', 'ssl_ca', 'vals', ['', '/opt/mysql.pdns/.cert/ca-cert.pem']}, {'var', 'ssl_cert', 'vals', ['', '/opt/mysql.pdns/.cert/server-cert.pem']}, {'var', 'ssl_key', 'vals', ['', '/opt/mysql.pdns/.cert/server-key.pem']}], 'Diff two different configs')
237   ***     50      0      1   unless $dbh
243   ***     50      0      1   $sandbox_version eq '5.0' ? :
257   ***     50      0      1   unless is_deeply($diff, [], 'Sandbox has no different vars')


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
diff           5 MySQLConfigComparer.t:39
missing        3 MySQLConfigComparer.t:47


