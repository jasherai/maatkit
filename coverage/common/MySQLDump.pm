---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/MySQLDump.pm   66.2   50.0   25.0   73.3    n/a  100.0   57.9
Total                          66.2   50.0   25.0   73.3    n/a  100.0   57.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLDump.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:52:50 2009
Finish:       Fri Jul 31 18:52:50 2009

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
18                                                    # MySQLDump package $Revision: 4160 $
19                                                    # ###########################################################################
20                                                    package MySQLDump;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
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
57    ***      1     50                          13      $args{cache} = 1 unless defined $args{cache};
58             1                                 17      my $self = bless \%args, $class;
59             1                                  5      return $self;
60                                                    }
61                                                    
62                                                    sub dump {
63             6                    6            46      my ( $self, $dbh, $quoter, $db, $tbl, $what ) = @_;
64                                                    
65             6    100                          43      if ( $what eq 'table' ) {
                    100                               
      ***            50                               
66             3                                 20         my $ddl = $self->get_create_table($dbh, $quoter, $db, $tbl);
67             3    100                          11         return unless $ddl;
68             2    100                          11         if ( $ddl->[0] eq 'table' ) {
69             1                                  7            return $before
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
81             2                                  9         my $trgs = $self->get_triggers($dbh, $quoter, $db, $tbl);
82    ***      2    100     66                   17         if ( $trgs && @$trgs ) {
83             1                                  6            my $result = $before . "\nDELIMITER ;;\n";
84             1                                  4            foreach my $trg ( @$trgs ) {
85    ***      3     50                          15               if ( $trg->{sql_mode} ) {
86             3                                 14                  $result .= qq{/*!50003 SET SESSION SQL_MODE='$trg->{sql_mode}' */;;\n};
87                                                                }
88             3                                  8               $result .= "/*!50003 CREATE */ ";
89    ***      3     50                          13               if ( $trg->{definer} ) {
90             6                                 17                  my ( $user, $host )
91             3                                 16                     = map { s/'/''/g; "'$_'"; }
               6                                 26   
92                                                                        split('@', $trg->{definer}, 2);
93             3                                 16                  $result .= "/*!50017 DEFINER=$user\@$host */ ";
94                                                                }
95             3                                 17               $result .= sprintf("/*!50003 TRIGGER %s %s %s ON %s\nFOR EACH ROW %s */;;\n\n",
96                                                                   $quoter->quote($trg->{trigger}),
97             3                                 16                  @{$trg}{qw(timing event)},
98                                                                   $quoter->quote($trg->{table}),
99                                                                   $trg->{statement});
100                                                            }
101            1                                  4            $result .= "DELIMITER ;\n\n/*!50003 SET SESSION SQL_MODE=\@OLD_SQL_MODE */;\n\n";
102            1                                  8            return $result;
103                                                         }
104                                                         else {
105            1                                  6            return undef;
106                                                         }
107                                                      }
108                                                      elsif ( $what eq 'view' ) {
109            1                                  5         my $ddl = $self->get_create_table($dbh, $quoter, $db, $tbl);
110            1                                  5         return '/*!50001 DROP TABLE IF EXISTS ' . $quoter->quote($tbl) . "*/;\n"
111                                                            . '/*!50001 DROP VIEW IF EXISTS ' . $quoter->quote($tbl) . "*/;\n"
112                                                            . '/*!50001 ' . $ddl->[1] . "*/;\n";
113                                                      }
114                                                      else {
115   ***      0                                  0         die "You didn't say what to dump.";
116                                                      }
117                                                   }
118                                                   
119                                                   # USEs the given database, and returns the previous default database.
120                                                   sub _use_db {
121            7                    7            37      my ( $self, $dbh, $quoter, $new ) = @_;
122            7    100                          33      if ( !$new ) {
123            1                                  2         MKDEBUG && _d('No new DB to use');
124            1                                  4         return;
125                                                      }
126            6                                 18      my $sql = 'SELECT DATABASE()';
127            6                                 14      MKDEBUG && _d($sql);
128            6                                 17      my $curr = $dbh->selectrow_array($sql);
129   ***      6    100     66                 1033      if ( $curr && $new && $curr eq $new ) {
                           100                        
130            4                                  9         MKDEBUG && _d('Current and new DB are the same');
131            4                                 16         return $curr;
132                                                      }
133            2                                 21      $sql = 'USE ' . $quoter->quote($new);
134            2                                  6      MKDEBUG && _d($sql);
135            2                                230      $dbh->do($sql);
136            2                                 13      return $curr;
137                                                   }
138                                                   
139                                                   sub get_create_table {
140            4                    4            24      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
141   ***      4    100     66                   63      if ( !$self->{cache} || !$self->{tables}->{$db}->{$tbl} ) {
142            3                                 14         my $sql = '/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
143                                                            . q{@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, 'ANSI_QUOTES', ''), ',,', ','), }
144                                                            . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
145                                                            . '@@SQL_QUOTE_SHOW_CREATE := 1 */';
146            3                                  6         MKDEBUG && _d($sql);
147            3                                  9         eval { $dbh->do($sql); };
               3                                646   
148            3                                 12         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
149            3                                 18         my $curr_db = $self->_use_db($dbh, $quoter, $db);
150            3                                 19         $sql = "SHOW CREATE TABLE " . $quoter->quote($db, $tbl);
151            3                                  9         MKDEBUG && _d($sql);
152            3                                  7         my $href;
153            3                                  9         eval { $href = $dbh->selectrow_hashref($sql); };
               3                                  7   
154            3    100                          21         if ( $EVAL_ERROR ) {
155            1                                 13            warn "Failed to $sql.  The table may be damaged.\nError: $EVAL_ERROR";
156            1                                  5            return;
157                                                         }
158            2                                  9         $self->_use_db($dbh, $quoter, $curr_db);
159            2                                  7         $sql = '/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
160                                                            . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */';
161            2                                  4         MKDEBUG && _d($sql);
162            2                                243         $dbh->do($sql);
163            2                                 13         my ($key) = grep { m/create table/i } keys %$href;
               4                                 22   
164            2    100                          11         if ( $key ) {
165            1                                  6            MKDEBUG && _d('This table is a base table');
166            1                                 12            $self->{tables}->{$db}->{$tbl} = [ 'table', $href->{$key} ];
167                                                         }
168                                                         else {
169            1                                  3            MKDEBUG && _d('This table is a view');
170            1                                  4            ($key) = grep { m/create view/i } keys %$href;
               2                                 13   
171            1                                 10            $self->{tables}->{$db}->{$tbl} = [ 'view', $href->{$key} ];
172                                                         }
173                                                      }
174            3                                 19      return $self->{tables}->{$db}->{$tbl};
175                                                   }
176                                                   
177                                                   sub get_columns {
178            1                    1             5      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
179            1                                  3      MKDEBUG && _d('Get columns for', $db, $tbl);
180   ***      1     50     33                   52      if ( !$self->{cache} || !$self->{columns}->{$db}->{$tbl} ) {
181            1                                  4         my $curr_db = $self->_use_db($dbh, $quoter, $db);
182            1                                  6         my $sql = "SHOW COLUMNS FROM " . $quoter->quote($db, $tbl);
183            1                                  3         MKDEBUG && _d($sql);
184            1                                 22         my $cols = $dbh->selectall_arrayref($sql, { Slice => {} });
185            1                                 12         $self->_use_db($dbh, $quoter, $curr_db);
186            9                                 21         $self->{columns}->{$db}->{$tbl} = [
187                                                            map {
188            1                                  5               my %row;
189            9                                 46               @row{ map { lc $_ } keys %$_ } = values %$_;
              54                                185   
190            9                                 47               \%row;
191                                                            } @$cols
192                                                         ];
193                                                      }
194            1                                  8      return $self->{columns}->{$db}->{$tbl};
195                                                   }
196                                                   
197                                                   sub get_tmp_table {
198            1                    1             7      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
199            1                                  8      my $result = 'CREATE TABLE ' . $quoter->quote($tbl) . " (\n";
200            9                                 42      $result .= join(",\n",
201            1                                  6         map { '  ' . $quoter->quote($_->{field}) . ' ' . $_->{type} }
202            1                                  4         @{$self->get_columns($dbh, $quoter, $db, $tbl)});
203            1                                  5      $result .= "\n)";
204            1                                  2      MKDEBUG && _d($result);
205            1                                  8      return $result;
206                                                   }
207                                                   
208                                                   sub get_triggers {
209            2                    2            11      my ( $self, $dbh, $quoter, $db, $tbl ) = @_;
210   ***      2     50     33                   26      if ( !$self->{cache} || !$self->{triggers}->{$db} ) {
211            2                                  9         $self->{triggers}->{$db} = {};
212            2                                  7         my $sql = '/*!40101 SET @OLD_SQL_MODE := @@SQL_MODE, '
213                                                            . q{@@SQL_MODE := REPLACE(REPLACE(@@SQL_MODE, 'ANSI_QUOTES', ''), ',,', ','), }
214                                                            . '@OLD_QUOTE := @@SQL_QUOTE_SHOW_CREATE, '
215                                                            . '@@SQL_QUOTE_SHOW_CREATE := 1 */';
216            2                                  4         MKDEBUG && _d($sql);
217            2                                  6         eval { $dbh->do($sql); };
               2                                319   
218            2                                  6         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
219            2                                 12         $sql = "SHOW TRIGGERS FROM " . $quoter->quote($db);
220            2                                  5         MKDEBUG && _d($sql);
221            2                                  4         my $sth = $dbh->prepare($sql);
222            2                               2577         $sth->execute();
223            2    100                          47         if ( $sth->rows ) {
224            1                                 32            my $trgs = $sth->fetchall_arrayref({});
225            1                                  9            foreach my $trg (@$trgs) {
226                                                               # Lowercase the hash keys because the NAME_lc property might be set
227                                                               # on the $dbh, so the lettercase is unpredictable.  This makes them
228                                                               # predictable.
229            6                                 16               my %trg;
230            6                                 33               @trg{ map { lc $_ } keys %$trg } = values %$trg;
              48                                177   
231            6                                 24               push @{ $self->{triggers}->{$db}->{ $trg{table} } }, \%trg;
               6                                 44   
232                                                            }
233                                                         }
234            2                                 11         $sql = '/*!40101 SET @@SQL_MODE := @OLD_SQL_MODE, '
235                                                            . '@@SQL_QUOTE_SHOW_CREATE := @OLD_QUOTE */';
236            2                                 21         MKDEBUG && _d($sql);
237            2                                356         $dbh->do($sql);
238                                                      }
239   ***      2     50                          11      if ( $tbl ) {
240            2                                 15         return $self->{triggers}->{$db}->{$tbl};
241                                                      }
242   ***      0                                         return values %{$self->{triggers}->{$db}};
      ***      0                                      
243                                                   }
244                                                   
245                                                   sub get_databases {
246   ***      0                    0                    my ( $self, $dbh, $quoter, $like ) = @_;
247   ***      0      0      0                           if ( !$self->{cache} || !$self->{databases} || $like ) {
      ***                    0                        
248   ***      0                                            my $sql = 'SHOW DATABASES';
249   ***      0                                            my @params;
250   ***      0      0                                     if ( $like ) {
251   ***      0                                               $sql .= ' LIKE ?';
252   ***      0                                               push @params, $like;
253                                                         }
254   ***      0                                            my $sth = $dbh->prepare($sql);
255   ***      0                                            MKDEBUG && _d($sql, @params);
256   ***      0                                            $sth->execute( @params );
257   ***      0                                            my @dbs = map { $_->[0] } @{$sth->fetchall_arrayref()};
      ***      0                                      
      ***      0                                      
258   ***      0      0                                     $self->{databases} = \@dbs unless $like;
259   ***      0                                            return @dbs;
260                                                      }
261   ***      0                                         return @{$self->{databases}};
      ***      0                                      
262                                                   }
263                                                   
264                                                   sub get_table_status {
265   ***      0                    0                    my ( $self, $dbh, $quoter, $db, $like ) = @_;
266   ***      0      0      0                           if ( !$self->{cache} || !$self->{table_status}->{$db} || $like ) {
      ***                    0                        
267   ***      0                                            my $sql = "SHOW TABLE STATUS FROM " . $quoter->quote($db);
268   ***      0                                            my @params;
269   ***      0      0                                     if ( $like ) {
270   ***      0                                               $sql .= ' LIKE ?';
271   ***      0                                               push @params, $like;
272                                                         }
273   ***      0                                            MKDEBUG && _d($sql, @params);
274   ***      0                                            my $sth = $dbh->prepare($sql);
275   ***      0                                            $sth->execute(@params);
276   ***      0                                            my @tables = @{$sth->fetchall_arrayref({})};
      ***      0                                      
277   ***      0                                            @tables = map {
278   ***      0                                               my %tbl; # Make a copy with lowercased keys
279   ***      0                                               @tbl{ map { lc $_ } keys %$_ } = values %$_;
      ***      0                                      
280   ***      0             0                                 $tbl{engine} ||= $tbl{type} || $tbl{comment};
      ***                    0                        
281   ***      0                                               delete $tbl{type};
282   ***      0                                               \%tbl;
283                                                         } @tables;
284   ***      0      0                                     $self->{table_status}->{$db} = \@tables unless $like;
285   ***      0                                            return @tables;
286                                                      }
287   ***      0                                         return @{$self->{table_status}->{$db}};
      ***      0                                      
288                                                   }
289                                                   
290                                                   sub get_table_list {
291   ***      0                    0                    my ( $self, $dbh, $quoter, $db, $like ) = @_;
292   ***      0      0      0                           if ( !$self->{cache} || !$self->{table_list}->{$db} || $like ) {
      ***                    0                        
293   ***      0                                            my $sql = "SHOW /*!50002 FULL*/ TABLES FROM " . $quoter->quote($db);
294   ***      0                                            my @params;
295   ***      0      0                                     if ( $like ) {
296   ***      0                                               $sql .= ' LIKE ?';
297   ***      0                                               push @params, $like;
298                                                         }
299   ***      0                                            MKDEBUG && _d($sql, @params);
300   ***      0                                            my $sth = $dbh->prepare($sql);
301   ***      0                                            $sth->execute(@params);
302   ***      0                                            my @tables = @{$sth->fetchall_arrayref()};
      ***      0                                      
303   ***      0      0      0                              @tables = map {
304   ***      0                                               my %tbl = (
305                                                               name   => $_->[0],
306                                                               engine => ($_->[1] || '') eq 'VIEW' ? 'VIEW' : '',
307                                                            );
308   ***      0                                               \%tbl;
309                                                         } @tables;
310   ***      0      0                                     $self->{table_list}->{$db} = \@tables unless $like;
311   ***      0                                            return @tables;
312                                                      }
313   ***      0                                         return @{$self->{table_list}->{$db}};
      ***      0                                      
314                                                   }
315                                                   
316                                                   sub _d {
317   ***      0                    0                    my ($package, undef, $line) = caller 0;
318   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
319   ***      0                                              map { defined $_ ? $_ : 'undef' }
320                                                           @_;
321   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
322                                                   }
323                                                   
324                                                   1;
325                                                   
326                                                   # ###########################################################################
327                                                   # End MySQLDump package
328                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
57    ***     50      1      0   unless defined $args{'cache'}
65           100      3      3   if ($what eq 'table') { }
             100      2      1   elsif ($what eq 'triggers') { }
      ***     50      1      0   elsif ($what eq 'view') { }
67           100      1      2   unless $ddl
68           100      1      1   if ($$ddl[0] eq 'table') { }
82           100      1      1   if ($trgs and @$trgs) { }
85    ***     50      3      0   if ($$trg{'sql_mode'})
89    ***     50      3      0   if ($$trg{'definer'})
122          100      1      6   if (not $new)
129          100      4      2   if ($curr and $new and $curr eq $new)
141          100      3      1   if (not $$self{'cache'} or not $$self{'tables'}{$db}{$tbl})
154          100      1      2   if ($EVAL_ERROR)
164          100      1      1   if ($key) { }
180   ***     50      1      0   if (not $$self{'cache'} or not $$self{'columns'}{$db}{$tbl})
210   ***     50      2      0   if (not $$self{'cache'} or not $$self{'triggers'}{$db})
223          100      1      1   if ($sth->rows)
239   ***     50      2      0   if ($tbl)
247   ***      0      0      0   if (not $$self{'cache'} or not $$self{'databases'} or $like)
250   ***      0      0      0   if ($like)
258   ***      0      0      0   unless $like
266   ***      0      0      0   if (not $$self{'cache'} or not $$self{'table_status'}{$db} or $like)
269   ***      0      0      0   if ($like)
284   ***      0      0      0   unless $like
292   ***      0      0      0   if (not $$self{'cache'} or not $$self{'table_list'}{$db} or $like)
295   ***      0      0      0   if ($like)
303   ***      0      0      0   ($$_[1] || '') eq 'VIEW' ? :
310   ***      0      0      0   unless $like
318   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
82    ***     66      1      0      1   $trgs and @$trgs
129   ***     66      1      0      5   $curr and $new
             100      1      1      4   $curr and $new and $curr eq $new

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
303   ***      0      0      0   $$_[1] || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
141   ***     66      0      3      1   not $$self{'cache'} or not $$self{'tables'}{$db}{$tbl}
180   ***     33      0      1      0   not $$self{'cache'} or not $$self{'columns'}{$db}{$tbl}
210   ***     33      0      2      0   not $$self{'cache'} or not $$self{'triggers'}{$db}
247   ***      0      0      0      0   not $$self{'cache'} or not $$self{'databases'}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'databases'} or $like
266   ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_status'}{$db}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_status'}{$db} or $like
280   ***      0      0      0      0   $tbl{'type'} || $tbl{'comment'}
      ***      0      0      0      0   $tbl{'engine'} ||= $tbl{'type'} || $tbl{'comment'}
292   ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_list'}{$db}
      ***      0      0      0      0   not $$self{'cache'} or not $$self{'table_list'}{$db} or $like


Covered Subroutines
-------------------

Subroutine       Count Location                                        
---------------- ----- ------------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:22 
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:23 
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:25 
BEGIN                1 /home/daniel/dev/maatkit/common/MySQLDump.pm:27 
_use_db              7 /home/daniel/dev/maatkit/common/MySQLDump.pm:121
dump                 6 /home/daniel/dev/maatkit/common/MySQLDump.pm:63 
get_columns          1 /home/daniel/dev/maatkit/common/MySQLDump.pm:178
get_create_table     4 /home/daniel/dev/maatkit/common/MySQLDump.pm:140
get_tmp_table        1 /home/daniel/dev/maatkit/common/MySQLDump.pm:198
get_triggers         2 /home/daniel/dev/maatkit/common/MySQLDump.pm:209
new                  1 /home/daniel/dev/maatkit/common/MySQLDump.pm:56 

Uncovered Subroutines
---------------------

Subroutine       Count Location                                        
---------------- ----- ------------------------------------------------
_d                   0 /home/daniel/dev/maatkit/common/MySQLDump.pm:317
get_databases        0 /home/daniel/dev/maatkit/common/MySQLDump.pm:246
get_table_list       0 /home/daniel/dev/maatkit/common/MySQLDump.pm:291
get_table_status     0 /home/daniel/dev/maatkit/common/MySQLDump.pm:265


