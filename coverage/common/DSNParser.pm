---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/DSNParser.pm   81.0   63.2   54.3   80.0    n/a  100.0   73.1
Total                          81.0   63.2   54.3   80.0    n/a  100.0   73.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          DSNParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:36 2009
Finish:       Fri Jul 31 18:51:36 2009

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
18                                                    # DSNParser package $Revision: 4103 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  2   
               1                                  7   
21             1                    1           109   use warnings FATAL => 'all';
               1                                  3   
               1                                  9   
22                                                    
23                                                    package DSNParser;
24                                                    
25             1                    1            10   use DBI;
               1                                 44   
               1                                 11   
26             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                 17   
27                                                    $Data::Dumper::Indent    = 0;
28                                                    $Data::Dumper::Quotekeys = 0;
29             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
32                                                    
33                                                    # Defaults are built-in, but you can add/replace items by passing them as
34                                                    # hashrefs of {key, desc, copy, dsn}.  The desc and dsn items are optional.
35                                                    # You can set properties with the prop() sub.  Don't set the 'opts' property.
36                                                    sub new {
37             2                    2            22      my ( $class, @opts ) = @_;
38             2                                 71      my $self = {
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
83             1                                  2         MKDEBUG && _d('Adding extra property', $opt->{key});
84             1                                  9         $self->{opts}->{$opt->{key}} = { desc => $opt->{desc}, copy => $opt->{copy} };
85                                                       }
86             2                                 24      return bless $self, $class;
87                                                    }
88                                                    
89                                                    # Recognized properties:
90                                                    # * dbidriver: which DBI driver to use; assumes mysql, supports Pg.
91                                                    # * required:  which parts are required (hashref).
92                                                    # * setvars:   a list of variables to set after connecting
93                                                    sub prop {
94            22                   22           100      my ( $self, $prop, $value ) = @_;
95            22    100                          91      if ( @_ > 2 ) {
96             4                                  9         MKDEBUG && _d('Setting', $prop, 'property');
97             4                                 15         $self->{$prop} = $value;
98                                                       }
99            22                                128      return $self->{$prop};
100                                                   }
101                                                   
102                                                   # Parse DSN string, like "h=host,P=3306", and return hashref with
103                                                   # all DSN values, like:
104                                                   #    {
105                                                   #       D => undef,
106                                                   #       F => undef,
107                                                   #       h => 'host',
108                                                   #       p => undef,
109                                                   #       P => 3306,
110                                                   #       S => undef,
111                                                   #       t => undef,
112                                                   #       u => undef,
113                                                   #       A => undef,
114                                                   #    }
115                                                   sub parse {
116           14                   14            82      my ( $self, $dsn, $prev, $defaults ) = @_;
117   ***     14     50                          59      if ( !$dsn ) {
118   ***      0                                  0         MKDEBUG && _d('No DSN to parse');
119   ***      0                                  0         return;
120                                                      }
121           14                                 31      MKDEBUG && _d('Parsing', $dsn);
122           14           100                   60      $prev     ||= {};
123           14           100                   51      $defaults ||= {};
124           14                                 30      my %given_props;
125           14                                 36      my %final_props;
126           14                                 35      my %opts = %{$self->{opts}};
              14                                138   
127                                                   
128                                                      # Parse given props
129           14                                 96      foreach my $dsn_part ( split(/,/, $dsn) ) {
130           28    100                         198         if ( my ($prop_key, $prop_val) = $dsn_part =~  m/^(.)=(.*)$/ ) {
131                                                            # Handle the typical DSN parts like h=host, P=3306, etc.
132           25                                117            $given_props{$prop_key} = $prop_val;
133                                                         }
134                                                         else {
135                                                            # Handle barewords
136            3                                  6            MKDEBUG && _d('Interpreting', $dsn_part, 'as h=', $dsn_part);
137            3                                 13            $given_props{h} = $dsn_part;
138                                                         }
139                                                      }
140                                                   
141                                                      # Fill in final props from given, previous, and/or default props
142           14                                 67      foreach my $key ( keys %opts ) {
143          124                                252         MKDEBUG && _d('Finding value for', $key);
144          124                                388         $final_props{$key} = $given_props{$key};
145          124    100    100                 1060         if (   !defined $final_props{$key}
      ***                   66                        
146                                                              && defined $prev->{$key} && $opts{$key}->{copy} )
147                                                         {
148           10                                 37            $final_props{$key} = $prev->{$key};
149           10                                 21            MKDEBUG && _d('Copying value for', $key, 'from previous DSN');
150                                                         }
151          124    100                         489         if ( !defined $final_props{$key} ) {
152           87                                267            $final_props{$key} = $defaults->{$key};
153           87                                223            MKDEBUG && _d('Copying value for', $key, 'from defaults');
154                                                         }
155                                                      }
156                                                   
157                                                      # Sanity check props
158           14                                 68      foreach my $key ( keys %given_props ) {
159           27    100                         115         die "Unrecognized DSN part '$key' in '$dsn'\n"
160                                                            unless exists $opts{$key};
161                                                      }
162           13    100                          56      if ( (my $required = $self->prop('required')) ) {
163            2                                  9         foreach my $key ( keys %$required ) {
164            2    100                           8            die "Missing DSN part '$key' in '$dsn'\n" unless $final_props{$key};
165                                                         }
166                                                      }
167                                                   
168           12                                131      return \%final_props;
169                                                   }
170                                                   
171                                                   # Like parse() above but takes an OptionParser object instead of
172                                                   # a DSN string.
173                                                   sub parse_options {
174            1                    1            10      my ( $self, $o ) = @_;
175   ***      1     50                           6      die 'I need an OptionParser object' unless ref $o eq 'OptionParser';
176            2                                  9      my $dsn_string
177                                                         = join(',',
178            9    100                          31             map  { "$_=".$o->get($_); }
179            1                                  6             grep { $o->has($_) && $o->get($_) }
180            1                                  3             keys %{$self->{opts}}
181                                                           );
182            1                                  4      MKDEBUG && _d('DSN string made from options:', $dsn_string);
183            1                                  5      return $self->parse($dsn_string);
184                                                   }
185                                                   
186                                                   sub as_string {
187            3                    3            12      my ( $self, $dsn ) = @_;
188            3    100                          16      return $dsn unless ref $dsn;
189            6    100                          46      return join(',',
190           11    100                          80         map  { "$_=" . ($_ eq 'p' ? '...' : $dsn->{$_}) }
191            2                                 17         grep { defined $dsn->{$_} && $self->{opts}->{$_} }
192                                                         sort keys %$dsn );
193                                                   }
194                                                   
195                                                   sub usage {
196            2                    2             9      my ( $self ) = @_;
197            2                                  7      my $usage
198                                                         = "DSN syntax is key=value[,key=value...]  Allowable DSN keys:\n\n"
199                                                         . "  KEY  COPY  MEANING\n"
200                                                         . "  ===  ====  =============================================\n";
201            2                                  6      my %opts = %{$self->{opts}};
               2                                 16   
202            2                                 20      foreach my $key ( sort keys %opts ) {
203           18    100    100                  149         $usage .= "  $key    "
204                                                                .  ($opts{$key}->{copy} ? 'yes   ' : 'no    ')
205                                                                .  ($opts{$key}->{desc} || '[No description]')
206                                                                . "\n";
207                                                      }
208            2                                  7      $usage .= "\n  If the DSN is a bareword, the word is treated as the 'h' key.\n";
209            2                                 13      return $usage;
210                                                   }
211                                                   
212                                                   # Supports PostgreSQL via the dbidriver element of $info, but assumes MySQL by
213                                                   # default.
214                                                   sub get_cxn_params {
215            4                    4            33      my ( $self, $info ) = @_;
216            4                                  9      my $dsn;
217            4                                 12      my %opts = %{$self->{opts}};
               4                                 36   
218            4           100                   22      my $driver = $self->prop('dbidriver') || '';
219            4    100                          16      if ( $driver eq 'Pg' ) {
220            1                                  9         $dsn = 'DBI:Pg:dbname=' . ( $info->{D} || '' ) . ';'
221            2                                  9            . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
222   ***      1            50                    9                        grep { defined $info->{$_} }
223                                                                        qw(h P));
224                                                      }
225                                                      else {
226            8                                 44         $dsn = 'DBI:mysql:' . ( $info->{D} || '' ) . ';'
227           15                                 54            . join(';', map  { "$opts{$_}->{dsn}=$info->{$_}" }
228            3           100                   24                        grep { defined $info->{$_} }
229                                                                        qw(F h P S A))
230                                                            . ';mysql_read_default_group=client';
231                                                      }
232            4                                 12      MKDEBUG && _d($dsn);
233            4                                 40      return ($dsn, $info->{u}, $info->{p});
234                                                   }
235                                                   
236                                                   # Fills in missing info from a DSN after successfully connecting to the server.
237                                                   sub fill_in_dsn {
238            1                    1            18      my ( $self, $dbh, $dsn ) = @_;
239            1                                  3      my $vars = $dbh->selectall_hashref('SHOW VARIABLES', 'Variable_name');
240            1                                  2      my ($user, $db) = $dbh->selectrow_array('SELECT USER(), DATABASE()');
241            1                                237      $user =~ s/@.*//;
242   ***      1            50                    6      $dsn->{h} ||= $vars->{hostname}->{Value};
243   ***      1            50                    8      $dsn->{S} ||= $vars->{'socket'}->{Value};
244   ***      1            50                   40      $dsn->{P} ||= $vars->{port}->{Value};
245   ***      1            50                    6      $dsn->{u} ||= $user;
246   ***      1            50                  116      $dsn->{D} ||= $db;
247                                                   }
248                                                   
249                                                   # Actually opens a connection, then sets some things on the connection so it is
250                                                   # the way the Maatkit tools will expect.  Tools should NEVER open their own
251                                                   # connection or use $dbh->reconnect, or these things will not take place!
252                                                   sub get_dbh {
253            1                    1             6      my ( $self, $cxn_string, $user, $pass, $opts ) = @_;
254   ***      1            50                    5      $opts ||= {};
255   ***      1     50                          16      my $defaults = {
256                                                         AutoCommit         => 0,
257                                                         RaiseError         => 1,
258                                                         PrintError         => 0,
259                                                         ShowErrorStatement => 1,
260                                                         mysql_enable_utf8 => ($cxn_string =~ m/charset=utf8/ ? 1 : 0),
261                                                      };
262            1                                  5      @{$defaults}{ keys %$opts } = values %$opts;
               1                                  4   
263                                                   
264                                                      # Try twice to open the $dbh and set it up as desired.
265            1                                  2      my $dbh;
266            1                                  3      my $tries = 2;
267   ***      1            66                   15      while ( !$dbh && $tries-- ) {
268                                                         MKDEBUG && _d($cxn_string, ' ', $user, ' ', $pass, ' {',
269            1                                  2            join(', ', map { "$_=>$defaults->{$_}" } keys %$defaults ), '}');
270                                                   
271            1                                  3         eval {
272            1                                  8            $dbh = DBI->connect($cxn_string, $user, $pass, $defaults);
273                                                   
274                                                            # If it's a MySQL connection, set some options.
275   ***      1     50                          12            if ( $cxn_string =~ m/mysql/i ) {
276            1                                  3               my $sql;
277                                                   
278                                                               # Set SQL_MODE and options for SHOW CREATE TABLE.
279            1                                  3               $sql = q{SET @@SQL_QUOTE_SHOW_CREATE = 1}
280                                                                    . q{/*!40101, @@SQL_MODE='NO_AUTO_VALUE_ON_ZERO'*/};
281            1                                  2               MKDEBUG && _d($dbh, ':', $sql);
282            1                                143               $dbh->do($sql);
283                                                   
284                                                               # Set character set and binmode on STDOUT.
285   ***      1     50                          19               if ( my ($charset) = $cxn_string =~ m/charset=(\w+)/ ) {
286            1                                  5                  $sql = "/*!40101 SET NAMES $charset*/";
287            1                                  3                  MKDEBUG && _d($dbh, ':', $sql);
288            1                                116                  $dbh->do($sql);
289            1                                  3                  MKDEBUG && _d('Enabling charset for STDOUT');
290   ***      1     50                          18                  if ( $charset eq 'utf8' ) {
291   ***      1     50                          20                     binmode(STDOUT, ':utf8')
292                                                                        or die "Can't binmode(STDOUT, ':utf8'): $OS_ERROR";
293                                                                  }
294                                                                  else {
295   ***      0      0                           0                     binmode(STDOUT) or die "Can't binmode(STDOUT): $OS_ERROR";
296                                                                  }
297                                                               }
298                                                   
299   ***      1     50                           8               if ( $self->prop('setvars') ) {
300   ***      0                                  0                  $sql = "SET " . $self->prop('setvars');
301   ***      0                                  0                  MKDEBUG && _d($dbh, ':', $sql);
302   ***      0                                  0                  $dbh->do($sql);
303                                                               }
304                                                            }
305                                                         };
306   ***      1     50     33                   11         if ( !$dbh && $EVAL_ERROR ) {
307   ***      0                                  0            MKDEBUG && _d($EVAL_ERROR);
308   ***      0      0                           0            if ( $EVAL_ERROR =~ m/not a compiled character set|character set utf8/ ) {
309   ***      0                                  0               MKDEBUG && _d('Going to try again without utf8 support');
310   ***      0                                  0               delete $defaults->{mysql_enable_utf8};
311                                                            }
312   ***      0      0                           0            if ( !$tries ) {
313   ***      0                                  0               die $EVAL_ERROR;
314                                                            }
315                                                         }
316                                                      }
317                                                   
318            1                                  3      MKDEBUG && _d('DBH info: ',
319                                                         $dbh,
320                                                         Dumper($dbh->selectrow_hashref(
321                                                            'SELECT DATABASE(), CONNECTION_ID(), VERSION()/*!50038 , @@hostname*/')),
322                                                         'Connection info:',      $dbh->{mysql_hostinfo},
323                                                         'Character set info:',   Dumper($dbh->selectall_arrayref(
324                                                                        'SHOW VARIABLES LIKE "character_set%"', { Slice => {}})),
325                                                         '$DBD::mysql::VERSION:', $DBD::mysql::VERSION,
326                                                         '$DBI::VERSION:',        $DBI::VERSION,
327                                                      );
328                                                   
329            1                                  6      return $dbh;
330                                                   }
331                                                   
332                                                   # Tries to figure out a hostname for the connection.
333                                                   sub get_hostname {
334   ***      0                    0             0      my ( $self, $dbh ) = @_;
335   ***      0      0      0                    0      if ( my ($host) = ($dbh->{mysql_hostinfo} || '') =~ m/^(\w+) via/ ) {
336   ***      0                                  0         return $host;
337                                                      }
338   ***      0                                  0      my ( $hostname, $one ) = $dbh->selectrow_array(
339                                                         'SELECT /*!50038 @@hostname, */ 1');
340   ***      0                                  0      return $hostname;
341                                                   }
342                                                   
343                                                   # Disconnects a database handle, but complains verbosely if there are any active
344                                                   # children.  These are usually $sth handles that haven't been finish()ed.
345                                                   sub disconnect {
346   ***      0                    0             0      my ( $self, $dbh ) = @_;
347   ***      0                                  0      MKDEBUG && $self->print_active_handles($dbh);
348   ***      0                                  0      $dbh->disconnect;
349                                                   }
350                                                   
351                                                   sub print_active_handles {
352   ***      0                    0             0      my ( $self, $thing, $level ) = @_;
353   ***      0             0                    0      $level ||= 0;
354   ***      0      0      0                    0      printf("# Active %sh: %s %s %s\n", ($thing->{Type} || 'undef'), "\t" x $level,
      ***             0      0                        
      ***                    0                        
355                                                         $thing, (($thing->{Type} || '') eq 'st' ? $thing->{Statement} || '' : ''))
356                                                         or die "Cannot print: $OS_ERROR";
357   ***      0                                  0      foreach my $handle ( grep {defined} @{ $thing->{ChildHandles} } ) {
      ***      0                                  0   
      ***      0                                  0   
358   ***      0                                  0         $self->print_active_handles( $handle, $level + 1 );
359                                                      }
360                                                   }
361                                                   
362                                                   # Copy all set vals in dsn_1 to dsn_2.  Existing val in dsn_2 are not
363                                                   # overwritten unless overwrite=>1 is given, but undef never overwrites a
364                                                   # val.
365                                                   sub copy {
366            2                    2            11      my ( $self, $dsn_1, $dsn_2, %args ) = @_;
367   ***      2     50                           8      die 'I need a dsn_1 argument' unless $dsn_1;
368   ***      2     50                           8      die 'I need a dsn_2 argument' unless $dsn_2;
369           18                                 46      my %new_dsn = map {
370            2                                 12         my $key = $_;
371           18                                 39         my $val;
372           18    100                          59         if ( $args{overwrite} ) {
373            9    100                          39            $val = defined $dsn_1->{$key} ? $dsn_1->{$key} : $dsn_2->{$key};
374                                                         }
375                                                         else {
376            9    100                          38            $val = defined $dsn_2->{$key} ? $dsn_2->{$key} : $dsn_1->{$key};
377                                                         }
378           18                                 77         $key => $val;
379            2                                 11      } keys %{$self->{opts}};
380            2                                 28      return \%new_dsn;
381                                                   }
382                                                   
383                                                   sub _d {
384   ***      0                    0                    my ($package, undef, $line) = caller 0;
385   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
386   ***      0                                              map { defined $_ ? $_ : 'undef' }
387                                                           @_;
388   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
389                                                   }
390                                                   
391                                                   1;
392                                                   
393                                                   # ###########################################################################
394                                                   # End DSNParser package
395                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
95           100      4     18   if (@_ > 2)
117   ***     50      0     14   if (not $dsn)
130          100     25      3   if (my($prop_key, $prop_val) = $dsn_part =~ /^(.)=(.*)$/) { }
145          100     10    114   if (not defined $final_props{$key} and defined $$prev{$key} and $opts{$key}{'copy'})
151          100     87     37   if (not defined $final_props{$key})
159          100      1     26   unless exists $opts{$key}
162          100      2     11   if (my $required = $self->prop('required'))
164          100      1      1   unless $final_props{$key}
175   ***     50      0      1   unless ref $o eq 'OptionParser'
178          100      6      3   if $o->has($_)
188          100      1      2   unless ref $dsn
189          100      1      5   $_ eq 'p' ? :
190          100      7      4   if defined $$dsn{$_}
203          100     16      2   $opts{$key}{'copy'} ? :
219          100      1      3   if ($driver eq 'Pg') { }
255   ***     50      1      0   $cxn_string =~ /charset=utf8/ ? :
275   ***     50      1      0   if ($cxn_string =~ /mysql/i)
285   ***     50      1      0   if (my($charset) = $cxn_string =~ /charset=(\w+)/)
290   ***     50      1      0   if ($charset eq 'utf8') { }
291   ***     50      0      1   unless binmode STDOUT, ':utf8'
295   ***      0      0      0   unless binmode STDOUT
299   ***     50      0      1   if ($self->prop('setvars'))
306   ***     50      0      1   if (not $dbh and $EVAL_ERROR)
308   ***      0      0      0   if ($EVAL_ERROR =~ /not a compiled character set|character set utf8/)
312   ***      0      0      0   if (not $tries)
335   ***      0      0      0   if (my($host) = ($$dbh{'mysql_hostinfo'} || '') =~ /^(\w+) via/)
354   ***      0      0      0   ($$thing{'Type'} || '') eq 'st' ? :
      ***      0      0      0   unless printf "# Active %sh: %s %s %s\n", $$thing{'Type'} || 'undef', "\t" x $level, $thing, ($$thing{'Type'} || '') eq 'st' ? $$thing{'Statement'} || '' : ''
367   ***     50      0      2   unless $dsn_1
368   ***     50      0      2   unless $dsn_2
372          100      9      9   if ($args{'overwrite'}) { }
373          100      4      5   defined $$dsn_1{$key} ? :
376          100      3      6   defined $$dsn_2{$key} ? :
385   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
145          100     27     87     10   not defined $final_props{$key} and defined $$prev{$key}
      ***     66    114      0     10   not defined $final_props{$key} and defined $$prev{$key} and $opts{$key}{'copy'}
267   ***     66      1      0      1   not $dbh and $tries--
306   ***     33      1      0      0   not $dbh and $EVAL_ERROR

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
122          100      5      9   $prev ||= {}
123          100      5      9   $defaults ||= {}
203          100     16      2   $opts{$key}{'desc'} || '[No description]'
218          100      1      3   $self->prop('dbidriver') || ''
222   ***     50      1      0   $$info{'D'} || ''
228          100      2      1   $$info{'D'} || ''
242   ***     50      1      0   $$dsn{'h'} ||= $$vars{'hostname'}{'Value'}
243   ***     50      0      1   $$dsn{'S'} ||= $$vars{'socket'}{'Value'}
244   ***     50      1      0   $$dsn{'P'} ||= $$vars{'port'}{'Value'}
245   ***     50      0      1   $$dsn{'u'} ||= $user
246   ***     50      0      1   $$dsn{'D'} ||= $db
254   ***     50      1      0   $opts ||= {}
335   ***      0      0      0   $$dbh{'mysql_hostinfo'} || ''
353   ***      0      0      0   $level ||= 0
354   ***      0      0      0   $$thing{'Type'} || 'undef'
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
as_string                3 /home/daniel/dev/maatkit/common/DSNParser.pm:187
copy                     2 /home/daniel/dev/maatkit/common/DSNParser.pm:366
fill_in_dsn              1 /home/daniel/dev/maatkit/common/DSNParser.pm:238
get_cxn_params           4 /home/daniel/dev/maatkit/common/DSNParser.pm:215
get_dbh                  1 /home/daniel/dev/maatkit/common/DSNParser.pm:253
new                      2 /home/daniel/dev/maatkit/common/DSNParser.pm:37 
parse                   14 /home/daniel/dev/maatkit/common/DSNParser.pm:116
parse_options            1 /home/daniel/dev/maatkit/common/DSNParser.pm:174
prop                    22 /home/daniel/dev/maatkit/common/DSNParser.pm:94 
usage                    2 /home/daniel/dev/maatkit/common/DSNParser.pm:196

Uncovered Subroutines
---------------------

Subroutine           Count Location                                        
-------------------- ----- ------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/DSNParser.pm:384
disconnect               0 /home/daniel/dev/maatkit/common/DSNParser.pm:346
get_hostname             0 /home/daniel/dev/maatkit/common/DSNParser.pm:334
print_active_handles     0 /home/daniel/dev/maatkit/common/DSNParser.pm:352


