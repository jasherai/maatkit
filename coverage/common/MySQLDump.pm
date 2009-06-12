---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/MySQLDump.pm   65.1   46.3   22.7   73.3    n/a  100.0   56.2
Total                          65.1   46.3   22.7   73.3    n/a  100.0   56.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLDump.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:29 2009
Finish:       Wed Jun 10 17:20:29 2009

/home/daniel/dev/maatkit/common/MySQLDump.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-@CURRENTVERSION@ Baron Schwartz.
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
18                                                    # MySQLDump package $Revision: 3312 $
19                                                    # ###########################################################################
20                                                    package MySQLDump;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
28                                                    
29                                                    ( our $before = <<'EOF') =~ s/^   //gm;
30                                                       /*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
31                                                       /*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
32                                                       /*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
33                                                       /*!40101 SET NAMES utf8 */;
34                                                       /*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
35                                                       /*!40103 SET TIME_ZONE='+00:00' */;
36                                                       /*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
37                                                       /*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
38                                                       /*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
39                                                       /*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
40                                                    EOF
41                                                    
42                                                    ( our $after = <<'EOF') =~ s/^   //gm;
43                                                       /*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;
44                                                       /*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
45                                                       /*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
46                                                       /*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
47                                                       /*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
48                                                       /*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
49                                                       /*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
50                                                       /*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
51                                                    EOF
52                                                    
53                                                    # Arguments:
54                                                    # * cache: defaults to 1
55                                                    sub new {
56             1                    1             6      my ( $class, %args ) = @_;
57    ***      1     50                           7      $args{cache} = 1 unless defined $args{cache};
58             1                                 15      my $self = bless \%args, $class;
59             1                                  5      return $self;
60                                                    }
61                                                    
62                                                    sub dump {
63             5                    5            35      my ( $self, $dbh, $quoter, $db, $tbl, $what ) = @_;
64                                                    
65             5    100                          37      if ( $what eq 'table' ) {
                    100                               
      ***            50                               
66             2                                 11         my $ddl = $self->get_create_table($dbh, $quoter, $db, $tbl);
67             2    100                          12         if ( $ddl->[0] eq 'table' ) {
68             1                                  7            return $before
69                                                                . 'DROP TABLE IF EXISTS ' . $quoter->quote($tbl) . ";\n"
70                                                                . $ddl->[1] . ";\n";
71                                                          }
72                                                          else {
73             1                                  6            return 'DROP TABLE IF EXISTS ' . $quoter->quote($tbl) . ";\n"
74                                                                . '/*!50001 DROP VIEW IF EXISTS '
75                                                                . $quoter->quote($tbl) . "*/;\n/*!50001 "
76                                                                . $self->get_tmp_table($dbh, $quoter, $db, $tbl) . "*/;\n";
77                                                          }
78                                                       }
79                                                       elsif ( $what eq 'triggers' ) {
80             2                                 10         my $trgs = $self->get_triggers($dbh, $quoter, $db, $tbl);
81    ***      2    100     66                   17         if ( $trgs && @$trgs ) {
82             1                                  7            my $result = $before . "\nDELIMITER ;;\n";
83             1                                  4            foreach my $trg ( @$trgs ) {
84    ***      3     50                          14               if ( $trg->{sql_mode} ) {
85             3                                 13                  $result .= qq{/*!50003 SET SESSION SQL_MODE='$trg->{sql_mode}' */;;\n};
86                                                                }
87             3                                 10               $result .= "/*!50003 CREATE */ ";
88    ***      3     50                          13               if ( $trg->{definer} ) {
89             6                                 17                  my ( $user, $host )
90             3                                 16                     = map { s/'/''/g; "'$_'"; }
               6                                 26   
91                                                                        split('@', $trg->{definer}, 2);
92             3                                 19                  $result .= "/*!50017 DEFINER=$user\@$host */ ";
93                                                                }
94             3                                 17               $result .= sprintf("/*!50003 TRIGGER %s %s %s ON %s\nFOR EACH ROW %s */;;\n\n",
95                                                                   $quoter->quote($trg->{trigger}),
96             3                                 16                  @{$trg}{qw(timing event)},
97                                                                   $quoter->quote($trg->{table}),
98                                                                   $trg->{statement});
99                                                             }
100            1                                  4            $result .= "DELIMITER ;\n\n/*!50003 SET SESSION SQL_MODE=\@OLD_SQL_MODE */;\n\n";
101            1                                  7            return $result;
102                                                         }
103                                                         else {
104            1                                  5            return undef;
105                                                         }
106                                                      }
107                                                      elsif ( $what eq 'view' ) {
108            1                                  6         my $ddl = $self->get_create_table($dbh, $quoter, $db, $tbl);
109            1                                  6         return '/*!50001 DROP TABLE IF EXISTS ' . $quoter->quote($tbl) . "*/;\n"
110                                                            . '/*!50001 DROP VIEW IF EXISTS ' . $quoter->quote($tbl) . "*/;\n"
111                                                            . '/*!50001 ' . $ddl->[1] . "*/;\n";
112                                                      }
113                                                      else {
114   ***      0                                  0         die "You didn't say what to dump.";
115                                                      }
116                                                   }
117                                                   
118                                                   # USEs the given database, and returns the previous default database.
119                                                   sub _use_db {
120            6                    6            30      my ( $self, $dbh, $quoter, $new ) = @_;
121            6    100                          27      if ( !$new ) {
122            1                                  2         MKDEBUG && _d('No new DB to use');
123            1                                  3         return;
124                                                      }
125            5                                 13      my $sql = 'SELECT DATABASE()';
126            5                                 10      MKDEBUG && _d($sql);
127            5                                 13      my $curr = $dbh->selectrow_array($sql);
128   ***      5    100     66                  796      if ( $curr && $new && $curr eq $new ) {
      ***                   66                        
129            4                                 11         MKDEBUG && _d('Current and new DB are the same');
130            4                                 16         return $curr;
131                                                      }
132            1                                  6      $sql = 'USE ' . $quoter->quote($new);
133            1                                  3      MKDEBUG && _d($sql);
134            1                                113      $dbh->do($sql);
135            1                                  5      return $curr;
136                                                   }
137                                                   
138                                                   sub get_create_table {
139            3                    3            18      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
140   ***      3    100     66                   44      if ( !$self->{cache} || !$self->{tables}->{$db}->{$tbl} ) {
141            2                                  7         my $sql = '/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
142                                                            . q{@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, 'ANSI_QUOTES', ''), ',,', ','), }
143                                                            . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
144                                                            . '@@SQL_QUOTE_SHOW_CREATE := 1 */';
145            2                                  5         MKDEBUG && _d($sql);
146            2                                  5         eval { $dbh->do($sql); };
               2                                483   
147            2                                  6         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
148            2                                 12         my $curr_db = $self->_use_db($dbh, $quoter, $db);
149            2                                 10         $sql = "SHOW CREATE TABLE " . $quoter->quote($db, $tbl);
150            2                                  5         MKDEBUG && _d($sql);
151            2                                  6         my $href = $dbh->selectrow_hashref($sql);
152            2                                 14         $self->_use_db($dbh, $quoter, $curr_db);
153            2                                  6         $sql = '/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
154                                                            . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */';
155            2                                  4         MKDEBUG && _d($sql);
156            2                                242         $dbh->do($sql);
157            2                                 12         my ($key) = grep { m/create table/i } keys %$href;
               4                                 21   
158            2    100                          10         if ( $key ) {
159            1                                  3            MKDEBUG && _d('This table is a base table');
160            1                                 10            $self->{tables}->{$db}->{$tbl} = [ 'table', $href->{$key} ];
161                                                         }
162                                                         else {
163            1                                  3            MKDEBUG && _d('This table is a view');
164            1                                  5            ($key) = grep { m/create view/i } keys %$href;
               2                                 12   
165            1                                 10            $self->{tables}->{$db}->{$tbl} = [ 'view', $href->{$key} ];
166                                                         }
167                                                      }
168            3                                 19      return $self->{tables}->{$db}->{$tbl};
169                                                   }
170                                                   
171                                                   sub get_columns {
172            1                    1             5      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
173            1                                  3      MKDEBUG && _d('Get columns for', $db, $tbl);
174   ***      1     50     33                   14      if ( !$self->{cache} || !$self->{columns}->{$db}->{$tbl} ) {
175            1                                  4         my $curr_db = $self->_use_db($dbh, $quoter, $db);
176            1                                  6         my $sql = "SHOW COLUMNS FROM " . $quoter->quote($db, $tbl);
177            1                                  3         MKDEBUG && _d($sql);
178            1                                 22         my $cols = $dbh->selectall_arrayref($sql, { Slice => {} });
179            1                                 11         $self->_use_db($dbh, $quoter, $curr_db);
180            9                                 19         $self->{columns}->{$db}->{$tbl} = [
181                                                            map {
182            1                                  5               my %row;
183            9                                 47               @row{ map { lc $_ } keys %$_ } = values %$_;
              54                                189   
184            9                                 49               \%row;
185                                                            } @$cols
186                                                         ];
187                                                      }
188            1                                  8      return $self->{columns}->{$db}->{$tbl};
189                                                   }
190                                                   
191                                                   sub get_tmp_table {
192            1                    1             7      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
193            1                                  5      my $result = 'CREATE TABLE ' . $quoter->quote($tbl) . " (\n";
194            9                                 41      $result .= join(",\n",
195            1                                  7         map { '  ' . $quoter->quote($_->{field}) . ' ' . $_->{type} }
196            1                                  5         @{$self->get_columns($dbh, $quoter, $db, $tbl)});
197            1                                  5      $result .= "\n)";
198            1                                  2      MKDEBUG && _d($result);
199            1                                  9      return $result;
200                                                   }
201                                                   
202                                                   sub get_triggers {
203            2                    2            10      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
204   ***      2     50     33                   27      if ( !$self->{cache} || !$self->{triggers}->{$db} ) {
205            2                                  9         $self->{triggers}->{$db} = {};
206            2                                  9         my $sql = '/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
207                                                            . q{@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, 'ANSI_QUOTES', ''), ',,', ','), }
208                                                            . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
209                                                            . '@@SQL_QUOTE_SHOW_CREATE := 1 */';
210            2                                  4         MKDEBUG && _d($sql);
211            2                                  6         eval { $dbh->do($sql); };
               2                                354   
212            2                                  7         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
213            2                                 10         $sql = "SHOW TRIGGERS FROM " . $quoter->quote($db);
214            2                                  4         MKDEBUG && _d($sql);
215            2                                  4         my $sth = $dbh->prepare($sql);
216            2                               2554         $sth->execute();
217            2    100                          65         if ( $sth->rows ) {
218            1                                 34            my $trgs = $sth->fetchall_arrayref({});
219            1                                  9            foreach my $trg (@$trgs) {
220                                                               # Lowercase the hash keys because the NAME_lc property might be set
221                                                               # on the $dbh, so the lettercase is unpredictable.  This makes them
222                                                               # predictable.
223            6                                 14               my %trg;
224            6                                 32               @trg{ map { lc $_ } keys %$trg } = values %$trg;
              48                                168   
225            6                                 24               push @{ $self->{triggers}->{$db}->{ $trg{table} } }, \%trg;
               6                                 49   
226                                                            }
227                                                         }
228            2                                  9         $sql = '/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
229                                                            . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */';
230            2                                  5         MKDEBUG && _d($sql);
231            2                                318         $dbh->do($sql);
232                                                      }
233   ***      2     50                          11      if ( $tbl ) {
234            2                                 15         return $self->{triggers}->{$db}->{$tbl};
235                                                      }
236   ***      0                                         return values %{$self->{triggers}->{$db}};
      ***      0                                      
237                                                   }
238                                                   
239                                                   sub get_databases {
240   ***      0                    0                    my ( $self, $dbh, $quoter, $like ) = @_;
241   ***      0      0      0                           if ( !$self->{cache} || !$self->{databases} || $like ) {
      ***                    0                        
242   ***      0                                            my $sql = 'SHOW DATABASES';
243   ***      0                                            my @params;
244   ***      0      0                                     if ( $like ) {
245   ***      0                                               $sql .= ' LIKE ?';
246   ***      0                                               push @params, $like;
247                                                         }
248   ***      0                                            my $sth = $dbh->prepare($sql);
249   ***      0                                            MKDEBUG && _d($sql, @params);
250   ***      0                                            $sth->execute( @params );
251   ***      0                                            my @dbs = map { $_->[0] } @{$sth->fetchall_arrayref()};
      ***      0                                      
      ***      0                                      
252   ***      0      0                                     $self->{databases} = \@dbs unless $like;
253   ***      0                                            return @dbs;
254                                                      }
255   ***      0                                         return @{$self->{databases}};
      ***      0                                      
256                                                   }
257                                                   
258                                                   sub get_table_status {
259   ***      0                    0                    my ( $self, $dbh, $quoter, $db, $like ) = @_;
260   ***      0      0      0                           if ( !$self->{cache} || !$self->{table_status}->{$db} || $like ) {
      ***                    0                        
261   ***      0                                            my $sql = "SHOW TABLE STATUS FROM " . $quoter->quote($db);
262   ***      0                                            my @params;
263   ***      0      0                                     if ( $like ) {
264   ***      0                                               $sql .= ' LIKE ?';
265   ***      0                                               push @params, $like;
266                                                         }
267   ***      0                                            MKDEBUG && _d($sql, @params);
268   ***      0                                            my $sth = $dbh->prepare($sql);
269   ***      0                                            $sth->execute(@params);
270   ***      0                                            my @tables = @{$sth->fetchall_arrayref({})};
      ***      0                                      
271   ***      0                                            @tables = map {
272   ***      0                                               my %tbl; # Make a copy with lowercased keys
273   ***      0                                               @tbl{ map { lc $_ } keys %$_ } = values %$_;
      ***      0                                      
274   ***      0             0                                 $tbl{engine} ||= $tbl{type} || $tbl{comment};
      ***                    0                        
275   ***      0                                               delete $tbl{type};
276   ***      0                                               \%tbl;
277                                                         } @tables;
278   ***      0      0                                     $self->{table_status}->{$db} = \@tables unless $like;
279   ***      0                                            return @tables;
280                                                      }
281   ***      0                                         return @{$self->{table_status}->{$db}};
      ***      0                                      
282                                                   }
283                                                   
284                                                   sub get_table_list {
285   ***      0                    0                    my ( $self, $dbh, $quoter, $db, $like ) = @_;
286   ***      0      0      0                           if ( !$self->{cache} || !$self->{table_list}->{$db} || $like ) {
      ***                    0                        
287   ***      0                                            my $sql = "SHOW /*!50002 FULL*/ TABLES FROM " . $quoter->quote($db);
288   ***      0                                            my @params;
289   ***      0      0                                     if ( $like ) {
290   ***      0                                               $sql .= ' LIKE ?';
291   ***      0                                               push @params, $like;
292                                                         }
293   ***      0                                            MKDEBUG && _d($sql, @params);
294   ***      0                                            my $sth = $dbh->prepare($sql);
295   ***      0                                            $sth->execute(@params);
296   ***      0                                            my @tables = @{$sth->fetchall_arrayref()};
      ***      0                                      
297   ***      0      0      0                              @tables = map {
298   ***      0                                               my %tbl = (
299                                                               name   => $_->[0],
300                                                               engine => ($_->[1] || '') eq 'VIEW' ? 'VIEW' : '',
301                                                            );
302   ***      0                                               \%tbl;
303                                                         } @tables;
304   ***      0      0                                     $self->{table_list}->{$db} = \@tables unless $like;
305   ***      0                                            return @tables;
306                                                      }
307   ***      0                                         return @{$self->{table_list}->{$db}};
      ***      0                                      
308                                                   }
309                                                   
310                                                   sub _d {
311   ***      0                    0                    my ($package, undef, $line) = caller 0;
312   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
313   ***      0                                              map { defined $_ ? $_ : 'undef' }
314                                                           @_;
315   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
316                                                   }
317                                                   
318                                                   1;
319                                                   
320                                                   # ###########################################################################
321                                                   # End MySQLDump package
322                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
57    ***     50      1      0   unless defined $args{'cache'}
65           100      2      3   if ($what eq 'table') { }
             100      2      1   elsif ($what eq 'triggers') { }
      ***     50      1      0   elsif ($what eq 'view') { }
67           100      1      1   if ($$ddl[0] eq 'table') { }
81           100      1      1   if ($trgs and @$trgs) { }
84    ***     50      3      0   if ($$trg{'sql_mode'})
88    ***     50      3      0   if ($$trg{'definer'})
121          100      1      5   if (not $new)
128          100      4      1   if ($curr and $new and $curr eq $new)
140          100      2      1   if (not $$self{'cache'} or not $$self{'tables'}{$db}{$tbl})
158          100      1      1   if ($key) { }
174   ***     50      1      0   if (not $$self{'cache'} or not $$self{'columns'}{$db}{$tbl})
204   ***     50      2      0   if (not $$self{'cache'} or not $$self{'triggers'}{$db})
217          100      1      1   if ($sth->rows)
233   ***     50      2      0   if ($tbl)
241   ***      0      0      0   if (not $$self{'cache'} or not $$self{'databases'} or $like)
244   ***      0      0      0   if ($like)
252   ***      0      0      0   unless $like
260   ***      0      0      0   if (not $$self{'cache'} or not $$self{'table_status'}{$db} or $like)
263   ***      0      0      0   if ($like)
278   ***      0      0      0   unless $like
286   ***      0      0      0   if (not $$self{'cache'} or not $$self{'table_list'}{$db} or $like)
289   ***      0      0      0   if ($like)
297   ***      0      0      0   ($$_[1] || '') eq 'VIEW' ? :
304   ***      0      0      0   unless $like
312   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
81    ***     66      1      0      1   $trgs and @$trgs
128   ***     66      1      0      4   $curr and $new
      ***     66      1      0      4   $curr and $new and $curr eq $new

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
297   ***      0      0      0   $$_[1] || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
140   ***     66      0      2      1   not $$self{'cache'} or not $$self{'tables'}{$db}{$tbl}
174   ***     33      0      1      0   not $$self{'cache'} or not $$self{'columns'}{$db}{$tbl}
204   ***     33      0      2      0   not $$self{'cache'} or not $$self{'triggers'}{$db}
241   ***      0      0      0      0   not $$self{'cache'} or not $$self{'databases'}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'databases'} or $like
260   ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_status'}{$db}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_status'}{$db} or $like
274   ***      0      0      0      0   $tbl{'type'} || $tbl{'comment'}
      ***      0      0      0      0   $tbl{'engine'} ||= $tbl{'type'} || $tbl{'comment'}
286   ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_list'}{$db}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_list'}{$db} or $like


Covered Subroutines
-------------------

Subroutine       Count Location                                        
---------------- ----- ------------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:22 
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:23 
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:25 
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:27 
_use_db              6 /home/daniel/dev/maatkit/common/MySQLDump.pm:120
dump                 5 /home/daniel/dev/maatkit/common/MySQLDump.pm:63 
get_columns          1 /home/daniel/dev/maatkit/common/MySQLDump.pm:172
get_create_table     3 /home/daniel/dev/maatkit/common/MySQLDump.pm:139
get_tmp_table        1 /home/daniel/dev/maatkit/common/MySQLDump.pm:192
get_triggers         2 /home/daniel/dev/maatkit/common/MySQLDump.pm:203
new                  1 /home/daniel/dev/maatkit/common/MySQLDump.pm:56 

Uncovered Subroutines
---------------------

Subroutine       Count Location                                        
---------------- ----- ------------------------------------------------
_d                   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:311
get_databases        0 /home/daniel/dev/maatkit/common/MySQLDump.pm:240
get_table_list       0 /home/daniel/dev/maatkit/common/MySQLDump.pm:285
get_table_status     0 /home/daniel/dev/maatkit/common/MySQLDump.pm:259


