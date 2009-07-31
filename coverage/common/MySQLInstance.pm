---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/MySQLInstance.pm   91.7   77.8   65.3   96.3    n/a  100.0   84.4
Total                          91.7   77.8   65.3   96.3    n/a  100.0   84.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLInstance.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:52:57 2009
Finish:       Fri Jul 31 18:52:58 2009

/home/daniel/dev/maatkit/common/MySQLInstance.pm

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
18                                                    # MySQLInstance package $Revision: 3459 $
19                                                    # ###########################################################################
20                                                    package MySQLInstance;
21                                                    
22             1                    1             9   use strict;
               1                                  3   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1            11   use File::Temp ();
               1                                  3   
               1                                  3   
27             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  9   
28                                                    $Data::Dumper::Indent = 1;
29                                                    
30             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
31                                                    
32                                                    my $option_pattern = '([^\s=]+)(?:=(\S+))?';
33                                                    
34                                                    # SHOW GLOBAL VARIABLES dialect => mysqld --help --verbose dialect
35                                                    my %alias_for = (
36                                                       ON   => 'TRUE',
37                                                       OFF  => 'FALSE',
38                                                       YES  => '1',
39                                                       NO   => '0',
40                                                    );
41                                                    
42                                                    # Many vars can have undefined values which, unless we always check,
43                                                    # will cause Perl errors. Therefore, for certain vars an undefined
44                                                    # value means something specific, as seen in the hash below. Otherwise,
45                                                    # a blank string is used in place of an undefined value.
46                                                    my %undef_for = (
47                                                       'log'                         => 'OFF',
48                                                       log_bin                       => 'OFF',
49                                                       log_slow_queries              => 'OFF',
50                                                       log_slave_updates             => 'ON',
51                                                       log_queries_not_using_indexes => 'ON',
52                                                       log_update                    => 'OFF',
53                                                       skip_bdb                      => 0,
54                                                       skip_external_locking         => 'ON',
55                                                       skip_name_resolve             => 'ON',
56                                                    );
57                                                    
58                                                    # About these sys vars the MySQL manual says: "This variable is unused."
59                                                    # Or, they're simply vars we don't care about.
60                                                    # They're currently only ignored in out_of_sync_sys_vars().
61                                                    my %ignore_sys_var = (
62                                                       date_format     => 1,
63                                                       datetime_format => 1,
64                                                       time_format     => 1,
65                                                    );
66                                                    
67                                                    # Certain sys vars vary so much in their online vs. conf value that we
68                                                    # must specially check their equality, otherwise out_of_sync_sys_vars()
69                                                    # reports a number of false-positives.
70                                                    # TODO: These need to be tested more thoroughly. Some will want to check
71                                                    #       ON/1 as well as OFF/0, etc.
72                                                    my %eq_for = (
73                                                       ft_stopword_file          => sub { return _veq(@_, '(built-in)', ''); },
74                                                       query_cache_type          => sub { return _veq(@_, 'ON', '1');        },
75                                                       ssl                       => sub { return _veq(@_, '1', 'TRUE');      },
76                                                       sql_mode                  => sub { return _veq(@_, '', 'OFF');        },
77                                                    
78                                                       basedir                   => sub { return _patheq(@_);                },
79                                                       language                  => sub { return _patheq(@_);                },
80                                                    
81                                                       log_bin                   => sub { return _eqifon(@_);                },
82                                                       log_slow_queries          => sub { return _eqifon(@_);                },
83                                                    
84                                                       general_log_file          => sub { return _eqifconfundef(@_);         },
85                                                       innodb_data_file_path     => sub { return _eqifconfundef(@_);         },
86                                                       innodb_log_group_home_dir => sub { return _eqifconfundef(@_);         },
87                                                       log_error                 => sub { return _eqifconfundef(@_);         },
88                                                       open_files_limit          => sub { return _eqifconfundef(@_);         },
89                                                       slow_query_log_file       => sub { return _eqifconfundef(@_);         },
90                                                       tmpdir                    => sub { return _eqifconfundef(@_);         },
91                                                    
92                                                       long_query_time           => sub { return _numericeq(@_);             },
93                                                    );
94                                                    
95                                                    # Certain sys vars can be given multiple times in the defaults file.
96                                                    # Therefore, they are exceptions to duplicate checking.
97                                                    # See http://dev.mysql.com/doc/refman/5.0/en/replication-options-slave.html
98                                                    my %can_be_duplicate = (
99                                                       replicate_wild_do_table     => 1,
100                                                      replicate_wild_ignore_table => 1,
101                                                      replicate_rewrite_db        => 1,
102                                                      replicate_ignore_table      => 1,
103                                                      replicate_ignore_db         => 1,
104                                                      replicate_do_table          => 1,
105                                                      replicate_do_db             => 1,
106                                                   );
107                                                   
108                                                   # Returns an array ref of hashes. Each hash represents a single mysqld process.
109                                                   # The cmd key val is suitable for passing to MySQLInstance::new().
110                                                   sub mysqld_processes
111                                                   {
112            2                    2            47      my ( $ps_output ) = @_;
113            2                                  9      my @mysqld_processes;
114            2                                 12      my $cmd = 'ps -o euser,%cpu,rss,vsz,cmd -e | grep -v grep | grep mysql';
115   ***      2     50                          13      my $ps  = defined $ps_output ? $ps_output : `$cmd`;
116   ***      2     50                          14      if ( $ps ) {
117            2                                  6         MKDEBUG && _d('ps full output:', $ps);
118            2                                 25         foreach my $line ( split("\n", $ps) ) {
119           25                                 79            MKDEBUG && _d('ps line:', $line);
120           25                                253            my ($user, $pcpu, $rss, $vsz, $cmd) = split(/\s+/, $line, 5);
121           25                                155            my $bin = find_mysqld_binary_unix($cmd);
122           25    100                         106            if ( !$bin ) {
123           19                                 46               MKDEBUG && _d('No mysqld binary in ps line');
124           19                                 69               next;
125                                                            }
126            6                                 16            MKDEBUG && _d('mysqld binary from ps:', $bin);
127            6    100                       17191            push @mysqld_processes,
                    100                               
128                                                               { user    => $user,
129                                                                 pcpu    => $pcpu,
130                                                                 rss     => $rss,
131                                                                 vsz     => $vsz,
132                                                                 cmd     => $cmd,
133                                                                 # TODO: this is untestable.  We need to make a callback to get the
134                                                                 # output of "file" for this.
135                                                                 '64bit' => `file $bin` =~ m/64-bit/ ? 'Yes' : 'No',
136                                                                 syslog  => $ps =~ m/logger/ ? 'Yes' : 'No',
137                                                               };
138                                                         }
139                                                      }
140            2                                 46      MKDEBUG && _d('mysqld processes:', Dumper(\@mysqld_processes));
141            2                                 46      return \@mysqld_processes;
142                                                   }
143                                                   
144                                                   sub new {
145           11                   11           248      my ( $class, $cmd ) = @_;
146           11                                 40      my $self = {};
147           11                                 25      MKDEBUG && _d('cmd:', $cmd);
148           11    100                          58      $self->{mysqld_binary} = find_mysqld_binary_unix($cmd)
149                                                         or die "No mysqld binary found in $cmd";
150           10                              28648      my $file_output  = `file $self->{mysqld_binary} 2>&1`;
151           10                                237      $self->{regsize} = get_register_size($file_output);
152           10                                284      %{ $self->{cmd_line_ops} }
              76                                650   
153                                                         = map {
154           10                                231              my ( $var, $val ) = m/$option_pattern/o;
155           76                                304              $var =~ s/-/_/go;
156           76           100                  313              $val ||= $undef_for{$var} || '';
                           100                        
157           76                                297              $var => $val;
158                                                           } ($cmd =~ m/--(\S+)/g);
159           10           100                   88      $self->{cmd_line_ops}->{defaults_file} ||= '';
160           10                                 45      $self->{conf_sys_vars}   = {};
161           10                                 42      $self->{online_sys_vars} = {};
162           10                                 24      MKDEBUG && _d('new MySQLInstance:', Dumper($self));
163           10                                210      return bless $self, $class;
164                                                   }
165                                                   
166                                                   # Extracts the register size (64-bit, 32-bit, ???) from the output of 'file'.
167                                                   sub get_register_size {
168           12                   12           152      my ( $file_output ) = @_;
169           12                                286      my ( $size ) = $file_output =~ m/\b(\d+)-bit/;
170           12           100                  191      return $size || 0;
171                                                   }
172                                                   
173                                                   sub find_mysqld_binary_unix {
174           39                   39           279      my ( $cmd ) = @_;
175           39                                413      my ( $binary ) = $cmd =~ m/(\S+mysqld)\b(?=\s|\Z)/;
176           39           100                  380      return $binary || '';
177                                                   }
178                                                   
179                                                   sub load_sys_vars {
180            2                    2            62      my ( $self, $dbh ) = @_;
181                                                   
182                                                      # This happens frequently enough in the real world to merit
183                                                      # its own perma-message that we may reuse in various places.
184            2                                  9      my $mysqld_broken_msg
185                                                         = "The mysqld binary may be broken. "
186                                                         . "Try manually running the command above.\n"
187                                                         . "Information about system variables from the defaults file "
188                                                         . "will not be available.\n";
189                                                   
190                                                      # Sys vars and defaults according to mysqld (if possible; see issue 135).
191            2                                 13      my ( $defaults_file_op, $tmp_file ) = $self->_defaults_file_op();
192            2                                 17      my $cmd = "$self->{mysqld_binary} $defaults_file_op --help --verbose";
193            2                                  5      MKDEBUG && _d('Getting sys vars from mysqld:', $cmd);
194            2                              10139      my $retval = system("$cmd 1>/dev/null 2>/dev/null");
195            2                                 27      $retval = $retval >> 8;
196   ***      2     50                          35      if ( $retval != 0 ) {
197   ***      0                                  0         MKDEBUG && _d('self dump:', Dumper($self));
198   ***      0                                  0         warn "Cannot execute $cmd\n" . $mysqld_broken_msg;
199                                                      }
200                                                      else {
201            2    100                       10256         if ( my $mysqld_output = `$cmd` ) {
202                                                            # Parse from mysqld output the list of sys vars and their
203                                                            # default values listed at the end after all the help info.
204            1                                225            my ($sys_vars) = $mysqld_output =~ m/---\n(.*?)\n\n/ms;
205            1                                351            %{ $self->{conf_sys_vars} }
             258                               1441   
206                                                               = map {
207            1                                 75                    my ( $var, $val ) = m/^(\S+)\s+(?:(\S+))?/;
208          258                                909                    $var =~ s/-/_/go;
209          258    100    100                 1811                    if ( $val && $val =~ m/\(No/ ) { # (No default value)
210           36                                 96                       $val = undef;
211                                                                    }
212          258           100                 1083                    $val ||= $undef_for{$var} || '';
                           100                        
213          258                                935                    $var => $val;
214                                                                 } split "\n", $sys_vars;
215                                                   
216                                                            # Parse list of default defaults files. These are the defaults
217                                                            # files that mysqld and my_print_defaults read (in order) if not
218                                                            # explicitly given a --defaults-file option. Regarding issue 58,
219                                                            # this list can have duplicates, which we must remove. Otherwise,
220                                                            # my_print_defaults will print false duplicates because it reads
221                                                            # the same file twice.
222            1                                 85            $self->_load_default_defaults_files($mysqld_output);
223                                                         }
224                                                         else {
225            1                                 10            warn "MySQL returned no information by running $cmd\n"
226                                                               . $mysqld_broken_msg;
227                                                         }
228                                                      }
229                                                   
230                                                      # Sys vars from SHOW STATUS
231            2                                 40      $self->_load_online_sys_vars($dbh);
232                                                   
233                                                      # Sys vars from defaults file
234                                                      # These are used later by duplicate_values() and overriden_values().
235                                                      # These are also necessary for vars like skip-name-resolve which are not
236                                                      # shown in either SHOW VARIABLES or mysqld --help --verbose but are need
237                                                      # for checks in MySQLAdvisor. 
238            2                                 18      $self->{defaults_files_sys_vars}
239                                                         = $self->_vars_from_defaults_file($defaults_file_op); 
240            2                                  9      foreach my $var_val ( reverse @{ $self->{defaults_file_sys_vars} } ) {
               2                                 18   
241           44                                186         my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
242           44    100                         216         if ( !exists $self->{conf_sys_vars}->{$var} ) {
243           22                                147            $self->{conf_sys_vars}->{$var} = $val;
244                                                         }
245           44    100                         268         if ( !exists $self->{online_sys_vars}->{$var} ) {
246            4                                 22            $self->{online_sys_vars}->{$var} = $val;
247                                                         }
248                                                      }
249                                                   
250            2                                 16      return;
251                                                   }
252                                                   
253                                                   # Returns a --defaults-file cmd line op suitable for mysqld, my_print_defaults,
254                                                   # etc., or a blank string if the defaults file is unknown.
255                                                   sub _defaults_file_op {
256            2                    2             9      my ( $self, $ddf )   = @_;  # ddf = default defaults file (optional)
257            2                                  8      my $defaults_file_op = '';
258            2                                  6      my $tmp_file         = undef;
259   ***      2     50                          12      my $defaults_file    = defined $ddf ? $ddf
260                                                                           : $self->{cmd_line_ops}->{defaults_file};
261                                                   
262   ***      2     50     33                   51      if ( $defaults_file && -f $defaults_file ) {
263                                                         # Copy defaults file to /tmp/ because Debian/Ubuntu mysqld apparently
264                                                         # has a bug which prevents it from being read from non-standard
265                                                         # locations.
266            2                                 45         $tmp_file = File::Temp->new();
267            2                                 23         my $cp_cmd = "cp $defaults_file "
268                                                                    . $tmp_file->filename;
269            2                               7069         `$cp_cmd`;
270            2                                 79         $defaults_file_op = "--defaults-file=" . $tmp_file->filename;
271                                                   
272            2                                 14         MKDEBUG && _d('Tmp file for defaults file', $defaults_file, ':',
273                                                            $tmp_file->filename);
274                                                      }
275                                                      else {
276   ***      0                                  0         MKDEBUG && _d('Defaults file does not exist:', $defaults_file);
277                                                      }
278                                                   
279                                                      # Must return $tmp_file obj so its reference lasts into the caller because
280                                                      # when it's destroyed the actual tmp file is automatically unlinked 
281            2                                 36      return ( $defaults_file_op, $tmp_file );
282                                                   }
283                                                   
284                                                   # Loads $self->{default_defaults_files} with the list of default defaults files
285                                                   # read by mysqld, my_print_defaults, etc. with duplicates removed when no
286                                                   # explicit --defaults-file option is given. Order is preserved (and important).
287                                                   sub _load_default_defaults_files {
288            2                    2           156      my ( $self, $mysqld_output ) = @_;
289            2                                551      my ( $ddf_list ) = $mysqld_output =~ /Default options.+order:\n(.*?)\n/ms;
290   ***      2     50                          11      if ( !$ddf_list ) {
291                                                         # TODO: change to warn and try to continue
292   ***      0                                  0         die "Cannot parse default defaults files: $mysqld_output\n";
293                                                      }
294            2                                  5      MKDEBUG && _d('List of default defaults files:', $ddf_list);
295            2                                  5      my %have_seen;
296            2                                 16      @{ $self->{default_defaults_files} }
               6                                 35   
297            2                                 23         = grep { !$have_seen{$_}++ } split /\s/, $ddf_list;
298            2                                 22      return;
299                                                   }
300                                                   
301                                                   # Loads $self->{default_files_sys_vars} with only the sys vars that
302                                                   # are explicitly set in the defaults file. This is used for detecting
303                                                   # duplicates and overriden var/vals.
304                                                   sub _vars_from_defaults_file {
305            4                    4            46      my ( $self, $defaults_file_op, $my_print_defaults ) = @_;
306                                                   
307                                                      # Check first that my_print_defaults can be executed.
308                                                      # If not, we must die because we will not be able to do anything else.
309                                                      # TODO: change to warn and try to continue
310            4           100                   46      my $my_print_defaults_cmd = $my_print_defaults || 'my_print_defaults';
311            4                              13188      my $retval = system("$my_print_defaults_cmd --help 1>/dev/null 2>/dev/null");
312            4                                 40      $retval = $retval >> 8;
313            4    100                          55      if ( $retval != 0 ) {
314            1                                 12         MKDEBUG && _d('self dump:', Dumper($self));
315            1                                 10         die "Cannot execute my_print_defaults command '$my_print_defaults_cmd'";
316                                                      }
317                                                   
318            3                                 14      my @defaults_file_ops;
319            3                                  9      my @ddf_ops;
320                                                   
321            3    100                          47      if( !$defaults_file_op ) {
322                                                         # Having no defaults file op, my_print_defaults is going to rely
323                                                         # on the default defaults files reported by mysqld --help --verbose,
324                                                         # which we should have already saved in $self->{default_defaults_files}.
325                                                         # Due to issue 58, we must use the defaults files from our own list
326                                                         # which is free of duplicates.
327                                                   
328            1                                 18         foreach my $ddf ( @{ $self->{default_defaults_files} } ) {
               1                                 29   
329   ***      0                                  0            my @dfo = $self->_defaults_file_op($ddf);
330   ***      0      0                           0            if ( defined $dfo[1] ) { # tmp_file handle
331   ***      0                                  0               push @ddf_ops, [ @dfo ];
332   ***      0                                  0               push @defaults_file_ops, $dfo[0]; # defaults file op
333                                                            }
334                                                         }
335                                                      }
336                                                      else {
337            2                                 29         $defaults_file_ops[0] = $defaults_file_op;
338                                                      }
339                                                   
340            3    100                          32      if ( scalar @defaults_file_ops == 0 ) {
341                                                         # This would be a rare case in which the mysqld binary was not
342                                                         # given a --defaults-file opt, and none of the default defaults
343                                                         # files parsed from mysqld --help --verbose exist.
344            1                                 10         MKDEBUG && _d('self dump:', Dumper($self));
345                                                         # TODO: change to warn and try to continue
346            1                                  9         die 'MySQL instance has no valid defaults files.'
347                                                      }
348                                                   
349            2                                 21      foreach my $defaults_file_op ( @defaults_file_ops ) {
350            2                                 16         my $cmd = "$my_print_defaults_cmd $defaults_file_op mysqld";
351            2                                  6         MKDEBUG && _d('my_print_defaults cmd:', $cmd);
352   ***      2     50                        5902         if ( my $my_print_defaults_output = `$cmd` ) {
353            2                                 63            foreach my $var_val ( split "\n", $my_print_defaults_output ) {
354                                                               # Make sys vars from conf look like those from SHOW VARIABLES
355                                                               # (I.e. log_slow_queries instead of log-slow-queries
356                                                               # and 33554432 instead of 32M, etc.)
357           44                                400               my ( $var, $val ) = $var_val =~ m/^--$option_pattern/o;
358           44                                170               $var =~ s/-/_/go;
359                                                               # TODO: this can be more compact ( $digits_for{lc $2} )
360                                                               # and shouldn't use $1, $2
361                                                               # And I think %digits_for should go in Transformers and that
362                                                               # Transformers should be both an obj/class and simple exported
363                                                               # subs, like File::Temp, for maximal flexibility and because
364                                                               # I think it would be cool. :-)
365           44    100    100                  418               if ( defined $val && $val =~ /(\d+)([kKmMgGtT]?)/) {
366           34    100                         161                  if ( $2 ) {
367            4                                 66                     my %digits_for = (
368                                                                        'k'   => 1_024,
369                                                                        'K'   => 1_204,
370                                                                        'm'   => 1_048_576,
371                                                                        'M'   => 1_048_576,
372                                                                        'g'   => 1_073_741_824,
373                                                                        'G'   => 1_073_741_824,
374                                                                        't'   => 1_099_511_627_776,
375                                                                        'T'   => 1_099_511_627_776,
376                                                                     );
377            4                                 47                     $val = $1 * $digits_for{$2};
378                                                                  }
379                                                               }
380   ***     44            50                  176               $val ||= $undef_for{$var} || '';
                           100                        
381           44                                106               push @{ $self->{defaults_file_sys_vars} }, [ $var, $val ];
              44                                293   
382                                                            }
383                                                         }
384                                                      }
385            2                                 40      return;
386                                                   }
387                                                   
388                                                   sub _load_online_sys_vars {
389            2                    2            16      my ( $self, $dbh ) = @_;
390            2                                572      %{ $self->{online_sys_vars} }
             480                               2228   
391            2                                113         = map { $_->{Variable_name} => $_->{Value} }
392            2                                  8               @{ $dbh->selectall_arrayref('SHOW /*!40101 GLOBAL*/ VARIABLES',
393                                                                                           { Slice => {} })
394                                                               };
395            2                                254      return;
396                                                   }
397                                                   
398                                                   # Get DSN specific to this MySQL instance.  If $opts{S} is passed in, which
399                                                   # corresponds to --socket on the command line, then don't convert 'localhost'
400                                                   # to 127.0.0.1.
401                                                   sub get_DSN {
402            6                    6           391      my ( $self, $o ) = @_;
403   ***      6     50                          53      die 'I need an OptionParser object' unless ref $o eq 'OptionParser';
404   ***      6            50                   55      my $port   = $self->{cmd_line_ops}->{port} || '';
405   ***      6            66                   73      my $socket = $o->get('socket') || $self->{cmd_line_ops}->{'socket'} || '';
      ***                   50                        
406            6    100                          30      my $host   = $o->get('socket') ? 'localhost'
                    100                               
407                                                                 : $port ne 3306     ? '127.0.0.1'
408                                                                 :                   'localhost';
409                                                      return {
410            6                                 75         P => $port,
411                                                         S => $socket,
412                                                         h => $host,
413                                                      };
414                                                   }
415                                                   
416                                                   # duplicate_sys_vars() returns an array ref of sys var names that
417                                                   # appear more than once in the defaults file
418                                                   sub duplicate_sys_vars {
419            2                    2            55      my ( $self ) = @_;
420            2                                  5      my @duplicate_vars;
421            2                                  5      my %have_seen;
422            2                                  7      foreach my $var_val ( @{ $self->{defaults_file_sys_vars} } ) {
               2                                  9   
423           36                                159         my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
424           36    100                         151         next if $can_be_duplicate{$var};
425           22    100                         121         push @duplicate_vars, $var if $have_seen{$var}++ == 1;
426                                                      }
427            2                                 16      return \@duplicate_vars;
428                                                   }
429                                                   
430                                                   # overriden_sys_vars() returns a hash ref of overriden sys vars:
431                                                   #    key   = sys var that is overriden
432                                                   #    value = array [ val being used, val overriden ]
433                                                   sub overriden_sys_vars {
434            1                    1            16      my ( $self ) = @_;
435            1                                  3      my %overriden_vars;
436            1                                  3      foreach my $var_val ( @{ $self->{defaults_file_sys_vars} } ) {
               1                                  6   
437           22                                101         my ( $var, $val ) = ( $var_val->[0], $var_val->[1] );
438   ***     22     50     33                  169         if ( !defined $var || !defined $val ) {
439   ***      0                                  0            MKDEBUG && _d('Undefined var or val:', Dumper($var_val));
440   ***      0                                  0            next;
441                                                         }
442           22    100                         100         if ( exists $self->{cmd_line_ops}->{$var} ) {
443   ***      8    100     33                   90            if(    ( !defined $self->{cmd_line_ops}->{$var} && !defined $val)
      ***                   66                        
444                                                                || ( $self->{cmd_line_ops}->{$var} ne $val) ) {
445            2                                 13               $overriden_vars{$var} = [ $self->{cmd_line_ops}->{$var}, $val ];
446                                                            }
447                                                         }
448                                                      }
449            1                                  5      return \%overriden_vars;
450                                                   }
451                                                   
452                                                   # out_of_sync_sys_vars() returns a hash ref of sys vars that differ in their
453                                                   # online vs. config values:
454                                                   #    {
455                                                   #       out of sync sys var => {
456                                                   #          online => val,
457                                                   #          config => val,
458                                                   #       },
459                                                   #       etc.
460                                                   #    }
461                                                   sub out_of_sync_sys_vars {
462            3                    3           319      my ( $self ) = @_;
463            3                                 17      my %out_of_sync_vars;
464                                                   
465            3                                 97      VAR:
466            3                                 13      foreach my $var ( keys %{ $self->{conf_sys_vars} } ) {
467          259    100                         906         next VAR if exists $ignore_sys_var{$var};
468          256    100                        1116         next VAR unless exists $self->{online_sys_vars}->{$var};
469                                                   
470          183                                633         my $conf_val        = $self->{conf_sys_vars}->{$var};
471          183                                620         my $online_val      = $self->{online_sys_vars}->{$var};
472          183                                439         my $var_out_of_sync = 0;
473                                                   
474                                                         # TODO: try this on a server with skip_grant_tables set, it crashes on
475                                                         # me in a not-friendly way.  Probably ought to use eval {} and catch
476                                                         # error.
477                                                   
478                                                         # If one var has a value and that value isn't equal to the
479                                                         # other var's value, then they're out of sync. However, if
480                                                         # both vars are valueless (0, '0', or ''), then they are
481                                                         # in sync--this prevents 0 and '' being treated as out of sync.
482          183    100    100                 1518         if ( ($conf_val || $online_val) && ($conf_val ne $online_val) ) {
                           100                        
483           41                                 97            $var_out_of_sync = 1;
484                                                   
485                                                            # Try some exceptions, cases like where ON and TRUE are the
486                                                            # same to us but not to Perl.
487           41    100                        1105            if ( exists $eq_for{$var} ) {
488                                                               # If they're equal then they're not (!) out of sync
489            9                                 54               $var_out_of_sync = !$eq_for{$var}->($conf_val, $online_val);
490                                                            }
491           41    100                         160            if ( exists $alias_for{$online_val} ) {
492           34    100                         154               $var_out_of_sync = 0 if $conf_val eq $alias_for{$online_val};
493                                                            }
494                                                         }
495                                                   
496          183    100                         666         if ( $var_out_of_sync ) {
497            2                                 18            $out_of_sync_vars{$var} = { online=>$online_val, config=>$conf_val };
498                                                         }
499                                                      }
500                                                   
501            3                                 33      return \%out_of_sync_vars;
502                                                   }
503                                                   
504                                                   sub load_status_vals {
505            1                    1            17      my ( $self, $dbh ) = @_;
506            1                                293      %{ $self->{status_vals} }
             253                               1109   
507            1                                 21         = map { $_->{Variable_name} => $_->{Value} }
508            1                                  4               @{ $dbh->selectall_arrayref('SHOW /*!50002 GLOBAL */ STATUS',
509                                                                                           { Slice => {} })
510                                                               };
511            1                                125      return;
512                                                   }
513                                                   
514                                                   sub get_eq_for {
515            5                    5            25      my ( $var ) = @_;
516   ***      5     50                          23      if ( exists $eq_for{$var} ) {
517            5                                 23         return $eq_for{$var};
518                                                      }
519   ***      0                                  0      return;
520                                                   }
521                                                   
522                                                   # variable eq: returns true if x and y equal each other
523                                                   # where x and y can be either val1 or val2.
524                                                   sub _veq { 
525            5                    5            28      my ( $x, $y, $val1, $val2 ) = @_;
526   ***      5     50     33                   91      return 1 if ( ($x eq $val1 || $x eq $val2) && ($y eq $val1 || $y eq $val2) );
      ***                   33                        
      ***                   33                        
527   ***      0                                  0      return 0;
528                                                   }
529                                                   
530                                                   # path eq: returns true if x and y are directory paths that differ
531                                                   # only by a trailing /.
532                                                   sub _patheq {
533            2                    2            11      my ( $x, $y ) = @_;
534   ***      2     50                          16      $x .= '/' if $x !~ m/\/$/;
535   ***      2     50                          11      $y .= '/' if $y !~ m/\/$/;
536            2                                 10      return $x eq $y;
537                                                   }
538                                                   
539                                                   # eq if ON: returns true if either x or y is ON and the other value
540                                                   # is any value.
541                                                   sub _eqifon { 
542            2                    2            10      my ( $x, $y ) = @_;
543   ***      2     50     33                   24      return 1 if ( $x && $x eq 'ON' && $y );
      ***                   33                        
544   ***      2     50     33                   33      return 1 if ( $y && $y eq 'ON' && $x );
      ***                   33                        
545   ***      0                                  0      return 0;
546                                                   }
547                                                   
548                                                   # eq if config value is undefined (''): returns true if the config value
549                                                   # is undefined because for certain vars and undefined conf val results
550                                                   # in the online value showing the built-in default val. These vals, then,
551                                                   # are not technically out-of-sync.
552                                                   sub _eqifconfundef {
553            3                    3            13      my ( $conf_val, $online_val ) = @_;
554   ***      3     50                          18      return ($conf_val eq '' ? 1 : 0);
555                                                   }
556                                                   
557                                                   # numeric eq: returns true if the two vals are numerically eq. A string
558                                                   # eq test works for most cases, even numbers, except when decimal precision
559                                                   # becomes an issue. long_query_time, for example, can be set to 2.2 in the
560                                                   # config file, but the online value shows its full precision as 2.200000.
561                                                   # Thus, a string eq incorrectly fails.
562                                                   sub _numericeq {
563            2                    2            11      my ( $x, $y ) = @_;
564            2    100                          21      return ($x == $y ? 1 : 0);
565                                                   }
566                                                   
567                                                   sub _d {
568   ***      0                    0                    my ($package, undef, $line) = caller 0;
569   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
570   ***      0                                              map { defined $_ ? $_ : 'undef' }
571                                                           @_;
572   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
573                                                   }
574                                                   
575                                                   1;
576                                                   
577                                                   # ###########################################################################
578                                                   # End MySQLInstance package
579                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
115   ***     50      2      0   defined $ps_output ? :
116   ***     50      2      0   if ($ps)
122          100     19      6   if (not $bin)
127          100      5      1   `file $bin` =~ /64-bit/ ? :
             100      5      1   $ps =~ /logger/ ? :
148          100      1     10   unless $$self{'mysqld_binary'} = find_mysqld_binary_unix($cmd)
196   ***     50      0      2   if ($retval != 0) { }
201          100      1      1   if (my $mysqld_output = `$cmd`) { }
209          100     36    222   if ($val and $val =~ /\(No/)
242          100     22     22   if (not exists $$self{'conf_sys_vars'}{$var})
245          100      4     40   if (not exists $$self{'online_sys_vars'}{$var})
259   ***     50      0      2   defined $ddf ? :
262   ***     50      2      0   if ($defaults_file and -f $defaults_file) { }
290   ***     50      0      2   if (not $ddf_list)
313          100      1      3   if ($retval != 0)
321          100      1      2   if (not $defaults_file_op) { }
330   ***      0      0      0   if (defined $dfo[1])
340          100      1      2   if (scalar @defaults_file_ops == 0)
352   ***     50      2      0   if (my $my_print_defaults_output = `$cmd`)
365          100     34     10   if (defined $val and $val =~ /(\d+)([kKmMgGtT]?)/)
366          100      4     30   if ($2)
403   ***     50      0      6   unless ref $o eq 'OptionParser'
406          100      4      1   $port ne 3306 ? :
             100      1      5   $o->get('socket') ? :
424          100     14     22   if $can_be_duplicate{$var}
425          100      2     20   if $have_seen{$var}++ == 1
438   ***     50      0     22   if (not defined $var or not defined $val)
442          100      8     14   if (exists $$self{'cmd_line_ops'}{$var})
443          100      2      6   if (not defined $$self{'cmd_line_ops'}{$var} and not defined $val or $$self{'cmd_line_ops'}{$var} ne $val)
467          100      3    256   if exists $ignore_sys_var{$var}
468          100     73    183   unless exists $$self{'online_sys_vars'}{$var}
482          100     41    142   if ($conf_val || $online_val and $conf_val ne $online_val)
487          100      9     32   if (exists $eq_for{$var})
491          100     34      7   if (exists $alias_for{$online_val})
492          100     31      3   if $conf_val eq $alias_for{$online_val}
496          100      2    181   if ($var_out_of_sync)
516   ***     50      5      0   if (exists $eq_for{$var})
526   ***     50      5      0   if $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
534   ***     50      2      0   if not $x =~ m[/$]
535   ***     50      0      2   if not $y =~ m[/$]
543   ***     50      0      2   if $x and $x eq 'ON' and $y
544   ***     50      2      0   if $y and $y eq 'ON' and $x
554   ***     50      3      0   $conf_val eq '' ? :
564          100      1      1   $x == $y ? :
569   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
209          100     26    196     36   $val and $val =~ /\(No/
262   ***     33      0      0      2   $defaults_file and -f $defaults_file
365          100      4      6     34   defined $val and $val =~ /(\d+)([kKmMgGtT]?)/
443   ***     33      8      0      0   not defined $$self{'cmd_line_ops'}{$var} and not defined $val
482          100     33    109     41   $conf_val || $online_val and $conf_val ne $online_val
526   ***     33      0      0      5   $x eq $val1 || $x eq $val2 and $y eq $val1 || $y eq $val2
543   ***     33      0      2      0   $x and $x eq 'ON'
      ***     33      2      0      0   $x and $x eq 'ON' and $y
544   ***     33      0      0      2   $y and $y eq 'ON'
      ***     33      0      0      2   $y and $y eq 'ON' and $x

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
156          100      9      1   $undef_for{$var} || ''
             100     66     10   $val ||= $undef_for{$var} || ''
159          100      8      2   $$self{'cmd_line_ops'}{'defaults_file'} ||= ''
170          100     10      2   $size || 0
176          100     18     21   $binary || ''
212          100      2     60   $undef_for{$var} || ''
             100    196     62   $val ||= $undef_for{$var} || ''
310          100      1      3   $my_print_defaults || 'my_print_defaults'
380   ***     50      4      0   $undef_for{$var} || ''
             100     40      4   $val ||= $undef_for{$var} || ''
404   ***     50      6      0   $$self{'cmd_line_ops'}{'port'} || ''
405   ***     50      6      0   $o->get('socket') || $$self{'cmd_line_ops'}{'socket'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
405   ***     66      1      5      0   $o->get('socket') || $$self{'cmd_line_ops'}{'socket'}
438   ***     33      0      0     22   not defined $var or not defined $val
443   ***     66      0      2      6   not defined $$self{'cmd_line_ops'}{$var} and not defined $val or $$self{'cmd_line_ops'}{$var} ne $val
482          100    147      3     33   $conf_val || $online_val
526   ***     33      0      5      0   $x eq $val1 || $x eq $val2
      ***     33      5      0      0   $y eq $val1 || $y eq $val2


Covered Subroutines
-------------------

Subroutine                   Count Location                                            
---------------------------- ----- ----------------------------------------------------
BEGIN                            1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:22 
BEGIN                            1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:23 
BEGIN                            1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:25 
BEGIN                            1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:26 
BEGIN                            1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:27 
BEGIN                            1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:30 
_defaults_file_op                2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:256
_eqifconfundef                   3 /home/daniel/dev/maatkit/common/MySQLInstance.pm:553
_eqifon                          2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:542
_load_default_defaults_files     2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:288
_load_online_sys_vars            2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:389
_numericeq                       2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:563
_patheq                          2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:533
_vars_from_defaults_file         4 /home/daniel/dev/maatkit/common/MySQLInstance.pm:305
_veq                             5 /home/daniel/dev/maatkit/common/MySQLInstance.pm:525
duplicate_sys_vars               2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:419
find_mysqld_binary_unix         39 /home/daniel/dev/maatkit/common/MySQLInstance.pm:174
get_DSN                          6 /home/daniel/dev/maatkit/common/MySQLInstance.pm:402
get_eq_for                       5 /home/daniel/dev/maatkit/common/MySQLInstance.pm:515
get_register_size               12 /home/daniel/dev/maatkit/common/MySQLInstance.pm:168
load_status_vals                 1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:505
load_sys_vars                    2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:180
mysqld_processes                 2 /home/daniel/dev/maatkit/common/MySQLInstance.pm:112
new                             11 /home/daniel/dev/maatkit/common/MySQLInstance.pm:145
out_of_sync_sys_vars             3 /home/daniel/dev/maatkit/common/MySQLInstance.pm:462
overriden_sys_vars               1 /home/daniel/dev/maatkit/common/MySQLInstance.pm:434

Uncovered Subroutines
---------------------

Subroutine                   Count Location                                            
---------------------------- ----- ----------------------------------------------------
_d                               0 /home/daniel/dev/maatkit/common/MySQLInstance.pm:568


