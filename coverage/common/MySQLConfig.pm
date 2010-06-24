---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/MySQLConfig.pm   90.8   70.0   63.2   88.9    0.0   91.5   79.7
MySQLConfig.t                 100.0   50.0   33.3  100.0    n/a    8.5   95.1
Total                          93.8   68.8   59.1   93.1    0.0  100.0   83.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:13 2010
Finish:       Thu Jun 24 19:35:13 2010

Run:          MySQLConfig.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:15 2010
Finish:       Thu Jun 24 19:35:15 2010

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
18                                                    # MySQLConfig package $Revision: 6397 $
19                                                    # ###########################################################################
20                                                    package MySQLConfig;
21                                                    
22                                                    # This package encapsulates a MySQL config (i.e. its system variables)
23                                                    # from different sources: SHOW VARIABLES, mysqld --help --verbose, etc.
24                                                    # (See set_config() for full list of valid input.)  It basically just
25                                                    # parses the config into a common data struct, then MySQLConfig objects
26                                                    # are passed to other modules like MySQLConfigComparer.
27                                                    
28             1                    1             5   use strict;
               1                                  2   
               1                                 11   
29             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
30             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
31             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
32                                                    $Data::Dumper::Indent    = 1;
33                                                    $Data::Dumper::Sortkeys  = 1;
34                                                    $Data::Dumper::Quotekeys = 0;
35                                                    
36    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 18   
37                                                    
38                                                    my %undef_for = (
39                                                       'log'                         => 'OFF',
40                                                       log_bin                       => 'OFF',
41                                                       log_slow_queries              => 'OFF',
42                                                       log_slave_updates             => 'ON',
43                                                       log_queries_not_using_indexes => 'ON',
44                                                       log_update                    => 'OFF',
45                                                       skip_bdb                      => 0,
46                                                       skip_external_locking         => 'ON',
47                                                       skip_name_resolve             => 'ON',
48                                                    );
49                                                    
50                                                    my %can_be_duplicate = (
51                                                       replicate_wild_do_table     => 1,
52                                                       replicate_wild_ignore_table => 1,
53                                                       replicate_rewrite_db        => 1,
54                                                       replicate_ignore_table      => 1,
55                                                       replicate_ignore_db         => 1,
56                                                       replicate_do_table          => 1,
57                                                       replicate_do_db             => 1,
58                                                    );
59                                                    
60                                                    sub new {
61    ***      3                    3      0     16      my ( $class, %args ) = @_;
62                                                    
63             3                                 30      my $self = {
64                                                          # defaults
65                                                          defaults_file  => undef,
66                                                          version        => '',
67                                                    
68                                                          # override defaults
69                                                          %args,
70                                                    
71                                                          # private
72                                                          default_defaults_files => [],
73                                                          duplicate_vars         => {},
74                                                          config                 => {},
75                                                       };
76                                                    
77             3                                 27      return bless $self, $class;
78                                                    }
79                                                    
80                                                    # Returns true if the MySQL config has the given system variable.
81                                                    sub has {
82    ***      3                    3      0     12      my ( $self, $var ) = @_;
83             3                                 22      return exists $self->{config}->{$var};
84                                                    }
85                                                    
86                                                    # Returns the value for the given system variable.  Returns its
87                                                    # online/effective value by default.
88                                                    sub get {
89    ***      6                    6      0     30      my ( $self, $var ) = @_;
90    ***      6     50                          27      return unless $var;
91             6                                 44      return $self->{config}->{$var};
92                                                    }
93                                                    
94                                                    # Returns the whole hashref of config vals.
95                                                    sub get_config {
96    ***      2                    2      0     12      my ( $self, %args ) = @_;
97             2                                194      return $self->{config};
98                                                    }
99                                                    
100                                                   sub get_duplicate_variables {
101   ***      1                    1      0      4      my ( $self ) = @_;
102            1                                  9      return $self->{duplicate_vars};
103                                                   }
104                                                   
105                                                   sub version {
106   ***      0                    0      0      0      my ( $self ) = @_;
107   ***      0                                  0      return $self->{version};
108                                                   }
109                                                   
110                                                   # Arguments:
111                                                   #   * from    scalar: one of mysqld, my_print_defaults, or show_variables
112                                                   #   when from=mysqld or my_print_defaults:
113                                                   #     * file    scalar: get output from file, or
114                                                   #     * fh      scalar: get output from fh
115                                                   #   when from=show_variables:
116                                                   #     * dbh     obj: get SHOW VARIABLES from dbh, or
117                                                   #     * rows    arrayref: get SHOW VARIABLES from rows
118                                                   # Sets the offline or online config values from the given source.
119                                                   # Returns nothing.
120                                                   sub set_config {
121   ***      6                    6      0     42      my ( $self, %args ) = @_;
122            6                                 27      foreach my $arg ( qw(from) ) {
123   ***      6     50                          35         die "I need a $arg argument" unless $args{$arg};
124                                                      }
125            6                                 21      my $from = $args{from};
126            6                                 21      MKDEBUG && _d('Set config', Dumper(\%args));
127                                                   
128            6    100    100                   77      if ( $from eq 'mysqld' || $from eq 'my_print_defaults' ) {
      ***            50                               
129   ***      3     50     33                   34         die "Setting the MySQL config from $from requires a "
      ***                   33                        
130                                                               . "cmd, file, or fh argument"
131                                                            unless $args{cmd} || $args{file} || $args{fh};
132                                                   
133            3                                  9         my $output;
134            3                                  9         my $fh = $args{fh};
135   ***      3     50                          13         if ( $args{file} ) {
136            3    100                          88            open $fh, '<', $args{file}
137                                                               or die "Cannot open $args{file}: $OS_ERROR";
138                                                         }
139   ***      2     50                           9         if ( $fh ) {
140            2                                  6            $output = do { local $/ = undef; <$fh> };
               2                                 10   
               2                              11898   
141                                                         }
142                                                   
143            2                                  9         my ($config, $dupes, $ddf);
144            2    100                          22         if ( $from eq 'mysqld' ) {
      ***            50                               
145            1                                  5            ($config, $ddf) = $self->parse_mysqld($output);
146                                                         }
147                                                         elsif ( $from eq 'my_print_defaults' ) {
148            1                                 11            ($config, $dupes) = $self->parse_my_print_defaults($output);
149                                                         }
150                                                   
151   ***      2     50                          10         die "Failed to parse MySQL config from $from" unless $config;
152            2                                  8         $self->{config}                 = $config;
153            2    100                          12         $self->{default_defaults_files} = $ddf   if $ddf;
154            2    100                           7         $self->{duplicate_vars}         = $dupes if $dupes;
155                                                      }
156                                                      elsif ( $args{from} eq 'show_variables' ) {
157   ***      3     50     66                   26         die "Setting the MySQL config from $from requires a "
158                                                               . "dbh or rows argument"
159                                                            unless $args{dbh} || $args{rows};
160                                                   
161            3                                 10         my $rows = $args{rows};
162            3    100                          13         if ( $args{dbh} ) {
163            1                                  6            $rows = $self->_show_variables($args{dbh});
164   ***      1     50                          15            $self->_set_version($args{dbh}) unless $self->{version};
165                                                         }
166   ***      3     50                          15         if ( $rows ) {
167            3                                 15            my %config = map { @$_ } @$rows;
             542                               2474   
168            3                                185            $self->{config} = \%config;
169                                                         }
170                                                      }
171                                                      else {
172   ***      0                                  0         die "I don't know how to set the MySQL config from $from";
173                                                      }
174            5                                124      return;
175                                                   }
176                                                   
177                                                   # Parse "mysqld --help --verbose" and return a hashref of variable=>values
178                                                   # and an arrayref of default defaults files if possible.  The "default
179                                                   # defaults files" are the defaults file that mysqld reads by default if no
180                                                   # defaults file is explicitly given by --default-file.
181                                                   sub parse_mysqld {
182   ***      1                    1      0     94      my ( $self, $output ) = @_;
183   ***      1     50                           5      return unless $output;
184                                                   
185                                                      # First look for the list of default defaults files like
186                                                      #   Default options are read from the following files in the given order:
187                                                      #   /etc/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
188            1                                  3      my @ddf;
189   ***      1     50                          11      if ( $output =~ m/^Default options are read.+\n/mg ) {
190            1                                 54         my ($ddf) = $output =~ m/\G^(.+)\n/m;
191            1                                  3         my %seen;
192            1                                  7         my @ddf = grep { !$seen{$_} } split(' ', $ddf);
               3                                 13   
193            1                                  4         MKDEBUG && _d('Default defaults files:', @ddf);
194                                                      }
195                                                      else {
196   ***      0                                  0         MKDEBUG && _d("mysqld help output doesn't list default defaults files");
197                                                      }
198                                                   
199                                                      # The list of sys vars and their default vals begins like:
200                                                      #   Variables (--variable-name=value)
201                                                      #   and boolean options {FALSE|TRUE}  Value (after reading options)
202                                                      #   --------------------------------- -----------------------------
203                                                      #   help                              TRUE
204                                                      #   abort-slave-event-count           0
205                                                      # So we search for that line of hypens.
206   ***      1     50                         711      if ( $output !~ m/^-+ -+$/mg ) {
207   ***      0                                  0         MKDEBUG && _d("mysqld help output doesn't list vars and vals");
208   ***      0                                  0         return;
209                                                      }
210                                                   
211                                                      # Cut off everything before the list of vars and vals.
212            1                                 10      my $varvals = substr($output, (pos $output) + 1, length $output);
213                                                   
214                                                      # Parse the "var  val" lines.  2nd retval is duplicates but there
215                                                      # shouldn't be any with mysqld.
216            1                                236      my ($config, undef) = $self->_parse_varvals($varvals =~ m/\G^(\S+)(.*)\n/mg);
217                                                   
218            1                                 35      return $config, \@ddf;
219                                                   }
220                                                   
221                                                   # Parse "my_print_defaults" output and return a hashref of variable=>values
222                                                   # and a hashref of any duplicated variables.
223                                                   sub parse_my_print_defaults {
224   ***      1                    1      0      9      my ( $self, $output ) = @_;
225   ***      1     50                           9      return unless $output;
226                                                   
227                                                      # Parse the "--var=val" lines.
228           18                                122      my ($config, $dupes) = $self->_parse_varvals(
229            1                                 19         map { $_ =~ m/^--([^=]+)(?:=(.*))?$/ } split("\n", $output)
230                                                      );
231                                                   
232            1                                  9      return $config, $dupes;
233                                                   }
234                                                   
235                                                   # Parses a list of variables and their values ("varvals"), returns two
236                                                   # hashrefs: one with normalized variable=>value, the other with duplicate
237                                                   # vars.  The varvals list should start with a var at index 0 and its value
238                                                   # at index 1 then repeat for the next var-val pair.  
239                                                   sub _parse_varvals {
240            2                    2           249      my ( $self, @varvals ) = @_;
241                                                   
242                                                      # Config built from parsing the given varvals.
243            2                                 34      my %config;
244                                                   
245                                                      # Discover duplicate vars.  
246            2                                  6      my $duplicate_var = 0;
247            2                                  5      my %duplicates;
248                                                   
249                                                      # Keep track if item is var or val because each needs special modifications.
250            2                                  6      my $var      = 1;
251            2                                  6      my $last_var = undef;
252            2                                  8      foreach my $item ( @varvals ) {
253          552    100                        1599         if ( $var ) {
254                                                            # Variable names via config files are like "log-bin" but
255                                                            # via SHOW VARIABLES they're like "log_bin".
256          276                                987            $item =~ s/-/_/g;
257                                                   
258                                                            # If this var exists in the offline config already, then
259                                                            # its a duplicate.  Its original value will be saved before
260                                                            # being overwritten with the new value.
261   ***    276    100     66                 1301            if ( exists $config{$item} && !$can_be_duplicate{$item} ) {
262            4                                  9               MKDEBUG && _d("Duplicate var:", $item);
263            4                                 10               $duplicate_var = 1;
264                                                            }
265                                                   
266          276                                688            $var      = 0;  # next item should be the val for this var
267          276                                845            $last_var = $item;
268                                                         }
269                                                         else {
270          276    100                         910            if ( $item ) {
271          275                                858               $item =~ s/^\s+//;
272                                                   
273          275    100                        1595               if ( my ($num, $factor) = $item =~ m/(\d+)([kmgt])$/i ) {
                    100                               
274            3                                 16                  my %factor_for = (
275                                                                     k => 1_024,
276                                                                     m => 1_048_576,
277                                                                     g => 1_073_741_824,
278                                                                     t => 1_099_511_627_776,
279                                                                  );
280            3                                 17                  $item = $num * $factor_for{lc $factor};
281                                                               }
282                                                               elsif ( $item =~ m/No default/ ) {
283           37                                113                  $item = undef;
284                                                               }
285                                                            }
286                                                   
287          276    100    100                 1117            $item = $undef_for{$last_var} || '' unless defined $item;
288                                                   
289          276    100                         953            if ( $duplicate_var ) {
290                                                               # Save var's original value before overwritng with this new value.
291            4                                  8               push @{$duplicates{$last_var}}, $config{$last_var};
               4                                 22   
292            4                                 12               $duplicate_var = 0;
293                                                            }
294                                                   
295                                                            # Save this var-val.
296          276                               1024            $config{$last_var} = $item;
297                                                   
298          276                                848            $var = 1;  # next item should be a var
299                                                         }
300                                                      }
301                                                   
302            2                                 50      return \%config, \%duplicates;
303                                                   }
304                                                   
305                                                   sub _show_variables {
306            1                    1             5      my ( $self, $dbh ) = @_;
307            1                                  3      my $sql = "SHOW /*!40103 GLOBAL*/ VARIABLES";
308            1                                  3      MKDEBUG && _d($dbh, $sql);
309            1                                  2      my $rows = $dbh->selectall_arrayref($sql);
310            1                               1776      return $rows;
311                                                   }
312                                                   
313                                                   sub _set_version {
314            1                    1             4      my ( $self, $dbh ) = @_;
315            1                                  3      my $version = $dbh->selectrow_arrayref('SELECT VERSION()')->[0];
316   ***      1     50                         151      return unless $version;
317            1                                 26      $version =~ s/(\d\.\d{1,2}.\d{1,2})/$1/;
318            1                                  4      MKDEBUG && _d('MySQL version', $version);
319            1                                  4      $self->{version} = $version;
320            1                                  4      return;
321                                                   }
322                                                   
323                                                   sub _d {
324   ***      0                    0                    my ($package, undef, $line) = caller 0;
325   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
326   ***      0                                              map { defined $_ ? $_ : 'undef' }
327                                                           @_;
328   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
329                                                   }
330                                                   
331                                                   1;
332                                                   
333                                                   # ###########################################################################
334                                                   # End MySQLConfig package
335                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
90    ***     50      0      6   unless $var
123   ***     50      0      6   unless $args{$arg}
128          100      3      3   if ($from eq 'mysqld' or $from eq 'my_print_defaults') { }
      ***     50      3      0   elsif ($args{'from'} eq 'show_variables') { }
129   ***     50      0      3   unless $args{'cmd'} or $args{'file'} or $args{'fh'}
135   ***     50      3      0   if ($args{'file'})
136          100      1      2   unless open $fh, '<', $args{'file'}
139   ***     50      2      0   if ($fh)
144          100      1      1   if ($from eq 'mysqld') { }
      ***     50      1      0   elsif ($from eq 'my_print_defaults') { }
151   ***     50      0      2   unless $config
153          100      1      1   if $ddf
154          100      1      1   if $dupes
157   ***     50      0      3   unless $args{'dbh'} or $args{'rows'}
162          100      1      2   if ($args{'dbh'})
164   ***     50      1      0   unless $$self{'version'}
166   ***     50      3      0   if ($rows)
183   ***     50      0      1   unless $output
189   ***     50      1      0   if ($output =~ /^Default options are read.+\n/gm) { }
206   ***     50      0      1   if (not $output =~ /^-+ -+$/gm)
225   ***     50      0      1   unless $output
253          100    276    276   if ($var) { }
261          100      4    272   if (exists $config{$item} and not $can_be_duplicate{$item})
270          100    275      1   if ($item)
273          100      3    272   if (my($num, $factor) = $item =~ /(\d+)([kmgt])$/i) { }
             100     37    235   elsif ($item =~ /No default/) { }
287          100     38    238   unless defined $item
289          100      4    272   if ($duplicate_var)
316   ***     50      0      1   unless $version
325   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
261   ***     66    272      0      4   exists $config{$item} and not $can_be_duplicate{$item}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
36    ***     50      0      1   $ENV{'MKDEBUG'} || 0
287          100      4     34   $undef_for{$last_var} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
128          100      2      1      3   $from eq 'mysqld' or $from eq 'my_print_defaults'
129   ***     33      0      3      0   $args{'cmd'} or $args{'file'}
      ***     33      3      0      0   $args{'cmd'} or $args{'file'} or $args{'fh'}
157   ***     66      1      2      0   $args{'dbh'} or $args{'rows'}


Covered Subroutines
-------------------

Subroutine              Count Pod Location                                          
----------------------- ----- --- --------------------------------------------------
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:28 
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:29 
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:30 
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:31 
BEGIN                       1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:36 
_parse_varvals              2     /home/daniel/dev/maatkit/common/MySQLConfig.pm:240
_set_version                1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:314
_show_variables             1     /home/daniel/dev/maatkit/common/MySQLConfig.pm:306
get                         6   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:89 
get_config                  2   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:96 
get_duplicate_variables     1   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:101
has                         3   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:82 
new                         3   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:61 
parse_my_print_defaults     1   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:224
parse_mysqld                1   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:182
set_config                  6   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:121

Uncovered Subroutines
---------------------

Subroutine              Count Pod Location                                          
----------------------- ----- --- --------------------------------------------------
_d                          0     /home/daniel/dev/maatkit/common/MySQLConfig.pm:324
version                     0   0 /home/daniel/dev/maatkit/common/MySQLConfig.pm:106


MySQLConfig.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            11   use Test::More tests => 13;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            13   use MySQLConfig;
               1                                 91   
               1                                 12   
15             1                    1            11   use DSNParser;
               1                                  3   
               1                                 12   
16             1                    1            14   use Sandbox;
               1                                  3   
               1                                 10   
17             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 39   
18                                                    
19             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
20             1                                239   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
21             1                                 61   my $dbh = $sb->get_dbh_for('master');
22                                                    
23             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                 22   
24             1                                396   $Data::Dumper::Indent    = 1;
25             1                                  4   $Data::Dumper::Sortkeys  = 1;
26             1                                  3   $Data::Dumper::Quotekeys = 0;
27                                                    
28             1                                 13   my $config = new MySQLConfig();
29                                                    
30             1                                  3   my $output;
31             1                                  3   my $sample = "common/t/samples/configs/";
32                                                    
33                                                    throws_ok(
34                                                       sub {
35             1                    1            19         $config->set_config(from=>'mysqld', file=>"fooz");
36                                                       },
37             1                                 24      qr/Cannot open /,
38                                                       'set_config() dies if the file cannot be opened'
39                                                    );
40                                                    
41                                                    # #############################################################################
42                                                    # Config from mysqld --help --verbose
43                                                    # #############################################################################
44                                                    
45             1                                 19   $config->set_config(from=>'mysqld', file=>"$trunk/$sample/mysqldhelp001.txt");
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
308            1                                 41   is(
309                                                      $config->get('wait_timeout', offline=>1),
310                                                      28800,
311                                                      'get() from mysqld'
312                                                   );
313                                                   
314            1                                  7   ok(
315                                                      $config->has('wait_timeout'),
316                                                      'has() from mysqld'
317                                                   );
318                                                   
319            1                                  6   ok(
320                                                     !$config->has('foo'),
321                                                     "has(), doesn't have it"
322                                                   );
323                                                   
324                                                   # #############################################################################
325                                                   # Config from SHOW VARIABLES
326                                                   # #############################################################################
327                                                   
328            1                                 10   $config->set_config(from=>'show_variables', rows=>[ [qw(foo bar)], [qw(a z)] ]);
329            1                                  6   is_deeply(
330                                                      $config->get_config(),
331                                                      {
332                                                         foo => 'bar',
333                                                         a   => 'z',
334                                                      },
335                                                      'set_config(from=>show_variables, rows=>...)'
336                                                   );
337                                                   
338            1                                 10   is(
339                                                      $config->get('foo'),
340                                                      'bar',
341                                                      'get() from show variables'
342                                                   );
343                                                   
344            1                                  6   ok(
345                                                      $config->has('foo'),
346                                                      'has() from show variables'
347                                                   );
348                                                   
349                                                   # #############################################################################
350                                                   # Config from my_print_defaults
351                                                   # #############################################################################
352                                                   
353            1                                 10   $config->set_config(from=>'my_print_defaults',
354                                                      file=>"$trunk/$sample/myprintdef001.txt");
355                                                   
356            1                                  6   is(
357                                                      $config->get('port', offline=>1),
358                                                      '12349',
359                                                      "Duplicate var's last value used"
360                                                   );
361                                                   
362            1                                  7   is(
363                                                      $config->get('innodb_buffer_pool_size', offline=>1),
364                                                      '16777216',
365                                                      'Converted size char to int'
366                                                   );
367                                                   
368            1                                  6   is_deeply(
369                                                      $config->get_duplicate_variables(),
370                                                      {
371                                                         'port' => [12345],
372                                                      },
373                                                      'get_duplicate_variables()'
374                                                   );
375                                                   
376                                                   # #############################################################################
377                                                   # Online tests.
378                                                   # #############################################################################
379   ***      1     50                           5   SKIP: {
380            1                                  7      skip 'Cannot connect to sandbox master', 1 unless $dbh;
381                                                   
382            1                                  9      $config = new MySQLConfig();
383            1                                 12      $config->set_config(from=>'show_variables', dbh=>$dbh);
384            1                                  8      is(
385                                                         $config->get('datadir'),
386                                                         '/tmp/12345/data/',
387                                                         'set_config(from=>show_variables, dbh=>...)'
388                                                      );
389                                                   
390            1                                  9      $config  = new MySQLConfig();
391            1                                  3      my $rows = $dbh->selectall_arrayref('show variables');
392            1                               1665      $config->set_config(from=>'show_variables', rows=>$rows);
393            1                                  8      is(
394                                                         $config->get('datadir'),
395                                                         '/tmp/12345/data/',
396                                                         'set_config(from=>show_variables, rows=>...)'
397                                                      );
398                                                   }
399                                                   
400                                                   # #############################################################################
401                                                   # Done.
402                                                   # #############################################################################
403            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
379   ***     50      0      1   unless $dbh


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


