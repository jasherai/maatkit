---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...unk/common/MySQLConfig.pm   94.7   69.0   58.1   95.8    0.0   96.5   81.7
MySQLConfig.t                 100.0   50.0   33.3  100.0    n/a    3.5   95.0
Total                          96.1   67.8   55.9   97.3    0.0  100.0   84.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Mar 18 19:19:43 2011
Finish:       Fri Mar 18 19:19:43 2011

Run:          MySQLConfig.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Mar 18 19:19:45 2011
Finish:       Fri Mar 18 19:19:45 2011

/home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010-2011 Percona Inc.
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
18                                                    # MySQLConfig package $Revision: 7352 $
19                                                    # ###########################################################################
20                                                    package MySQLConfig;
21                                                    
22                                                    # This package encapsulates a MySQL config (i.e. its system variables)
23                                                    # from different sources: SHOW VARIABLES, mysqld --help --verbose, etc.
24                                                    # (See set_config() for full list of valid input.)  It basically just
25                                                    # parses the config into a common data struct, then MySQLConfig objects
26                                                    # are passed to other modules like MySQLConfigComparer.
27                                                    
28             1                    1             4   use strict;
               1                                  3   
               1                                  7   
29             1                    1            10   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
30             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
31             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
32                                                    $Data::Dumper::Indent    = 1;
33                                                    $Data::Dumper::Sortkeys  = 1;
34                                                    $Data::Dumper::Quotekeys = 0;
35                                                    
36    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
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
61    ***      6                    6      0     42      my ( $class, %args ) = @_;
62             6                                 29      my @required_args = qw(source TextResultSetParser);
63             6                                 22      foreach my $arg ( @required_args ) {
64    ***     12     50                          62         die "I need a $arg arugment" unless $args{$arg};
65                                                       }
66                                                    
67             6                                 36      my %config_data = parse_config(%args);
68                                                    
69             5                                 35      my $self = {
70                                                          %args,
71                                                          %config_data,
72                                                       };
73                                                    
74             5                                 56      return bless $self, $class;
75                                                    }
76                                                    
77                                                    sub parse_config {
78    ***      6                    6      0     28      my ( %args ) = @_;
79             6                                 27      my @required_args = qw(source TextResultSetParser);
80             6                                 21      foreach my $arg ( @required_args ) {
81    ***     12     50                          55         die "I need a $arg arugment" unless $args{$arg};
82                                                       }
83             6                                 26      my ($source) = @args{@required_args};
84                                                    
85             6                                 16      my %config_data;
86             6    100    100                  159      if ( -f $source ) {
      ***           100     66                        
                    100                               
87             3                                 21         %config_data = parse_config_from_file(%args);
88                                                       }
89                                                       elsif ( ref $source && ref $source eq 'ARRAY' ) {
90             1                                  5         $config_data{type} = 'show_variables';
91             1                                  4         $config_data{vars} = { map { @$_ } @$source };
               2                                 11   
92                                                       }
93                                                       elsif ( ref $source && (ref $source) =~ m/DBI/i ) {
94             1                                  5         $config_data{type} = 'show_variables';
95             1                                  3         my $sql = "SHOW /*!40103 GLOBAL*/ VARIABLES";
96             1                                  2         MKDEBUG && _d($source, $sql);
97             1                                  2         my $rows = $source->selectall_arrayref($sql);
98             1                               1798         $config_data{vars} = { map { @$_ } @$rows };
             270                               1014   
99             1                                 31         $config_data{mysql_version} = _get_version($source);
100                                                      }
101                                                      else {
102            1                                  3         die "Unknown or invalid source: $source";
103                                                      }
104                                                   
105            5                                 52      return %config_data;
106                                                   }
107                                                   
108                                                   sub parse_config_from_file {
109   ***      3                    3      0     16      my ( %args ) = @_;
110            3                                 15      my @required_args = qw(source TextResultSetParser);
111            3                                 10      foreach my $arg ( @required_args ) {
112   ***      6     50                          29         die "I need a $arg arugment" unless $args{$arg};
113                                                      }
114            3                                 14      my ($source) = @args{@required_args};
115                                                   
116   ***      3            33                   27      my $type = $args{type} || detect_source_type(%args);
117   ***      3     50                          39      if ( !$type ) {
118   ***      0                                  0         die "Cannot auto-detect the type of MySQL config data in $source"
119                                                      }
120                                                   
121            3                                  7      my $vars;      # variables hashref
122            3                                  6      my $dupes;     # duplicate vars hashref
123            3                                  9      my $opt_files; # option files arrayref
124   ***      3     50                          21      if ( $type eq 'show_variables' ) {
                    100                               
                    100                               
      ***            50                               
125   ***      0                                  0         $vars = parse_show_variables(%args);
126                                                      }
127                                                      elsif ( $type eq 'mysqld' ) {
128            1                                 19         ($vars, $opt_files) = parse_mysqld(%args);
129                                                      }
130                                                      elsif ( $type eq 'my_print_defaults' ) {
131            1                                 22         ($vars, $dupes) = parse_my_print_defaults(%args);
132                                                      }
133                                                      elsif ( $type eq 'option_file' ) {
134            1                                  8         ($vars, $dupes) = parse_option_file(%args);
135                                                      }
136                                                      else {
137   ***      0                                  0         die "Invalid type of MySQL config data in $source: $type"
138                                                      }
139                                                   
140   ***      3     50     33                   55      die "Failed to parse MySQL config data from $source"
141                                                         unless $vars && keys %$vars;
142                                                   
143                                                      return (
144            3                                 34         type           => $type,
145                                                         vars           => $vars,
146                                                         option_files   => $opt_files,
147                                                         duplicate_vars => $dupes,
148                                                      );
149                                                   }
150                                                   
151                                                   sub detect_source_type {
152   ***      3                    3      0     16      my ( %args ) = @_;
153            3                                 15      my @required_args = qw(source);
154            3                                 12      foreach my $arg ( @required_args ) {
155   ***      3     50                          17         die "I need a $arg arugment" unless $args{$arg};
156                                                      }
157            3                                 13      my ($source) = @args{@required_args};
158                                                   
159            3                                  8      MKDEBUG && _d("Detecting type of output in", $source);
160   ***      3     50                          91      open my $fh, '<', $source or die "Cannot open $source: $OS_ERROR";
161            3                                  8      my $type;
162            3                                 68      while ( defined(my $line = <$fh>) ) {
163           26                                 56         MKDEBUG && _d($line);
164   ***     26     50     33                  594         if (    $line =~ m/\|\s+\w+\s+\|\s+.+?\|/
      ***           100     33                        
      ***           100     66                        
      ***           100     66                        
165                                                              || $line =~ m/\*+ \d/
166                                                              || $line =~ m/Variable_name:\s+\w+/ )
167                                                         {
168   ***      0                                  0            MKDEBUG && _d('show variables config line');
169   ***      0                                  0            $type = 'show_variables';
170   ***      0                                  0            last;
171                                                         }
172                                                         elsif ( $line =~ m/^--\w+/ ) {
173            1                                  4            MKDEBUG && _d('my_print_defaults config line');
174            1                                  3            $type = 'my_print_defaults';
175            1                                  3            last;
176                                                         }
177                                                         elsif ( $line =~ m/^\s*\[[a-zA-Z]+\]\s*$/ ) {
178            1                                  3            MKDEBUG && _d('option file config line');
179            1                                  4            $type = 'option_file',
180                                                            last;
181                                                         }
182                                                         elsif (    $line =~ m/Starts the MySQL database server/
183                                                                 || $line =~ m/Default options are read from /
184                                                                 || $line =~ m/^help\s+TRUE / )
185                                                         {
186            1                                  2            MKDEBUG && _d('mysqld config line');
187            1                                  4            $type = 'mysqld';
188            1                                  4            last;
189                                                         }
190                                                      }
191            3                                 28      close $fh;
192            3                                  9      return $type;
193                                                   }
194                                                   
195                                                   sub parse_show_variables {
196   ***      1                    1      0      8      my ( %args ) = @_;
197            1                                  7      my @required_args = qw(source TextResultSetParser);
198            1                                  4      foreach my $arg ( @required_args ) {
199   ***      2     50                          11         die "I need a $arg arugment" unless $args{$arg};
200                                                      }
201            1                                  5      my ($source, $trp) = @args{@required_args};
202            1                                  5      my $output         = _slurp_file($source);
203   ***      1     50                          11      return unless $output;
204                                                   
205          240                              15454      my %config = map {
206            1                                  7         $_->{Variable_name} => $_->{Value}
207            1                                  3      } @{ $trp->parse($output) };
208                                                   
209            1                                304      return \%config;
210                                                   }
211                                                   
212                                                   # Parse "mysqld --help --verbose" and return a hashref of variable=>values
213                                                   # and an arrayref of default defaults files if possible.  The "default
214                                                   # defaults files" are the defaults file that mysqld reads by default if no
215                                                   # defaults file is explicitly given by --default-file.
216                                                   sub parse_mysqld {
217   ***      1                    1      0      6      my ( %args ) = @_;
218            1                                  5      my @required_args = qw(source);
219            1                                  4      foreach my $arg ( @required_args ) {
220   ***      1     50                           6         die "I need a $arg arugment" unless $args{$arg};
221                                                      }
222            1                                  6      my ($source) = @args{@required_args};
223            1                                  5      my $output   = _slurp_file($source);
224   ***      1     50                          10      return unless $output;
225                                                   
226                                                      # First look for the list of option files like
227                                                      #   Default options are read from the following files in the given order:
228                                                      #   /etc/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
229            1                                  2      my @opt_files;
230   ***      1     50                          12      if ( $output =~ m/^Default options are read.+\n/mg ) {
231            1                                 51         my ($opt_files) = $output =~ m/\G^(.+)\n/m;
232            1                                  4         my %seen;
233            1                                  7         my @opt_files = grep { !$seen{$_} } split(' ', $opt_files);
               3                                 14   
234            1                                  4         MKDEBUG && _d('Option files:', @opt_files);
235                                                      }
236                                                      else {
237   ***      0                                  0         MKDEBUG && _d("mysqld help output doesn't list option files");
238                                                      }
239                                                   
240                                                      # The list of sys vars and their default vals begins like:
241                                                      #   Variables (--variable-name=value)
242                                                      #   and boolean options {FALSE|TRUE}  Value (after reading options)
243                                                      #   --------------------------------- -----------------------------
244                                                      #   help                              TRUE
245                                                      #   abort-slave-event-count           0
246                                                      # So we search for that line of hypens.
247   ***      1     50                         735      if ( $output !~ m/^-+ -+$/mg ) {
248   ***      0                                  0         MKDEBUG && _d("mysqld help output doesn't list vars and vals");
249   ***      0                                  0         return;
250                                                      }
251                                                   
252                                                      # Cut off everything before the list of vars and vals.
253            1                                 13      my $varvals = substr($output, (pos $output) + 1, length $output);
254                                                   
255                                                      # Parse the "var  val" lines.  2nd retval is duplicates but there
256                                                      # shouldn't be any with mysqld.
257            1                                247      my ($config, undef) = _parse_varvals($varvals =~ m/\G^(\S+)(.*)\n/mg);
258                                                   
259            1                                 46      return $config, \@opt_files;
260                                                   }
261                                                   
262                                                   # Parse "my_print_defaults" output and return a hashref of variable=>values
263                                                   # and a hashref of any duplicated variables.
264                                                   sub parse_my_print_defaults {
265   ***      1                    1      0      7      my ( %args ) = @_;
266            1                                  5      my @required_args = qw(source);
267            1                                  6      foreach my $arg ( @required_args ) {
268   ***      1     50                           6         die "I need a $arg arugment" unless $args{$arg};
269                                                      }
270            1                                  4      my ($source) = @args{@required_args};
271            1                                  5      my $output   = _slurp_file($source);
272   ***      1     50                           9      return unless $output;
273                                                   
274                                                      # Parse the "--var=val" lines.
275           18                                 88      my ($config, $dupes) = _parse_varvals(
276            1                                 10         map { $_ =~ m/^--([^=]+)(?:=(.*))?$/ } split("\n", $output)
277                                                      );
278                                                   
279            1                                  8      return $config, $dupes;
280                                                   }
281                                                   
282                                                   # Parse the [mysqld] section of an option file and return a hashref of
283                                                   # variable=>values and a hashref of any duplicated variables.
284                                                   sub parse_option_file {
285   ***      1                    1      0      5      my ( %args ) = @_;
286            1                                  5      my @required_args = qw(source);
287            1                                  5      foreach my $arg ( @required_args ) {
288   ***      1     50                           7         die "I need a $arg arugment" unless $args{$arg};
289                                                      }
290            1                                  5      my ($source) = @args{@required_args};
291            1                                  4      my $output   = _slurp_file($source);
292   ***      1     50                           9      return unless $output;
293                                                   
294            1                                146      my ($mysqld_section) = $output =~ m/\[mysqld\](.+?)^(?:\[\w+\]|\Z)/xms;
295   ***      1     50                           5      die "Failed to parse the [mysqld] section from $source"
296                                                         unless $mysqld_section;
297                                                   
298                                                      # Parse the "var=val" lines.
299           22                                103      my ($config, $dupes) = _parse_varvals(
300           89                                333         map  { $_ =~ m/^([^=]+)(?:=(.*))?$/ }
301            1                                 27         grep { $_ !~ m/^\s*#/ }  # no # comment lines
302                                                         split("\n", $mysqld_section)
303                                                      );
304                                                   
305            1                                 17      return $config, $dupes;
306                                                   }
307                                                   
308                                                   # Parses a list of variables and their values ("varvals"), returns two
309                                                   # hashrefs: one with normalized variable=>value, the other with duplicate
310                                                   # vars.  The varvals list should start with a var at index 0 and its value
311                                                   # at index 1 then repeat for the next var-val pair.  
312                                                   sub _parse_varvals {
313            3                    3           210      my ( @varvals ) = @_;
314                                                   
315                                                      # Config built from parsing the given varvals.
316            3                                 38      my %config;
317                                                   
318                                                      # Discover duplicate vars.  
319            3                                 10      my $duplicate_var = 0;
320            3                                  8      my %duplicates;
321                                                   
322                                                      # Keep track if item is var or val because each needs special modifications.
323            3                                  7      my $var      = 1;
324            3                                 10      my $last_var = undef;
325            3                                 12      foreach my $item ( @varvals ) {
326          590    100                        1978         if ( $item ) {
327          587                               1755            $item =~ s/^\s+//;  # strip leading whitespace
328          587                               1657            $item =~ s/\s+$//;  # strip trailing whitespace
329                                                         }
330                                                   
331          590    100                        1724         if ( $var ) {
332                                                            # Variable names via config files are like "log-bin" but
333                                                            # via SHOW VARIABLES they're like "log_bin".
334          295                                893            $item =~ s/-/_/g;
335                                                   
336                                                            # If this var exists in the offline config already, then
337                                                            # its a duplicate.  Its original value will be saved before
338                                                            # being overwritten with the new value.
339   ***    295    100     66                 1414            if ( exists $config{$item} && !$can_be_duplicate{$item} ) {
340            4                                  9               MKDEBUG && _d("Duplicate var:", $item);
341            4                                 12               $duplicate_var = 1;
342                                                            }
343                                                   
344          295                                726            $var      = 0;  # next item should be the val for this var
345          295                                902            $last_var = $item;
346                                                         }
347                                                         else {
348          295    100                         965            if ( $item ) {
349          266                                709               $item =~ s/^\s+//;
350                                                   
351          266    100                        1604               if ( my ($num, $factor) = $item =~ m/(\d+)([kmgt])$/i ) {
                    100                               
352            9                                 43                  my %factor_for = (
353                                                                     k => 1_024,
354                                                                     m => 1_048_576,
355                                                                     g => 1_073_741_824,
356                                                                     t => 1_099_511_627_776,
357                                                                  );
358            9                                 43                  $item = $num * $factor_for{lc $factor};
359                                                               }
360                                                               elsif ( $item =~ m/No default/ ) {
361           37                                111                  $item = undef;
362                                                               }
363                                                            }
364                                                   
365          295    100    100                 1172            $item = $undef_for{$last_var} || '' unless defined $item;
366                                                   
367          295    100                         944            if ( $duplicate_var ) {
368                                                               # Save var's original value before overwritng with this new value.
369            4                                 10               push @{$duplicates{$last_var}}, $config{$last_var};
               4                                 20   
370            4                                 13               $duplicate_var = 0;
371                                                            }
372                                                   
373                                                            # Save this var-val.
374          295                               1068            $config{$last_var} = $item;
375                                                   
376          295                                902            $var = 1;  # next item should be a var
377                                                         }
378                                                      }
379                                                   
380            3                                 62      return \%config, \%duplicates;
381                                                   }
382                                                   
383                                                   sub _slurp_file {
384            4                    4            18      my ( $file ) = @_;
385   ***      4     50                          16      die "I need a file argument" unless $file;
386   ***      4     50                         118      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
387            4                                 12      my $contents = do { local $/ = undef; <$fh> };
               4                                 24   
               4                                307   
388            4                                 30      close $fh;
389            4                                 10      return $contents;
390                                                   }
391                                                   
392                                                   sub _get_version {
393            1                    1             5      my ( $dbh ) = @_;
394   ***      1     50                           6      return unless $dbh;
395            1                                  2      my $version = $dbh->selectrow_arrayref('SELECT VERSION()')->[0];
396            1                                229      $version =~ s/(\d\.\d{1,2}.\d{1,2})/$1/;
397            1                                  2      MKDEBUG && _d('MySQL version', $version);
398            1                                 69      return $version;
399                                                   }
400                                                   
401                                                   # #############################################################################
402                                                   # Accessor methods.
403                                                   # #############################################################################
404                                                   
405                                                   # Returns true if this MySQLConfig obj has the given variable.
406                                                   sub has {
407   ***      3                    3      0     14      my ( $self, $var ) = @_;
408            3                                 19      return exists $self->{vars}->{$var};
409                                                   }
410                                                   
411                                                   # Returns the value for the given variable.
412                                                   sub get {
413   ***      5                    5      0     25      my ( $self, $var ) = @_;
414   ***      5     50                          21      return unless $var;
415            5                                 34      return $self->{vars}->{$var};
416                                                   }
417                                                   
418                                                   # Returns all variables-values.
419                                                   sub get_variables {
420   ***      3                    3      0     12      my ( $self, %args ) = @_;
421            3                                205      return $self->{vars};
422                                                   }
423                                                   
424                                                   sub get_duplicate_variables {
425   ***      1                    1      0      5      my ( $self ) = @_;
426            1                                  9      return $self->{duplicate_vars};
427                                                   }
428                                                   
429                                                   sub get_option_files {
430   ***      0                    0      0      0      my ( $self ) = @_;
431   ***      0                                  0      return $self->{option_files};
432                                                   }
433                                                   
434                                                   sub get_mysql_version {
435   ***      1                    1      0      5      my ( $self ) = @_;
436            1                                 12      return $self->{mysql_version};
437                                                   }
438                                                   
439                                                   sub get_type {
440   ***      5                    5      0     20      my ( $self ) = @_;
441            5                                 37      return $self->{type};
442                                                   }
443                                                   
444                                                   sub _d {
445            1                    1             8      my ($package, undef, $line) = caller 0;
446   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 13   
447            1                                  5           map { defined $_ ? $_ : 'undef' }
448                                                           @_;
449            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
450                                                   }
451                                                   
452                                                   1;
453                                                   
454                                                   # ###########################################################################
455                                                   # End MySQLConfig package
456                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
64    ***     50      0     12   unless $args{$arg}
81    ***     50      0     12   unless $args{$arg}
86           100      3      3   if (-f $source) { }
             100      1      2   elsif (ref $source and ref $source eq 'ARRAY') { }
             100      1      1   elsif (ref $source and ref($source) =~ /DBI/i) { }
112   ***     50      0      6   unless $args{$arg}
117   ***     50      0      3   if (not $type)
124   ***     50      0      3   if ($type eq 'show_variables') { }
             100      1      2   elsif ($type eq 'mysqld') { }
             100      1      1   elsif ($type eq 'my_print_defaults') { }
      ***     50      1      0   elsif ($type eq 'option_file') { }
140   ***     50      0      3   unless $vars and keys %$vars
155   ***     50      0      3   unless $args{$arg}
160   ***     50      0      3   unless open my $fh, '<', $source
164   ***     50      0     26   if ($line =~ /\|\s+\w+\s+\|\s+.+?\|/ or $line =~ /\*+ \d/ or $line =~ /Variable_name:\s+\w+/) { }
             100      1     25   elsif ($line =~ /^--\w+/) { }
             100      1     24   elsif ($line =~ /^\s*\[[a-zA-Z]+\]\s*$/) { }
             100      1     23   elsif ($line =~ /Starts the MySQL database server/ or $line =~ /Default options are read from / or $line =~ /^help\s+TRUE /) { }
199   ***     50      0      2   unless $args{$arg}
203   ***     50      0      1   unless $output
220   ***     50      0      1   unless $args{$arg}
224   ***     50      0      1   unless $output
230   ***     50      1      0   if ($output =~ /^Default options are read.+\n/gm) { }
247   ***     50      0      1   if (not $output =~ /^-+ -+$/gm)
268   ***     50      0      1   unless $args{$arg}
272   ***     50      0      1   unless $output
288   ***     50      0      1   unless $args{$arg}
292   ***     50      0      1   unless $output
295   ***     50      0      1   unless $mysqld_section
326          100    587      3   if ($item)
331          100    295    295   if ($var) { }
339          100      4    291   if (exists $config{$item} and not $can_be_duplicate{$item})
348          100    266     29   if ($item)
351          100      9    257   if (my($num, $factor) = $item =~ /(\d+)([kmgt])$/i) { }
             100     37    220   elsif ($item =~ /No default/) { }
365          100     40    255   unless defined $item
367          100      4    291   if ($duplicate_var)
385   ***     50      0      4   unless $file
386   ***     50      0      4   unless open my $fh, '<', $file
394   ***     50      0      1   unless $dbh
414   ***     50      0      5   unless $var
446   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
86           100      1      1      1   ref $source and ref $source eq 'ARRAY'
      ***     66      1      0      1   ref $source and ref($source) =~ /DBI/i
140   ***     33      0      0      3   $vars and keys %$vars
339   ***     66    291      0      4   exists $config{$item} and not $can_be_duplicate{$item}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
36    ***     50      0      1   $ENV{'MKDEBUG'} || 0
365          100      5     35   $undef_for{$last_var} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
116   ***     33      0      3      0   $args{'type'} || detect_source_type(%args)
164   ***     33      0      0     26   $line =~ /\|\s+\w+\s+\|\s+.+?\|/ or $line =~ /\*+ \d/
      ***     33      0      0     26   $line =~ /\|\s+\w+\s+\|\s+.+?\|/ or $line =~ /\*+ \d/ or $line =~ /Variable_name:\s+\w+/
      ***     66      1      0     23   $line =~ /Starts the MySQL database server/ or $line =~ /Default options are read from /
      ***     66      1      0     23   $line =~ /Starts the MySQL database server/ or $line =~ /Default options are read from / or $line =~ /^help\s+TRUE /


Covered Subroutines
-------------------

Subroutine              Count Pod Location                                                
----------------------- ----- --- --------------------------------------------------------
BEGIN                       1     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:28 
BEGIN                       1     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:29 
BEGIN                       1     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:30 
BEGIN                       1     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:31 
BEGIN                       1     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:36 
_d                          1     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:445
_get_version                1     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:393
_parse_varvals              3     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:313
_slurp_file                 4     /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:384
detect_source_type          3   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:152
get                         5   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:413
get_duplicate_variables     1   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:425
get_mysql_version           1   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:435
get_type                    5   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:440
get_variables               3   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:420
has                         3   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:407
new                         6   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:61 
parse_config                6   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:78 
parse_config_from_file      3   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:109
parse_my_print_defaults     1   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:265
parse_mysqld                1   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:217
parse_option_file           1   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:285
parse_show_variables        1   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:196

Uncovered Subroutines
---------------------

Subroutine              Count Pod Location                                                
----------------------- ----- --- --------------------------------------------------------
get_option_files            0   0 /home/daniel/dev/maatkit/trunk/common/MySQLConfig.pm:430


MySQLConfig.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            31      die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  9   
12             1                    1            10   use Test::More tests => 21;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use MySQLConfig;
               1                                  3   
               1                                115   
15             1                    1            10   use DSNParser;
               1                                  4   
               1                                 12   
16             1                    1            14   use Sandbox;
               1                                  2   
               1                                 10   
17             1                    1            11   use TextResultSetParser;
               1                                  4   
               1                                 16   
18             1                    1            10   use MaatkitTest;
               1                                  5   
               1                                 37   
19                                                    
20             1                                 10   my $dp  = new DSNParser(opts=>$dsn_opts);
21             1                                233   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
22             1                                 52   my $dbh = $sb->get_dbh_for('master');
23                                                    
24             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
25             1                                  4   $Data::Dumper::Indent    = 1;
26             1                                  3   $Data::Dumper::Sortkeys  = 1;
27             1                                  3   $Data::Dumper::Quotekeys = 0;
28                                                    
29             1                                  4   my $output;
30             1                                  3   my $sample = "common/t/samples/configs/";
31             1                                  8   my $trp    = new TextResultSetParser();
32                                                    
33                                                    throws_ok(
34                                                       sub {
35             1                    1            24         my $config = new MySQLConfig(
36                                                             source              => 'fooz',
37                                                             TextResultSetParser => $trp,
38                                                          );
39                                                       },
40             1                                 61      qr/invalid source/,
41                                                       'Dies if source cannot be opened'
42                                                    );
43                                                    
44                                                    # #############################################################################
45                                                    # parse_show_variables()
46                                                    # #############################################################################
47             1                                 18   is_deeply(
48                                                       MySQLConfig::parse_show_variables(
49                                                          source => "$trunk/common/t/samples/show-variables/vars003.txt",
50                                                          TextResultSetParser => $trp,
51                                                       ),
52                                                       {
53                                                          auto_increment_increment => '1',
54                                                          auto_increment_offset => '1',
55                                                          automatic_sp_privileges => 'ON',
56                                                          back_log => '50',
57                                                          basedir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/',
58                                                          binlog_cache_size => '32768',
59                                                          bulk_insert_buffer_size => '8388608',
60                                                          character_set_client => 'latin1',
61                                                          character_set_connection => 'latin1',
62                                                          character_set_database => 'latin1',
63                                                          character_set_filesystem => 'binary',
64                                                          character_set_results => 'latin1',
65                                                          character_set_server => 'latin1',
66                                                          character_set_system => 'utf8',
67                                                          character_sets_dir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
68                                                          collation_connection => 'latin1_swedish_ci',
69                                                          collation_database => 'latin1_swedish_ci',
70                                                          collation_server => 'latin1_swedish_ci',
71                                                          completion_type => '0',
72                                                          concurrent_insert => '1',
73                                                          connect_timeout => '10',
74                                                          datadir => '/tmp/12345/data/',
75                                                          date_format => '%Y-%m-%d',
76                                                          datetime_format => '%Y-%m-%d %H:%i:%s',
77                                                          default_week_format => '0',
78                                                          delay_key_write => 'ON',
79                                                          delayed_insert_limit => '100',
80                                                          delayed_insert_timeout => '300',
81                                                          delayed_queue_size => '1000',
82                                                          div_precision_increment => '4',
83                                                          engine_condition_pushdown => 'OFF',
84                                                          expire_logs_days => '0',
85                                                          flush => 'OFF',
86                                                          flush_time => '0',
87                                                          ft_boolean_syntax => '',
88                                                          ft_max_word_len => '84',
89                                                          ft_min_word_len => '4',
90                                                          ft_query_expansion_limit => '20',
91                                                          ft_stopword_file => '(built-in)',
92                                                          group_concat_max_len => '1024',
93                                                          have_archive => 'YES',
94                                                          have_bdb => 'NO',
95                                                          have_blackhole_engine => 'YES',
96                                                          have_community_features => 'YES',
97                                                          have_compress => 'YES',
98                                                          have_crypt => 'YES',
99                                                          have_csv => 'YES',
100                                                         have_dynamic_loading => 'YES',
101                                                         have_example_engine => 'NO',
102                                                         have_federated_engine => 'YES',
103                                                         have_geometry => 'YES',
104                                                         have_innodb => 'YES',
105                                                         have_isam => 'NO',
106                                                         have_merge_engine => 'YES',
107                                                         have_ndbcluster => 'DISABLED',
108                                                         have_openssl => 'DISABLED',
109                                                         have_profiling => 'YES',
110                                                         have_query_cache => 'YES',
111                                                         have_raid => 'NO',
112                                                         have_rtree_keys => 'YES',
113                                                         have_ssl => 'DISABLED',
114                                                         have_symlink => 'YES',
115                                                         hostname => 'dante',
116                                                         init_connect => '',
117                                                         init_file => '',
118                                                         init_slave => '',
119                                                         innodb_adaptive_hash_index => 'ON',
120                                                         innodb_additional_mem_pool_size => '1048576',
121                                                         innodb_autoextend_increment => '8',
122                                                         innodb_buffer_pool_awe_mem_mb => '0',
123                                                         innodb_buffer_pool_size => '16777216',
124                                                         innodb_checksums => 'ON',
125                                                         innodb_commit_concurrency => '0',
126                                                         innodb_concurrency_tickets => '500',
127                                                         innodb_data_file_path => 'ibdata1:10M:autoextend',
128                                                         innodb_data_home_dir => '/tmp/12345/data',
129                                                         innodb_doublewrite => 'ON',
130                                                         innodb_fast_shutdown => '1',
131                                                         innodb_file_io_threads => '4',
132                                                         innodb_file_per_table => 'OFF',
133                                                         innodb_flush_log_at_trx_commit => '1',
134                                                         innodb_flush_method => '',
135                                                         innodb_force_recovery => '0',
136                                                         innodb_lock_wait_timeout => '50',
137                                                         innodb_locks_unsafe_for_binlog => 'OFF',
138                                                         innodb_log_arch_dir => '',
139                                                         innodb_log_archive => 'OFF',
140                                                         innodb_log_buffer_size => '1048576',
141                                                         innodb_log_file_size => '5242880',
142                                                         innodb_log_files_in_group => '2',
143                                                         innodb_log_group_home_dir => '/tmp/12345/data',
144                                                         innodb_max_dirty_pages_pct => '90',
145                                                         innodb_max_purge_lag => '0',
146                                                         innodb_mirrored_log_groups => '1',
147                                                         innodb_open_files => '300',
148                                                         innodb_rollback_on_timeout => 'OFF',
149                                                         innodb_support_xa => 'ON',
150                                                         innodb_sync_spin_loops => '20',
151                                                         innodb_table_locks => 'ON',
152                                                         innodb_thread_concurrency => '8',
153                                                         innodb_thread_sleep_delay => '10000',
154                                                         innodb_use_legacy_cardinality_algorithm => 'ON',
155                                                         interactive_timeout => '28800',
156                                                         join_buffer_size => '131072',
157                                                         keep_files_on_create => 'OFF',
158                                                         key_buffer_size => '16777216',
159                                                         key_cache_age_threshold => '300',
160                                                         key_cache_block_size => '1024',
161                                                         key_cache_division_limit => '100',
162                                                         language => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
163                                                         large_files_support => 'ON',
164                                                         large_page_size => '0',
165                                                         large_pages => 'OFF',
166                                                         lc_time_names => 'en_US',
167                                                         license => 'GPL',
168                                                         local_infile => 'ON',
169                                                         locked_in_memory => 'OFF',
170                                                         log => 'OFF',
171                                                         log_bin => 'ON',
172                                                         log_bin_trust_function_creators => 'OFF',
173                                                         log_error => '',
174                                                         log_queries_not_using_indexes => 'OFF',
175                                                         log_slave_updates => 'ON',
176                                                         log_slow_queries => 'OFF',
177                                                         log_warnings => '1',
178                                                         long_query_time => '10',
179                                                         low_priority_updates => 'OFF',
180                                                         lower_case_file_system => 'OFF',
181                                                         lower_case_table_names => '0',
182                                                         max_allowed_packet => '1048576',
183                                                         max_binlog_cache_size => '18446744073709547520',
184                                                         max_binlog_size => '1073741824',
185                                                         max_connect_errors => '10',
186                                                         max_connections => '100',
187                                                         max_delayed_threads => '20',
188                                                         max_error_count => '64',
189                                                         max_heap_table_size => '16777216',
190                                                         max_insert_delayed_threads => '20',
191                                                         max_join_size => '18446744073709551615',
192                                                         max_length_for_sort_data => '1024',
193                                                         max_prepared_stmt_count => '16382',
194                                                         max_relay_log_size => '0',
195                                                         max_seeks_for_key => '18446744073709551615',
196                                                         max_sort_length => '1024',
197                                                         max_sp_recursion_depth => '0',
198                                                         max_tmp_tables => '32',
199                                                         max_user_connections => '0',
200                                                         max_write_lock_count => '18446744073709551615',
201                                                         multi_range_count => '256',
202                                                         myisam_data_pointer_size => '6',
203                                                         myisam_max_sort_file_size => '9223372036853727232',
204                                                         myisam_recover_options => 'OFF',
205                                                         myisam_repair_threads => '1',
206                                                         myisam_sort_buffer_size => '8388608',
207                                                         myisam_stats_method => 'nulls_unequal',
208                                                         ndb_autoincrement_prefetch_sz => '1',
209                                                         ndb_cache_check_time => '0',
210                                                         ndb_connectstring => '',
211                                                         ndb_force_send => 'ON',
212                                                         ndb_use_exact_count => 'ON',
213                                                         ndb_use_transactions => 'ON',
214                                                         net_buffer_length => '16384',
215                                                         net_read_timeout => '30',
216                                                         net_retry_count => '10',
217                                                         net_write_timeout => '60',
218                                                         new => 'OFF',
219                                                         old_passwords => 'OFF',
220                                                         open_files_limit => '1024',
221                                                         optimizer_prune_level => '1',
222                                                         optimizer_search_depth => '62',
223                                                         pid_file => '/tmp/12345/data/mysql_sandbox12345.pid',
224                                                         plugin_dir => '',
225                                                         port => '12345',
226                                                         preload_buffer_size => '32768',
227                                                         profiling => 'OFF',
228                                                         profiling_history_size => '15',
229                                                         protocol_version => '10',
230                                                         query_alloc_block_size => '8192',
231                                                         query_cache_limit => '1048576',
232                                                         query_cache_min_res_unit => '4096',
233                                                         query_cache_size => '0',
234                                                         query_cache_type => 'ON',
235                                                         query_cache_wlock_invalidate => 'OFF',
236                                                         query_prealloc_size => '8192',
237                                                         range_alloc_block_size => '4096',
238                                                         read_buffer_size => '131072',
239                                                         read_only => 'OFF',
240                                                         read_rnd_buffer_size => '262144',
241                                                         relay_log => 'mysql-relay-bin',
242                                                         relay_log_index => '',
243                                                         relay_log_info_file => 'relay-log.info',
244                                                         relay_log_purge => 'ON',
245                                                         relay_log_space_limit => '0',
246                                                         rpl_recovery_rank => '0',
247                                                         secure_auth => 'OFF',
248                                                         secure_file_priv => '',
249                                                         server_id => '12345',
250                                                         skip_external_locking => 'ON',
251                                                         skip_networking => 'OFF',
252                                                         skip_show_database => 'OFF',
253                                                         slave_compressed_protocol => 'OFF',
254                                                         slave_load_tmpdir => '/tmp/',
255                                                         slave_net_timeout => '3600',
256                                                         slave_skip_errors => 'OFF',
257                                                         slave_transaction_retries => '10',
258                                                         slow_launch_time => '2',
259                                                         socket => '/tmp/12345/mysql_sandbox12345.sock',
260                                                         sort_buffer_size => '2097144',
261                                                         sql_big_selects => 'ON',
262                                                         sql_mode => '',
263                                                         sql_notes => 'ON',
264                                                         sql_warnings => 'OFF',
265                                                         ssl_ca => '',
266                                                         ssl_capath => '',
267                                                         ssl_cert => '',
268                                                         ssl_cipher => '',
269                                                         ssl_key => '',
270                                                         storage_engine => 'MyISAM',
271                                                         sync_binlog => '0',
272                                                         sync_frm => 'ON',
273                                                         system_time_zone => 'MDT',
274                                                         table_cache => '64',
275                                                         table_lock_wait_timeout => '50',
276                                                         table_type => 'MyISAM',
277                                                         thread_cache_size => '0',
278                                                         thread_stack => '262144',
279                                                         time_format => '%H:%i:%s',
280                                                         time_zone => 'SYSTEM',
281                                                         timed_mutexes => 'OFF',
282                                                         tmp_table_size => '33554432',
283                                                         tmpdir => '/tmp/',
284                                                         transaction_alloc_block_size => '8192',
285                                                         transaction_prealloc_size => '4096',
286                                                         tx_isolation => 'REPEATABLE-READ',
287                                                         updatable_views_with_limit => 'YES',
288                                                         version => '5.0.82-log',
289                                                         version_comment => 'MySQL Community Server (GPL)',
290                                                         version_compile_machine => 'x86_64',
291                                                         version_compile_os => 'unknown-linux-gnu',
292                                                         wait_timeout => '28800'
293                                                      },
294                                                      'parse_show_variables()',
295                                                   );
296                                                   
297                                                   # #############################################################################
298                                                   # Config from mysqld --help --verbose
299                                                   # #############################################################################
300            1                                 96   my $config = new MySQLConfig(
301                                                      source              => "$trunk/$sample/mysqldhelp001.txt",
302                                                      TextResultSetParser => $trp,
303                                                   );
304                                                   
305            1                                  8   is(
306                                                      $config->get_type(),
307                                                      'mysqld',
308                                                      "Detect mysqld type"
309                                                   );
310                                                   
311            1                                  6   is_deeply(
312                                                      $config->get_variables(),
313                                                      {
314                                                         abort_slave_event_count => '0',
315                                                         allow_suspicious_udfs => 'FALSE',
316                                                         auto_increment_increment => '1',
317                                                         auto_increment_offset => '1',
318                                                         automatic_sp_privileges => 'TRUE',
319                                                         back_log => '50',
320                                                         basedir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23',
321                                                         bdb => 'FALSE',
322                                                         bind_address => '',
323                                                         binlog_cache_size => '32768',
324                                                         bulk_insert_buffer_size => '8388608',
325                                                         character_set_client_handshake => 'TRUE',
326                                                         character_set_filesystem => 'binary',
327                                                         character_set_server => 'latin1',
328                                                         character_sets_dir => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/charsets/',
329                                                         chroot => '',
330                                                         collation_server => 'latin1_swedish_ci',
331                                                         completion_type => '0',
332                                                         concurrent_insert => '1',
333                                                         connect_timeout => '10',
334                                                         console => 'FALSE',
335                                                         datadir => '/tmp/12345/data/',
336                                                         date_format => '',
337                                                         datetime_format => '',
338                                                         default_character_set => 'latin1',
339                                                         default_collation => 'latin1_swedish_ci',
340                                                         default_time_zone => '',
341                                                         default_week_format => '0',
342                                                         delayed_insert_limit => '100',
343                                                         delayed_insert_timeout => '300',
344                                                         delayed_queue_size => '1000',
345                                                         des_key_file => '',
346                                                         disconnect_slave_event_count => '0',
347                                                         div_precision_increment => '4',
348                                                         enable_locking => 'FALSE',
349                                                         enable_pstack => 'FALSE',
350                                                         engine_condition_pushdown => 'FALSE',
351                                                         expire_logs_days => '0',
352                                                         external_locking => 'FALSE',
353                                                         federated => 'TRUE',
354                                                         flush_time => '0',
355                                                         ft_max_word_len => '84',
356                                                         ft_min_word_len => '4',
357                                                         ft_query_expansion_limit => '20',
358                                                         ft_stopword_file => '',
359                                                         gdb => 'FALSE',
360                                                         group_concat_max_len => '1024',
361                                                         help => 'TRUE',
362                                                         init_connect => '',
363                                                         init_file => '',
364                                                         init_slave => '',
365                                                         innodb => 'TRUE',
366                                                         innodb_adaptive_hash_index => 'TRUE',
367                                                         innodb_additional_mem_pool_size => '1048576',
368                                                         innodb_autoextend_increment => '8',
369                                                         innodb_buffer_pool_awe_mem_mb => '0',
370                                                         innodb_buffer_pool_size => '16777216',
371                                                         innodb_checksums => 'TRUE',
372                                                         innodb_commit_concurrency => '0',
373                                                         innodb_concurrency_tickets => '500',
374                                                         innodb_data_home_dir => '/tmp/12345/data',
375                                                         innodb_doublewrite => 'TRUE',
376                                                         innodb_fast_shutdown => '1',
377                                                         innodb_file_io_threads => '4',
378                                                         innodb_file_per_table => 'FALSE',
379                                                         innodb_flush_log_at_trx_commit => '1',
380                                                         innodb_flush_method => '',
381                                                         innodb_force_recovery => '0',
382                                                         innodb_lock_wait_timeout => '3',
383                                                         innodb_locks_unsafe_for_binlog => 'FALSE',
384                                                         innodb_log_arch_dir => '',
385                                                         innodb_log_buffer_size => '1048576',
386                                                         innodb_log_file_size => '5242880',
387                                                         innodb_log_files_in_group => '2',
388                                                         innodb_log_group_home_dir => '/tmp/12345/data',
389                                                         innodb_max_dirty_pages_pct => '90',
390                                                         innodb_max_purge_lag => '0',
391                                                         innodb_mirrored_log_groups => '1',
392                                                         innodb_open_files => '300',
393                                                         innodb_rollback_on_timeout => 'FALSE',
394                                                         innodb_status_file => 'FALSE',
395                                                         innodb_support_xa => 'TRUE',
396                                                         innodb_sync_spin_loops => '20',
397                                                         innodb_table_locks => 'TRUE',
398                                                         innodb_thread_concurrency => '8',
399                                                         innodb_thread_sleep_delay => '10000',
400                                                         innodb_use_legacy_cardinality_algorithm => 'TRUE',
401                                                         interactive_timeout => '28800',
402                                                         isam => 'FALSE',
403                                                         join_buffer_size => '131072',
404                                                         keep_files_on_create => 'FALSE',
405                                                         key_buffer_size => '16777216',
406                                                         key_cache_age_threshold => '300',
407                                                         key_cache_block_size => '1024',
408                                                         key_cache_division_limit => '100',
409                                                         language => '/home/daniel/mysql_binaries/mysql-5.0.82-linux-x86_64-glibc23/share/mysql/english/',
410                                                         large_pages => 'FALSE',
411                                                         lc_time_names => 'en_US',
412                                                         local_infile => 'TRUE',
413                                                         log => 'OFF',
414                                                         log_bin => 'mysql-bin',
415                                                         log_bin_index => '',
416                                                         log_bin_trust_function_creators => 'FALSE',
417                                                         log_bin_trust_routine_creators => 'FALSE',
418                                                         log_error => '',
419                                                         log_isam => 'myisam.log',
420                                                         log_queries_not_using_indexes => 'FALSE',
421                                                         log_short_format => 'FALSE',
422                                                         log_slave_updates => 'TRUE',
423                                                         log_slow_admin_statements => 'FALSE',
424                                                         log_slow_queries => 'OFF',
425                                                         log_tc => 'tc.log',
426                                                         log_tc_size => '24576',
427                                                         log_update => 'OFF',
428                                                         log_warnings => '1',
429                                                         long_query_time => '10',
430                                                         low_priority_updates => 'FALSE',
431                                                         lower_case_table_names => '0',
432                                                         master_connect_retry => '60',
433                                                         master_host => '',
434                                                         master_info_file => 'master.info',
435                                                         master_password => '',
436                                                         master_port => '3306',
437                                                         master_retry_count => '86400',
438                                                         master_ssl => 'FALSE',
439                                                         master_ssl_ca => '',
440                                                         master_ssl_capath => '',
441                                                         master_ssl_cert => '',
442                                                         master_ssl_cipher => '',
443                                                         master_ssl_key => '',
444                                                         master_user => 'test',
445                                                         max_allowed_packet => '1048576',
446                                                         max_binlog_cache_size => '18446744073709547520',
447                                                         max_binlog_dump_events => '0',
448                                                         max_binlog_size => '1073741824',
449                                                         max_connect_errors => '10',
450                                                         max_connections => '100',
451                                                         max_delayed_threads => '20',
452                                                         max_error_count => '64',
453                                                         max_heap_table_size => '16777216',
454                                                         max_join_size => '18446744073709551615',
455                                                         max_length_for_sort_data => '1024',
456                                                         max_prepared_stmt_count => '16382',
457                                                         max_relay_log_size => '0',
458                                                         max_seeks_for_key => '18446744073709551615',
459                                                         max_sort_length => '1024',
460                                                         max_sp_recursion_depth => '0',
461                                                         max_tmp_tables => '32',
462                                                         max_user_connections => '0',
463                                                         max_write_lock_count => '18446744073709551615',
464                                                         memlock => 'FALSE',
465                                                         merge => 'TRUE',
466                                                         multi_range_count => '256',
467                                                         myisam_block_size => '1024',
468                                                         myisam_data_pointer_size => '6',
469                                                         myisam_max_extra_sort_file_size => '2147483648',
470                                                         myisam_max_sort_file_size => '9223372036853727232',
471                                                         myisam_recover => 'OFF',
472                                                         myisam_repair_threads => '1',
473                                                         myisam_sort_buffer_size => '8388608',
474                                                         myisam_stats_method => 'nulls_unequal',
475                                                         ndb_autoincrement_prefetch_sz => '1',
476                                                         ndb_cache_check_time => '0',
477                                                         ndb_connectstring => '',
478                                                         ndb_force_send => 'TRUE',
479                                                         ndb_mgmd_host => '',
480                                                         ndb_nodeid => '0',
481                                                         ndb_optimized_node_selection => 'TRUE',
482                                                         ndb_shm => 'FALSE',
483                                                         ndb_use_exact_count => 'TRUE',
484                                                         ndb_use_transactions => 'TRUE',
485                                                         ndbcluster => 'FALSE',
486                                                         net_buffer_length => '16384',
487                                                         net_read_timeout => '30',
488                                                         net_retry_count => '10',
489                                                         net_write_timeout => '60',
490                                                         new => 'FALSE',
491                                                         old_passwords => 'FALSE',
492                                                         old_style_user_limits => 'FALSE',
493                                                         open_files_limit => '0',
494                                                         optimizer_prune_level => '1',
495                                                         optimizer_search_depth => '62',
496                                                         pid_file => '/tmp/12345/data/mysql_sandbox12345.pid',
497                                                         plugin_dir => '',
498                                                         port => '12345',
499                                                         port_open_timeout => '0',
500                                                         preload_buffer_size => '32768',
501                                                         profiling_history_size => '15',
502                                                         query_alloc_block_size => '8192',
503                                                         query_cache_limit => '1048576',
504                                                         query_cache_min_res_unit => '4096',
505                                                         query_cache_size => '0',
506                                                         query_cache_type => '1',
507                                                         query_cache_wlock_invalidate => 'FALSE',
508                                                         query_prealloc_size => '8192',
509                                                         range_alloc_block_size => '4096',
510                                                         read_buffer_size => '131072',
511                                                         read_only => 'FALSE',
512                                                         read_rnd_buffer_size => '262144',
513                                                         record_buffer => '131072',
514                                                         relay_log => 'mysql-relay-bin',
515                                                         relay_log_index => '',
516                                                         relay_log_info_file => 'relay-log.info',
517                                                         relay_log_purge => 'TRUE',
518                                                         relay_log_space_limit => '0',
519                                                         replicate_same_server_id => 'FALSE',
520                                                         report_host => '127.0.0.1',
521                                                         report_password => '',
522                                                         report_port => '12345',
523                                                         report_user => '',
524                                                         rpl_recovery_rank => '0',
525                                                         safe_user_create => 'FALSE',
526                                                         secure_auth => 'FALSE',
527                                                         secure_file_priv => '',
528                                                         server_id => '12345',
529                                                         show_slave_auth_info => 'FALSE',
530                                                         skip_grant_tables => 'FALSE',
531                                                         skip_slave_start => 'FALSE',
532                                                         slave_compressed_protocol => 'FALSE',
533                                                         slave_load_tmpdir => '/tmp/',
534                                                         slave_net_timeout => '3600',
535                                                         slave_transaction_retries => '10',
536                                                         slow_launch_time => '2',
537                                                         socket => '/tmp/12345/mysql_sandbox12345.sock',
538                                                         sort_buffer_size => '2097144',
539                                                         sporadic_binlog_dump_fail => 'FALSE',
540                                                         sql_mode => 'OFF',
541                                                         ssl => 'FALSE',
542                                                         ssl_ca => '',
543                                                         ssl_capath => '',
544                                                         ssl_cert => '',
545                                                         ssl_cipher => '',
546                                                         ssl_key => '',
547                                                         symbolic_links => 'TRUE',
548                                                         sync_binlog => '0',
549                                                         sync_frm => 'TRUE',
550                                                         sysdate_is_now => 'FALSE',
551                                                         table_cache => '64',
552                                                         table_lock_wait_timeout => '50',
553                                                         tc_heuristic_recover => '',
554                                                         temp_pool => 'TRUE',
555                                                         thread_cache_size => '0',
556                                                         thread_concurrency => '10',
557                                                         thread_stack => '262144',
558                                                         time_format => '',
559                                                         timed_mutexes => 'FALSE',
560                                                         tmp_table_size => '33554432',
561                                                         tmpdir => '',
562                                                         transaction_alloc_block_size => '8192',
563                                                         transaction_prealloc_size => '4096',
564                                                         updatable_views_with_limit => '1',
565                                                         use_symbolic_links => 'TRUE',
566                                                         verbose => 'TRUE',
567                                                         wait_timeout => '28800',
568                                                         warnings => '1'
569                                                      },
570                                                      'mysqldhelp001.txt'
571                                                   );
572                                                   
573            1                                 36   is(
574                                                      $config->get('wait_timeout', offline=>1),
575                                                      28800,
576                                                      'get() from mysqld'
577                                                   );
578                                                   
579            1                                  7   ok(
580                                                      $config->has('wait_timeout'),
581                                                      'has() from mysqld'
582                                                   );
583                                                   
584            1                                  6   ok(
585                                                     !$config->has('foo'),
586                                                     "has(), doesn't have it"
587                                                   );
588                                                   
589                                                   # #############################################################################
590                                                   # Config from SHOW VARIABLES
591                                                   # #############################################################################
592            1                                 13   $config = new MySQLConfig(
593                                                      source              => [ [qw(foo bar)], [qw(a z)] ],
594                                                      TextResultSetParser => $trp,
595                                                   );
596                                                   
597            1                                 58   is(
598                                                      $config->get_type(),
599                                                      'show_variables',
600                                                      "Detect show_variables type (arrayref)"
601                                                   );
602                                                   
603            1                                  6   is_deeply(
604                                                      $config->get_variables(),
605                                                      {
606                                                         foo => 'bar',
607                                                         a   => 'z',
608                                                      },
609                                                      'Variables from arrayref'
610                                                   );
611                                                   
612            1                                 10   is(
613                                                      $config->get('foo'),
614                                                      'bar',
615                                                      'get() from arrayref',
616                                                   );
617                                                   
618            1                                  5   ok(
619                                                      $config->has('foo'),
620                                                      'has() from arrayref',
621                                                   );
622                                                   
623                                                   # #############################################################################
624                                                   # Config from my_print_defaults
625                                                   # #############################################################################
626            1                                 10   $config = new MySQLConfig(
627                                                      source              => "$trunk/$sample/myprintdef001.txt",
628                                                      TextResultSetParser => $trp,
629                                                   );
630                                                   
631            1                                  8   is(
632                                                      $config->get_type(),
633                                                      'my_print_defaults',
634                                                      "Detect my_print_defaults type"
635                                                   );
636                                                   
637            1                                  6   is(
638                                                      $config->get('port', offline=>1),
639                                                      '12349',
640                                                      "Duplicate var's last value used"
641                                                   );
642                                                   
643            1                                  5   is(
644                                                      $config->get('innodb_buffer_pool_size', offline=>1),
645                                                      '16777216',
646                                                      'Converted size char to int'
647                                                   );
648                                                   
649            1                                  5   is_deeply(
650                                                      $config->get_duplicate_variables(),
651                                                      {
652                                                         'port' => [12345],
653                                                      },
654                                                      'get_duplicate_variables()'
655                                                   );
656                                                   
657                                                   # #############################################################################
658                                                   # Config from option file (my.cnf)
659                                                   # #############################################################################
660            1                                 16   $config = new MySQLConfig(
661                                                      source              => "$trunk/$sample/mycnf001.txt",
662                                                      TextResultSetParser => $trp,
663                                                   );
664                                                   
665            1                                 12   is(
666                                                      $config->get_type(),
667                                                      'option_file',
668                                                      "Detect option_file type"
669                                                   );
670                                                   
671   ***      1     50                           6   is_deeply(
672                                                      $config->get_variables(),
673                                                      {
674                                                         'user'                  => 'mysql',
675                                                         'pid_file'              => '/var/run/mysqld/mysqld.pid',
676                                                         'socket'                => '/var/run/mysqld/mysqld.sock',
677                                                         'port'                  => 3306,
678                                                         'basedir'               => '/usr',
679                                                         'datadir'               => '/var/lib/mysql',
680                                                         'tmpdir'		            => '/tmp',
681                                                         'skip_external_locking' => 'ON',
682                                                         'bind_address'		      => '127.0.0.1',
683                                                         'key_buffer'		      => 16777216,
684                                                         'max_allowed_packet'	   => 16777216,
685                                                         'thread_stack'		      => 131072,
686                                                         'thread_cache_size'	   => 8,
687                                                         'myisam_recover'		   => 'BACKUP',
688                                                         'query_cache_limit'     => 1048576,
689                                                         'query_cache_size'      => 16777216,
690                                                         'expire_logs_days'	   => 10,
691                                                         'max_binlog_size'       => 104857600,
692                                                         'skip_federated'        => '',
693                                                      },
694                                                      "Vars from option file"
695                                                   ) or print Dumper($config->get_variables());
696                                                   
697                                                   # #############################################################################
698                                                   # Online test.
699                                                   # #############################################################################
700   ***      1     50                           5   SKIP: {
701            1                                 13      skip 'Cannot connect to sandbox master', 3 unless $dbh;
702                                                   
703            1                                  9      $config = new MySQLConfig(
704                                                         source              => $dbh,
705                                                         TextResultSetParser => $trp,
706                                                      );
707                                                   
708            1                                 12      is(
709                                                         $config->get_type(),
710                                                         "show_variables",
711                                                         "Detect show_variables type (dbh)"
712                                                      );
713                                                   
714            1                                  9      is(
715                                                         $config->get('datadir'),
716                                                         '/tmp/12345/data/',
717                                                         "Vars from dbh"
718                                                      );
719                                                   
720            1                                  7      like(
721                                                         $config->get_mysql_version(),
722                                                         qr/5\.\d+\.\d+/,
723                                                         "MySQL version from dbh"
724                                                      );
725                                                   }
726                                                   
727                                                   # #############################################################################
728                                                   # Done.
729                                                   # #############################################################################
730                                                   {
731            1                                  6      local *STDERR;
               1                                  7   
732            1                    1             2      open STDERR, '>', \$output;
               1                                314   
               1                                  3   
               1                                  7   
733            1                                 20      $config->_d('Complete test coverage');
734                                                   }
735                                                   like(
736            1                                 13      $output,
737                                                      qr/Complete test coverage/,
738                                                      '_d() works'
739                                                   );
740            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}
671   ***     50      0      1   unless is_deeply($config->get_variables, {'user', 'mysql', 'pid_file', '/var/run/mysqld/mysqld.pid', 'socket', '/var/run/mysqld/mysqld.sock', 'port', 3306, 'basedir', '/usr', 'datadir', '/var/lib/mysql', 'tmpdir', '/tmp', 'skip_external_locking', 'ON', 'bind_address', '127.0.0.1', 'key_buffer', 16777216, 'max_allowed_packet', 16777216, 'thread_stack', 131072, 'thread_cache_size', 8, 'myisam_recover', 'BACKUP', 'query_cache_limit', 1048576, 'query_cache_size', 16777216, 'expire_logs_days', 10, 'max_binlog_size', 104857600, 'skip_federated', ''}, 'Vars from option file')
700   ***     50      0      1   unless $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}


Covered Subroutines
-------------------

Subroutine Count Location         
---------- ----- -----------------
BEGIN          1 MySQLConfig.t:10 
BEGIN          1 MySQLConfig.t:11 
BEGIN          1 MySQLConfig.t:12 
BEGIN          1 MySQLConfig.t:14 
BEGIN          1 MySQLConfig.t:15 
BEGIN          1 MySQLConfig.t:16 
BEGIN          1 MySQLConfig.t:17 
BEGIN          1 MySQLConfig.t:18 
BEGIN          1 MySQLConfig.t:24 
BEGIN          1 MySQLConfig.t:4  
BEGIN          1 MySQLConfig.t:732
BEGIN          1 MySQLConfig.t:9  
__ANON__       1 MySQLConfig.t:35 


