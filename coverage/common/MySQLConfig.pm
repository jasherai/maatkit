---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/MySQLConfig.pm   90.0   72.6   68.2   93.3    0.0   94.6   79.8
MySQLConfig.t                 100.0   50.0   33.3  100.0    n/a    5.4   95.0
Total                          93.4   71.2   64.0   96.2    0.0  100.0   83.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Apr  6 16:27:25 2010
Finish:       Tue Apr  6 16:27:25 2010

Run:          MySQLConfig.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Apr  6 16:27:27 2010
Finish:       Tue Apr  6 16:27:27 2010

/home/daniel/dev/maatkit/common/MySQLConfig.pm

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
18                                                    # MySQLConfig package $Revision: 6094 $
19                                                    # ###########################################################################
20                                                    package MySQLConfig;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 14   
27                                                    
28                                                    my %undef_for = (
29                                                       'log'                         => 'OFF',
30                                                       log_bin                       => 'OFF',
31                                                       log_slow_queries              => 'OFF',
32                                                       log_slave_updates             => 'ON',
33                                                       log_queries_not_using_indexes => 'ON',
34                                                       log_update                    => 'OFF',
35                                                       skip_bdb                      => 0,
36                                                       skip_external_locking         => 'ON',
37                                                       skip_name_resolve             => 'ON',
38                                                    );
39                                                    
40                                                    my %eq_for = (
41                                                       ft_stopword_file          => sub { return _veq(@_, '(built-in)', ''); },
42                                                       query_cache_type          => sub { return _veq(@_, 'ON', '1');        },
43                                                       ssl                       => sub { return _veq(@_, '1', 'TRUE');      },
44                                                       sql_mode                  => sub { return _veq(@_, '', 'OFF');        },
45                                                    
46                                                       basedir                   => sub { return _patheq(@_);                },
47                                                       language                  => sub { return _patheq(@_);                },
48                                                    
49                                                       log_bin                   => sub { return _eqifon(@_);                },
50                                                       log_slow_queries          => sub { return _eqifon(@_);                },
51                                                    
52                                                       general_log_file          => sub { return _eqifconfundef(@_);         },
53                                                       innodb_data_file_path     => sub { return _eqifconfundef(@_);         },
54                                                       innodb_log_group_home_dir => sub { return _eqifconfundef(@_);         },
55                                                       log_error                 => sub { return _eqifconfundef(@_);         },
56                                                       open_files_limit          => sub { return _eqifconfundef(@_);         },
57                                                       slow_query_log_file       => sub { return _eqifconfundef(@_);         },
58                                                       tmpdir                    => sub { return _eqifconfundef(@_);         },
59                                                    
60                                                       long_query_time           => sub { return _numericeq(@_);             },
61                                                    );
62                                                    
63                                                    my %can_be_duplicate = (
64                                                       replicate_wild_do_table     => 1,
65                                                       replicate_wild_ignore_table => 1,
66                                                       replicate_rewrite_db        => 1,
67                                                       replicate_ignore_table      => 1,
68                                                       replicate_ignore_db         => 1,
69                                                       replicate_do_table          => 1,
70                                                       replicate_do_db             => 1,
71                                                    );
72                                                    
73                                                    sub new {
74    ***      2                    2      0     11      my ( $class, %args ) = @_;
75                                                    
76             2                                 27      my $self = {
77                                                          # defaults
78                                                          defaults_file => undef, 
79                                                          commands      => {
80                                                             mysqld            => "mysqld",
81                                                             my_print_defaults => "my_print_defaults",
82                                                             show_variables    => "SHOW /*!40103 GLOBAL*/ VARIABLES",
83                                                          },
84                                                    
85                                                          # override defaults
86                                                          %args,
87                                                    
88                                                          # private
89                                                          default_defaults_files => [],
90                                                          duplicate_vars         => {},
91                                                          config                 => {
92                                                             offline => {},  # vars as set by defaults files
93                                                             online  => {},  # vars as currently set on running server
94                                                          },
95                                                       };
96                                                    
97             2                                 20      return bless $self, $class;
98                                                    }
99                                                    
100                                                   # Returns true if the MySQL config has the given system variable.
101                                                   sub has {
102   ***      3                    3      0     12      my ( $self, $var ) = @_;
103            3           100                   53      return exists $self->{config}->{offline}->{$var}
104                                                          || exists $self->{config}->{online}->{$var};
105                                                   }
106                                                   
107                                                   # Returns the value for the given system variable.  Returns its
108                                                   # online/effective value by default.
109                                                   sub get {
110   ***      7                    7      0     38      my ( $self, $var, %args ) = @_;
111   ***      7     50                          28      return unless $var;
112            7    100                          68      return $args{offline} ? $self->{config}->{offline}->{$var}
113                                                         :                    $self->{config}->{online}->{$var};
114                                                   }
115                                                   
116                                                   # Returns the whole online (default) or offline hashref of config vals.
117                                                   sub get_config {
118   ***      3                    3      0     16      my ( $self, %args ) = @_;
119            3    100                         186      return $args{offline} ? $self->{config}->{offline}
120                                                         :                    $self->{config}->{online};
121                                                   }
122                                                   
123                                                   sub get_duplicate_variables {
124   ***      1                    1      0      5      my ( $self ) = @_;
125            1                                  9      return $self->{duplicate_vars};
126                                                   }
127                                                   
128                                                   # Arguments:
129                                                   #   * from    scalar: one of mysqld, my_print_defaults, or show_variables
130                                                   #   when from=mysqld or my_print_defaults:
131                                                   #     * cmd     scalar: get output from cmd, or
132                                                   #     * file    scalar: get output from file, or
133                                                   #     * fh      scalar: get output from fh
134                                                   #   when from=show_variables:
135                                                   #     * dbh     obj: dbh to get SHOW VARIABLES
136                                                   #     * rows    arrayref: vals from SHOW VARIABLES
137                                                   # Sets the offline or online config values from the given source.
138                                                   # Returns nothing.
139                                                   sub set_config {
140   ***      5                    5      0     35      my ( $self, %args ) = @_;
141            5                                 21      foreach my $arg ( qw(from) ) {
142   ***      5     50                          29         die "I need a $arg argument" unless $args{$arg};
143                                                      }
144            5                                 17      my $from = $args{from};
145                                                   
146            5    100    100                   45      if ( $from eq 'mysqld' || $from eq 'my_print_defaults' ) {
      ***            50                               
147   ***      3     50     33                   34         die "Setting the MySQL config from $from requires a "
      ***                   33                        
148                                                               . "cmd, file, or fh argument"
149                                                            unless $args{cmd} || $args{file} || $args{fh};
150                                                   
151            3                                  9         my $output;
152            3                                  9         my $fh = $args{fh};
153   ***      3     50                          12         if ( $args{cmd} ) {
154   ***      0                                  0            my $cmd_sub = "_get_${from}_output";
155   ***      0                                  0            $output = $self->$cmd_sub();
156                                                         }
157   ***      3     50                          13         if ( $args{file} ) {
158            3    100                          89            open $fh, '<', $args{file}
159                                                               or die "Cannot open $args{file}: $OS_ERROR";
160                                                         }
161   ***      2     50                          10         if ( $fh ) {
162            2                                  5            $output = do { local $/ = undef; <$fh> };
               2                                 16   
               2                                169   
163                                                         }
164                                                   
165            2                                  7         my ($config, $dupes, $ddf);
166            2    100                          12         if ( $from eq 'mysqld' ) {
      ***            50                               
167            1                                  5            ($config, $ddf) = $self->parse_mysqld($output);
168                                                         }
169                                                         elsif ( $from eq 'my_print_defaults' ) {
170            1                                  5            ($config, $dupes) = $self->parse_my_print_defaults($output);
171                                                         }
172                                                   
173   ***      2     50                          11         die "Failed to parse MySQL config from $from" unless $config;
174            2                                 68         @{$self->{config}->{offline}}{keys %$config} = values %$config;
               2                                157   
175                                                   
176            2    100                          38         $self->{default_defaults_files} = $ddf   if $ddf;
177            2    100                           8         $self->{duplicate_vars}         = $dupes if $dupes;
178                                                      }
179                                                      elsif ( $args{from} eq 'show_variables' ) {
180   ***      2     50     66                   23         die "Setting the MySQL config from $from requires a "
181                                                               . "dbh or rows argument"
182                                                            unless $args{dbh} || $args{rows};
183                                                   
184            2                                  7         my $rows = $args{rows};
185            2    100                           9         if ( $args{dbh} ) {
186            1                                  5            my $sql = $self->{commands}->{show_variables};
187            1                                  2            MKDEBUG && _d($args{dbh}, $sql);
188            1                                  3            $rows = $args{dbh}->selectall_arrayref($sql);
189                                                         }
190            2                               1335         $self->set_online_config($rows);
191                                                      }
192                                                      else {
193   ***      0                                  0         die "I don't know how to set the MySQL config from $from";
194                                                      }
195            4                                 51      return;
196                                                   }
197                                                   
198                                                   # Set online config given the arrayref of rows.  This arrayref is
199                                                   # usually from SHOW VARIABLES.  This sub is usually called via
200                                                   # set_config().
201                                                   sub set_online_config {
202   ***      2                    2      0     11      my ( $self, $rows ) = @_;
203   ***      2     50                           9      return unless $rows;
204            2                                  9      my %config = map { @$_ } @$rows;
             242                               1029   
205            2                                 61      $self->{config}->{online} = \%config;
206            2                                 57      return;
207                                                   }
208                                                   
209                                                   # Parse "mysqld --help --verbose" and return a hashref of variable=>values
210                                                   # and an arrayref of default defaults files if possible.  The "default
211                                                   # defaults files" are the defaults file that mysqld reads by default if no
212                                                   # defaults file is explicitly given by --default-file.
213                                                   sub parse_mysqld {
214   ***      1                    1      0     97      my ( $self, $output ) = @_;
215   ***      1     50                           6      return unless $output;
216                                                   
217                                                      # First look for the list of default defaults files like
218                                                      #   Default options are read from the following files in the given order:
219                                                      #   /etc/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
220            1                                  2      my @ddf;
221   ***      1     50                          10      if ( $output =~ m/^Default options are read.+\n/mg ) {
222            1                                 51         my ($ddf) = $output =~ m/\G^(.+)\n/m;
223            1                                  3         my %seen;
224            1                                  6         my @ddf = grep { !$seen{$_} } split(' ', $ddf);
               3                                 13   
225            1                                  4         MKDEBUG && _d('Default defaults files:', @ddf);
226                                                      }
227                                                      else {
228   ***      0                                  0         MKDEBUG && _d("mysqld help output doesn't list default defaults files");
229                                                      }
230                                                   
231                                                      # The list of sys vars and their default vals begins like:
232                                                      #   Variables (--variable-name=value)
233                                                      #   and boolean options {FALSE|TRUE}  Value (after reading options)
234                                                      #   --------------------------------- -----------------------------
235                                                      #   help                              TRUE
236                                                      #   abort-slave-event-count           0
237                                                      # So we search for that line of hypens.
238   ***      1     50                         687      if ( $output !~ m/^-+ -+$/mg ) {
239   ***      0                                  0         MKDEBUG && _d("mysqld help output doesn't list vars and vals");
240   ***      0                                  0         return;
241                                                      }
242                                                   
243                                                      # Cut off everything before the list of vars and vals.
244            1                                 11      my $varvals = substr($output, (pos $output) + 1, length $output);
245                                                   
246                                                      # Parse the "var  val" lines.  2nd retval is duplicates but there
247                                                      # shouldn't be any with mysqld.
248            1                                237      my ($config, undef) = $self->_parse_varvals($varvals =~ m/\G^(\S+)(.*)\n/mg);
249                                                   
250            1                                 40      return $config, \@ddf;
251                                                   }
252                                                   
253                                                   # Parse "my_print_defaults" output and return a hashref of variable=>values
254                                                   # and a hashref of any duplicated variables.
255                                                   sub parse_my_print_defaults {
256   ***      1                    1      0      5      my ( $self, $output ) = @_;
257   ***      1     50                           5      return unless $output;
258                                                   
259                                                      # Parse the "--var=val" lines.
260           18                                 85      my ($config, $dupes) = $self->_parse_varvals(
261            1                                 11         map { $_ =~ m/^--([^=]+)(?:=(.*))?$/ } split("\n", $output)
262                                                      );
263                                                   
264            1                                  7      return $config, $dupes;
265                                                   }
266                                                   
267                                                   # Parses a list of variables and their values ("varvals"), returns two
268                                                   # hashrefs: one with normalized variable=>value, the other with duplicate
269                                                   # vars.  The varvals list should start with a var at index 0 and its value
270                                                   # at index 1 then repeat for the next var-val pair.  
271                                                   sub _parse_varvals {
272            2                    2           257      my ( $self, @varvals ) = @_;
273                                                   
274                                                      # Config built from parsing the given varvals.
275            2                                 34      my %config;
276                                                   
277                                                      # Discover duplicate vars.  
278            2                                  6      my $duplicate_var = 0;
279            2                                  5      my %duplicates;
280                                                   
281                                                      # Keep track if item is var or val because each needs special modifications.
282            2                                  6      my $var      = 1;
283            2                                  7      my $last_var = undef;
284                                                   
285            2                                  7      foreach my $item ( @varvals ) {
286          552    100                        1627         if ( $var ) {
287                                                            # Variable names via config files are like "log-bin" but
288                                                            # via SHOW VARIABLES they're like "log_bin".
289          276                                868            $item =~ s/-/_/g;
290                                                   
291                                                            # If this var exists in the offline config already, then
292                                                            # its a duplicate.  Its original value will be saved before
293                                                            # being overwritten with the new value.
294   ***    276    100     66                 1300            if ( exists $config{$item} && !$can_be_duplicate{$item} ) {
295            4                                  9               MKDEBUG && _d("Duplicate var:", $item);
296            4                                 10               $duplicate_var = 1;
297                                                            }
298                                                   
299          276                                676            $var      = 0;  # next item should be the val for this var
300          276                                886            $last_var = $item;
301                                                         }
302                                                         else {
303          276    100                         896            if ( $item ) {
304          275                                834               $item =~ s/^\s+//;
305                                                   
306          275    100                        1627               if ( my ($num, $factor) = $item =~ m/(\d+)([kmgt])/i ) {
                    100                               
307            4                                 19                  my %factor_for = (
308                                                                     k => 1_024,
309                                                                     m => 1_048_576,
310                                                                     g => 1_073_741_824,
311                                                                     t => 1_099_511_627_776,
312                                                                  );
313            4                                 20                  $item = $num * $factor_for{lc $factor};
314                                                               }
315                                                               elsif ( $item =~ m/No default/ ) {
316           37                                112                  $item = undef;
317                                                               }
318                                                            }
319                                                   
320          276    100    100                 1127            $item = $undef_for{$last_var} || '' unless defined $item;
321                                                   
322          276    100                         893            if ( $duplicate_var ) {
323                                                               # Save var's original value before overwritng with this new value.
324            4                                 12               push @{$duplicates{$last_var}}, $config{$last_var};
               4                                 20   
325            4                                 10               $duplicate_var = 0;
326                                                            }
327                                                   
328                                                            # Save this var-val.
329          276                               1008            $config{$last_var} = $item;
330                                                   
331          276                                865            $var = 1;  # next item should be a var
332                                                         }
333                                                      }
334                                                   
335            2                                 55      return \%config, \%duplicates;
336                                                   }
337                                                   
338                                                   sub _d {
339   ***      0                    0                    my ($package, undef, $line) = caller 0;
340   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
341   ***      0                                              map { defined $_ ? $_ : 'undef' }
342                                                           @_;
343   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
344                                                   }
345                                                   
346                                                   1;
347                                                   
348                                                   # ###########################################################################
349                                                   # End MySQLConfig package
350                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
111   ***     50      0      7   unless $var
112          100      4      3   $args{'offline'} ? :
119          100      1      2   $args{'offline'} ? :
142   ***     50      0      5   unless $args{$arg}
146          100      3      2   if ($from eq 'mysqld' or $from eq 'my_print_defaults') { }
      ***     50      2      0   elsif ($args{'from'} eq 'show_variables') { }
147   ***     50      0      3   unless $args{'cmd'} or $args{'file'} or $args{'fh'}
153   ***     50      0      3   if ($args{'cmd'})
157   ***     50      3      0   if ($args{'file'})
158          100      1      2   unless open $fh, '<', $args{'file'}
161   ***     50      2      0   if ($fh)
166          100      1      1   if ($from eq 'mysqld') { }
      ***     50      1      0   elsif ($from eq 'my_print_defaults') { }
173   ***     50      0      2   unless $config
176          100      1      1   if $ddf
177          100      1      1   if $dupes
180   ***     50      0      2   unless $args{'dbh'} or $args{'rows'}
185          100      1      1   if ($args{'dbh'})
203   ***     50      0      2   unless $rows
215   ***     50      0      1   unless $output
221   ***     50      1      0   if ($output =~ /^Default options are read.+\n/gm) { }
238   ***     50      0      1   if (not $output =~ /^-+ -+$/gm)
257   ***     50      0      1   unless $output
286          100    276    276   if ($var) { }
294          100      4    272   if (exists $config{$item} and not $can_be_duplicate{$item})
303          100    275      1   if ($item)
306          100      4    271   if (my($num, $factor) = $item =~ /(\d+)([kmgt])/i) { }
             100     37    234   elsif ($item =~ /No default/) { }
320          100     38    238   unless defined $item
322          100      4    272   if ($duplicate_var)
340   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
294   ***     66    272      0      4   exists $config{$item} and not $can_be_duplicate{$item}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0
320          100      4     34   $undef_for{$last_var} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
103          100      1      1      1   exists $$self{'config'}{'offline'}{$var} || exists $$self{'config'}{'online'}{$var}
146          100      2      1      2   $from eq 'mysqld' or $from eq 'my_print_defaults'
147   ***     33      0      3      0   $args{'cmd'} or $args{'file'}
      ***     33      3      0      0   $args{'cmd'} or $args{'file'} or $args{'fh'}
180   ***     66      1      1      0   $args{'dbh'} or $args{'rows'}


Covered Subroutines
-------------------

Subroutine              Count Pod Location                                          
----------------------- ----- --- --------------------------------------------------
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:22 
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:23 
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:24 
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:26 
_parse_varvals              2     /home/daniel/dev/maatkit/common/MySQLConfig.pm:272
get                         7   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:110
get_config                  3   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:118
get_duplicate_variables     1   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:124
has                         3   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:102
new                         2   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:74 
parse_my_print_defaults     1   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:256
parse_mysqld                1   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:214
set_config                  5   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:140
set_online_config           2   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:202

Uncovered Subroutines
---------------------

Subroutine              Count Pod Location                                          
----------------------- ----- --- --------------------------------------------------
_d                          0     /home/daniel/dev/maatkit/common/MySQLConfig.pm:339


MySQLConfig.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
12             1                    1            11   use Test::More tests => 15;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            11   use MySQLConfig;
               1                                  3   
               1                                 10   
15             1                    1            10   use DSNParser;
               1                                  4   
               1                                 12   
16             1                    1            12   use Sandbox;
               1                                  3   
               1                                 14   
17             1                    1            14   use MaatkitTest;
               1                                  3   
               1                                 16   
18                                                    
19             1                                  9   my $dp  = new DSNParser(opts=>$dsn_opts);
20             1                                228   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
21             1                                 52   my $dbh = $sb->get_dbh_for('master');
22                                                    
23             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  6   
24             1                                201   $Data::Dumper::Indent    = 1;
25             1                                  5   $Data::Dumper::Sortkeys  = 1;
26             1                                  3   $Data::Dumper::Quotekeys = 0;
27                                                    
28             1                                 11   my $config = new MySQLConfig();
29                                                    
30             1                                  3   my $output;
31             1                                  3   my $sample = "common/t/samples/configs/";
32                                                    
33                                                    throws_ok(
34                                                       sub {
35             1                    1            17         $config->set_config(from=>'mysqld', file=>"fooz");
36                                                       },
37             1                                 18      qr/Cannot open /,
38                                                       'set_config() dies if the file cannot be opened'
39                                                    );
40                                                    
41                                                    # #############################################################################
42                                                    # Config from mysqld --help --verbose
43                                                    # #############################################################################
44                                                    
45             1                                 20   $config->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
46             1                                  8   is_deeply(
47                                                       $config->get_config(offline=>1),
48                                                       {
49                                                          abort_slave_event_count => '0',
50                                                          allow_suspicious_udfs => 'FALSE',
51                                                          auto_increment_increment => '1',
52                                                          auto_increment_offset => '1',
53                                                          automatic_sp_privileges => 'TRUE',
54                                                          back_log => '50',
55                                                          basedir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23',
56                                                          bdb => 'FALSE',
57                                                          bind_address => '',
58                                                          binlog_cache_size => '32768',
59                                                          bulk_insert_buffer_size => '8388608',
60                                                          character_set_client_handshake => 'TRUE',
61                                                          character_set_filesystem => 'binary',
62                                                          character_set_server => 'latin1',
63                                                          character_sets_dir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
64                                                          chroot => '',
65                                                          collation_server => 'latin1_swedish_ci',
66                                                          completion_type => '0',
67                                                          concurrent_insert => '1',
68                                                          connect_timeout => '10',
69                                                          console => 'FALSE',
70                                                          datadir => '/tmp/12345/data/',
71                                                          date_format => '',
72                                                          datetime_format => '',
73                                                          default_character_set => 'latin1',
74                                                          default_collation => 'latin1_swedish_ci',
75                                                          default_time_zone => '',
76                                                          default_week_format => '0',
77                                                          delayed_insert_limit => '100',
78                                                          delayed_insert_timeout => '300',
79                                                          delayed_queue_size => '1000',
80                                                          des_key_file => '',
81                                                          disconnect_slave_event_count => '0',
82                                                          div_precision_increment => '4',
83                                                          enable_locking => 'FALSE',
84                                                          enable_pstack => 'FALSE',
85                                                          engine_condition_pushdown => 'FALSE',
86                                                          expire_logs_days => '0',
87                                                          external_locking => 'FALSE',
88                                                          federated => 'TRUE',
89                                                          flush_time => '0',
90                                                          ft_max_word_len => '84',
91                                                          ft_min_word_len => '4',
92                                                          ft_query_expansion_limit => '20',
93                                                          ft_stopword_file => '',
94                                                          gdb => 'FALSE',
95                                                          group_concat_max_len => '1024',
96                                                          help => 'TRUE',
97                                                          init_connect => '',
98                                                          init_file => '',
99                                                          init_slave => '',
100                                                         innodb => 'TRUE',
101                                                         innodb_adaptive_hash_index => 'TRUE',
102                                                         innodb_additional_mem_pool_size => '1048576',
103                                                         innodb_autoextend_increment => '8',
104                                                         innodb_buffer_pool_awe_mem_mb => '0',
105                                                         innodb_buffer_pool_size => '16777216',
106                                                         innodb_checksums => 'TRUE',
107                                                         innodb_commit_concurrency => '0',
108                                                         innodb_concurrency_tickets => '500',
109                                                         innodb_data_home_dir => '/tmp/12345/data',
110                                                         innodb_doublewrite => 'TRUE',
111                                                         innodb_fast_shutdown => '1',
112                                                         innodb_file_io_threads => '4',
113                                                         innodb_file_per_table => 'FALSE',
114                                                         innodb_flush_log_at_trx_commit => '1',
115                                                         innodb_flush_method => '',
116                                                         innodb_force_recovery => '0',
117                                                         innodb_lock_wait_timeout => '50',
118                                                         innodb_locks_unsafe_for_binlog => 'FALSE',
119                                                         innodb_log_arch_dir => '',
120                                                         innodb_log_buffer_size => '1048576',
121                                                         innodb_log_file_size => '5242880',
122                                                         innodb_log_files_in_group => '2',
123                                                         innodb_log_group_home_dir => '/tmp/12345/data',
124                                                         innodb_max_dirty_pages_pct => '90',
125                                                         innodb_max_purge_lag => '0',
126                                                         innodb_mirrored_log_groups => '1',
127                                                         innodb_open_files => '300',
128                                                         innodb_rollback_on_timeout => 'FALSE',
129                                                         innodb_status_file => 'FALSE',
130                                                         innodb_support_xa => 'TRUE',
131                                                         innodb_sync_spin_loops => '20',
132                                                         innodb_table_locks => 'TRUE',
133                                                         innodb_thread_concurrency => '8',
134                                                         innodb_thread_sleep_delay => '10000',
135                                                         innodb_use_legacy_cardinality_algorithm => 'TRUE',
136                                                         interactive_timeout => '28800',
137                                                         isam => 'FALSE',
138                                                         join_buffer_size => '131072',
139                                                         keep_files_on_create => 'FALSE',
140                                                         key_buffer_size => '16777216',
141                                                         key_cache_age_threshold => '300',
142                                                         key_cache_block_size => '1024',
143                                                         key_cache_division_limit => '100',
144                                                         language => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
145                                                         large_pages => 'FALSE',
146                                                         lc_time_names => 'en_US',
147                                                         local_infile => 'TRUE',
148                                                         log => 'OFF',
149                                                         log_bin => 'mysql-bin',
150                                                         log_bin_index => '',
151                                                         log_bin_trust_function_creators => 'FALSE',
152                                                         log_bin_trust_routine_creators => 'FALSE',
153                                                         log_error => '',
154                                                         log_isam => 'myisam.log',
155                                                         log_queries_not_using_indexes => 'FALSE',
156                                                         log_short_format => 'FALSE',
157                                                         log_slave_updates => 'TRUE',
158                                                         log_slow_admin_statements => 'FALSE',
159                                                         log_slow_queries => 'OFF',
160                                                         log_tc => 'tc.log',
161                                                         log_tc_size => '24576',
162                                                         log_update => 'OFF',
163                                                         log_warnings => '1',
164                                                         long_query_time => '10',
165                                                         low_priority_updates => 'FALSE',
166                                                         lower_case_table_names => '0',
167                                                         master_connect_retry => '60',
168                                                         master_host => '',
169                                                         master_info_file => 'master.info',
170                                                         master_password => '',
171                                                         master_port => '3306',
172                                                         master_retry_count => '86400',
173                                                         master_ssl => 'FALSE',
174                                                         master_ssl_ca => '',
175                                                         master_ssl_capath => '',
176                                                         master_ssl_cert => '',
177                                                         master_ssl_cipher => '',
178                                                         master_ssl_key => '',
179                                                         master_user => 'test',
180                                                         max_allowed_packet => '1048576',
181                                                         max_binlog_cache_size => '18446744073709547520',
182                                                         max_binlog_dump_events => '0',
183                                                         max_binlog_size => '1073741824',
184                                                         max_connect_errors => '10',
185                                                         max_connections => '100',
186                                                         max_delayed_threads => '20',
187                                                         max_error_count => '64',
188                                                         max_heap_table_size => '16777216',
189                                                         max_join_size => '18446744073709551615',
190                                                         max_length_for_sort_data => '1024',
191                                                         max_prepared_stmt_count => '16382',
192                                                         max_relay_log_size => '0',
193                                                         max_seeks_for_key => '18446744073709551615',
194                                                         max_sort_length => '1024',
195                                                         max_sp_recursion_depth => '0',
196                                                         max_tmp_tables => '32',
197                                                         max_user_connections => '0',
198                                                         max_write_lock_count => '18446744073709551615',
199                                                         memlock => 'FALSE',
200                                                         merge => 'TRUE',
201                                                         multi_range_count => '256',
202                                                         myisam_block_size => '1024',
203                                                         myisam_data_pointer_size => '6',
204                                                         myisam_max_extra_sort_file_size => '2147483648',
205                                                         myisam_max_sort_file_size => '9223372036853727232',
206                                                         myisam_recover => 'OFF',
207                                                         myisam_repair_threads => '1',
208                                                         myisam_sort_buffer_size => '8388608',
209                                                         myisam_stats_method => 'nulls_unequal',
210                                                         ndb_autoincrement_prefetch_sz => '1',
211                                                         ndb_cache_check_time => '0',
212                                                         ndb_connectstring => '',
213                                                         ndb_force_send => 'TRUE',
214                                                         ndb_mgmd_host => '',
215                                                         ndb_nodeid => '0',
216                                                         ndb_optimized_node_selection => 'TRUE',
217                                                         ndb_shm => 'FALSE',
218                                                         ndb_use_exact_count => 'TRUE',
219                                                         ndb_use_transactions => 'TRUE',
220                                                         ndbcluster => 'FALSE',
221                                                         net_buffer_length => '16384',
222                                                         net_read_timeout => '30',
223                                                         net_retry_count => '10',
224                                                         net_write_timeout => '60',
225                                                         new => 'FALSE',
226                                                         old_passwords => 'FALSE',
227                                                         old_style_user_limits => 'FALSE',
228                                                         open_files_limit => '0',
229                                                         optimizer_prune_level => '1',
230                                                         optimizer_search_depth => '62',
231                                                         pid_file => '/tmp/12345/data/mysql_sandbox12345.pid',
232                                                         plugin_dir => '',
233                                                         port => '12345',
234                                                         port_open_timeout => '0',
235                                                         preload_buffer_size => '32768',
236                                                         profiling_history_size => '15',
237                                                         query_alloc_block_size => '8192',
238                                                         query_cache_limit => '1048576',
239                                                         query_cache_min_res_unit => '4096',
240                                                         query_cache_size => '0',
241                                                         query_cache_type => '1',
242                                                         query_cache_wlock_invalidate => 'FALSE',
243                                                         query_prealloc_size => '8192',
244                                                         range_alloc_block_size => '4096',
245                                                         read_buffer_size => '131072',
246                                                         read_only => 'FALSE',
247                                                         read_rnd_buffer_size => '262144',
248                                                         record_buffer => '131072',
249                                                         relay_log => 'mysql-relay-bin',
250                                                         relay_log_index => '',
251                                                         relay_log_info_file => 'relay-log.info',
252                                                         relay_log_purge => 'TRUE',
253                                                         relay_log_space_limit => '0',
254                                                         replicate_same_server_id => 'FALSE',
255                                                         report_host => '127.0.0.1',
256                                                         report_password => '',
257                                                         report_port => '12345',
258                                                         report_user => '',
259                                                         rpl_recovery_rank => '0',
260                                                         safe_user_create => 'FALSE',
261                                                         secure_auth => 'FALSE',
262                                                         secure_file_priv => '',
263                                                         server_id => '12345',
264                                                         show_slave_auth_info => 'FALSE',
265                                                         skip_grant_tables => 'FALSE',
266                                                         skip_slave_start => 'FALSE',
267                                                         slave_compressed_protocol => 'FALSE',
268                                                         slave_load_tmpdir => '/tmp/',
269                                                         slave_net_timeout => '3600',
270                                                         slave_transaction_retries => '10',
271                                                         slow_launch_time => '2',
272                                                         socket => '/tmp/12345/mysql_sandbox12345.sock',
273                                                         sort_buffer_size => '2097144',
274                                                         sporadic_binlog_dump_fail => 'FALSE',
275                                                         sql_mode => 'OFF',
276                                                         ssl => 'FALSE',
277                                                         ssl_ca => '',
278                                                         ssl_capath => '',
279                                                         ssl_cert => '',
280                                                         ssl_cipher => '',
281                                                         ssl_key => '',
282                                                         symbolic_links => 'TRUE',
283                                                         sync_binlog => '0',
284                                                         sync_frm => 'TRUE',
285                                                         sysdate_is_now => 'FALSE',
286                                                         table_cache => '64',
287                                                         table_lock_wait_timeout => '50',
288                                                         tc_heuristic_recover => '',
289                                                         temp_pool => 'TRUE',
290                                                         thread_cache_size => '0',
291                                                         thread_concurrency => '10',
292                                                         thread_stack => '262144',
293                                                         time_format => '',
294                                                         timed_mutexes => 'FALSE',
295                                                         tmp_table_size => '33554432',
296                                                         tmpdir => '',
297                                                         transaction_alloc_block_size => '8192',
298                                                         transaction_prealloc_size => '4096',
299                                                         updatable_views_with_limit => '1',
300                                                         use_symbolic_links => 'TRUE',
301                                                         verbose => 'TRUE',
302                                                         wait_timeout => '28800',
303                                                         warnings => '1'
304                                                      },
305                                                      'set_config(from=>mysqld, file=>mysqldhelp001.txt)'
306                                                   );
307                                                   
308            1                                 39   is_deeply(
309                                                      $config->get_config(),
310                                                      {},
311                                                      "Didn't set online config"
312                                                   );
313                                                   
314            1                                 11   is(
315                                                      $config->get('wait_timeout'),
316                                                      undef,
317                                                      'get(), default online but not loaded'
318                                                   );
319                                                   
320            1                                  6   is(
321                                                      $config->get('wait_timeout', offline=>1),
322                                                      28800,
323                                                      'get(), offline'
324                                                   );
325                                                   
326            1                                  7   ok(
327                                                      $config->has('wait_timeout'),
328                                                      'has(), has it from offline'
329                                                   );
330                                                   
331            1                                  7   ok(
332                                                     !$config->has('foo'),
333                                                     "has(), doesn't have it"
334                                                   );
335                                                   
336                                                   # #############################################################################
337                                                   # Config from SHOW VARIABLES
338                                                   # #############################################################################
339                                                   
340            1                                 10   $config->set_config(from=>'show_variables', rows=>[ [qw(foo bar)], [qw(a z)] ]);
341            1                                  6   is_deeply(
342                                                      $config->get_config(),
343                                                      {
344                                                         foo => 'bar',
345                                                         a   => 'z',
346                                                      },
347                                                      'set_config(from=>show_variables, rows=>...)'
348                                                   );
349                                                   
350            1                                 10   is(
351                                                      $config->get('foo'),
352                                                      'bar',
353                                                      'get()',
354                                                   );
355                                                   
356            1                                  7   is(
357                                                      $config->get('foo', offline=>1),
358                                                      undef,
359                                                      "Didn't load online var into offline"
360                                                   );
361                                                   
362            1                                  6   ok(
363                                                      $config->has('foo'),
364                                                      'has(), has it from online'
365                                                   );
366                                                   
367                                                   # #############################################################################
368                                                   # Config from my_print_defaults
369                                                   # #############################################################################
370                                                   
371            1                                  9   $config->set_config(from=>'my_print_defaults',
372                                                      file=>"$trunk/$sample/myprintdef001.txt");
373                                                   
374            1                                  6   is(
375                                                      $config->get('port', offline=>1),
376                                                      '12349',
377                                                      "Duplicate var's last value used"
378                                                   );
379                                                   
380            1                                  7   is(
381                                                      $config->get('innodb_buffer_pool_size', offline=>1),
382                                                      '16777216',
383                                                      'Converted size char to int'
384                                                   );
385                                                   
386            1                                  6   is_deeply(
387                                                      $config->get_duplicate_variables(),
388                                                      {
389                                                         'port' => [12345],
390                                                      },
391                                                      'get_duplicate_variables()'
392                                                   );
393                                                   
394                                                   # #############################################################################
395                                                   # Online tests.
396                                                   # #############################################################################
397   ***      1     50                           5   SKIP: {
398            1                                  8      skip 'Cannot connect to sandbox master', 1 unless $dbh;
399                                                   
400            1                                  8      $config = new MySQLConfig();
401                                                   
402            1                                 72      $config->set_config(from=>'show_variables', dbh=>$dbh);
403            1                                  7      is(
404                                                         $config->get('datadir'),
405                                                         '/tmp/12345/data/',
406                                                         'set_config(from=>show_variables, dbh=>...)'
407                                                      );
408                                                   }
409                                                   
410                                                   # #############################################################################
411                                                   # Done.
412                                                   # #############################################################################
413            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
397   ***     50      0      1   unless $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location        
---------- ----- ----------------
BEGIN          1 MySQLConfig.t:10
BEGIN          1 MySQLConfig.t:11
BEGIN          1 MySQLConfig.t:12
BEGIN          1 MySQLConfig.t:14
BEGIN          1 MySQLConfig.t:15
BEGIN          1 MySQLConfig.t:16
BEGIN          1 MySQLConfig.t:17
BEGIN          1 MySQLConfig.t:23
BEGIN          1 MySQLConfig.t:4 
BEGIN          1 MySQLConfig.t:9 
__ANON__       1 MySQLConfig.t:35


