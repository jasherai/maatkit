---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/DSNParser.pm   82.5   63.9   54.3   85.0    n/a  100.0   74.3
Total                          82.5   63.9   54.3   85.0    n/a  100.0   74.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          DSNParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:36 2009
Finish:       Wed Jun 10 17:19:36 2009

/home/daniel/dev/maatkit/common/DSNParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Baron Schwartz.
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
18                                                    # DSNParser package $Revision: 3577 $
19                                                    # ###########################################################################
20             1                    1             8   use strict;
               1                                  2   
               1                                  7   
21             1                    1             6   use warnings FATAL => 'all';
               1                                103   
               1                                 10   
22                                                    
23                                                    package DSNParser;
24                                                    
25             1                    1            10   use DBI;
               1                                 43   
               1                                 12   
26             1                    1             8   use Data::Dumper;
               1                                  2   
               1                                  9   
27                                                    $Data::Dumper::Indent    = 0;
28                                                    $Data::Dumper::Quotekeys = 0;
29             1                    1             7   use English qw(-no_match_vars);
               1                                  2   
               1                                 18   
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
32                                                    
33                                                    # Defaults are built-in, but you can add/replace items by passing them as
34                                                    # hashrefs of {key, desc, copy, dsn}.  The desc and dsn items are optional.
35                                                    # You can set properties with the prop() sub.  Don't set the 'opts' property.
36                                                    sub new {
37             2                    2            22      my ( $class, @opts ) = @_;
38             2                                 58      my $self = {
39                                                          opts => {
40                                                             A => {
41                                                                desc => 'Default character set',
42                                                                dsn  => 'charset',
43                                                                copy => 1,
44                                                             },
45                                                             D => {
46                                                                desc => 'Database to use',
47                                                                dsn  => 'database',
48                                                                copy => 1,
49                                                             },
50                                                             F => {
51                                                                desc => 'Only read default options from the given file',
52                                                                dsn  => 'mysql_read_default_file',
53                                                                copy => 1,
54                                                             },
55                                                             h => {
56                                                                desc => 'Connect to host',
57                                                                dsn  => 'host',
58                                                                copy => 1,
59                                                             },
60                                                             p => {
61                                                                desc => 'Password to use when connecting',
62                                                                dsn  => 'password',
63                                                                copy => 1,
64                                                             },
65                                                             P => {
66                                                                desc => 'Port number to use for connection',
67                                                                dsn  => 'port',
68                                                                copy => 1,
69                                                             },
70                                                             S => {
71                                                                desc => 'Socket file to use for connection',
72                                                                dsn  => 'mysql_socket',
73                                                                copy => 1,
74                                                             },
75                                                             u => {
76                                                                desc => 'User for login if not current user',
77                                                                dsn  => 'user',
78                                                                copy => 1,
79                                                             },
80                                                          },
81                                                       };
82             2                                 10      foreach my $opt ( @opts ) {
83             1                                  3         MKDEBUG && _d('Adding extra property', $opt->{key});
84             1                                  9         $self->{opts}->{$opt->{key}} = { desc => $opt->{desc}, copy => $opt->{copy} };
85                                                       }
86             2                                 23      return bless $self, $class;
87                                                    }
88                                                    
89                                                    # Recognized properties:
90                                                    # * autokey:   which key to treat a bareword as (typically h=host).
91                                                    # * dbidriver: which DBI driver to use; assumes mysql, supports Pg.
92                                                    # * required:  which parts are required (hashref).
93                                                    # * setvars:   a list of variables to set after connecting
94                                                    sub prop {
95            38                   38           170      my ( $self, $prop, $value ) = @_;
96            38    100                         162      if ( @_ > 2 ) {
97             4                                 10         MKDEBUG && _d('Setting', $prop, 'property');
98             4                                 19         $self->{$prop} = $value;
99                                                       }
100           38                                206      return $self->{$prop};
101                                                   }
102                                                   
103                                                   # Parse DSN string, like "h=host,P=3306", and return hashref with
104                                                   # all DSN values, like:
105                                                   #    {
106                                                   #       D => undef,
107                                                   #       F => undef,
108                                                   #       h => 'host',
109                                                   #       p => undef,
110                                                   #       P => 3306,
111                                                   #       S => undef,
112                                                   #       t => undef,
113                                                   #       u => undef,
114                                                   #       A => undef,
115                                                   #    }
116                                                   sub parse {
117           14                   14            86      my ( $self, $dsn, $prev, $defaults ) = @_;
118   ***     14     50                          63      if ( !$dsn ) {
119   ***      0                                  0         MKDEBUG && _d('No DSN to parse');
120   ***      0                                  0         return;
121                                                      }
122           14                                 32      MKDEBUG && _d('Parsing', $dsn);
123           14           100                   59      $prev     ||= {};
124           14           100                   53      $defaults ||= {};
125           14                                 33      my %given_props;
126           14                                 32      my %final_props;
127           14                                 41      my %opts = %{$self->{opts}};
              14                                138   
128           14                                 79      my $prop_autokey = $self->prop('autokey');
129                                                   
130                                                      # Parse given props
131           14                                 79      foreach my $dsn_part ( split(/,/, $dsn) ) {
132           28    100                         216         if ( my ($prop_key, $prop_val) = $dsn_part =~  m/^(.)=(.*)$/ ) {
      ***            50                               
133                                                            # Handle the typical DSN parts like h=host, P=3306, etc.
134           25                                119            $given_props{$prop_key} = $prop_val;
135                                                         }
136                                                         elsif ( $prop_autokey ) {
137                                                            # Handle barewords
138            3                                  8            MKDEBUG && _d('Interpreting', $dsn_part, 'as',
139                                                               $prop_autokey, '=', $dsn_part);
140            3                                 13            $given_props{$prop_autokey} = $dsn_part;
141                                                         }
142                                                         else {
143   ***      0                                  0            MKDEBUG && _d('Bad DSN part:', $dsn_part);
144                                                         }
145                                                      }
146                                                   
147                                                      # Fill in final props from given, previous, and/or default props
148           14                                 69      foreach my $key ( keys %opts ) {
149          124                                275         MKDEBUG && _d('Finding value for', $key);
150          124                                391         $final_props{$key} = $given_props{$key};
151          124    100    100                 1078         if (   !defined $final_props{$key}
      ***                   66                        
152                                                              && defined $prev->{$key} && $opts{$key}->{copy} )
153                                                         {
154           10                                 34            $final_props{$key} = $prev->{$key};
155           10                                 23            MKDEBUG && _d('Copying value for', $key, 'from previous DSN');
156                                                         }
157          124    100                         493         if ( !defined $final_props{$key} ) {
158           87                                281            $final_props{$key} = $defaults->{$key};
159           87                                254            MKDEBUG && _d('Copying value for', $key, 'from defaults');
160                                                         }
161                                                      }
162                                                   
163                                                      # Sanity check props
164           14                                 68      foreach my $key ( keys %given_props ) {
165           27    100                         117         die "Unrecognized DSN part '$key' in '$dsn'\n"
166                                                            unless exists $opts{$key};
167                                                      }
168           13    100                          52      if ( (my $required = $self->prop('required')) ) {
169            2                                 10         foreach my $key ( keys %$required ) {
170            2    100                           9            die "Missing DSN part '$key' in '$dsn'\n" unless $final_props{$key};
171                                                         }
172                                                      }
173                                                   
174           12                                148      return \%final_props;
175                                                   }
176                                                   
177                                                   # Like parse() above but takes an OptionParser object instead of
178                                                   # a DSN string.
179                                                   sub parse_options {
180            1                    1            12      my ( $self, $o ) = @_;
181   ***      1     50                           6      die 'I need an OptionParser object' unless ref $o eq 'OptionParser';
182            2                                 10      my $dsn_string
183                                                         = join(',',
184            9    100                          33             map  { "$_=".$o->get($_); }
185            1                                  6             grep { $o->has($_) && $o->get($_) }
186            1                                  4             keys %{$self->{opts}}
187                                                           );
188            1                                  4      MKDEBUG && _d('DSN string made from options:', $dsn_string);
189            1                                  6      return $self->parse($dsn_string);
190                                                   }
191                                                   
192                                                   sub as_string {
193            3                    3            13      my ( $self, $dsn ) = @_;
194            3    100                          19      return $dsn unless ref $dsn;
195            6    100                          49      return join(',',
196           11    100                          80         map  { "$_=" . ($_ eq 'p' ? '...' : $dsn->{$_}) }
197            2                                 22         grep { defined $dsn->{$_} && $self->{opts}->{$_} }
198                                                         sort keys %$dsn );
199                                                   }
200                                                   
201                                                   sub usage {
202            2                    2             8      my ( $self ) = @_;
203            2                                  7      my $usage
204                                                         = "DSN syntax is key=value[,key=value...]  Allowable DSN keys:\n\n"
205                                                         . "  KEY  COPY  MEANING\n"
206                                                         . "  ===  ====  =============================================\n";
207            2                                  6      my %opts = %{$self->{opts}};
               2                                 18   
208            2                                 23      foreach my $key ( sort keys %opts ) {
209           18    100    100                  155         $usage .= "  $key    "
210                                                                .  ($opts{$key}->{copy} ? 'yes   ' : 'no    ')
211                                                                .  ($opts{$key}->{desc} || '[No description]')
212                                                                . "\n";
213                                                      }
214            2    100                          11      if ( (my $key = $self->prop('autokey')) ) {
215            1                                 10         $usage .= "  If the DSN is a bareword, the word is treated as the '$key' key.\n";
216                                                      }
217            2                                 15      return $usage;
218                                                   }
219                                                   
220                                                   # Supports PostgreSQL via the dbidriver element of $info, but assumes MySQL by
221                                                   # default.
222                                                   sub get_cxn_params {
223            4                    4            39      my ( $self, $info ) = @_;
224            4                                 10      my $dsn;
225            4                                 11      my %opts = %{$self->{opts}};
               4                                 47   
226            4           100                   20      my $driver = $self->prop('dbidriver') || '';
227            4    100                          19      if ( $driver eq 'Pg' ) {
228            1                                 11         $dsn = 'DBI:Pg:dbname=' . ( $info->{D} || '' ) . ';'
229            2                                  9            . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
230   ***      1            50                   10                        grep { defined $info->{$_} }
231                                                                        qw(h P));
232                                                      }
233                                                      else {
234            8                                 49         $dsn = 'DBI:mysql:' . ( $info->{D} || '' ) . ';'
235           15                                 53            . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
236            3           100                   26                        grep { defined $info->{$_} }
237                                                                        qw(F h P S A))
238                                                            . ';mysql_read_default_group=client';
239                                                      }
240            4                                 11      MKDEBUG && _d($dsn);
241            4                                 45      return ($dsn, $info->{u}, $info->{p});
242                                                   }
243                                                   
244                                                   # Fills in missing info from a DSN after successfully connecting to the server.
245                                                   sub fill_in_dsn {
246            1                    1            18      my ( $self, $dbh, $dsn ) = @_;
247            1                                  2      my $vars = $dbh->selectall_hashref('SHOW VARIABLES', 'Variable_name');
248            1                                  3      my ($user, $db) = $dbh->selectrow_array('SELECT USER(), DATABASE()');
249            1                                264      $user =~ s/@.*//;
250   ***      1            50                    6      $dsn->{h} ||= $vars->{hostname}->{Value};
251   ***      1            50                   48      $dsn->{S} ||= $vars->{'socket'}->{Value};
252   ***      1            50                    5      $dsn->{P} ||= $vars->{port}->{Value};
253   ***      1            50                    6      $dsn->{u} ||= $user;
254   ***      1            50                  112      $dsn->{D} ||= $db;
255                                                   }
256                                                   
257                                                   # Actually opens a connection, then sets some things on the connection so it is
258                                                   # the way the Maatkit tools will expect.  Tools should NEVER open their own
259                                                   # connection or use $dbh->reconnect, or these things will not take place!
260                                                   sub get_dbh {
261            1                    1             5      my ( $self, $cxn_string, $user, $pass, $opts ) = @_;
262   ***      1            50                    5      $opts ||= {};
263   ***      1     50                           9      my $defaults = {
264                                                         AutoCommit        => 0,
265                                                         RaiseError        => 1,
266                                                         PrintError        => 0,
267                                                         mysql_enable_utf8 => ($cxn_string =~ m/charset=utf8/ ? 1 : 0),
268                                                      };
269            1                                 11      @{$defaults}{ keys %$opts } = values %$opts;
               1                                  3   
270                                                   
271                                                      # Try twice to open the $dbh and set it up as desired.
272            1                                  3      my $dbh;
273            1                                  3      my $tries = 2;
274   ***      1            66                   15      while ( !$dbh && $tries-- ) {
275                                                         MKDEBUG && _d($cxn_string, ' ', $user, ' ', $pass, ' {',
276            1                                  2            join(', ', map { "$_=>$defaults->{$_}" } keys %$defaults ), '}');
277                                                   
278            1                                  3         eval {
279            1                                  8            $dbh = DBI->connect($cxn_string, $user, $pass, $defaults);
280                                                   
281                                                            # If it's a MySQL connection, set some options.
282   ***      1     50                          13            if ( $cxn_string =~ m/mysql/i ) {
283            1                                  2               my $sql;
284                                                   
285                                                               # Set SQL_MODE and options for SHOW CREATE TABLE.
286            1                                  5               $sql = q{SET @@SQL_QUOTE_SHOW_CREATE = 1}
287                                                                    . q{/*!40101, @@SQL_MODE='NO_AUTO_VALUE_ON_ZERO'*/};
288            1                                  2               MKDEBUG && _d($dbh, ':', $sql);
289            1                                137               $dbh->do($sql);
290                                                   
291                                                               # Set character set and binmode on STDOUT.
292   ***      1     50                          16               if ( my ($charset) = $cxn_string =~ m/charset=(\w+)/ ) {
293            1                                  7                  $sql = "/*!40101 SET NAMES $charset*/";
294            1                                  4                  MKDEBUG && _d($dbh, ':', $sql);
295            1                                110                  $dbh->do($sql);
296            1                                  3                  MKDEBUG && _d('Enabling charset for STDOUT');
297   ***      1     50                           6                  if ( $charset eq 'utf8' ) {
298   ***      1     50                          23                     binmode(STDOUT, ':utf8')
299                                                                        or die "Can't binmode(STDOUT, ':utf8'): $OS_ERROR";
300                                                                  }
301                                                                  else {
302   ***      0      0                           0                     binmode(STDOUT) or die "Can't binmode(STDOUT): $OS_ERROR";
303                                                                  }
304                                                               }
305                                                   
306   ***      1     50                           7               if ( $self->prop('setvars') ) {
307   ***      0                                  0                  $sql = "SET " . $self->prop('setvars');
308   ***      0                                  0                  MKDEBUG && _d($dbh, ':', $sql);
309   ***      0                                  0                  $dbh->do($sql);
310                                                               }
311                                                            }
312                                                         };
313   ***      1     50     33                   12         if ( !$dbh && $EVAL_ERROR ) {
314   ***      0                                  0            MKDEBUG && _d($EVAL_ERROR);
315   ***      0      0                           0            if ( $EVAL_ERROR =~ m/not a compiled character set|character set utf8/ ) {
316   ***      0                                  0               MKDEBUG && _d('Going to try again without utf8 support');
317   ***      0                                  0               delete $defaults->{mysql_enable_utf8};
318                                                            }
319   ***      0      0                           0            if ( !$tries ) {
320   ***      0                                  0               die $EVAL_ERROR;
321                                                            }
322                                                         }
323                                                      }
324                                                   
325            1                                  3      MKDEBUG && _d('DBH info: ',
326                                                         $dbh,
327                                                         Dumper($dbh->selectrow_hashref(
328                                                            'SELECT DATABASE(), CONNECTION_ID(), VERSION()/*!50038 , @@hostname*/')),
329                                                         'Connection info:',      $dbh->{mysql_hostinfo},
330                                                         'Character set info:',   Dumper($dbh->selectall_arrayref(
331                                                                        'SHOW VARIABLES LIKE "character_set%"', { Slice => {}})),
332                                                         '$DBD::mysql::VERSION:', $DBD::mysql::VERSION,
333                                                         '$DBI::VERSION:',        $DBI::VERSION,
334                                                      );
335                                                   
336            1                                  7      return $dbh;
337                                                   }
338                                                   
339                                                   # Tries to figure out a hostname for the connection.
340                                                   sub get_hostname {
341   ***      0                    0             0      my ( $self, $dbh ) = @_;
342   ***      0      0      0                    0      if ( my ($host) = ($dbh->{mysql_hostinfo} || '') =~ m/^(\w+) via/ ) {
343   ***      0                                  0         return $host;
344                                                      }
345   ***      0                                  0      my ( $hostname, $one ) = $dbh->selectrow_array(
346                                                         'SELECT /*!50038 @@hostname, */ 1');
347   ***      0                                  0      return $hostname;
348                                                   }
349                                                   
350                                                   # Disconnects a database handle, but complains verbosely if there are any active
351                                                   # children.  These are usually $sth handles that haven't been finish()ed.
352                                                   sub disconnect {
353            1                    1            12      my ( $self, $dbh ) = @_;
354            1                                  3      MKDEBUG && $self->print_active_handles($dbh);
355            1                                 97      $dbh->disconnect;
356                                                   }
357                                                   
358                                                   sub print_active_handles {
359   ***      0                    0             0      my ( $self, $thing, $level ) = @_;
360   ***      0             0                    0      $level ||= 0;
361   ***      0      0      0                    0      printf("# Active %sh: %s %s %s\n", ($thing->{Type} || 'undef'), "\t" x $level,
      ***             0      0                        
      ***                    0                        
362                                                         $thing, (($thing->{Type} || '') eq 'st' ? $thing->{Statement} || '' : ''))
363                                                         or die "Cannot print: $OS_ERROR";
364   ***      0                                  0      foreach my $handle ( grep {defined} @{ $thing->{ChildHandles} } ) {
      ***      0                                  0   
      ***      0                                  0   
365   ***      0                                  0         $self->print_active_handles( $handle, $level + 1 );
366                                                      }
367                                                   }
368                                                   
369                                                   # Copy all set vals in dsn_1 to dsn_2.  Existing val in dsn_2 are not
370                                                   # overwritten unless overwrite=>1 is given, but undef never overwrites a
371                                                   # val.
372                                                   sub copy {
373            2                    2            13      my ( $self, $dsn_1, $dsn_2, %args ) = @_;
374   ***      2     50                           9      die 'I need a dsn_1 argument' unless $dsn_1;
375   ***      2     50                           8      die 'I need a dsn_2 argument' unless $dsn_2;
376           18                                 46      my %new_dsn = map {
377            2                                 13         my $key = $_;
378           18                                 38         my $val;
379           18    100                          58         if ( $args{overwrite} ) {
380            9    100                          39            $val = defined $dsn_1->{$key} ? $dsn_1->{$key} : $dsn_2->{$key};
381                                                         }
382                                                         else {
383            9    100                          41            $val = defined $dsn_2->{$key} ? $dsn_2->{$key} : $dsn_1->{$key};
384                                                         }
385           18                                 76         $key => $val;
386            2                                  7      } keys %{$self->{opts}};
387            2                                 28      return \%new_dsn;
388                                                   }
389                                                   
390                                                   sub _d {
391   ***      0                    0                    my ($package, undef, $line) = caller 0;
392   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
393   ***      0                                              map { defined $_ ? $_ : 'undef' }
394                                                           @_;
395   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
396                                                   }
397                                                   
398                                                   1;
399                                                   
400                                                   # ###########################################################################
401                                                   # End DSNParser package
402                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
96           100      4     34   if (@_ > 2)
118   ***     50      0     14   if (not $dsn)
132          100     25      3   if (my($prop_key, $prop_val) = $dsn_part =~ /^(.)=(.*)$/) { }
      ***     50      3      0   elsif ($prop_autokey) { }
151          100     10    114   if (not defined $final_props{$key} and defined $$prev{$key} and $opts{$key}{'copy'})
157          100     87     37   if (not defined $final_props{$key})
165          100      1     26   unless exists $opts{$key}
168          100      2     11   if (my $required = $self->prop('required'))
170          100      1      1   unless $final_props{$key}
181   ***     50      0      1   unless ref $o eq 'OptionParser'
184          100      6      3   if $o->has($_)
194          100      1      2   unless ref $dsn
195          100      1      5   $_ eq 'p' ? :
196          100      7      4   if defined $$dsn{$_}
209          100     16      2   $opts{$key}{'copy'} ? :
214          100      1      1   if (my $key = $self->prop('autokey'))
227          100      1      3   if ($driver eq 'Pg') { }
263   ***     50      1      0   $cxn_string =~ /charset=utf8/ ? :
282   ***     50      1      0   if ($cxn_string =~ /mysql/i)
292   ***     50      1      0   if (my($charset) = $cxn_string =~ /charset=(\w+)/)
297   ***     50      1      0   if ($charset eq 'utf8') { }
298   ***     50      0      1   unless binmode STDOUT, ':utf8'
302   ***      0      0      0   unless binmode STDOUT
306   ***     50      0      1   if ($self->prop('setvars'))
313   ***     50      0      1   if (not $dbh and $EVAL_ERROR)
315   ***      0      0      0   if ($EVAL_ERROR =~ /not a compiled character set|character set utf8/)
319   ***      0      0      0   if (not $tries)
342   ***      0      0      0   if (my($host) = ($$dbh{'mysql_hostinfo'} || '') =~ /^(\w+) via/)
361   ***      0      0      0   ($$thing{'Type'} || '') eq 'st' ? :
      ***      0      0      0   unless printf "# Active %sh: %s %s %s\n", $$thing{'Type'} || 'undef', "\t" x $level, $thing, ($$thing{'Type'} || '') eq 'st' ? $$thing{'Statement'} || '' : ''
374   ***     50      0      2   unless $dsn_1
375   ***     50      0      2   unless $dsn_2
379          100      9      9   if ($args{'overwrite'}) { }
380          100      4      5   defined $$dsn_1{$key} ? :
383          100      3      6   defined $$dsn_2{$key} ? :
392   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
151          100     27     87     10   not defined $final_props{$key} and defined $$prev{$key}
      ***     66    114      0     10   not defined $final_props{$key} and defined $$prev{$key} and $opts{$key}{'copy'}
274   ***     66      1      0      1   not $dbh and $tries--
313   ***     33      1      0      0   not $dbh and $EVAL_ERROR

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
123          100      5      9   $prev ||= {}
124          100      5      9   $defaults ||= {}
209          100     16      2   $opts{$key}{'desc'} || '[No description]'
226          100      1      3   $self->prop('dbidriver') || ''
230   ***     50      1      0   $$info{'D'} || ''
236          100      2      1   $$info{'D'} || ''
250   ***     50      1      0   $$dsn{'h'} ||= $$vars{'hostname'}{'Value'}
251   ***     50      0      1   $$dsn{'S'} ||= $$vars{'socket'}{'Value'}
252   ***     50      1      0   $$dsn{'P'} ||= $$vars{'port'}{'Value'}
253   ***     50      0      1   $$dsn{'u'} ||= $user
254   ***     50      0      1   $$dsn{'D'} ||= $db
262   ***     50      1      0   $opts ||= {}
342   ***      0      0      0   $$dbh{'mysql_hostinfo'} || ''
360   ***      0      0      0   $level ||= 0
361   ***      0      0      0   $$thing{'Type'} || 'undef'
      ***      0      0      0   $$thing{'Type'} || ''
      ***      0      0      0   $$thing{'Statement'} || ''


Covered Subroutines
-------------------

Subroutine           Count Location                                        
-------------------- ----- ------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/DSNParser.pm:20 
BEGIN                    1 /home/daniel/dev/maatkit/common/DSNParser.pm:21 
BEGIN                    1 /home/daniel/dev/maatkit/common/DSNParser.pm:25 
BEGIN                    1 /home/daniel/dev/maatkit/common/DSNParser.pm:26 
BEGIN                    1 /home/daniel/dev/maatkit/common/DSNParser.pm:29 
BEGIN                    1 /home/daniel/dev/maatkit/common/DSNParser.pm:31 
as_string                3 /home/daniel/dev/maatkit/common/DSNParser.pm:193
copy                     2 /home/daniel/dev/maatkit/common/DSNParser.pm:373
disconnect               1 /home/daniel/dev/maatkit/common/DSNParser.pm:353
fill_in_dsn              1 /home/daniel/dev/maatkit/common/DSNParser.pm:246
get_cxn_params           4 /home/daniel/dev/maatkit/common/DSNParser.pm:223
get_dbh                  1 /home/daniel/dev/maatkit/common/DSNParser.pm:261
new                      2 /home/daniel/dev/maatkit/common/DSNParser.pm:37 
parse                   14 /home/daniel/dev/maatkit/common/DSNParser.pm:117
parse_options            1 /home/daniel/dev/maatkit/common/DSNParser.pm:180
prop                    38 /home/daniel/dev/maatkit/common/DSNParser.pm:95 
usage                    2 /home/daniel/dev/maatkit/common/DSNParser.pm:202

Uncovered Subroutines
---------------------

Subroutine           Count Location                                        
-------------------- ----- ------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/DSNParser.pm:391
get_hostname             0 /home/daniel/dev/maatkit/common/DSNParser.pm:341
print_active_handles     0 /home/daniel/dev/maatkit/common/DSNParser.pm:359


