---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableParser.pm   91.4   69.0   50.0   93.3    n/a  100.0   83.5
Total                          91.4   69.0   50.0   93.3    n/a  100.0   83.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:14 2009
Finish:       Wed Jun 10 17:21:14 2009

/home/daniel/dev/maatkit/common/TableParser.pm

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
18                                                    # TableParser package $Revision: 3475 $
19                                                    # ###########################################################################
20                                                    package TableParser;
21                                                    
22             1                    1             9   use strict;
               1                                  2   
               1                                  9   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  7   
               1                                  8   
25                                                    
26             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
27                                                    
28                                                    sub new {
29             1                    1            13      my ( $class ) = @_;
30             1                                 14      return bless {}, $class;
31                                                    }
32                                                    
33                                                    # Several subs in this module require either a $ddl or $tbl param.
34                                                    #
35                                                    # $ddl is the return value from MySQLDump::get_create_table() (which returns
36                                                    # the output of SHOW CREATE TALBE).
37                                                    #
38                                                    # $tbl is the return value from the sub below, parse().
39                                                    #
40                                                    # And some subs have an optional $opts param which is a hashref of options.
41                                                    # $opts->{mysql_version} is typically used, which is the return value from
42                                                    # VersionParser::parser() (which returns a zero-padded MySQL version,
43                                                    # e.g. 004001000 for 4.1.0).
44                                                    
45                                                    sub parse {
46            13                   13           302      my ( $self, $ddl, $opts ) = @_;
47                                                    
48    ***     13     50                         101      if ( ref $ddl eq 'ARRAY' ) {
49    ***      0      0                           0         if ( lc $ddl->[0] eq 'table' ) {
50    ***      0                                  0            $ddl = $ddl->[1];
51                                                          }
52                                                          else {
53                                                             return {
54    ***      0                                  0               engine => 'VIEW',
55                                                             };
56                                                          }
57                                                       }
58                                                    
59            13    100                         149      if ( $ddl !~ m/CREATE (?:TEMPORARY )?TABLE `/ ) {
60             2                                  9         die "Cannot parse table definition; is ANSI quoting "
61                                                             . "enabled or SQL_QUOTE_SHOW_CREATE disabled?";
62                                                       }
63                                                    
64                                                       # Lowercase identifiers to avoid issues with case-sensitivity in Perl.
65                                                       # (Bug #1910276).
66            11                                569      $ddl =~ s/(`[^`]+`)/\L$1/g;
67                                                    
68            11                                 76      my $engine = $self->get_engine($ddl);
69                                                    
70            11                                498      my @defs   = $ddl =~ m/^(\s+`.*?),?$/gm;
71            11                                 55      my @cols   = map { $_ =~ m/`([^`]+)`/ } @defs;
              48                                291   
72            11                                 34      MKDEBUG && _d('Columns:', join(', ', @cols));
73                                                    
74                                                       # Save the column definitions *exactly*
75            11                                 36      my %def_for;
76            11                                 90      @def_for{@cols} = @defs;
77                                                    
78                                                       # Find column types, whether numeric, whether nullable, whether
79                                                       # auto-increment.
80            11                                 35      my (@nums, @null);
81            11                                 41      my (%type_for, %is_nullable, %is_numeric, %is_autoinc);
82            11                                 51      foreach my $col ( @cols ) {
83            48                                160         my $def = $def_for{$col};
84            48                                306         my ( $type ) = $def =~ m/`[^`]+`\s([a-z]+)/;
85    ***     48     50                         193         die "Can't determine column type for $def" unless $type;
86            48                                166         $type_for{$col} = $type;
87            48    100                         295         if ( $type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ) {
88            26                                 90            push @nums, $col;
89            26                                 93            $is_numeric{$col} = 1;
90                                                          }
91            48    100                         221         if ( $def !~ m/NOT NULL/ ) {
92            21                                 67            push @null, $col;
93            21                                 77            $is_nullable{$col} = 1;
94                                                          }
95            48    100                         285         $is_autoinc{$col} = $def =~ m/AUTO_INCREMENT/i ? 1 : 0;
96                                                       }
97                                                    
98                                                       # TODO: passing is_nullable this way is just a quick hack. Ultimately,
99                                                       # we probably should decompose this sub further, taking out the block
100                                                      # above that parses col props like nullability, auto_inc, type, etc.
101           11                                 66      my $keys = $self->get_keys($ddl, $opts, \%is_nullable);
102                                                   
103                                                      return {
104           48                                218         cols           => \@cols,
105           48                                342         col_posn       => { map { $cols[$_] => $_ } 0..$#cols },
106           11                                106         is_col         => { map { $_ => 1 } @cols },
107                                                         null_cols      => \@null,
108                                                         is_nullable    => \%is_nullable,
109                                                         is_autoinc     => \%is_autoinc,
110                                                         keys           => $keys,
111                                                         defs           => \%def_for,
112                                                         numeric_cols   => \@nums,
113                                                         is_numeric     => \%is_numeric,
114                                                         engine         => $engine,
115                                                         type_for       => \%type_for,
116                                                      };
117                                                   }
118                                                   
119                                                   # Sorts indexes in this order: PRIMARY, unique, non-nullable, any (shortest
120                                                   # first, alphabetical).  Only BTREE indexes are considered.
121                                                   # TODO: consider length as # of bytes instead of # of columns.
122                                                   sub sort_indexes {
123            2                    2            49      my ( $self, $tbl ) = @_;
124                                                   
125                                                      my @indexes
126            2                                 10         = sort {
127            8                                 34            (($a ne 'PRIMARY') <=> ($b ne 'PRIMARY'))
128                                                            || ( !$tbl->{keys}->{$a}->{is_unique} <=> !$tbl->{keys}->{$b}->{is_unique} )
129                                                            || ( $tbl->{keys}->{$a}->{is_nullable} <=> $tbl->{keys}->{$b}->{is_nullable} )
130   ***      8    100     66                  114            || ( scalar(@{$tbl->{keys}->{$a}->{cols}}) <=> scalar(@{$tbl->{keys}->{$b}->{cols}}) )
               2           100                   13   
131                                                         }
132                                                         grep {
133            2                                 26            $tbl->{keys}->{$_}->{type} eq 'BTREE'
134                                                         }
135            2                                  8         sort keys %{$tbl->{keys}};
136                                                   
137            2                                 13      MKDEBUG && _d('Indexes sorted best-first:', join(', ', @indexes));
138            2                                 15      return @indexes;
139                                                   }
140                                                   
141                                                   # Finds the 'best' index; if the user specifies one, dies if it's not in the
142                                                   # table.
143                                                   sub find_best_index {
144            3                    3            17      my ( $self, $tbl, $index ) = @_;
145            3                                  8      my $best;
146            3    100                          16      if ( $index ) {
147            2                                  7         ($best) = grep { uc $_ eq uc $index } keys %{$tbl->{keys}};
               8                                 31   
               2                                 29   
148                                                      }
149            3    100                          16      if ( !$best ) {
150            2    100                           9         if ( $index ) {
151                                                            # The user specified an index, so we can't choose our own.
152            1                                  3            die "Index '$index' does not exist in table";
153                                                         }
154                                                         else {
155                                                            # Try to pick the best index.
156                                                            # TODO: eliminate indexes that have column prefixes.
157            1                                  7            ($best) = $self->sort_indexes($tbl);
158                                                         }
159                                                      }
160            2                                  6      MKDEBUG && _d('Best index found is', $best);
161            2                                 13      return $best;
162                                                   }
163                                                   
164                                                   # Takes a dbh, database, table, quoter, and WHERE clause, and reports the
165                                                   # indexes MySQL thinks are best for EXPLAIN SELECT * FROM that table.  If no
166                                                   # WHERE, just returns an empty list.  If no possible_keys, returns empty list,
167                                                   # even if 'key' is not null.  Only adds 'key' to the list if it's included in
168                                                   # possible_keys.
169                                                   sub find_possible_keys {
170            2                    2           433      my ( $self, $dbh, $database, $table, $quoter, $where ) = @_;
171   ***      2     50                          10      return () unless $where;
172            2                                 10      my $sql = 'EXPLAIN SELECT * FROM ' . $quoter->quote($database, $table)
173                                                         . ' WHERE ' . $where;
174            2                                  5      MKDEBUG && _d($sql);
175            2                                  6      my $expl = $dbh->selectrow_hashref($sql);
176                                                      # Normalize columns to lowercase
177            2                                 23      $expl = { map { lc($_) => $expl->{$_} } keys %$expl };
              20                                 89   
178   ***      2     50                          17      if ( $expl->{possible_keys} ) {
179            2                                  7         MKDEBUG && _d('possible_keys =', $expl->{possible_keys});
180            2                                 20         my @candidates = split(',', $expl->{possible_keys});
181            2                                  7         my %possible   = map { $_ => 1 } @candidates;
               4                                 20   
182   ***      2     50                          11         if ( $expl->{key} ) {
183            2                                  6            MKDEBUG && _d('MySQL chose', $expl->{key});
184            2                                 11            unshift @candidates, grep { $possible{$_} } split(',', $expl->{key});
               3                                 14   
185            2                                  6            MKDEBUG && _d('Before deduping:', join(', ', @candidates));
186            2                                  5            my %seen;
187            2                                  8            @candidates = grep { !$seen{$_}++ } @candidates;
               7                                 32   
188                                                         }
189            2                                  5         MKDEBUG && _d('Final list:', join(', ', @candidates));
190            2                                 32         return @candidates;
191                                                      }
192                                                      else {
193   ***      0                                  0         MKDEBUG && _d('No keys in possible_keys');
194   ***      0                                  0         return ();
195                                                      }
196                                                   }
197                                                   
198                                                   # Returns true if the table exists.  If $can_insert is set, also checks whether
199                                                   # the user can insert into the table.
200                                                   sub table_exists {
201            3                    3            31      my ( $self, $dbh, $db, $tbl, $q, $can_insert ) = @_;
202            3                                 12      my $result = 0;
203            3                                 17      my $db_tbl = $q->quote($db, $tbl);
204            3                                 12      my $sql    = "SHOW FULL COLUMNS FROM $db_tbl";
205            3                                  7      MKDEBUG && _d($sql);
206            3                                  9      eval {
207            3                                  7         my $sth = $dbh->prepare($sql);
208            3                                730         $sth->execute();
209            1                                  7         my @columns = @{$sth->fetchall_arrayref({})};
               1                                 34   
210   ***      1     50                          12         if ( $can_insert ) {
211   ***      0             0                    0            $result = grep { ($_->{Privileges} || '') =~ m/insert/ } @columns;
      ***      0                                  0   
212                                                         }
213                                                         else {
214            1                                 24            $result = 1;
215                                                         }
216                                                      };
217            3                                 11      if ( MKDEBUG && $EVAL_ERROR ) {
218                                                         _d($EVAL_ERROR);
219                                                      }
220            3                                 24      return $result;
221                                                   }
222                                                   
223                                                   sub get_engine {
224           22                   22           204      my ( $self, $ddl, $opts ) = @_;
225           22                                479      my ( $engine ) = $ddl =~ m/\).*?(?:ENGINE|TYPE)=(\w+)/;
226           22                                 66      MKDEBUG && _d('Storage engine:', $engine);
227   ***     22            50                  140      return $engine || undef;
228                                                   }
229                                                   
230                                                   # $ddl is a SHOW CREATE TABLE returned from MySQLDumper::get_create_table().
231                                                   # The general format of a key is
232                                                   # [FOREIGN|UNIQUE|PRIMARY|FULLTEXT|SPATIAL] KEY `name` [USING BTREE|HASH] (`cols`).
233                                                   # Returns a hashref of keys and their properties:
234                                                   #    key => {
235                                                   #       type         => BTREE, FULLTEXT or  SPATIAL
236                                                   #       name         => column name, like: "foo_key"
237                                                   #       colnames     => original col def string, like: "(`a`,`b`)"
238                                                   #       cols         => arrayref containing the col names, like: [qw(a b)]
239                                                   #       col_prefixes => arrayref containing any col prefixes (parallels cols)
240                                                   #       is_unique    => 1 if the col is UNIQUE or PRIMARY
241                                                   #       is_nullable  => true (> 0) if one or more col can be NULL
242                                                   #       is_col       => hashref with key for each col=>1
243                                                   #   },
244                                                   #   key => ...
245                                                   # Foreign keys are ignored; use get_fks() instead.
246                                                   sub get_keys {
247           11                   11            72      my ( $self, $ddl, $opts, $is_nullable ) = @_;
248           11                                139      my $engine = $self->get_engine($ddl);
249           11                                 36      my $keys   = {};
250                                                   
251                                                      KEY:
252           11                                152      foreach my $key ( $ddl =~ m/^  ((?:[A-Z]+ )?KEY .*)$/gm ) {
253                                                   
254                                                         # If you want foreign keys, use get_fks() below.
255   ***     16     50                          76         next KEY if $key =~ m/FOREIGN/;
256                                                   
257           16                                 38         MKDEBUG && _d('Parsed key:', $key);
258                                                   
259                                                         # Make allowances for HASH bugs in SHOW CREATE TABLE.  A non-MEMORY table
260                                                         # will report its index as USING HASH even when this is not supported.
261                                                         # The true type should be BTREE.  See
262                                                         # http://bugs.mysql.com/bug.php?id=22632
263   ***     16     50                          92         if ( $engine !~ m/MEMORY|HEAP/ ) {
264           16                                 53            $key =~ s/USING HASH/USING BTREE/;
265                                                         }
266                                                   
267                                                         # Determine index type
268           16                                126         my ( $type, $cols ) = $key =~ m/(?:USING (\w+))? \((.+)\)/;
269           16                                 74         my ( $special ) = $key =~ m/(FULLTEXT|SPATIAL)/;
270   ***     16            33                  202         $type = $type || $special || 'BTREE';
      ***                   50                        
271   ***     16     50     33                  114         if ( $opts->{mysql_version} && $opts->{mysql_version} lt '004001000'
      ***                   33                        
272                                                            && $engine =~ m/HEAP|MEMORY/i )
273                                                         {
274   ***      0                                  0            $type = 'HASH'; # MySQL pre-4.1 supports only HASH indexes on HEAP
275                                                         }
276                                                   
277           16                                126         my ($name) = $key =~ m/(PRIMARY|`[^`]*`)/;
278           16    100                          88         my $unique = $key =~ m/PRIMARY|UNIQUE/ ? 1 : 0;
279           16                                 40         my @cols;
280           16                                 37         my @col_prefixes;
281           16                                 87         foreach my $col_def ( split(',', $cols) ) {
282                                                            # Parse columns of index including potential column prefixes
283                                                            # E.g.: `a`,`b`(20)
284           21                                162            my ($name, $prefix) = $col_def =~ m/`([^`]+)`(?:\((\d+)\))?/;
285           21                                 91            push @cols, $name;
286           21                                 93            push @col_prefixes, $prefix;
287                                                         }
288           16                                 77         $name =~ s/`//g;
289                                                   
290           16                                 38         MKDEBUG && _d('Key', $name, 'cols:', join(', ', @cols));
291                                                   
292           21                                119         $keys->{$name} = {
293                                                            name         => $name,
294                                                            type         => $type,
295                                                            colnames     => $cols,
296                                                            cols         => \@cols,
297                                                            col_prefixes => \@col_prefixes,
298                                                            is_unique    => $unique,
299           21                                221            is_nullable  => scalar(grep { $is_nullable->{$_} } @cols),
300           16                                 93            is_col       => { map { $_ => 1 } @cols },
301                                                         };
302                                                      }
303                                                   
304           11                                 50      return $keys;
305                                                   }
306                                                   
307                                                   # Like get_keys() above but only returns a hash of foreign keys.
308                                                   sub get_fks {
309            4                    4            58      my ( $self, $ddl, $opts ) = @_;
310            4                                 17      my $fks = {};
311                                                   
312            4                                 49      foreach my $fk (
313                                                         $ddl =~ m/CONSTRAINT .* FOREIGN KEY .* REFERENCES [^\)]*\)/mg )
314                                                      {
315            4                                 33         my ( $name ) = $fk =~ m/CONSTRAINT `(.*?)`/;
316            4                                 27         my ( $cols ) = $fk =~ m/FOREIGN KEY \(([^\)]+)\)/;
317            4                                 32         my ( $parent, $parent_cols ) = $fk =~ m/REFERENCES (\S+) \(([^\)]+)\)/;
318                                                   
319   ***      4    100     66                   57         if ( $parent !~ m/\./ && $opts->{database} ) {
320            1                                  5            $parent = "`$opts->{database}`.$parent";
321                                                         }
322                                                   
323            4                                 24         $fks->{$name} = {
324                                                            name           => $name,
325                                                            colnames       => $cols,
326            4                                 30            cols           => [ map { s/[ `]+//g; $_; } split(',', $cols) ],
               4                                 17   
327                                                            parent_tbl     => $parent,
328                                                            parent_colnames=> $parent_cols,
329            4                                 26            parent_cols    => [ map { s/[ `]+//g; $_; } split(',', $parent_cols) ],
               4                                 46   
330                                                         };
331                                                      }
332                                                   
333            4                                 60      return $fks;
334                                                   }
335                                                   
336                                                   # Removes the AUTO_INCREMENT property from the end of SHOW CREATE TABLE.  A
337                                                   # sample:
338                                                   # ) ENGINE=InnoDB AUTO_INCREMENT=201 DEFAULT CHARSET=utf8;
339                                                   sub remove_auto_increment {
340            1                    1            26      my ( $self, $ddl ) = @_;
341            1                                 19      $ddl =~ s/(^\).*?) AUTO_INCREMENT=\d+\b/$1/m;
342            1                                  7      return $ddl;
343                                                   }
344                                                   
345                                                   sub _d {
346   ***      0                    0                    my ($package, undef, $line) = caller 0;
347   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
348   ***      0                                              map { defined $_ ? $_ : 'undef' }
349                                                           @_;
350   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
351                                                   }
352                                                   
353                                                   1;
354                                                   
355                                                   # ###########################################################################
356                                                   # End TableParser package
357                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
48    ***     50      0     13   if (ref $ddl eq 'ARRAY')
49    ***      0      0      0   if (lc $$ddl[0] eq 'table') { }
59           100      2     11   if (not $ddl =~ /CREATE (?:TEMPORARY )?TABLE `/)
85    ***     50      0     48   unless $type
87           100     26     22   if ($type =~ /(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/)
91           100     21     27   if (not $def =~ /NOT NULL/)
95           100      4     44   $def =~ /AUTO_INCREMENT/i ? :
130          100      2      6   unless ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'} or $$tbl{'keys'}{$a}{'is_nullable'} <=> $$tbl{'keys'}{$b}{'is_nullable'}
146          100      2      1   if ($index)
149          100      2      1   if (not $best)
150          100      1      1   if ($index) { }
171   ***     50      0      2   unless $where
178   ***     50      2      0   if ($$expl{'possible_keys'}) { }
182   ***     50      2      0   if ($$expl{'key'})
210   ***     50      0      1   if ($can_insert) { }
255   ***     50      0     16   if $key =~ /FOREIGN/
263   ***     50     16      0   if (not $engine =~ /MEMORY|HEAP/)
271   ***     50      0     16   if ($$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000' and $engine =~ /HEAP|MEMORY/i)
278          100      5     11   $key =~ /PRIMARY|UNIQUE/ ? :
319          100      1      3   if (not $parent =~ /\./ and $$opts{'database'})
347   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
271   ***     33     16      0      0   $$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000'
      ***     33     16      0      0   $$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000' and $engine =~ /HEAP|MEMORY/i
319   ***     66      0      3      1   not $parent =~ /\./ and $$opts{'database'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
211   ***      0      0      0   $$_{'Privileges'} || ''
227   ***     50     22      0   $engine || undef
270   ***     50      0     16   $type || $special || 'BTREE'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
130   ***     66      4      0      4   ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'}
             100      4      2      2   ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'} or $$tbl{'keys'}{$a}{'is_nullable'} <=> $$tbl{'keys'}{$b}{'is_nullable'}
270   ***     33      0      0     16   $type || $special


Covered Subroutines
-------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:22 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:23 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:24 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:26 
find_best_index           3 /home/daniel/dev/maatkit/common/TableParser.pm:144
find_possible_keys        2 /home/daniel/dev/maatkit/common/TableParser.pm:170
get_engine               22 /home/daniel/dev/maatkit/common/TableParser.pm:224
get_fks                   4 /home/daniel/dev/maatkit/common/TableParser.pm:309
get_keys                 11 /home/daniel/dev/maatkit/common/TableParser.pm:247
new                       1 /home/daniel/dev/maatkit/common/TableParser.pm:29 
parse                    13 /home/daniel/dev/maatkit/common/TableParser.pm:46 
remove_auto_increment     1 /home/daniel/dev/maatkit/common/TableParser.pm:340
sort_indexes              2 /home/daniel/dev/maatkit/common/TableParser.pm:123
table_exists              3 /home/daniel/dev/maatkit/common/TableParser.pm:201

Uncovered Subroutines
---------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
_d                        0 /home/daniel/dev/maatkit/common/TableParser.pm:346


