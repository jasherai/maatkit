---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/DSNParser.pm   78.0   65.5   50.9   73.7    0.0    0.2   67.9
DSNParser.t                   100.0   50.0   33.3  100.0    n/a   99.8   93.6
Total                          85.7   63.5   50.0   82.8    0.0  100.0   74.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:39 2010
Finish:       Thu Jun 24 19:32:39 2010

Run:          DSNParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:41 2010
Finish:       Thu Jun 24 19:32:48 2010

/home/daniel/dev/maatkit/common/DSNParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2010 Baron Schwartz.
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
18                                                    # DSNParser package $Revision: 6366 $
19                                                    # ###########################################################################
20                                                    package DSNParser;
21                                                    
22             1                    1             4   use strict;
               1                                  2   
               1                                  9   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  6   
               1                                  8   
25             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  8   
26                                                    $Data::Dumper::Indent    = 0;
27                                                    $Data::Dumper::Quotekeys = 0;
28                                                    
29                                                    eval {
30                                                       require DBI;
31                                                    };
32                                                    my $have_dbi = $EVAL_ERROR ? 0 : 1;
33                                                    
34    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 18   
35                                                    
36                                                    sub new {
37    ***      3                    3      0     20      my ( $class, %args ) = @_;
38             3                                 14      foreach my $arg ( qw(opts) ) {
39    ***      3     50                          20         die "I need a $arg argument" unless $args{$arg};
40                                                       }
41             3                                 15      my $self = {
42                                                          opts => {}  # h, P, u, etc.  Should come from DSN OPTIONS section in POD.
43                                                       };
44             3                                 20      foreach my $opt ( @{$args{opts}} ) {
               3                                 13   
45    ***     26     50     33                  229         if ( !$opt->{key} || !$opt->{desc} ) {
46    ***      0                                  0            die "Invalid DSN option: ", Dumper($opt);
47                                                          }
48                                                          MKDEBUG && _d('DSN option:',
49                                                             join(', ',
50            26                                 54               map { "$_=" . (defined $opt->{$_} ? ($opt->{$_} || '') : 'undef') }
51                                                                   keys %$opt
52                                                             )
53                                                          );
54            26           100                  252         $self->{opts}->{$opt->{key}} = {
55                                                             dsn  => $opt->{dsn},
56                                                             desc => $opt->{desc},
57                                                             copy => $opt->{copy} || 0,
58                                                          };
59                                                       }
60             3                                 28      return bless $self, $class;
61                                                    }
62                                                    
63                                                    # Recognized properties:
64                                                    # * dbidriver: which DBI driver to use; assumes mysql, supports Pg.
65                                                    # * required:  which parts are required (hashref).
66                                                    # * set-vars:  a list of variables to set after connecting
67                                                    sub prop {
68    ***     33                   33      0    176      my ( $self, $prop, $value ) = @_;
69            33    100                         170      if ( @_ > 2 ) {
70             5                                 15         MKDEBUG && _d('Setting', $prop, 'property');
71             5                                 19         $self->{$prop} = $value;
72                                                       }
73            33                                270      return $self->{$prop};
74                                                    }
75                                                    
76                                                    # Parse DSN string, like "h=host,P=3306", and return hashref with
77                                                    # all DSN values, like:
78                                                    #    {
79                                                    #       D => undef,
80                                                    #       F => undef,
81                                                    #       h => 'host',
82                                                    #       p => undef,
83                                                    #       P => 3306,
84                                                    #       S => undef,
85                                                    #       t => undef,
86                                                    #       u => undef,
87                                                    #       A => undef,
88                                                    #    }
89                                                    sub parse {
90    ***     15                   15      0     88      my ( $self, $dsn, $prev, $defaults ) = @_;
91    ***     15     50                          77      if ( !$dsn ) {
92    ***      0                                  0         MKDEBUG && _d('No DSN to parse');
93    ***      0                                  0         return;
94                                                       }
95            15                                 38      MKDEBUG && _d('Parsing', $dsn);
96            15           100                   70      $prev     ||= {};
97            15           100                   64      $defaults ||= {};
98            15                                 36      my %given_props;
99            15                                 40      my %final_props;
100           15                                 52      my $opts = $self->{opts};
101                                                   
102                                                      # Parse given props
103           15                                 91      foreach my $dsn_part ( split(/,/, $dsn) ) {
104           37    100                         313         if ( my ($prop_key, $prop_val) = $dsn_part =~  m/^(.)=(.*)$/ ) {
105                                                            # Handle the typical DSN parts like h=host, P=3306, etc.
106           34                                187            $given_props{$prop_key} = $prop_val;
107                                                         }
108                                                         else {
109                                                            # Handle barewords
110            3                                  7            MKDEBUG && _d('Interpreting', $dsn_part, 'as h=', $dsn_part);
111            3                                 14            $given_props{h} = $dsn_part;
112                                                         }
113                                                      }
114                                                   
115                                                      # Fill in final props from given, previous, and/or default props
116           15                                 93      foreach my $key ( keys %$opts ) {
117          122                                263         MKDEBUG && _d('Finding value for', $key);
118          122                                418         $final_props{$key} = $given_props{$key};
119          122    100    100                 1093         if (   !defined $final_props{$key}
      ***                   66                        
120                                                              && defined $prev->{$key} && $opts->{$key}->{copy} )
121                                                         {
122           10                                 39            $final_props{$key} = $prev->{$key};
123           10                                 26            MKDEBUG && _d('Copying value for', $key, 'from previous DSN');
124                                                         }
125          122    100                         535         if ( !defined $final_props{$key} ) {
126           76                                248            $final_props{$key} = $defaults->{$key};
127           76                                228            MKDEBUG && _d('Copying value for', $key, 'from defaults');
128                                                         }
129                                                      }
130                                                   
131                                                      # Sanity check props
132           15                                 75      foreach my $key ( keys %given_props ) {
133           36    100                         184         die "Unknown DSN option '$key' in '$dsn'.  For more details, "
134                                                               . "please use the --help option, or try 'perldoc $PROGRAM_NAME' "
135                                                               . "for complete documentation."
136                                                            unless exists $opts->{$key};
137                                                      }
138           14    100                          65      if ( (my $required = $self->prop('required')) ) {
139            2                                  8         foreach my $key ( keys %$required ) {
140            2    100                           9            die "Missing required DSN option '$key' in '$dsn'.  For more details, "
141                                                                  . "please use the --help option, or try 'perldoc $PROGRAM_NAME' "
142                                                                  . "for complete documentation."
143                                                               unless $final_props{$key};
144                                                         }
145                                                      }
146                                                   
147           13                                166      return \%final_props;
148                                                   }
149                                                   
150                                                   # Like parse() above but takes an OptionParser object instead of
151                                                   # a DSN string.
152                                                   sub parse_options {
153   ***      1                    1      0      5      my ( $self, $o ) = @_;
154   ***      1     50                           7      die 'I need an OptionParser object' unless ref $o eq 'OptionParser';
155            2                                 51      my $dsn_string
156                                                         = join(',',
157            8    100                          49             map  { "$_=".$o->get($_); }
158            1                                  7             grep { $o->has($_) && $o->get($_) }
159            1                                  4             keys %{$self->{opts}}
160                                                           );
161            1                                 28      MKDEBUG && _d('DSN string made from options:', $dsn_string);
162            1                                  6      return $self->parse($dsn_string);
163                                                   }
164                                                   
165                                                   # $props is an optional arrayref of allowed DSN parts to
166                                                   # include in the string.  So if you only want to stringify
167                                                   # h and P, then pass [qw(h P)].
168                                                   sub as_string {
169   ***      4                    4      0     17      my ( $self, $dsn, $props ) = @_;
170            4    100                          43      return $dsn unless ref $dsn;
171            3    100                          13      my %allowed = $props ? map { $_=>1 } @$props : ();
               2                                  9   
172            8    100                          60      return join(',',
173           12    100                          99         map  { "$_=" . ($_ eq 'p' ? '...' : $dsn->{$_})  }
174           13    100                          65         grep { defined $dsn->{$_} && $self->{opts}->{$_} }
175            3                                 27         grep { !$props || $allowed{$_}                   }
176                                                         sort keys %$dsn );
177                                                   }
178                                                   
179                                                   sub usage {
180   ***      0                    0      0      0      my ( $self ) = @_;
181   ***      0                                  0      my $usage
182                                                         = "DSN syntax is key=value[,key=value...]  Allowable DSN keys:\n\n"
183                                                         . "  KEY  COPY  MEANING\n"
184                                                         . "  ===  ====  =============================================\n";
185   ***      0                                  0      my %opts = %{$self->{opts}};
      ***      0                                  0   
186   ***      0                                  0      foreach my $key ( sort keys %opts ) {
187   ***      0      0      0                    0         $usage .= "  $key    "
188                                                                .  ($opts{$key}->{copy} ? 'yes   ' : 'no    ')
189                                                                .  ($opts{$key}->{desc} || '[No description]')
190                                                                . "\n";
191                                                      }
192   ***      0                                  0      $usage .= "\n  If the DSN is a bareword, the word is treated as the 'h' key.\n";
193   ***      0                                  0      return $usage;
194                                                   }
195                                                   
196                                                   # Supports PostgreSQL via the dbidriver element of $info, but assumes MySQL by
197                                                   # default.
198                                                   sub get_cxn_params {
199   ***      7                    7      0     43      my ( $self, $info ) = @_;
200            7                                 21      my $dsn;
201            7                                 29      my %opts = %{$self->{opts}};
               7                                 97   
202            7           100                   50      my $driver = $self->prop('dbidriver') || '';
203            7    100                          34      if ( $driver eq 'Pg' ) {
204            1                                  9         $dsn = 'DBI:Pg:dbname=' . ( $info->{D} || '' ) . ';'
205            2                                  8            . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
206   ***      1            50                    9                        grep { defined $info->{$_} }
207                                                                        qw(h P));
208                                                      }
209                                                      else {
210           16                                121         $dsn = 'DBI:mysql:' . ( $info->{D} || '' ) . ';'
211           30                                138            . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
212            6           100                   86                        grep { defined $info->{$_} }
213                                                                        qw(F h P S A))
214                                                            . ';mysql_read_default_group=client';
215                                                      }
216            7                                 28      MKDEBUG && _d($dsn);
217            7                                 92      return ($dsn, $info->{u}, $info->{p});
218                                                   }
219                                                   
220                                                   # Fills in missing info from a DSN after successfully connecting to the server.
221                                                   sub fill_in_dsn {
222   ***      1                    1      0      4      my ( $self, $dbh, $dsn ) = @_;
223            1                                  3      my $vars = $dbh->selectall_hashref('SHOW VARIABLES', 'Variable_name');
224            1                                  3      my ($user, $db) = $dbh->selectrow_array('SELECT USER(), DATABASE()');
225            1                                211      $user =~ s/@.*//;
226   ***      1            50                    7      $dsn->{h} ||= $vars->{hostname}->{Value};
227   ***      1            50                    7      $dsn->{S} ||= $vars->{'socket'}->{Value};
228   ***      1            50                    6      $dsn->{P} ||= $vars->{port}->{Value};
229   ***      1            50                    6      $dsn->{u} ||= $user;
230   ***      1            50                  131      $dsn->{D} ||= $db;
231                                                   }
232                                                   
233                                                   # Actually opens a connection, then sets some things on the connection so it is
234                                                   # the way the Maatkit tools will expect.  Tools should NEVER open their own
235                                                   # connection or use $dbh->reconnect, or these things will not take place!
236                                                   sub get_dbh {
237   ***      4                    4      0     35      my ( $self, $cxn_string, $user, $pass, $opts ) = @_;
238   ***      4            50                   24      $opts ||= {};
239            4    100                          59      my $defaults = {
240                                                         AutoCommit         => 0,
241                                                         RaiseError         => 1,
242                                                         PrintError         => 0,
243                                                         ShowErrorStatement => 1,
244                                                         mysql_enable_utf8 => ($cxn_string =~ m/charset=utf8/ ? 1 : 0),
245                                                      };
246            4                                 25      @{$defaults}{ keys %$opts } = values %$opts;
               4                                 20   
247                                                   
248                                                      # Only add this if explicitly set because we're not sure if
249                                                      # mysql_use_result=0 would leave default mysql_store_result
250                                                      # enabled.
251            4    100                          29      if ( $opts->{mysql_use_result} ) {
252            1                                  3         $defaults->{mysql_use_result} = 1;
253                                                      }
254                                                   
255   ***      4     50                          24      if ( !$have_dbi ) {
256   ***      0                                  0         die "Cannot connect to MySQL because the Perl DBI module is not "
257                                                            . "installed or not found.  Run 'perl -MDBI' to see the directories "
258                                                            . "that Perl searches for DBI.  If DBI is not installed, try:\n"
259                                                            . "  Debian/Ubuntu  apt-get install libdbi-perl\n"
260                                                            . "  RHEL/CentOS    yum install perl-DBI\n"
261                                                            . "  OpenSolaris    pgk install pkg:/SUNWpmdbi\n";
262                                                   
263                                                      }
264                                                   
265                                                      # Try twice to open the $dbh and set it up as desired.
266            4                                 17      my $dbh;
267            4                                 15      my $tries = 2;
268   ***      4            66                   57      while ( !$dbh && $tries-- ) {
269                                                         MKDEBUG && _d($cxn_string, ' ', $user, ' ', $pass, ' {',
270            4                                 11            join(', ', map { "$_=>$defaults->{$_}" } keys %$defaults ), '}');
271                                                   
272            4                                 22         eval {
273            4                                 57            $dbh = DBI->connect($cxn_string, $user, $pass, $defaults);
274                                                   
275                                                            # If it's a MySQL connection, set some options.
276   ***      4     50                          50            if ( $cxn_string =~ m/mysql/i ) {
277            4                                 14               my $sql;
278                                                   
279                                                               # Set SQL_MODE and options for SHOW CREATE TABLE.
280                                                               # Get current, server SQL mode.  Don't clobber this;
281                                                               # append our SQL mode to whatever is already set.
282                                                               # http://code.google.com/p/maatkit/issues/detail?id=801
283            4                                 18               $sql = 'SELECT @@SQL_MODE';
284            4                                 12               MKDEBUG && _d($dbh, $sql);
285            4                                 11               my ($sql_mode) = $dbh->selectrow_array($sql);
286                                                   
287            4    100                         860               $sql = 'SET @@SQL_QUOTE_SHOW_CREATE = 1'
288                                                                    . '/*!40101, @@SQL_MODE=\'NO_AUTO_VALUE_ON_ZERO'
289                                                                    . ($sql_mode ? ",$sql_mode" : '')
290                                                                    . '\'*/';
291            4                                 14               MKDEBUG && _d($dbh, $sql);
292            4                                580               $dbh->do($sql);
293                                                   
294                                                               # Set character set and binmode on STDOUT.
295            4    100                          69               if ( my ($charset) = $cxn_string =~ m/charset=(\w+)/ ) {
296            3                                 15                  $sql = "/*!40101 SET NAMES $charset*/";
297            3                                  9                  MKDEBUG && _d($dbh, ':', $sql);
298            3                                286                  $dbh->do($sql);
299            3                                 12                  MKDEBUG && _d('Enabling charset for STDOUT');
300   ***      3     50                          15                  if ( $charset eq 'utf8' ) {
301   ***      3     50                          47                     binmode(STDOUT, ':utf8')
302                                                                        or die "Can't binmode(STDOUT, ':utf8'): $OS_ERROR";
303                                                                  }
304                                                                  else {
305   ***      0      0                           0                     binmode(STDOUT) or die "Can't binmode(STDOUT): $OS_ERROR";
306                                                                  }
307                                                               }
308                                                   
309            4    100                          30               if ( $self->prop('set-vars') ) {
310            3                                 19                  $sql = "SET " . $self->prop('set-vars');
311            3                                 11                  MKDEBUG && _d($dbh, ':', $sql);
312            3                                337                  $dbh->do($sql);
313                                                               }
314                                                            }
315                                                         };
316   ***      4     50     33                   56         if ( !$dbh && $EVAL_ERROR ) {
317   ***      0                                  0            MKDEBUG && _d($EVAL_ERROR);
318   ***      0      0                           0            if ( $EVAL_ERROR =~ m/not a compiled character set|character set utf8/ ) {
      ***             0                               
319   ***      0                                  0               MKDEBUG && _d('Going to try again without utf8 support');
320   ***      0                                  0               delete $defaults->{mysql_enable_utf8};
321                                                            }
322                                                            elsif ( $EVAL_ERROR =~ m/locate DBD\/mysql/i ) {
323   ***      0                                  0               die "Cannot connect to MySQL because the Perl DBD::mysql module is "
324                                                                  . "not installed or not found.  Run 'perl -MDBD::mysql' to see "
325                                                                  . "the directories that Perl searches for DBD::mysql.  If "
326                                                                  . "DBD::mysql is not installed, try:\n"
327                                                                  . "  Debian/Ubuntu  apt-get install libdbd-mysql-perl\n"
328                                                                  . "  RHEL/CentOS    yum install perl-DBD-MySQL\n"
329                                                                  . "  OpenSolaris    pgk install pkg:/SUNWapu13dbd-mysql\n";
330                                                            }
331   ***      0      0                           0            if ( !$tries ) {
332   ***      0                                  0               die $EVAL_ERROR;
333                                                            }
334                                                         }
335                                                      }
336                                                   
337            4                                 13      MKDEBUG && _d('DBH info: ',
338                                                         $dbh,
339                                                         Dumper($dbh->selectrow_hashref(
340                                                            'SELECT DATABASE(), CONNECTION_ID(), VERSION()/*!50038 , @@hostname*/')),
341                                                         'Connection info:',      $dbh->{mysql_hostinfo},
342                                                         'Character set info:',   Dumper($dbh->selectall_arrayref(
343                                                                        'SHOW VARIABLES LIKE "character_set%"', { Slice => {}})),
344                                                         '$DBD::mysql::VERSION:', $DBD::mysql::VERSION,
345                                                         '$DBI::VERSION:',        $DBI::VERSION,
346                                                      );
347                                                   
348            4                                 30      return $dbh;
349                                                   }
350                                                   
351                                                   # Tries to figure out a hostname for the connection.
352                                                   sub get_hostname {
353   ***      0                    0      0      0      my ( $self, $dbh ) = @_;
354   ***      0      0      0                    0      if ( my ($host) = ($dbh->{mysql_hostinfo} || '') =~ m/^(\w+) via/ ) {
355   ***      0                                  0         return $host;
356                                                      }
357   ***      0                                  0      my ( $hostname, $one ) = $dbh->selectrow_array(
358                                                         'SELECT /*!50038 @@hostname, */ 1');
359   ***      0                                  0      return $hostname;
360                                                   }
361                                                   
362                                                   # Disconnects a database handle, but complains verbosely if there are any active
363                                                   # children.  These are usually $sth handles that haven't been finish()ed.
364                                                   sub disconnect {
365   ***      0                    0      0      0      my ( $self, $dbh ) = @_;
366   ***      0                                  0      MKDEBUG && $self->print_active_handles($dbh);
367   ***      0                                  0      $dbh->disconnect;
368                                                   }
369                                                   
370                                                   sub print_active_handles {
371   ***      0                    0      0      0      my ( $self, $thing, $level ) = @_;
372   ***      0             0                    0      $level ||= 0;
373   ***      0      0      0                    0      printf("# Active %sh: %s %s %s\n", ($thing->{Type} || 'undef'), "\t" x $level,
      ***             0      0                        
      ***                    0                        
374                                                         $thing, (($thing->{Type} || '') eq 'st' ? $thing->{Statement} || '' : ''))
375                                                         or die "Cannot print: $OS_ERROR";
376   ***      0                                  0      foreach my $handle ( grep {defined} @{ $thing->{ChildHandles} } ) {
      ***      0                                  0   
      ***      0                                  0   
377   ***      0                                  0         $self->print_active_handles( $handle, $level + 1 );
378                                                      }
379                                                   }
380                                                   
381                                                   # Copy all set vals in dsn_1 to dsn_2.  Existing val in dsn_2 are not
382                                                   # overwritten unless overwrite=>1 is given, but undef never overwrites a
383                                                   # val.
384                                                   sub copy {
385   ***      2                    2      0     11      my ( $self, $dsn_1, $dsn_2, %args ) = @_;
386   ***      2     50                           9      die 'I need a dsn_1 argument' unless $dsn_1;
387   ***      2     50                           8      die 'I need a dsn_2 argument' unless $dsn_2;
388           18                                 50      my %new_dsn = map {
389            2                                 13         my $key = $_;
390           18                                 38         my $val;
391           18    100                          57         if ( $args{overwrite} ) {
392            9    100                          43            $val = defined $dsn_1->{$key} ? $dsn_1->{$key} : $dsn_2->{$key};
393                                                         }
394                                                         else {
395            9    100                          40            $val = defined $dsn_2->{$key} ? $dsn_2->{$key} : $dsn_1->{$key};
396                                                         }
397           18                                 70         $key => $val;
398            2                                  6      } keys %{$self->{opts}};
399            2                                 27      return \%new_dsn;
400                                                   }
401                                                   
402                                                   sub _d {
403   ***      0                    0                    my ($package, undef, $line) = caller 0;
404   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
405   ***      0                                              map { defined $_ ? $_ : 'undef' }
406                                                           @_;
407   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
408                                                   }
409                                                   
410                                                   1;
411                                                   
412                                                   # ###########################################################################
413                                                   # End DSNParser package
414                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***     50      0      3   unless $args{$arg}
45    ***     50      0     26   if (not $$opt{'key'} or not $$opt{'desc'})
69           100      5     28   if (@_ > 2)
91    ***     50      0     15   if (not $dsn)
104          100     34      3   if (my($prop_key, $prop_val) = $dsn_part =~ /^(.)=(.*)$/) { }
119          100     10    112   if (not defined $final_props{$key} and defined $$prev{$key} and $$opts{$key}{'copy'})
125          100     76     46   if (not defined $final_props{$key})
133          100      1     35   unless exists $$opts{$key}
138          100      2     12   if (my $required = $self->prop('required'))
140          100      1      1   unless $final_props{$key}
154   ***     50      0      1   unless ref $o eq 'OptionParser'
157          100      6      2   if $o->has($_)
170          100      1      3   unless ref $dsn
171          100      1      2   $props ? :
172          100      1      7   $_ eq 'p' ? :
173          100      9      3   if defined $$dsn{$_}
174          100      3     10   unless not $props
187   ***      0      0      0   $opts{$key}{'copy'} ? :
203          100      1      6   if ($driver eq 'Pg') { }
239          100      3      1   $cxn_string =~ /charset=utf8/ ? :
251          100      1      3   if ($$opts{'mysql_use_result'})
255   ***     50      0      4   if (not $have_dbi)
276   ***     50      4      0   if ($cxn_string =~ /mysql/i)
287          100      1      3   $sql_mode ? :
295          100      3      1   if (my($charset) = $cxn_string =~ /charset=(\w+)/)
300   ***     50      3      0   if ($charset eq 'utf8') { }
301   ***     50      0      3   unless binmode STDOUT, ':utf8'
305   ***      0      0      0   unless binmode STDOUT
309          100      3      1   if ($self->prop('set-vars'))
316   ***     50      0      4   if (not $dbh and $EVAL_ERROR)
318   ***      0      0      0   if ($EVAL_ERROR =~ /not a compiled character set|character set utf8/) { }
      ***      0      0      0   elsif ($EVAL_ERROR =~ m[locate DBD/mysql]i) { }
331   ***      0      0      0   if (not $tries)
354   ***      0      0      0   if (my($host) = ($$dbh{'mysql_hostinfo'} || '') =~ /^(\w+) via/)
373   ***      0      0      0   ($$thing{'Type'} || '') eq 'st' ? :
      ***      0      0      0   unless printf "# Active %sh: %s %s %s\n", $$thing{'Type'} || 'undef', "\t" x $level, $thing, ($$thing{'Type'} || '') eq 'st' ? $$thing{'Statement'} || '' : ''
386   ***     50      0      2   unless $dsn_1
387   ***     50      0      2   unless $dsn_2
391          100      9      9   if ($args{'overwrite'}) { }
392          100      4      5   defined $$dsn_1{$key} ? :
395          100      3      6   defined $$dsn_2{$key} ? :
404   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
119          100     36     76     10   not defined $final_props{$key} and defined $$prev{$key}
      ***     66    112      0     10   not defined $final_props{$key} and defined $$prev{$key} and $$opts{$key}{'copy'}
268   ***     66      4      0      4   not $dbh and $tries--
316   ***     33      4      0      0   not $dbh and $EVAL_ERROR

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
34    ***     50      0      1   $ENV{'MKDEBUG'} || 0
54           100     24      2   $$opt{'copy'} || 0
96           100      5     10   $prev ||= {}
97           100      5     10   $defaults ||= {}
187   ***      0      0      0   $opts{$key}{'desc'} || '[No description]'
202          100      1      6   $self->prop('dbidriver') || ''
206   ***     50      1      0   $$info{'D'} || ''
212          100      2      4   $$info{'D'} || ''
226   ***     50      1      0   $$dsn{'h'} ||= $$vars{'hostname'}{'Value'}
227   ***     50      0      1   $$dsn{'S'} ||= $$vars{'socket'}{'Value'}
228   ***     50      1      0   $$dsn{'P'} ||= $$vars{'port'}{'Value'}
229   ***     50      1      0   $$dsn{'u'} ||= $user
230   ***     50      0      1   $$dsn{'D'} ||= $db
238   ***     50      4      0   $opts ||= {}
354   ***      0      0      0   $$dbh{'mysql_hostinfo'} || ''
372   ***      0      0      0   $level ||= 0
373   ***      0      0      0   $$thing{'Type'} || 'undef'
      ***      0      0      0   $$thing{'Type'} || ''
      ***      0      0      0   $$thing{'Statement'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
45    ***     33      0      0     26   not $$opt{'key'} or not $$opt{'desc'}


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                        
-------------------- ----- --- ------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/DSNParser.pm:22 
BEGIN                    1     /home/daniel/dev/maatkit/common/DSNParser.pm:23 
BEGIN                    1     /home/daniel/dev/maatkit/common/DSNParser.pm:24 
BEGIN                    1     /home/daniel/dev/maatkit/common/DSNParser.pm:25 
BEGIN                    1     /home/daniel/dev/maatkit/common/DSNParser.pm:34 
as_string                4   0 /home/daniel/dev/maatkit/common/DSNParser.pm:169
copy                     2   0 /home/daniel/dev/maatkit/common/DSNParser.pm:385
fill_in_dsn              1   0 /home/daniel/dev/maatkit/common/DSNParser.pm:222
get_cxn_params           7   0 /home/daniel/dev/maatkit/common/DSNParser.pm:199
get_dbh                  4   0 /home/daniel/dev/maatkit/common/DSNParser.pm:237
new                      3   0 /home/daniel/dev/maatkit/common/DSNParser.pm:37 
parse                   15   0 /home/daniel/dev/maatkit/common/DSNParser.pm:90 
parse_options            1   0 /home/daniel/dev/maatkit/common/DSNParser.pm:153
prop                    33   0 /home/daniel/dev/maatkit/common/DSNParser.pm:68 

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                        
-------------------- ----- --- ------------------------------------------------
_d                       0     /home/daniel/dev/maatkit/common/DSNParser.pm:403
disconnect               0   0 /home/daniel/dev/maatkit/common/DSNParser.pm:365
get_hostname             0   0 /home/daniel/dev/maatkit/common/DSNParser.pm:353
print_active_handles     0   0 /home/daniel/dev/maatkit/common/DSNParser.pm:371
usage                    0   0 /home/daniel/dev/maatkit/common/DSNParser.pm:180


DSNParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            36      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            13   use strict;
               1                                  2   
               1                                  7   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  7   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            12   use Test::More tests => 26;
               1                                  3   
               1                                 11   
13                                                    
14             1                    1            13   use DSNParser;
               1                                  4   
               1                                 14   
15             1                    1            18   use OptionParser;
               1                                  8   
               1                                 44   
16             1                    1            16   use MaatkitTest;
               1                                  4   
               1                                 37   
17                                                    
18             1                                 35   my $opts = [
19                                                       {
20                                                          key => 'A',
21                                                          desc => 'Default character set',
22                                                          dsn  => 'charset',
23                                                          copy => 1,
24                                                       },
25                                                       {
26                                                          key => 'D',
27                                                          desc => 'Database to use',
28                                                          dsn  => 'database',
29                                                          copy => 1,
30                                                       },
31                                                       {
32                                                          key => 'F',
33                                                          desc => 'Only read default options from the given file',
34                                                          dsn  => 'mysql_read_default_file',
35                                                          copy => 1,
36                                                       },
37                                                       {
38                                                          key => 'h',
39                                                          desc => 'Connect to host',
40                                                          dsn  => 'host',
41                                                          copy => 1,
42                                                       },
43                                                       {
44                                                          key => 'p',
45                                                          desc => 'Password to use when connecting',
46                                                          dsn  => 'password',
47                                                          copy => 1,
48                                                       },
49                                                       {
50                                                          key => 'P',
51                                                          desc => 'Port number to use for connection',
52                                                          dsn  => 'port',
53                                                          copy => 1,
54                                                       },
55                                                       {
56                                                          key => 'S',
57                                                          desc => 'Socket file to use for connection',
58                                                          dsn  => 'mysql_socket',
59                                                          copy => 1,
60                                                       },
61                                                       {
62                                                          key => 'u',
63                                                          desc => 'User for login if not current user',
64                                                          dsn  => 'user',
65                                                          copy => 1,
66                                                       },
67                                                    ];
68                                                    
69             1                                 12   my $dp = new DSNParser(opts => $opts);
70                                                    
71             1                                  7   is_deeply(
72                                                       $dp->parse('u=a,p=b'),
73                                                       {  u => 'a',
74                                                          p => 'b',
75                                                          S => undef,
76                                                          h => undef,
77                                                          P => undef,
78                                                          F => undef,
79                                                          D => undef,
80                                                          A => undef,
81                                                       },
82                                                       'Basic DSN'
83                                                    );
84                                                    
85             1                                 13   is_deeply(
86                                                       $dp->parse('u=a,p=b,A=utf8'),
87                                                       {  u => 'a',
88                                                          p => 'b',
89                                                          S => undef,
90                                                          h => undef,
91                                                          P => undef,
92                                                          F => undef,
93                                                          D => undef,
94                                                          A => 'utf8',
95                                                       },
96                                                       'Basic DSN with charset'
97                                                    );
98                                                    
99                                                    # The test that was here is no longer needed now because
100                                                   # all opts must be specified now.
101                                                   
102            1                                 15   is_deeply(
103                                                      $dp->parse('u=a,p=b', { D => 'foo', h => 'me' }, { S => 'bar', h => 'host' } ),
104                                                      {  D => 'foo',
105                                                         F => undef,
106                                                         h => 'me',
107                                                         p => 'b',
108                                                         P => undef,
109                                                         S => 'bar',
110                                                         u => 'a',
111                                                         A => undef,
112                                                      },
113                                                      'DSN with defaults'
114                                                   );
115                                                   
116            1                                 17   is(
117                                                      $dp->as_string(
118                                                         $dp->parse('u=a,p=b', { D => 'foo', h => 'me' }, { S => 'bar', h => 'host' } )
119                                                      ),
120                                                      'D=foo,S=bar,h=me,p=...,u=a',
121                                                      'DSN stringified when it gets DSN as arg'
122                                                   );
123                                                   
124            1                                 11   is(
125                                                      $dp->as_string(
126                                                         'D=foo,S=bar,h=me,p=b,u=a',
127                                                      ),
128                                                      'D=foo,S=bar,h=me,p=b,u=a',
129                                                      'DSN stringified when it gets a string as arg'
130                                                   );
131                                                   
132            1                                  8   is (
133                                                      $dp->as_string({ bez => 'bat', h => 'foo' }),
134                                                      'h=foo',
135                                                      'DSN stringifies without extra crap',
136                                                   );
137                                                   
138            1                                 12   is (
139                                                      $dp->as_string({ h=>'localhost', P=>'3306',p=>'omg'}, [qw(h P)]),
140                                                      'P=3306,h=localhost',
141                                                      'DSN stringifies only requested parts'
142                                                   );
143                                                   
144                                                   # The test that was here is no longer need due to issue 55.
145                                                   # DSN usage comes from the POD now.
146                                                   
147            1                                  9   $dp->prop('autokey', 'h');
148            1                                  5   is_deeply(
149                                                      $dp->parse('automatic'),
150                                                      {  D => undef,
151                                                         F => undef,
152                                                         h => 'automatic',
153                                                         p => undef,
154                                                         P => undef,
155                                                         S => undef,
156                                                         u => undef,
157                                                         A => undef,
158                                                      },
159                                                      'DSN with autokey'
160                                                   );
161                                                   
162            1                                 12   $dp->prop('autokey', 'h');
163            1                                  5   is_deeply(
164                                                      $dp->parse('localhost,A=utf8'),
165                                                      {  u => undef,
166                                                         p => undef,
167                                                         S => undef,
168                                                         h => 'localhost',
169                                                         P => undef,
170                                                         F => undef,
171                                                         D => undef,
172                                                         A => 'utf8',
173                                                      },
174                                                      'DSN with an explicit key and an autokey',
175                                                   );
176                                                   
177            1                                 21   is_deeply(
178                                                      $dp->parse('automatic',
179                                                         { D => 'foo', h => 'me', p => 'b' },
180                                                         { S => 'bar', h => 'host', u => 'a' } ),
181                                                      {  D => 'foo',
182                                                         F => undef,
183                                                         h => 'automatic',
184                                                         p => 'b',
185                                                         P => undef,
186                                                         S => 'bar',
187                                                         u => 'a',
188                                                         A => undef,
189                                                      },
190                                                      'DSN with defaults and an autokey'
191                                                   );
192                                                   
193                                                   # The test that was here is no longer need due to issue 55.
194                                                   # DSN usage comes from the POD now.
195                                                   
196            1                                 17   is_deeply (
197                                                      [
198                                                         $dp->get_cxn_params(
199                                                            $dp->parse(
200                                                               'u=a,p=b',
201                                                               { D => 'foo', h => 'me' },
202                                                               { S => 'bar', h => 'host' } ))
203                                                      ],
204                                                      [
205                                                         'DBI:mysql:foo;host=me;mysql_socket=bar;mysql_read_default_group=client',
206                                                         'a',
207                                                         'b',
208                                                      ],
209                                                      'Got connection arguments',
210                                                   );
211                                                   
212            1                                 16   is_deeply (
213                                                      [
214                                                         $dp->get_cxn_params(
215                                                            $dp->parse(
216                                                               'u=a,p=b,A=foo',
217                                                               { D => 'foo', h => 'me' },
218                                                               { S => 'bar', h => 'host' } ))
219                                                      ],
220                                                      [
221                                                         'DBI:mysql:foo;host=me;mysql_socket=bar;charset=foo;mysql_read_default_group=client',
222                                                         'a',
223                                                         'b',
224                                                      ],
225                                                      'Got connection arguments with charset',
226                                                   );
227                                                   
228                                                   # Make sure we can connect to MySQL with a charset
229            1                                 13   my $d = $dp->parse('h=127.0.0.1,P=12345,A=utf8,u=msandbox,p=msandbox');
230            1                                  3   my $dbh;
231            1                                  2   eval {
232            1                                  5      $dbh = $dp->get_dbh($dp->get_cxn_params($d), {});
233                                                   };
234   ***      1     50                           5   SKIP: {
235            1                                  5      skip 'Cannot connect to sandbox master', 5 if $EVAL_ERROR;
236                                                   
237            1                                  6      $dp->fill_in_dsn($dbh, $d);
238            1                                  7      is($d->{P}, 12345, 'Left port alone');
239            1                                  6      is($d->{u}, 'msandbox', 'Filled in username');
240            1                                  7      is($d->{S}, '/tmp/12345/mysql_sandbox12345.sock', 'Filled in socket');
241            1                                  7      is($d->{h}, '127.0.0.1', 'Left hostname alone');
242                                                   
243            1                                  2      is_deeply(
244                                                         $dbh->selectrow_arrayref('select @@character_set_client, @@character_set_connection, @@character_set_results'),
245                                                         [qw(utf8 utf8 utf8)],
246                                                         'Set charset'
247                                                      );
248                                                   };
249                                                   
250            1                                 30   $dp->prop('dbidriver', 'Pg');
251            1                                 10   is_deeply (
252                                                      [
253                                                         $dp->get_cxn_params(
254                                                            {
255                                                               u => 'a',
256                                                               p => 'b',
257                                                               h => 'me',
258                                                               D => 'foo',
259                                                            },
260                                                         )
261                                                      ],
262                                                      [
263                                                         'DBI:Pg:dbname=foo;host=me',
264                                                         'a',
265                                                         'b',
266                                                      ],
267                                                      'Got connection arguments for PostgreSQL',
268                                                   );
269                                                   
270            1                                 13   $dp->prop('required', { h => 1 } );
271                                                   throws_ok (
272            1                    1            16      sub { $dp->parse('u=b') },
273            1                                 27      qr/Missing required DSN option 'h' in 'u=b'/,
274                                                      'Missing host part',
275                                                   );
276                                                   
277                                                   throws_ok (
278            1                    1            13      sub { $dp->parse('h=foo,Z=moo') },
279            1                                 23      qr/Unknown DSN option 'Z' in 'h=foo,Z=moo'/,
280                                                      'Extra key',
281                                                   );
282                                                   
283                                                   # #############################################################################
284                                                   # Test parse_options().
285                                                   # #############################################################################
286            1                                 17   my $o = new OptionParser(
287                                                      description => 'parses command line options.',
288                                                      dp          => $dp,
289                                                   );
290            1                                161   $o->_parse_specs(
291                                                      { spec => 'defaults-file|F=s', desc => 'defaults file'  },
292                                                      { spec => 'password|p=s',      desc => 'password'       },
293                                                      { spec => 'host|h=s',          desc => 'host'           },
294                                                      { spec => 'port|P=i',          desc => 'port'           },
295                                                      { spec => 'socket|S=s',        desc => 'socket'         },
296                                                      { spec => 'user|u=s',          desc => 'user'           },
297                                                   );
298            1                                669   @ARGV = qw(--host slave1 --user foo);
299            1                                  9   $o->get_opts();
300                                                   
301            1                                497   is_deeply(
302                                                      $dp->parse_options($o),
303                                                      {
304                                                         D => undef,
305                                                         F => undef,
306                                                         h => 'slave1',
307                                                         p => undef,
308                                                         P => undef,
309                                                         S => undef,
310                                                         u => 'foo',
311                                                         A => undef,
312                                                      },
313                                                      'Parses DSN from OptionParser obj'
314                                                   );
315                                                   
316                                                   # #############################################################################
317                                                   # Test copy().
318                                                   # #############################################################################
319                                                   
320            1                                 16   push @$opts, { key => 't', desc => 'table' };
321            1                                  9   $dp = new DSNParser(opts => $opts);
322                                                   
323            1                                  9   my $dsn_1 = {
324                                                      D => undef,
325                                                      F => undef,
326                                                      h => 'slave1',
327                                                      p => 'p1',
328                                                      P => '12345',
329                                                      S => undef,
330                                                      t => undef,
331                                                      u => 'foo',
332                                                      A => undef,
333                                                   };
334            1                                  8   my $dsn_2 = {
335                                                      D => 'test',
336                                                      F => undef,
337                                                      h => undef,
338                                                      p => 'p2',
339                                                      P => undef,
340                                                      S => undef,
341                                                      t => 'tbl',
342                                                      u => undef,
343                                                      A => undef,
344                                                   };
345                                                   
346            1                                  6   is_deeply(
347                                                      $dp->copy($dsn_1, $dsn_2),
348                                                      {
349                                                         D => 'test',
350                                                         F => undef,
351                                                         h => 'slave1',
352                                                         p => 'p2',
353                                                         P => '12345',
354                                                         S => undef,
355                                                         t => 'tbl',
356                                                         u => 'foo',
357                                                         A => undef,
358                                                      },
359                                                      'Copy DSN without overwriting destination'
360                                                   );
361            1                                 14   is_deeply(
362                                                      $dp->copy($dsn_1, $dsn_2, overwrite=>1),
363                                                      {
364                                                         D => 'test',
365                                                         F => undef,
366                                                         h => 'slave1',
367                                                         p => 'p1',
368                                                         P => '12345',
369                                                         S => undef,
370                                                         t => 'tbl',
371                                                         u => 'foo',
372                                                         A => undef,
373                                                      },
374                                                      'Copy DSN and overwrite destination'
375                                                   );
376                                                   
377                                                   # #############################################################################
378                                                   # Issue 93: DBI error messages can include full SQL
379                                                   # #############################################################################
380   ***      1     50                           5   SKIP: {
381            1                                  9      skip 'Cannot connect to sandbox master', 1 unless $dbh;
382            1                                  3      eval { $dbh->do('SELECT * FROM doesnt.exist WHERE foo = 1'); };
               1                                 10   
383            1                                 11      like(
384                                                         $EVAL_ERROR,
385                                                         qr/SELECT \* FROM doesnt.exist WHERE foo = 1/,
386                                                         'Includes SQL in error message (issue 93)'
387                                                      );
388                                                   };
389                                                   
390                                                   
391                                                   # #############################################################################
392                                                   # Issue 597: mk-slave-prefetch ignores --set-vars
393                                                   # #############################################################################
394                                                   
395                                                   # This affects all scripts because prop() doesn't match what get_dbh() does.
396   ***      1     50                           5   SKIP: {
397            1                                  7      skip 'Cannot connect to sandbox master', 1 unless $dbh;
398            1                                139      $dbh->do('SET @@global.wait_timeout=1');
399                                                   
400                                                      # This dbh is going to timeout too during this test so close
401                                                      # it now else we'll get an error.
402            1                                 50      $dbh->disconnect();
403                                                   
404            1                                 10      $dp = new DSNParser(opts => $opts);
405            1                                 17      $dp->prop('set-vars', 'wait_timeout=1000');
406            1                                  5      $d  = $dp->parse('h=127.0.0.1,P=12345,A=utf8,u=msandbox,p=msandbox');
407            1                                  8      my $dbh2 = $dp->get_dbh($dp->get_cxn_params($d), {mysql_use_result=>1});
408            1                             2000243      sleep 2;
409            1                                 11      eval {
410            1                                394         $dbh2->do('SELECT DATABASE()');
411                                                      };
412            1                                 20      is(
413                                                         $EVAL_ERROR,
414                                                         '',
415                                                         'SET vars (issue 597)'
416                                                      );
417            1                                123      $dbh2->disconnect();
418                                                   
419                                                      # Have to reconnect $dbh since it timedout too.
420            1                                 18      $dbh = $dp->get_dbh($dp->get_cxn_params($d), {});
421            1                                257      $dbh->do('SET @@global.wait_timeout=28800');
422                                                   };
423                                                   
424                                                   # #############################################################################
425                                                   # Issue 801: DSNParser clobbers SQL_MODE
426                                                   # #############################################################################
427            1                             2145141   SKIP: {
428            1                                  6      diag(`SQL_MODE="no_zero_date" $trunk/sandbox/start-sandbox master 12348 >/dev/null`);
429            1                                 32      my $dsn = $dp->parse('h=127.1,P=12348,u=msandbox,p=msandbox');
430            1                                 21      my $dbh = $dp->get_dbh($dp->get_cxn_params($dsn), {});
431                                                   
432   ***      1     50                          16      skip 'Cannot connect to second sandbox master', 1 unless $dbh;
433                                                   
434            1                                  4      my $row = $dbh->selectrow_arrayref('select @@sql_mode');
435            1                                220      is(
436                                                         $row->[0],
437                                                         'NO_AUTO_VALUE_ON_ZERO,NO_ZERO_DATE',
438                                                         "Did not clobber server SQL mode"
439                                                      );
440                                                   
441            1                                 76      $dbh->disconnect();
442            1                             3064718      diag(`$trunk/sandbox/stop-sandbox remove 12348 >/dev/null`);
443                                                   };
444                                                   
445                                                   # #############################################################################
446                                                   # Done.
447                                                   # #############################################################################
448   ***      1     50                         129   $dbh->disconnect() if $dbh;
449            1                                  6   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
234   ***     50      0      1   if $EVAL_ERROR
380   ***     50      0      1   unless $dbh
396   ***     50      0      1   unless $dbh
432   ***     50      0      1   unless $dbh
448   ***     50      1      0   if $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location       
---------- ----- ---------------
BEGIN          1 DSNParser.t:10 
BEGIN          1 DSNParser.t:11 
BEGIN          1 DSNParser.t:12 
BEGIN          1 DSNParser.t:14 
BEGIN          1 DSNParser.t:15 
BEGIN          1 DSNParser.t:16 
BEGIN          1 DSNParser.t:4  
BEGIN          1 DSNParser.t:9  
__ANON__       1 DSNParser.t:272
__ANON__       1 DSNParser.t:278


