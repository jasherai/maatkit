---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/MySQLFind.pm   95.4   85.4   88.1   94.4    n/a  100.0   91.8
Total                          95.4   85.4   88.1   94.4    n/a  100.0   91.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLFind.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:52:52 2009
Finish:       Fri Jul 31 18:52:54 2009

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
18                                                    # MySQLFind package $Revision: 4162 $
19                                                    # ###########################################################################
20                                                    package MySQLFind;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  6   
               1                                  9   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
26             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  9   
27                                                    $Data::Dumper::Indent    = 0;
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    
30             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  1   
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
64            21                   21           207      my ( $class, %args ) = @_;
65            21                                114      foreach my $arg ( qw(dumper quoter) ) {
66    ***     42     50                         211         die "I need a $arg argument" unless $args{$arg};
67                                                       }
68    ***     21     50                         102      die "Do not pass me a dbh argument" if $args{dbh};
69            21                                127      my $self = bless \%args, $class;
70            21    100    100                  343      $self->{need_engine}
      ***                   66                        
71                                                          = (   $self->{engines}->{permit}
72                                                             || $self->{engines}->{reject}
73                                                             || $self->{engines}->{regexp} ? 1 : 0);
74    ***     21     50     66                  158      die "I need a parser argument"
75                                                          if $self->{need_engine} && !defined $args{parser};
76            21                                 48      MKDEBUG && _d('Need engine:', $self->{need_engine} ? 'yes' : 'no');
77            21    100                         160      $self->{engines}->{views} = 1  unless defined $self->{engines}->{views};
78            21    100                         144      $self->{tables}->{status} = [] unless defined $self->{tables}->{status};
79            21    100                          90      if ( $args{useddl} ) {
80             4                                 15         MKDEBUG && _d('Will prefer DDL');
81                                                       }
82            21                                 90      return $self;
83                                                    }
84                                                    
85                                                    sub init_timestamp {
86             9                    9            31      my ( $self, $dbh ) = @_;
87             9    100                          61      return if $self->{timestamp}->{$dbh}->{now};
88             3                                 10      my $sql = 'SELECT CURRENT_TIMESTAMP';
89             3                                  6      MKDEBUG && _d($sql);
90             3                                  7      ($self->{timestamp}->{$dbh}->{now}) = $dbh->selectrow_array($sql);
91             3                                415      MKDEBUG && _d('Current timestamp:', $self->{timestamp}->{$dbh}->{now});
92                                                    }
93                                                    
94                                                    sub find_databases {
95             7                    7            31      my ( $self, $dbh ) = @_;
96            20                                112      return grep {
97                                                          $_ !~ m/^(information_schema|lost\+found)$/i
98            46                   46           152      }  $self->_filter('databases', sub { $_[0] },
99             7                                116            $self->{dumper}->get_databases(
100                                                               $dbh,
101                                                               $self->{quoter},
102                                                               $self->{databases}->{like}));
103                                                   }
104                                                   
105                                                   sub find_tables {
106           18                   18           117      my ( $self, $dbh, %args ) = @_; 
107                                                   
108                                                      # Get and filter tables by name.
109                                                      my @tables
110           77                   77           333         = $self->_filter('tables', sub { $_[0]->{name} },
111           18                                290            $self->_fetch_tbl_list($dbh, %args));
112                                                   
113                                                      # Ideally, _fetch_tbl_list() wouldn't return broken tables.  When it
114                                                      # calls MySQLDumper::get_table_status() it could filter broken tables,
115                                                      # but not when it calls get_table_list().  So we just filter them here;
116                                                      # MySQLDumper::get_create_table() will fail on broken tables.
117           18                                110      my %broken_table;
118                                                   
119                                                      # Filter tables by engines if needed.
120           18    100                          88      if ( $self->{need_engine} ) {
121            5                                 23         foreach my $tbl ( @tables ) {
122           16    100                          77            next if $tbl->{engine};
123                                                            # Strip db from tbl name. The tbl name was qualified with its
124                                                            # db during _fetch_tbl_list() above.
125           14                                114            my ( $tbl_name ) = $tbl->{name} =~ m/\.(.+)$/;
126           14                                120            my $struct = $self->{parser}->parse(
127                                                               $self->{dumper}->get_create_table(
128                                                                  $dbh, $self->{quoter}, $args{database}, $tbl_name));
129           14    100                          68            $broken_table{$tbl_name} = 1 unless $struct;
130           14                                133            $tbl->{engine} = $struct->{engine};
131                                                         }
132            5                   16            48         @tables = $self->_filter('engines', sub { $_[0]->{engine} }, @tables);
              16                                 68   
133                                                      }
134                                                   
135           18                                127      for my $i ( 0..$#tables ) {
136                                                         # <database>.<table> => <table> 
137           52                                263         $tables[$i]->{name} =~ s/^[^.]*\.//;
138                                                         
139           52    100                         265         if ( $broken_table{$tables[$i]->{name}} ) {
140            1                                  4            MKDEBUG && _d('Removing broken table:', $tables[$i]->{name});
141            1                                  8            delete $tables[$i];
142                                                         }
143                                                      }
144                                                   
145                                                      # Filter tables by status (if any criteria are defined).
146           18                                 51      foreach my $crit ( @{$self->{tables}->{status}} ) {
              18                                 95   
147            3                                 18         my ($key, $test) = %$crit;
148                                                         @tables
149           15                                 63            = grep {
150                                                               # TODO: tests other than date...
151            3                                 12               $self->_test_date($_, $key, $test, $dbh)
152                                                            } @tables;
153                                                      }
154                                                   
155                                                      # Return list of table names.
156           18                                 82      return map { $_->{name} } @tables;
              41                                230   
157                                                   }
158                                                   
159                                                   sub find_views {
160            1                    1             6      my ( $self, $dbh, %args ) = @_;
161            1                                  6      my @tables = $self->_fetch_tbl_list($dbh, %args);
162            1                                  5      @tables = grep { $_->{engine} eq 'VIEW' } @tables;
               5                                 22   
163            1                                  4      map { $_->{name} =~ s/^[^.]*\.// } @tables; # <database>.<table> => <table> 
               1                                 10   
164            1                                  5      return map { $_->{name} } @tables;
               1                                  6   
165                                                   }
166                                                   
167                                                   # USEs the given database, and returns the previous default database.
168                                                   sub _use_db {
169           38                   38           159      my ( $self, $dbh, $new ) = @_;
170           38    100                         155      if ( !$new ) {
171            1                                  3         MKDEBUG && _d('No new DB to use');
172            1                                  4         return;
173                                                      }
174           37                                107      my $sql = 'SELECT DATABASE()';
175           37                                 87      MKDEBUG && _d($sql);
176           37                                 89      my $curr = $dbh->selectrow_array($sql);
177   ***     37    100     66                 5954      if ( $curr && $new && $curr eq $new ) {
                           100                        
178           28                                 65         MKDEBUG && _d('Current and new DB are the same');
179           28                                108         return $curr;
180                                                      }
181            9                                 65      $sql = 'USE ' . $self->{quoter}->quote($new);
182            9                                 20      MKDEBUG && _d($sql);
183            9                                996      $dbh->do($sql);
184            9                                 48      return $curr;
185                                                   }
186                                                   
187                                                   # Returns hashrefs in the format SHOW TABLE STATUS would, but doesn't
188                                                   # necessarily call SHOW TABLE STATUS unless it needs to.  Hash keys are all
189                                                   # lowercase. Table names are returned as <database>.<table> so fully-qualified
190                                                   # matching can be done later on the database name.
191                                                   sub _fetch_tbl_list {
192           19                   19           100      my ( $self, $dbh, %args ) = @_;
193   ***     19     50                          93      die "database is required" unless $args{database};
194                                                   
195           19                                 84      my $curr_db = $self->_use_db($dbh, $args{database});
196                                                   
197                                                      # Get list of table names either with SHOW TABLE STATUS if any status
198                                                      # criteria are defined, else by SHOW TABLES.
199           19                                 55      my @tables;
200           19    100                          52      if ( scalar @{$self->{tables}->{status}} ) {
              19                                111   
201            3                                 32         @tables = $self->{dumper}->get_table_status(
202                                                            $dbh,
203                                                            $self->{quoter},
204                                                            $args{database},
205                                                            $self->{tables}->{like});
206                                                      }
207                                                      else {
208           16                                165         @tables = $self->{dumper}->get_table_list(
209                                                            $dbh,
210                                                            $self->{quoter},
211                                                            $args{database},
212                                                            $self->{tables}->{like});
213                                                      }
214                                                   
215                                                      # 2) map:  Qualify tables with their database.
216                                                      # 1) grep: Remove views if needed.
217           82                                566      @tables = map {
218           84    100                         475         my %hash = %$_;
219           82                                461         $hash{name} = join('.', $args{database}, $hash{name});
220           82                                316         \%hash;
221                                                      }
222                                                      grep {
223           19                                 94         ( $self->{engines}->{views} || ($_->{engine} ne 'VIEW') )
224                                                      } @tables;
225                                                   
226           19                                 94      $self->_use_db($dbh, $curr_db);
227                                                   
228           19                                125      return @tables;
229                                                   }
230                                                   
231                                                   sub _filter {
232           30                   30           191      my ( $self, $thing, $sub, @vals ) = @_;
233           30                                 92      MKDEBUG && _d('Filtering', $thing, 'list on', Dumper($self->{$thing}));
234           30                                149      my $permit = $self->{$thing}->{permit};
235           30                                113      my $reject = $self->{$thing}->{reject};
236           30                                100      my $regexp = $self->{$thing}->{regexp};
237          139                                453      return grep {
238           30                                 97         my $val = $sub->($_);
239          139    100                         507         $val = '' unless defined $val;
240                                                         # 'tables' is a special case, because it can be matched on either the
241                                                         # table name or the database and table name.
242          139    100                         481         if ( $thing eq 'tables' ) {
243           77                                429            (my $tbl = $val) =~ s/^.*\.//;
244           77    100    100                 1434            ( !$reject || (!$reject->{$val} && !$reject->{$tbl}) )
                           100                        
                           100                        
                           100                        
                           100                        
                           100                        
245                                                               && ( !$permit || $permit->{$val} || $permit->{$tbl} )
246                                                               && ( !$regexp || $val =~ m/$regexp/ )
247                                                         }
248                                                         else {
249           62    100    100                  941            ( !$reject || !$reject->{$val} )
                           100                        
                           100                        
                           100                        
250                                                               && ( !$permit || $permit->{$val} )
251                                                               && ( !$regexp || $val =~ m/$regexp/ )
252                                                         }
253                                                      } @vals;
254                                                   }
255                                                   
256                                                   sub _test_date {
257           15                   15            71      my ( $self, $table, $prop, $test, $dbh ) = @_;
258           15                                 51      $prop = lc $prop;
259           15    100                          69      if ( !defined $table->{$prop} ) {
260            6                                 13         MKDEBUG && _d($prop, 'is not defined');
261            6                                 53         return $self->{nullpass};
262                                                      }
263            9                                 68      my ( $equality, $num ) = $test =~ m/^([+-])?(\d+)$/;
264   ***      9     50                          39      die "Invalid date test $test for $prop" unless defined $num;
265            9                                 37      $self->init_timestamp($dbh);
266            9                                 63      my $sql = "SELECT DATE_SUB('$self->{timestamp}->{$dbh}->{now}', "
267                                                              . "INTERVAL $num SECOND)";
268            9                                 18      MKDEBUG && _d($sql);
269            9           100                   33      ($self->{timestamp}->{$dbh}->{$num}) ||= $dbh->selectrow_array($sql);
270            9                                418      my $time = $self->{timestamp}->{$dbh}->{$num};
271                                                      return 
272   ***      9            66                  173            ( $equality eq '-' && $table->{$prop} gt $time )
      ***                   66                        
      ***                   66                        
      ***                   66                        
273                                                         || ( $equality eq '+' && $table->{$prop} lt $time )
274                                                         || (                     $table->{$prop} eq $time );
275                                                   }
276                                                   
277                                                   sub _d {
278   ***      0                    0                    my ($package, undef, $line) = caller 0;
279   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
280   ***      0                                              map { defined $_ ? $_ : 'undef' }
281                                                           @_;
282   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
283                                                   }
284                                                   
285                                                   1;
286                                                   
287                                                   # ###########################################################################
288                                                   # End MySQLFind package
289                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
66    ***     50      0     42   unless $args{$arg}
68    ***     50      0     21   if $args{'dbh'}
70           100      5     16   $$self{'engines'}{'permit'} || $$self{'engines'}{'reject'} || $$self{'engines'}{'regexp'} ? :
74    ***     50      0     21   if $$self{'need_engine'} and not defined $args{'parser'}
77           100     19      2   unless defined $$self{'engines'}{'views'}
78           100     18      3   unless defined $$self{'tables'}{'status'}
79           100      4     17   if ($args{'useddl'})
87           100      6      3   if $$self{'timestamp'}{$dbh}{'now'}
120          100      5     13   if ($$self{'need_engine'})
122          100      2     14   if $$tbl{'engine'}
129          100      1     13   unless $struct
139          100      1     51   if ($broken_table{$tables[$i]{'name'}})
170          100      1     37   if (not $new)
177          100     28      9   if ($curr and $new and $curr eq $new)
193   ***     50      0     19   unless $args{'database'}
200          100      3     16   if (scalar @{$$self{'tables'}{'status'};}) { }
218          100     10     74   unless $$self{'engines'}{'views'}
239          100      1    138   unless defined $val
242          100     77     62   if ($thing eq 'tables') { }
244          100     62     15   if !$reject || !$$reject{$val} && !$$reject{$tbl} and !$permit || $$permit{$val} || $$permit{$tbl}
249          100     33     29   if !$reject || !$$reject{$val} and !$permit || $$permit{$val}
259          100      6      9   if (not defined $$table{$prop})
264   ***     50      0      9   unless defined $num
279   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
74    ***     66     16      5      0   $$self{'need_engine'} and not defined $args{'parser'}
177   ***     66      1      0     36   $curr and $new
             100      1      8     28   $curr and $new and $curr eq $new
244          100      1      1     13   !$$reject{$val} && !$$reject{$tbl}
             100      2     13     62   !$reject || !$$reject{$val} && !$$reject{$tbl} and !$permit || $$permit{$val} || $$permit{$tbl}
249          100      7     22     33   !$reject || !$$reject{$val} and !$permit || $$permit{$val}
272   ***     66      3      6      0   $equality eq '-' && $$table{$prop} gt $time
      ***     66      6      0      3   $equality eq '+' && $$table{$prop} lt $time

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
269          100      6      3   $$self{'timestamp'}{$dbh}{$num} ||= $dbh->selectrow_array($sql)

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
70           100      1      4     16   $$self{'engines'}{'permit'} || $$self{'engines'}{'reject'}
      ***     66      5      0     16   $$self{'engines'}{'permit'} || $$self{'engines'}{'reject'} || $$self{'engines'}{'regexp'}
244          100     57      3      2   not $regexp or $val =~ /$regexp/
             100     62     13      2   !$reject || !$$reject{$val} && !$$reject{$tbl}
             100     60      1     14   !$permit || $$permit{$val}
             100     61      1     13   !$permit || $$permit{$val} || $$permit{$tbl}
249          100     26      2      5   not $regexp or $val =~ /$regexp/
             100     44     11      7   !$reject || !$$reject{$val}
             100     27      6     22   !$permit || $$permit{$val}
272   ***     66      0      3      6   $equality eq '-' && $$table{$prop} gt $time || $equality eq '+' && $$table{$prop} lt $time
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
__ANON__           77 /home/daniel/dev/maatkit/common/MySQLFind.pm:110
__ANON__           16 /home/daniel/dev/maatkit/common/MySQLFind.pm:132
__ANON__           46 /home/daniel/dev/maatkit/common/MySQLFind.pm:98 
_fetch_tbl_list    19 /home/daniel/dev/maatkit/common/MySQLFind.pm:192
_filter            30 /home/daniel/dev/maatkit/common/MySQLFind.pm:232
_test_date         15 /home/daniel/dev/maatkit/common/MySQLFind.pm:257
_use_db            38 /home/daniel/dev/maatkit/common/MySQLFind.pm:169
find_databases      7 /home/daniel/dev/maatkit/common/MySQLFind.pm:95 
find_tables        18 /home/daniel/dev/maatkit/common/MySQLFind.pm:106
find_views          1 /home/daniel/dev/maatkit/common/MySQLFind.pm:160
init_timestamp      9 /home/daniel/dev/maatkit/common/MySQLFind.pm:86 
new                21 /home/daniel/dev/maatkit/common/MySQLFind.pm:64 

Uncovered Subroutines
---------------------

Subroutine      Count Location                                        
--------------- ----- ------------------------------------------------
_d                  0 /home/daniel/dev/maatkit/common/MySQLFind.pm:278


