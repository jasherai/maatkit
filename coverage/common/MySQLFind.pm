---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/MySQLFind.pm   95.2   81.8   88.1   94.4    n/a  100.0   91.1
Total                          95.2   81.8   88.1   94.4    n/a  100.0   91.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLFind.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:31 2009
Finish:       Wed Jun 10 17:20:33 2009

/home/daniel/dev/maatkit/common/MySQLFind.pm

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
18                                                    # MySQLFind package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    package MySQLFind;
21                                                    
22             1                    1            12   use strict;
               1                                  4   
               1                                 15   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                 13   
24                                                    
25             1                    1             7   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
26             1                    1            14   use Data::Dumper;
               1                                  3   
               1                                 15   
27                                                    $Data::Dumper::Indent    = 0;
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    
30             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 12   
31                                                    
32                                                    # SYNOPSIS:
33                                                    #   $f = new MySQLFind(
34                                                    #      dbh       => $dbh,
35                                                    #      quoter    => new Quoter(),
36                                                    #      useddl    => 1/0 (default 0),
37                                                    #      parser    => new TableParser(),
38                                                    #      dumper    => new MySQLDump(),
39                                                    #      nullpass  => 1/0 # whether an undefined status test is true
40                                                    #      databases => {
41                                                    #         permit => { a => 1, b => 1, },
42                                                    #         reject => { ... },
43                                                    #         regexp => 'pattern',
44                                                    #         like   => 'pattern',
45                                                    #      },
46                                                    #      tables => {
47                                                    #         permit => { a => 1, b => 1, },
48                                                    #         reject => { ... },
49                                                    #         regexp => 'pattern',
50                                                    #         like   => 'pattern',
51                                                    #         status => [
52                                                    #            { update => '[+-]seconds' }, # age of Update_time
53                                                    #         ],
54                                                    #      },
55                                                    #      engines => {
56                                                    #         views  => 1/0, # 1 default
57                                                    #         permit => {},
58                                                    #         reject => {},
59                                                    #         regexp => 'pattern',
60                                                    #      },
61                                                    #   );
62                                                    
63                                                    sub new {
64            20                   20           285      my ( $class, %args ) = @_;
65            20                                150      foreach my $arg ( qw(dumper quoter) ) {
66    ***     40     50                         309         die "I need a $arg argument" unless $args{$arg};
67                                                       }
68    ***     20     50                         137      die "Do not pass me a dbh argument" if $args{dbh};
69            20                                312      my $self = bless \%args, $class;
70            20    100    100                  534      $self->{need_engine}
      ***                   66                        
71                                                          = (   $self->{engines}->{permit}
72                                                             || $self->{engines}->{reject}
73                                                             || $self->{engines}->{regexp} ? 1 : 0);
74    ***     20     50     66                  202      die "I need a parser argument"
75                                                          if $self->{need_engine} && !defined $args{parser};
76            20                                 60      MKDEBUG && _d('Need engine:', $self->{need_engine} ? 'yes' : 'no');
77            20    100                         197      $self->{engines}->{views} = 1  unless defined $self->{engines}->{views};
78            20    100                         211      $self->{tables}->{status} = [] unless defined $self->{tables}->{status};
79            20    100                         133      if ( $args{useddl} ) {
80             4                                 17         MKDEBUG && _d('Will prefer DDL');
81                                                       }
82            20                                131      return $self;
83                                                    }
84                                                    
85                                                    sub init_timestamp {
86             9                    9            56      my ( $self, $dbh ) = @_;
87             9    100                         109      return if $self->{timestamp}->{$dbh}->{now};
88             3                                 15      my $sql = 'SELECT CURRENT_TIMESTAMP';
89             3                                  9      MKDEBUG && _d($sql);
90             3                                 10      ($self->{timestamp}->{$dbh}->{now}) = $dbh->selectrow_array($sql);
91             3                                733      MKDEBUG && _d('Current timestamp:', $self->{timestamp}->{$dbh}->{now});
92                                                    }
93                                                    
94                                                    sub find_databases {
95             6                    6            29      my ( $self, $dbh ) = @_;
96            17                                 96      return grep {
97                                                          $_ !~ m/^(information_schema|lost\+found)$/i
98            33                   33           115      }  $self->_filter('databases', sub { $_[0] },
99             6                                 95            $self->{dumper}->get_databases(
100                                                               $dbh,
101                                                               $self->{quoter},
102                                                               $self->{databases}->{like}));
103                                                   }
104                                                   
105                                                   sub find_tables {
106           17                   17           181      my ( $self, $dbh, %args ) = @_; 
107                                                   
108                                                      # Get and filter tables by name.
109                                                      my @tables
110           76                   76           592         = $self->_filter('tables', sub { $_[0]->{name} },
111           17                                302            $self->_fetch_tbl_list($dbh, %args));
112                                                   
113                                                      # Filter tables by engines if needed.
114           17    100                         321      if ( $self->{need_engine} ) {
115            4                                 31         foreach my $tbl ( @tables ) {
116           15    100                         122            next if $tbl->{engine};
117                                                            # Strip db from tbl name. The tbl name was qualified with its
118                                                            # db during _fetch_tbl_list() above.
119           13                                169            my ( $tbl_name ) = $tbl->{name} =~ m/\.(.+)$/;
120           13                                230            my $struct = $self->{parser}->parse(
121                                                               $self->{dumper}->get_create_table(
122                                                                  $dbh, $self->{quoter}, $args{database}, $tbl_name));
123           13                                257            $tbl->{engine} = $struct->{engine};
124                                                         }
125            4                   15            62         @tables = $self->_filter('engines', sub { $_[0]->{engine} }, @tables);
              15                                111   
126                                                      }
127                                                   
128                                                      # <database>.<table> => <table> 
129           17                                114      map { $_->{name} =~ s/^[^.]*\.// } @tables;
              51                                489   
130                                                   
131                                                      # Filter tables by status (if any criteria are defined).
132           17                                 80      foreach my $crit ( @{$self->{tables}->{status}} ) {
              17                                155   
133            3                                 29         my ($key, $test) = %$crit;
134                                                         @tables
135           15                                105            = grep {
136                                                               # TODO: tests other than date...
137            3                                 18               $self->_test_date($_, $key, $test, $dbh)
138                                                            } @tables;
139                                                      }
140                                                   
141                                                      # Return list of table names.
142           17                                111      return map { $_->{name} } @tables;
              41                                382   
143                                                   }
144                                                   
145                                                   sub find_views {
146            1                    1            12      my ( $self, $dbh, %args ) = @_;
147            1                                 11      my @tables = $self->_fetch_tbl_list($dbh, %args);
148            1                                  8      @tables = grep { $_->{engine} eq 'VIEW' } @tables;
               5                                 38   
149            1                                  6      map { $_->{name} =~ s/^[^.]*\.// } @tables; # <database>.<table> => <table> 
               1                                 16   
150            1                                  6      return map { $_->{name} } @tables;
               1                                 12   
151                                                   }
152                                                   
153                                                   # USEs the given database, and returns the previous default database.
154                                                   sub _use_db {
155           36                   36           258      my ( $self, $dbh, $new ) = @_;
156           36    100                         244      if ( !$new ) {
157            1                                  5         MKDEBUG && _d('No new DB to use');
158            1                                  5         return;
159                                                      }
160           35                                151      my $sql = 'SELECT DATABASE()';
161           35                                110      MKDEBUG && _d($sql);
162           35                                130      my $curr = $dbh->selectrow_array($sql);
163   ***     35    100     66                11382      if ( $curr && $new && $curr eq $new ) {
                           100                        
164           28                                 99         MKDEBUG && _d('Current and new DB are the same');
165           28                                207         return $curr;
166                                                      }
167            7                                119      $sql = 'USE ' . $self->{quoter}->quote($new);
168            7                                 25      MKDEBUG && _d($sql);
169            7                               1130      $dbh->do($sql);
170            7                                 60      return $curr;
171                                                   }
172                                                   
173                                                   # Returns hashrefs in the format SHOW TABLE STATUS would, but doesn't
174                                                   # necessarily call SHOW TABLE STATUS unless it needs to.  Hash keys are all
175                                                   # lowercase. Table names are returned as <database>.<table> so fully-qualified
176                                                   # matching can be done later on the database name.
177                                                   sub _fetch_tbl_list {
178           18                   18           167      my ( $self, $dbh, %args ) = @_;
179   ***     18     50                         146      die "database is required" unless $args{database};
180                                                   
181           18                                153      my $curr_db = $self->_use_db($dbh, $args{database});
182                                                   
183                                                      # Get list of table names either with SHOW TABLE STATUS if any status
184                                                      # criteria are defined, else by SHOW TABLES.
185           18                                 80      my @tables;
186           18    100                          69      if ( scalar @{$self->{tables}->{status}} ) {
              18                                185   
187            3                                 53         @tables = $self->{dumper}->get_table_status(
188                                                            $dbh,
189                                                            $self->{quoter},
190                                                            $args{database},
191                                                            $self->{tables}->{like});
192                                                      }
193                                                      else {
194           15                                281         @tables = $self->{dumper}->get_table_list(
195                                                            $dbh,
196                                                            $self->{quoter},
197                                                            $args{database},
198                                                            $self->{tables}->{like});
199                                                      }
200                                                   
201                                                      # 2) map:  Qualify tables with their database.
202                                                      # 1) grep: Remove views if needed.
203           81                               1002      @tables = map {
204           83    100                         794         my %hash = %$_;
205           81                                782         $hash{name} = join('.', $args{database}, $hash{name});
206           81                                491         \%hash;
207                                                      }
208                                                      grep {
209           18                                147         ( $self->{engines}->{views} || ($_->{engine} ne 'VIEW') )
210                                                      } @tables;
211                                                   
212           18                                151      $self->_use_db($dbh, $curr_db);
213                                                   
214           18                                213      return @tables;
215                                                   }
216                                                   
217                                                   sub _filter {
218           27                   27           259      my ( $self, $thing, $sub, @vals ) = @_;
219           27                                107      MKDEBUG && _d('Filtering', $thing, 'list on', Dumper($self->{$thing}));
220           27                                262      my $permit = $self->{$thing}->{permit};
221           27                                153      my $reject = $self->{$thing}->{reject};
222           27                                155      my $regexp = $self->{$thing}->{regexp};
223          124                                645      return grep {
224           27                                131         my $val = $sub->($_);
225   ***    124     50                         689         $val = '' unless defined $val;
226                                                         # 'tables' is a special case, because it can be matched on either the
227                                                         # table name or the database and table name.
228          124    100                         638         if ( $thing eq 'tables' ) {
229           76                                713            (my $tbl = $val) =~ s/^.*\.//;
230           76    100    100                 2674            ( !$reject || (!$reject->{$val} && !$reject->{$tbl}) )
                           100                        
                           100                        
                           100                        
                           100                        
                           100                        
231                                                               && ( !$permit || $permit->{$val} || $permit->{$tbl} )
232                                                               && ( !$regexp || $val =~ m/$regexp/ )
233                                                         }
234                                                         else {
235           48    100    100                  974            ( !$reject || !$reject->{$val} )
                           100                        
                           100                        
                           100                        
236                                                               && ( !$permit || $permit->{$val} )
237                                                               && ( !$regexp || $val =~ m/$regexp/ )
238                                                         }
239                                                      } @vals;
240                                                   }
241                                                   
242                                                   sub _test_date {
243           15                   15           132      my ( $self, $table, $prop, $test, $dbh ) = @_;
244           15                                 86      $prop = lc $prop;
245           15    100                         119      if ( !defined $table->{$prop} ) {
246            6                                 19         MKDEBUG && _d($prop, 'is not defined');
247            6                                 99         return $self->{nullpass};
248                                                      }
249            9                                110      my ( $equality, $num ) = $test =~ m/^([+-])?(\d+)$/;
250   ***      9     50                          64      die "Invalid date test $test for $prop" unless defined $num;
251            9                                 98      $self->init_timestamp($dbh);
252            9                                116      my $sql = "SELECT DATE_SUB('$self->{timestamp}->{$dbh}->{now}', "
253                                                              . "INTERVAL $num SECOND)";
254            9                                 28      MKDEBUG && _d($sql);
255            9           100                   66      ($self->{timestamp}->{$dbh}->{$num}) ||= $dbh->selectrow_array($sql);
256            9                                725      my $time = $self->{timestamp}->{$dbh}->{$num};
257                                                      return 
258   ***      9            66                  325            ( $equality eq '-' && $table->{$prop} gt $time )
      ***                   66                        
      ***                   66                        
      ***                   66                        
259                                                         || ( $equality eq '+' && $table->{$prop} lt $time )
260                                                         || (                     $table->{$prop} eq $time );
261                                                   }
262                                                   
263                                                   sub _d {
264   ***      0                    0                    my ($package, undef, $line) = caller 0;
265   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
266   ***      0                                              map { defined $_ ? $_ : 'undef' }
267                                                           @_;
268   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
269                                                   }
270                                                   
271                                                   1;
272                                                   
273                                                   # ###########################################################################
274                                                   # End MySQLFind package
275                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
66    ***     50      0     40   unless $args{$arg}
68    ***     50      0     20   if $args{'dbh'}
70           100      4     16   $$self{'engines'}{'permit'} || $$self{'engines'}{'reject'} || $$self{'engines'}{'regexp'} ? :
74    ***     50      0     20   if $$self{'need_engine'} and not defined $args{'parser'}
77           100     18      2   unless defined $$self{'engines'}{'views'}
78           100     17      3   unless defined $$self{'tables'}{'status'}
79           100      4     16   if ($args{'useddl'})
87           100      6      3   if $$self{'timestamp'}{$dbh}{'now'}
114          100      4     13   if ($$self{'need_engine'})
116          100      2     13   if $$tbl{'engine'}
156          100      1     35   if (not $new)
163          100     28      7   if ($curr and $new and $curr eq $new)
179   ***     50      0     18   unless $args{'database'}
186          100      3     15   if (scalar @{$$self{'tables'}{'status'};}) { }
204          100     10     73   unless $$self{'engines'}{'views'}
225   ***     50      0    124   unless defined $val
228          100     76     48   if ($thing eq 'tables') { }
230          100     61     15   if !$reject || !$$reject{$val} && !$$reject{$tbl} and !$permit || $$permit{$val} || $$permit{$tbl}
235          100     28     20   if !$reject || !$$reject{$val} and !$permit || $$permit{$val}
245          100      6      9   if (not defined $$table{$prop})
250   ***     50      0      9   unless defined $num
265   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
74    ***     66     16      4      0   $$self{'need_engine'} and not defined $args{'parser'}
163   ***     66      1      0     34   $curr and $new
             100      1      6     28   $curr and $new and $curr eq $new
230          100      1      1     13   !$$reject{$val} && !$$reject{$tbl}
             100      2     13     61   !$reject || !$$reject{$val} && !$$reject{$tbl} and !$permit || $$permit{$val} || $$permit{$tbl}
235          100      7     13     28   !$reject || !$$reject{$val} and !$permit || $$permit{$val}
258   ***     66      3      6      0   $equality eq '-' && $$table{$prop} gt $time
      ***     66      6      0      3   $equality eq '+' && $$table{$prop} lt $time

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
255          100      6      3   $$self{'timestamp'}{$dbh}{$num} ||= $dbh->selectrow_array($sql)

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
70           100      1      3     16   $$self{'engines'}{'permit'} || $$self{'engines'}{'reject'}
      ***     66      4      0     16   $$self{'engines'}{'permit'} || $$self{'engines'}{'reject'} || $$self{'engines'}{'regexp'}
230          100     56      3      2   not $regexp or $val =~ /$regexp/
             100     61     13      2   !$reject || !$$reject{$val} && !$$reject{$tbl}
             100     59      1     14   !$permit || $$permit{$val}
             100     60      1     13   !$permit || $$permit{$val} || $$permit{$tbl}
235          100     22      2      4   not $regexp or $val =~ /$regexp/
             100     32      9      7   !$reject || !$$reject{$val}
             100     23      5     13   !$permit || $$permit{$val}
258   ***     66      0      3      6   $equality eq '-' && $$table{$prop} gt $time || $equality eq '+' && $$table{$prop} lt $time
      ***     66      3      0      6   $equality eq '-' && $$table{$prop} gt $time || $equality eq '+' && $$table{$prop} lt $time || $$table{$prop} eq $time


Covered Subroutines
-------------------

Subroutine      Count Location                                        
--------------- ----- ------------------------------------------------
BEGIN               1 /home/daniel/dev/maatkit/common/MySQLFind.pm:22 
BEGIN               1 /home/daniel/dev/maatkit/common/MySQLFind.pm:23 
BEGIN               1 /home/daniel/dev/maatkit/common/MySQLFind.pm:25 
BEGIN               1 /home/daniel/dev/maatkit/common/MySQLFind.pm:26 
BEGIN               1 /home/daniel/dev/maatkit/common/MySQLFind.pm:30 
__ANON__           76 /home/daniel/dev/maatkit/common/MySQLFind.pm:110
__ANON__           15 /home/daniel/dev/maatkit/common/MySQLFind.pm:125
__ANON__           33 /home/daniel/dev/maatkit/common/MySQLFind.pm:98 
_fetch_tbl_list    18 /home/daniel/dev/maatkit/common/MySQLFind.pm:178
_filter            27 /home/daniel/dev/maatkit/common/MySQLFind.pm:218
_test_date         15 /home/daniel/dev/maatkit/common/MySQLFind.pm:243
_use_db            36 /home/daniel/dev/maatkit/common/MySQLFind.pm:155
find_databases      6 /home/daniel/dev/maatkit/common/MySQLFind.pm:95 
find_tables        17 /home/daniel/dev/maatkit/common/MySQLFind.pm:106
find_views          1 /home/daniel/dev/maatkit/common/MySQLFind.pm:146
init_timestamp      9 /home/daniel/dev/maatkit/common/MySQLFind.pm:86 
new                20 /home/daniel/dev/maatkit/common/MySQLFind.pm:64 

Uncovered Subroutines
---------------------

Subroutine      Count Location                                        
--------------- ----- ------------------------------------------------
_d                  0 /home/daniel/dev/maatkit/common/MySQLFind.pm:264


