---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/MySQLDump.pm   63.5   44.4   15.0   73.3    0.0   66.3   52.6
MySQLDump.t                   100.0   50.0   33.3  100.0    n/a   33.7   94.3
Total                          73.0   45.0   16.3   84.6    0.0  100.0   61.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:17 2010
Finish:       Thu Jun 24 19:35:17 2010

Run:          MySQLDump.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:18 2010
Finish:       Thu Jun 24 19:35:18 2010

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
18                                                    # MySQLDump package $Revision: 6345 $
19                                                    # ###########################################################################
20                                                    package MySQLDump;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                 10   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                 10   
24                                                    
25             1                    1             9   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 18   
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
53                                                    sub new {
54    ***      1                    1      0      6      my ( $class, %args ) = @_;
55             1                                  5      my $self = {
56                                                          cache => 0,  # Afaik no script uses this cache any longer because
57                                                                       # it has caused difficult-to-find bugs in the past.
58                                                       };
59             1                                 14      return bless $self, $class;
60                                                    }
61                                                    
62                                                    sub dump {
63    ***      6                    6      0     47      my ( $self, $dbh, $quoter, $db, $tbl, $what ) = @_;
64                                                    
65             6    100                          45      if ( $what eq 'table' ) {
                    100                               
      ***            50                               
66             3                                 22         my $ddl = $self->get_create_table($dbh, $quoter, $db, $tbl);
67             3    100                          12         return unless $ddl;
68             2    100                          12         if ( $ddl->[0] eq 'table' ) {
69             1                                 11            return $before
70                                                                . 'DROP TABLE IF EXISTS ' . $quoter->quote($tbl) . ";\n"
71                                                                . $ddl->[1] . ";\n";
72                                                          }
73                                                          else {
74             1                                  6            return 'DROP TABLE IF EXISTS ' . $quoter->quote($tbl) . ";\n"
75                                                                . '/*!50001 DROP VIEW IF EXISTS '
76                                                                . $quoter->quote($tbl) . "*/;\n/*!50001 "
77                                                                . $self->get_tmp_table($dbh, $quoter, $db, $tbl) . "*/;\n";
78                                                          }
79                                                       }
80                                                       elsif ( $what eq 'triggers' ) {
81             2                                 12         my $trgs = $self->get_triggers($dbh, $quoter, $db, $tbl);
82    ***      2    100     66                   20         if ( $trgs && @$trgs ) {
83             1                                  7            my $result = $before . "\nDELIMITER ;;\n";
84             1                                  4            foreach my $trg ( @$trgs ) {
85    ***      3     50                          67               if ( $trg->{sql_mode} ) {
86             3                                 16                  $result .= qq{/*!50003 SET SESSION SQL_MODE='$trg->{sql_mode}' */;;\n};
87                                                                }
88             3                                  8               $result .= "/*!50003 CREATE */ ";
89    ***      3     50                          13               if ( $trg->{definer} ) {
90             6                                 18                  my ( $user, $host )
91             3                                 17                     = map { s/'/''/g; "'$_'"; }
               6                                 26   
92                                                                        split('@', $trg->{definer}, 2);
93             3                                 15                  $result .= "/*!50017 DEFINER=$user\@$host */ ";
94                                                                }
95             3                                 89               $result .= sprintf("/*!50003 TRIGGER %s %s %s ON %s\nFOR EACH ROW %s */;;\n\n",
96                                                                   $quoter->quote($trg->{trigger}),
97             3                                 19                  @{$trg}{qw(timing event)},
98                                                                   $quoter->quote($trg->{table}),
99                                                                   $trg->{statement});
100                                                            }
101            1                                 27            $result .= "DELIMITER ;\n\n/*!50003 SET SESSION SQL_MODE=\@OLD_SQL_MODE */;\n\n";
102            1                                  8            return $result;
103                                                         }
104                                                         else {
105            1                                 11            return undef;
106                                                         }
107                                                      }
108                                                      elsif ( $what eq 'view' ) {
109            1                                  5         my $ddl = $self->get_create_table($dbh, $quoter, $db, $tbl);
110            1                                  6         return '/*!50001 DROP TABLE IF EXISTS ' . $quoter->quote($tbl) . "*/;\n"
111                                                            . '/*!50001 DROP VIEW IF EXISTS ' . $quoter->quote($tbl) . "*/;\n"
112                                                            . '/*!50001 ' . $ddl->[1] . "*/;\n";
113                                                      }
114                                                      else {
115   ***      0                                  0         die "You didn't say what to dump.";
116                                                      }
117                                                   }
118                                                   
119                                                   # USEs the given database.
120                                                   sub _use_db {
121            5                    5            29      my ( $self, $dbh, $quoter, $new ) = @_;
122   ***      5     50                          21      if ( !$new ) {
123   ***      0                                  0         MKDEBUG && _d('No new DB to use');
124   ***      0                                  0         return;
125                                                      }
126            5                                 37      my $sql = 'USE ' . $quoter->quote($new);
127            5                                162      MKDEBUG && _d($dbh, $sql);
128            5                                497      $dbh->do($sql);
129            5                                 20      return;
130                                                   }
131                                                   
132                                                   sub get_create_table {
133   ***      4                    4      0     27      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
134   ***      4     50     33                   31      if ( !$self->{cache} || !$self->{tables}->{$db}->{$tbl} ) {
135            4                                 13         my $sql = '/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
136                                                            . q{@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, 'ANSI_QUOTES', ''), ',,', ','), }
137                                                            . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
138                                                            . '@@SQL_QUOTE_SHOW_CREATE := 1 */';
139            4                                 11         MKDEBUG && _d($sql);
140            4                                 11         eval { $dbh->do($sql); };
               4                                867   
141            4                                 12         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
142            4                                 29         $self->_use_db($dbh, $quoter, $db);
143            4                                 22         $sql = "SHOW CREATE TABLE " . $quoter->quote($db, $tbl);
144            4                                131         MKDEBUG && _d($sql);
145            4                                 12         my $href;
146            4                                 10         eval { $href = $dbh->selectrow_hashref($sql); };
               4                                 10   
147            4    100                          34         if ( $EVAL_ERROR ) {
148            1                                 14            warn "Failed to $sql.  The table may be damaged.\nError: $EVAL_ERROR";
149            1                                  4            return;
150                                                         }
151                                                   
152            3                                 10         $sql = '/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
153                                                            . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */';
154            3                                  7         MKDEBUG && _d($sql);
155            3                                346         $dbh->do($sql);
156            3                                 23         my ($key) = grep { m/create table/i } keys %$href;
              10                                 52   
157            3    100                          15         if ( $key ) {
158            1                                  3            MKDEBUG && _d('This table is a base table');
159            1                                 14            $self->{tables}->{$db}->{$tbl} = [ 'table', $href->{$key} ];
160                                                         }
161                                                         else {
162            2                                  5            MKDEBUG && _d('This table is a view');
163            2                                 10            ($key) = grep { m/create view/i } keys %$href;
               8                                 31   
164            2                                 22            $self->{tables}->{$db}->{$tbl} = [ 'view', $href->{$key} ];
165                                                         }
166                                                      }
167            3                                 20      return $self->{tables}->{$db}->{$tbl};
168                                                   }
169                                                   
170                                                   sub get_columns {
171   ***      1                    1      0      6      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
172            1                                  2      MKDEBUG && _d('Get columns for', $db, $tbl);
173   ***      1     50     33                    9      if ( !$self->{cache} || !$self->{columns}->{$db}->{$tbl} ) {
174            1                                  4         $self->_use_db($dbh, $quoter, $db);
175            1                                  6         my $sql = "SHOW COLUMNS FROM " . $quoter->quote($db, $tbl);
176            1                                 33         MKDEBUG && _d($sql);
177            1                                 24         my $cols = $dbh->selectall_arrayref($sql, { Slice => {} });
178                                                   
179            9                                 21         $self->{columns}->{$db}->{$tbl} = [
180                                                            map {
181            1                                  9               my %row;
182            9                                 45               @row{ map { lc $_ } keys %$_ } = values %$_;
              54                                186   
183            9                                 52               \%row;
184                                                            } @$cols
185                                                         ];
186                                                      }
187            1                                  8      return $self->{columns}->{$db}->{$tbl};
188                                                   }
189                                                   
190                                                   sub get_tmp_table {
191   ***      1                    1      0      7      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
192            1                                  5      my $result = 'CREATE TABLE ' . $quoter->quote($tbl) . " (\n";
193            9                                216      $result .= join(",\n",
194            1                                  9         map { '  ' . $quoter->quote($_->{field}) . ' ' . $_->{type} }
195            1                                 24         @{$self->get_columns($dbh, $quoter, $db, $tbl)});
196            1                                 29      $result .= "\n)";
197            1                                  2      MKDEBUG && _d($result);
198            1                                  9      return $result;
199                                                   }
200                                                   
201                                                   sub get_triggers {
202   ***      2                    2      0     11      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
203   ***      2     50     33                   16      if ( !$self->{cache} || !$self->{triggers}->{$db} ) {
204            2                                 11         $self->{triggers}->{$db} = {};
205            2                                  6         my $sql = '/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
206                                                            . q{@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, 'ANSI_QUOTES', ''), ',,', ','), }
207                                                            . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
208                                                            . '@@SQL_QUOTE_SHOW_CREATE := 1 */';
209            2                                  5         MKDEBUG && _d($sql);
210            2                                  5         eval { $dbh->do($sql); };
               2                                360   
211            2                                  6         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
212            2                                 13         $sql = "SHOW TRIGGERS FROM " . $quoter->quote($db);
213            2                                 60         MKDEBUG && _d($sql);
214            2                                  5         my $sth = $dbh->prepare($sql);
215            2                              28481         $sth->execute();
216            2    100                          73         if ( $sth->rows ) {
217            1                                 44            my $trgs = $sth->fetchall_arrayref({});
218            1                                 11            foreach my $trg (@$trgs) {
219                                                               # Lowercase the hash keys because the NAME_lc property might be set
220                                                               # on the $dbh, so the lettercase is unpredictable.  This makes them
221                                                               # predictable.
222            6                                 14               my %trg;
223            6                                 37               @trg{ map { lc $_ } keys %$trg } = values %$trg;
              66                                238   
224            6                                 26               push @{ $self->{triggers}->{$db}->{ $trg{table} } }, \%trg;
               6                                 49   
225                                                            }
226                                                         }
227            2                                 10         $sql = '/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
228                                                            . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */';
229            2                                  5         MKDEBUG && _d($sql);
230            2                                462         $dbh->do($sql);
231                                                      }
232   ***      2     50                          11      if ( $tbl ) {
233            2                                 17         return $self->{triggers}->{$db}->{$tbl};
234                                                      }
235   ***      0                                         return values %{$self->{triggers}->{$db}};
      ***      0                                      
236                                                   }
237                                                   
238                                                   sub get_databases {
239   ***      0                    0      0             my ( $self, $dbh, $quoter, $like ) = @_;
240   ***      0      0      0                           if ( !$self->{cache} || !$self->{databases} || $like ) {
      ***                    0                        
241   ***      0                                            my $sql = 'SHOW DATABASES';
242   ***      0                                            my @params;
243   ***      0      0                                     if ( $like ) {
244   ***      0                                               $sql .= ' LIKE ?';
245   ***      0                                               push @params, $like;
246                                                         }
247   ***      0                                            my $sth = $dbh->prepare($sql);
248   ***      0                                            MKDEBUG && _d($sql, @params);
249   ***      0                                            $sth->execute( @params );
250   ***      0                                            my @dbs = map { $_->[0] } @{$sth->fetchall_arrayref()};
      ***      0                                      
      ***      0                                      
251   ***      0      0                                     $self->{databases} = \@dbs unless $like;
252   ***      0                                            return @dbs;
253                                                      }
254   ***      0                                         return @{$self->{databases}};
      ***      0                                      
255                                                   }
256                                                   
257                                                   sub get_table_status {
258   ***      0                    0      0             my ( $self, $dbh, $quoter, $db, $like ) = @_;
259   ***      0      0      0                           if ( !$self->{cache} || !$self->{table_status}->{$db} || $like ) {
      ***                    0                        
260   ***      0                                            my $sql = "SHOW TABLE STATUS FROM " . $quoter->quote($db);
261   ***      0                                            my @params;
262   ***      0      0                                     if ( $like ) {
263   ***      0                                               $sql .= ' LIKE ?';
264   ***      0                                               push @params, $like;
265                                                         }
266   ***      0                                            MKDEBUG && _d($sql, @params);
267   ***      0                                            my $sth = $dbh->prepare($sql);
268   ***      0                                            $sth->execute(@params);
269   ***      0                                            my @tables = @{$sth->fetchall_arrayref({})};
      ***      0                                      
270   ***      0                                            @tables = map {
271   ***      0                                               my %tbl; # Make a copy with lowercased keys
272   ***      0                                               @tbl{ map { lc $_ } keys %$_ } = values %$_;
      ***      0                                      
273   ***      0             0                                 $tbl{engine} ||= $tbl{type} || $tbl{comment};
      ***                    0                        
274   ***      0                                               delete $tbl{type};
275   ***      0                                               \%tbl;
276                                                         } @tables;
277   ***      0      0                                     $self->{table_status}->{$db} = \@tables unless $like;
278   ***      0                                            return @tables;
279                                                      }
280   ***      0                                         return @{$self->{table_status}->{$db}};
      ***      0                                      
281                                                   }
282                                                   
283                                                   sub get_table_list {
284   ***      0                    0      0             my ( $self, $dbh, $quoter, $db, $like ) = @_;
285   ***      0      0      0                           if ( !$self->{cache} || !$self->{table_list}->{$db} || $like ) {
      ***                    0                        
286   ***      0                                            my $sql = "SHOW /*!50002 FULL*/ TABLES FROM " . $quoter->quote($db);
287   ***      0                                            my @params;
288   ***      0      0                                     if ( $like ) {
289   ***      0                                               $sql .= ' LIKE ?';
290   ***      0                                               push @params, $like;
291                                                         }
292   ***      0                                            MKDEBUG && _d($sql, @params);
293   ***      0                                            my $sth = $dbh->prepare($sql);
294   ***      0                                            $sth->execute(@params);
295   ***      0                                            my @tables = @{$sth->fetchall_arrayref()};
      ***      0                                      
296   ***      0      0      0                              @tables = map {
297   ***      0                                               my %tbl = (
298                                                               name   => $_->[0],
299                                                               engine => ($_->[1] || '') eq 'VIEW' ? 'VIEW' : '',
300                                                            );
301   ***      0                                               \%tbl;
302                                                         } @tables;
303   ***      0      0                                     $self->{table_list}->{$db} = \@tables unless $like;
304   ***      0                                            return @tables;
305                                                      }
306   ***      0                                         return @{$self->{table_list}->{$db}};
      ***      0                                      
307                                                   }
308                                                   
309                                                   sub _d {
310   ***      0                    0                    my ($package, undef, $line) = caller 0;
311   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
312   ***      0                                              map { defined $_ ? $_ : 'undef' }
313                                                           @_;
314   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
315                                                   }
316                                                   
317                                                   1;
318                                                   
319                                                   # ###########################################################################
320                                                   # End MySQLDump package
321                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
65           100      3      3   if ($what eq 'table') { }
             100      2      1   elsif ($what eq 'triggers') { }
      ***     50      1      0   elsif ($what eq 'view') { }
67           100      1      2   unless $ddl
68           100      1      1   if ($$ddl[0] eq 'table') { }
82           100      1      1   if ($trgs and @$trgs) { }
85    ***     50      3      0   if ($$trg{'sql_mode'})
89    ***     50      3      0   if ($$trg{'definer'})
122   ***     50      0      5   if (not $new)
134   ***     50      4      0   if (not $$self{'cache'} or not $$self{'tables'}{$db}{$tbl})
147          100      1      3   if ($EVAL_ERROR)
157          100      1      2   if ($key) { }
173   ***     50      1      0   if (not $$self{'cache'} or not $$self{'columns'}{$db}{$tbl})
203   ***     50      2      0   if (not $$self{'cache'} or not $$self{'triggers'}{$db})
216          100      1      1   if ($sth->rows)
232   ***     50      2      0   if ($tbl)
240   ***      0      0      0   if (not $$self{'cache'} or not $$self{'databases'} or $like)
243   ***      0      0      0   if ($like)
251   ***      0      0      0   unless $like
259   ***      0      0      0   if (not $$self{'cache'} or not $$self{'table_status'}{$db} or $like)
262   ***      0      0      0   if ($like)
277   ***      0      0      0   unless $like
285   ***      0      0      0   if (not $$self{'cache'} or not $$self{'table_list'}{$db} or $like)
288   ***      0      0      0   if ($like)
296   ***      0      0      0   ($$_[1] || '') eq 'VIEW' ? :
303   ***      0      0      0   unless $like
311   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
82    ***     66      1      0      1   $trgs and @$trgs

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0
296   ***      0      0      0   $$_[1] || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
134   ***     33      4      0      0   not $$self{'cache'} or not $$self{'tables'}{$db}{$tbl}
173   ***     33      1      0      0   not $$self{'cache'} or not $$self{'columns'}{$db}{$tbl}
203   ***     33      2      0      0   not $$self{'cache'} or not $$self{'triggers'}{$db}
240   ***      0      0      0      0   not $$self{'cache'} or not $$self{'databases'}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'databases'} or $like
259   ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_status'}{$db}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_status'}{$db} or $like
273   ***      0      0      0      0   $tbl{'type'} || $tbl{'comment'}
      ***      0      0      0      0   $tbl{'engine'} ||= $tbl{'type'} || $tbl{'comment'}
285   ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_list'}{$db}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_list'}{$db} or $like


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                        
---------------- ----- --- ------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/MySQLDump.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/MySQLDump.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/MySQLDump.pm:25 
BEGIN                1     /home/daniel/dev/maatkit/common/MySQLDump.pm:27 
_use_db              5     /home/daniel/dev/maatkit/common/MySQLDump.pm:121
dump                 6   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:63 
get_columns          1   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:171
get_create_table     4   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:133
get_tmp_table        1   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:191
get_triggers         2   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:202
new                  1   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:54 

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                        
---------------- ----- --- ------------------------------------------------
_d                   0     /home/daniel/dev/maatkit/common/MySQLDump.pm:310
get_databases        0   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:239
get_table_list       0   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:284
get_table_status     0   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:258


MySQLDump.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 12;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use MySQLDump;
               1                                  2   
               1                                 11   
15             1                    1            10   use Quoter;
               1                                  3   
               1                                  9   
16             1                    1             9   use DSNParser;
               1                                  2   
               1                                 11   
17             1                    1            13   use Sandbox;
               1                                  2   
               1                                 10   
18             1                    1            10   use MaatkitTest;
               1                                  4   
               1                                 32   
19                                                    
20             1                                 12   my $dp = new DSNParser(opts=>$dsn_opts);
21             1                                237   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
22                                                    
23    ***      1     50                          54   my $dbh = $sb->get_dbh_for('master')
24                                                       or BAIL_OUT('Cannot connect to sandbox master');
25                                                    
26             1                                415   $sb->create_dbs($dbh, ['test']);
27                                                    
28             1                                719   my $du = new MySQLDump();
29             1                                 10   my $q  = new Quoter();
30                                                    
31             1                                 19   my $dump;
32                                                    
33                                                    # TODO: get_create_table() seems to return an arrayref sometimes!
34                                                    
35             1                                  3   SKIP: {
36             1                                  2      skip 'Sandbox master does not have the sakila database', 10
37    ***      1     50                           3         unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};
38                                                    
39             1                                382      $dump = $du->dump($dbh, $q, 'sakila', 'film', 'table');
40             1                                103      like($dump, qr/language_id/, 'Dump sakila.film');
41                                                    
42             1                                 15      $dump = $du->dump($dbh, $q, 'mysql', 'film', 'triggers');
43             1                                  8      ok(!defined $dump, 'no triggers in mysql');
44                                                    
45             1                                  7      $dump = $du->dump($dbh, $q, 'sakila', 'film', 'triggers');
46             1                                 12      like($dump, qr/AFTER INSERT/, 'dump triggers');
47                                                    
48             1                                 11      $dump = $du->dump($dbh, $q, 'sakila', 'customer_list', 'table');
49             1                                 11      like($dump, qr/CREATE TABLE/, 'Temp table def for view/table');
50             1                                 11      like($dump, qr/DROP TABLE/, 'Drop temp table def for view/table');
51             1                                 11      like($dump, qr/DROP VIEW/, 'Drop view def for view/table');
52             1                                 11      unlike($dump, qr/ALGORITHM/, 'No view def');
53                                                    
54             1                                 10      $dump = $du->dump($dbh, $q, 'sakila', 'customer_list', 'view');
55             1                                 11      like($dump, qr/DROP TABLE/, 'Drop temp table def for view');
56             1                                 11      like($dump, qr/DROP VIEW/, 'Drop view def for view');
57             1                                  9      like($dump, qr/ALGORITHM/, 'View def');
58                                                    };
59                                                    
60                                                    # #############################################################################
61                                                    # Issue 170: mk-parallel-dump dies when table-status Data_length is NULL
62                                                    # #############################################################################
63                                                    
64                                                    # The underlying problem for issue 170 is that MySQLDump doesn't eval some
65                                                    # of its queries so when MySQLFind uses it and hits a broken table it dies.
66                                                    
67             1                              14389   diag(`cp $trunk/mk-parallel-dump/t/samples/broken_tbl.frm /tmp/12345/data/test/broken_tbl.frm`);
68             1                                  5   my $output = '';
69             1                                  7   eval {
70             1                                 16      local *STDERR;
71             1                    1             2      open STDERR, '>', \$output;
               1                                349   
               1                                  3   
               1                                  9   
72             1                                 28      $dump = $du->dump($dbh, $q, 'test', 'broken_tbl', 'table');
73                                                    };
74             1                                 15   is(
75                                                       $EVAL_ERROR,
76                                                       '',
77                                                       'No error dumping broken table'
78                                                    );
79             1                                 15   like(
80                                                       $output,
81                                                       qr/table may be damaged.+selectrow_hashref failed/s,
82                                                       'Warns about possibly damaged table'
83                                                    );
84                                                    
85             1                                 16   $sb->wipe_clean($dbh);
86             1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
23    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')
37    ***     50      0      1   unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"');}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location      
---------- ----- --------------
BEGIN          1 MySQLDump.t:10
BEGIN          1 MySQLDump.t:11
BEGIN          1 MySQLDump.t:12
BEGIN          1 MySQLDump.t:14
BEGIN          1 MySQLDump.t:15
BEGIN          1 MySQLDump.t:16
BEGIN          1 MySQLDump.t:17
BEGIN          1 MySQLDump.t:18
BEGIN          1 MySQLDump.t:4 
BEGIN          1 MySQLDump.t:71
BEGIN          1 MySQLDump.t:9 


