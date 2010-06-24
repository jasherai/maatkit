---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableParser.pm   93.0   77.0   63.3   94.1    0.0    6.7   83.4
TableParser.t                 100.0   50.0   33.3  100.0    n/a   93.3   95.2
Total                          95.7   74.4   60.0   96.7    0.0  100.0   87.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:45 2010
Finish:       Thu Jun 24 19:37:45 2010

Run:          TableParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:46 2010
Finish:       Thu Jun 24 19:37:47 2010

/home/daniel/dev/maatkit/common/TableParser.pm

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
18                                                    # TableParser package $Revision: 5980 $
19                                                    # ###########################################################################
20                                                    package TableParser;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
26                                                    $Data::Dumper::Indent    = 1;
27                                                    $Data::Dumper::Sortkeys  = 1;
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    
30    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 15   
31                                                    
32                                                    
33                                                    sub new {
34    ***      1                    1      0      6      my ( $class, %args ) = @_;
35             1                                  6      my @required_args = qw(Quoter);
36             1                                  4      foreach my $arg ( @required_args ) {
37    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
38                                                       }
39             1                                  6      my $self = { %args };
40             1                                 12      return bless $self, $class;
41                                                    }
42                                                    
43                                                    # Several subs in this module require either a $ddl or $tbl param.
44                                                    #
45                                                    # $ddl is the return value from MySQLDump::get_create_table() (which returns
46                                                    # the output of SHOW CREATE TALBE).
47                                                    #
48                                                    # $tbl is the return value from the sub below, parse().
49                                                    #
50                                                    # And some subs have an optional $opts param which is a hashref of options.
51                                                    # $opts->{mysql_version} is typically used, which is the return value from
52                                                    # VersionParser::parser() (which returns a zero-padded MySQL version,
53                                                    # e.g. 004001000 for 4.1.0).
54                                                    
55                                                    sub parse {
56    ***     25                   25      0    489      my ( $self, $ddl, $opts ) = @_;
57            25    100                         214      return unless $ddl;
58    ***     24     50                         218      if ( ref $ddl eq 'ARRAY' ) {
59    ***      0      0                           0         if ( lc $ddl->[0] eq 'table' ) {
60    ***      0                                  0            $ddl = $ddl->[1];
61                                                          }
62                                                          else {
63                                                             return {
64    ***      0                                  0               engine => 'VIEW',
65                                                             };
66                                                          }
67                                                       }
68                                                    
69            24    100                         353      if ( $ddl !~ m/CREATE (?:TEMPORARY )?TABLE `/ ) {
70             2                                  7         die "Cannot parse table definition; is ANSI quoting "
71                                                             . "enabled or SQL_QUOTE_SHOW_CREATE disabled?";
72                                                       }
73                                                    
74            22                                311      my ($name)     = $ddl =~ m/CREATE (?:TEMPORARY )?TABLE\s+(`.+?`)/;
75    ***     22     50                         325      (undef, $name) = $self->{Quoter}->split_unquote($name) if $name;
76                                                    
77                                                       # Lowercase identifiers to avoid issues with case-sensitivity in Perl.
78                                                       # (Bug #1910276).
79            22                               2371      $ddl =~ s/(`[^`]+`)/\L$1/g;
80                                                    
81            22                                187      my $engine = $self->get_engine($ddl);
82                                                    
83            22                               1279      my @defs   = $ddl =~ m/^(\s+`.*?),?$/gm;
84            22                                156      my @cols   = map { $_ =~ m/`([^`]+)`/ } @defs;
              96                                858   
85            22                                 88      MKDEBUG && _d('Table cols:', join(', ', map { "`$_`" } @cols));
86                                                    
87                                                       # Save the column definitions *exactly*
88            22                                 74      my %def_for;
89            22                                270      @def_for{@cols} = @defs;
90                                                    
91                                                       # Find column types, whether numeric, whether nullable, whether
92                                                       # auto-increment.
93            22                                 95      my (@nums, @null);
94            22                                108      my (%type_for, %is_nullable, %is_numeric, %is_autoinc);
95            22                                127      foreach my $col ( @cols ) {
96            96                                464         my $def = $def_for{$col};
97            96                                909         my ( $type ) = $def =~ m/`[^`]+`\s([a-z]+)/;
98    ***     96     50                         555         die "Can't determine column type for $def" unless $type;
99            96                                467         $type_for{$col} = $type;
100           96    100                         859         if ( $type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ) {
101           59                                269            push @nums, $col;
102           59                                302            $is_numeric{$col} = 1;
103                                                         }
104           96    100                         627         if ( $def !~ m/NOT NULL/ ) {
105           44                                194            push @null, $col;
106           44                                208            $is_nullable{$col} = 1;
107                                                         }
108           96    100                         861         $is_autoinc{$col} = $def =~ m/AUTO_INCREMENT/i ? 1 : 0;
109                                                      }
110                                                   
111                                                      # TODO: passing is_nullable this way is just a quick hack. Ultimately,
112                                                      # we probably should decompose this sub further, taking out the block
113                                                      # above that parses col props like nullability, auto_inc, type, etc.
114           22                                191      my ($keys, $clustered_key) = $self->get_keys($ddl, $opts, \%is_nullable);
115                                                   
116                                                      return {
117           96                                626         name           => $name,
118                                                         cols           => \@cols,
119           96                                993         col_posn       => { map { $cols[$_] => $_ } 0..$#cols },
120           22                                272         is_col         => { map { $_ => 1 } @cols },
121                                                         null_cols      => \@null,
122                                                         is_nullable    => \%is_nullable,
123                                                         is_autoinc     => \%is_autoinc,
124                                                         clustered_key  => $clustered_key,
125                                                         keys           => $keys,
126                                                         defs           => \%def_for,
127                                                         numeric_cols   => \@nums,
128                                                         is_numeric     => \%is_numeric,
129                                                         engine         => $engine,
130                                                         type_for       => \%type_for,
131                                                      };
132                                                   }
133                                                   
134                                                   # Sorts indexes in this order: PRIMARY, unique, non-nullable, any (shortest
135                                                   # first, alphabetical).  Only BTREE indexes are considered.
136                                                   # TODO: consider length as # of bytes instead of # of columns.
137                                                   sub sort_indexes {
138   ***      2                    2      0      8      my ( $self, $tbl ) = @_;
139                                                   
140                                                      my @indexes
141            2                                 11         = sort {
142            8                                 37            (($a ne 'PRIMARY') <=> ($b ne 'PRIMARY'))
143                                                            || ( !$tbl->{keys}->{$a}->{is_unique} <=> !$tbl->{keys}->{$b}->{is_unique} )
144                                                            || ( $tbl->{keys}->{$a}->{is_nullable} <=> $tbl->{keys}->{$b}->{is_nullable} )
145   ***      8    100     66                  124            || ( scalar(@{$tbl->{keys}->{$a}->{cols}}) <=> scalar(@{$tbl->{keys}->{$b}->{cols}}) )
               2           100                   12   
146                                                         }
147                                                         grep {
148            2                                 24            $tbl->{keys}->{$_}->{type} eq 'BTREE'
149                                                         }
150            2                                  6         sort keys %{$tbl->{keys}};
151                                                   
152            2                                 14      MKDEBUG && _d('Indexes sorted best-first:', join(', ', @indexes));
153            2                                 15      return @indexes;
154                                                   }
155                                                   
156                                                   # Finds the 'best' index; if the user specifies one, dies if it's not in the
157                                                   # table.
158                                                   sub find_best_index {
159   ***      3                    3      0     15      my ( $self, $tbl, $index ) = @_;
160            3                                  7      my $best;
161            3    100                          14      if ( $index ) {
162            2                                  5         ($best) = grep { uc $_ eq uc $index } keys %{$tbl->{keys}};
               8                                 31   
               2                                 13   
163                                                      }
164            3    100                          15      if ( !$best ) {
165            2    100                           8         if ( $index ) {
166                                                            # The user specified an index, so we can't choose our own.
167            1                                  3            die "Index '$index' does not exist in table";
168                                                         }
169                                                         else {
170                                                            # Try to pick the best index.
171                                                            # TODO: eliminate indexes that have column prefixes.
172            1                                  6            ($best) = $self->sort_indexes($tbl);
173                                                         }
174                                                      }
175            2                                  5      MKDEBUG && _d('Best index found is', $best);
176            2                                 13      return $best;
177                                                   }
178                                                   
179                                                   # Takes a dbh, database, table, quoter, and WHERE clause, and reports the
180                                                   # indexes MySQL thinks are best for EXPLAIN SELECT * FROM that table.  If no
181                                                   # WHERE, just returns an empty list.  If no possible_keys, returns empty list,
182                                                   # even if 'key' is not null.  Only adds 'key' to the list if it's included in
183                                                   # possible_keys.
184                                                   sub find_possible_keys {
185   ***      2                    2      0     24      my ( $self, $dbh, $database, $table, $quoter, $where ) = @_;
186   ***      2     50                          19      return () unless $where;
187            2                                 20      my $sql = 'EXPLAIN SELECT * FROM ' . $quoter->quote($database, $table)
188                                                         . ' WHERE ' . $where;
189            2                                158      MKDEBUG && _d($sql);
190            2                                  9      my $expl = $dbh->selectrow_hashref($sql);
191                                                      # Normalize columns to lowercase
192            2                                 44      $expl = { map { lc($_) => $expl->{$_} } keys %$expl };
              20                                186   
193   ***      2     50                          31      if ( $expl->{possible_keys} ) {
194            2                                  7         MKDEBUG && _d('possible_keys =', $expl->{possible_keys});
195            2                                 34         my @candidates = split(',', $expl->{possible_keys});
196            2                                 13         my %possible   = map { $_ => 1 } @candidates;
               4                                 33   
197   ***      2     50                          19         if ( $expl->{key} ) {
198            2                                  7            MKDEBUG && _d('MySQL chose', $expl->{key});
199            2                                 21            unshift @candidates, grep { $possible{$_} } split(',', $expl->{key});
               3                                 21   
200            2                                  9            MKDEBUG && _d('Before deduping:', join(', ', @candidates));
201            2                                  9            my %seen;
202            2                                 11            @candidates = grep { !$seen{$_}++ } @candidates;
               7                                 56   
203                                                         }
204            2                                  9         MKDEBUG && _d('Final list:', join(', ', @candidates));
205            2                                 66         return @candidates;
206                                                      }
207                                                      else {
208   ***      0                                  0         MKDEBUG && _d('No keys in possible_keys');
209   ***      0                                  0         return ();
210                                                      }
211                                                   }
212                                                   
213                                                   # Required args:
214                                                   #   * dbh  dbh: active dbh
215                                                   #   * db   scalar: database name to check
216                                                   #   * tbl  scalar: table name to check
217                                                   # Optional args:
218                                                   #   * all_privs  bool: check for all privs (select,insert,update,delete)
219                                                   # Returns: bool
220                                                   # Can die: no
221                                                   # check_table() checks the given table for certain criteria and returns
222                                                   # true if all criteria are found, else it returns false.  The existence
223                                                   # of the table is always checked; if no optional args are given, then this
224                                                   # is the only check.  Any error causes a false return value (e.g. if the
225                                                   # table is crashed).
226                                                   sub check_table {
227   ***      8                    8      0    128      my ( $self, %args ) = @_;
228            8                                 68      my @required_args = qw(dbh db tbl);
229            8                                 53      foreach my $arg ( @required_args ) {
230   ***     24     50                         187         die "I need a $arg argument" unless $args{$arg};
231                                                      }
232            8                                 63      my ($dbh, $db, $tbl) = @args{@required_args};
233            8                                 50      my $q      = $self->{Quoter};
234            8                                 83      my $db_tbl = $q->quote($db, $tbl);
235            8                                594      MKDEBUG && _d('Checking', $db_tbl);
236                                                   
237            8                                 59      my $sql = "SHOW TABLES FROM " . $q->quote($db)
238                                                              . ' LIKE ' . $q->literal_like($tbl);
239            8                                 30      MKDEBUG && _d($sql);
240            8                                 29      my $row;
241            8                                 31      eval {
242            8                                 30         $row = $dbh->selectrow_arrayref($sql);
243                                                      };
244            8    100                        3468      if ( $EVAL_ERROR ) {
245            2                                 10         MKDEBUG && _d($EVAL_ERROR);
246            2                                 32         return 0;
247                                                      }
248   ***      6    100     66                  129      if ( !$row->[0] || $row->[0] ne $tbl ) {
249            1                                  5         MKDEBUG && _d('Table does not exist');
250            1                                 17         return 0;
251                                                      }
252                                                   
253                                                      # Table exists, return true unless we have privs to check.
254            5                                 18      MKDEBUG && _d('Table exists; no privs to check');
255            5    100                          85      return 1 unless $args{all_privs};
256                                                   
257                                                      # Get privs select,insert,update.
258            2                                 11      $sql = "SHOW FULL COLUMNS FROM $db_tbl";
259            2                                  7      MKDEBUG && _d($sql);
260            2                                  9      eval {
261            2                                  7         $row = $dbh->selectrow_hashref($sql);
262                                                      };
263   ***      2     50                          29      if ( $EVAL_ERROR ) {
264   ***      0                                  0         MKDEBUG && _d($EVAL_ERROR);
265   ***      0                                  0         return 0;
266                                                      }
267   ***      2     50                          21      if ( !scalar keys %$row ) {
268                                                         # This should never happen.
269   ***      0                                  0         MKDEBUG && _d('Table has no columns:', Dumper($row));
270   ***      0                                  0         return 0;
271                                                      }
272   ***      2            33                   44      my $privs = $row->{privileges} || $row->{Privileges};
273                                                   
274                                                      # Get delete priv since FULL COLUMNS doesn't show it.   
275            2                                 15      $sql = "DELETE FROM $db_tbl LIMIT 0";
276            2                                  8      MKDEBUG && _d($sql);
277            2                                  7      eval {
278            2                                205         $dbh->do($sql);
279                                                      };
280            2    100                          24      my $can_delete = $EVAL_ERROR ? 0 : 1;
281                                                   
282            2                                  6      MKDEBUG && _d('User privs on', $db_tbl, ':', $privs,
283                                                         ($can_delete ? 'delete' : ''));
284                                                   
285                                                      # Check that we have all privs.
286   ***      2    100     66                   82      if ( !($privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/
      ***                   66                        
      ***                   66                        
287                                                             && $can_delete) ) {
288            1                                  4         MKDEBUG && _d('User does not have all privs');
289            1                                 22         return 0;
290                                                      }
291                                                   
292            1                                  4      MKDEBUG && _d('User has all privs');
293            1                                 22      return 1;
294                                                   }
295                                                   
296                                                   sub get_engine {
297   ***     45                   45      0    342      my ( $self, $ddl, $opts ) = @_;
298           45                               1228      my ( $engine ) = $ddl =~ m/\).*?(?:ENGINE|TYPE)=(\w+)/;
299           45                                167      MKDEBUG && _d('Storage engine:', $engine);
300   ***     45            50                  358      return $engine || undef;
301                                                   }
302                                                   
303                                                   # $ddl is a SHOW CREATE TABLE returned from MySQLDumper::get_create_table().
304                                                   # The general format of a key is
305                                                   # [FOREIGN|UNIQUE|PRIMARY|FULLTEXT|SPATIAL] KEY `name` [USING BTREE|HASH] (`cols`).
306                                                   # Returns a hashref of keys and their properties and the clustered key (if
307                                                   # the engine is InnoDB):
308                                                   #   {
309                                                   #     key => {
310                                                   #       type         => BTREE, FULLTEXT or  SPATIAL
311                                                   #       name         => column name, like: "foo_key"
312                                                   #       colnames     => original col def string, like: "(`a`,`b`)"
313                                                   #       cols         => arrayref containing the col names, like: [qw(a b)]
314                                                   #       col_prefixes => arrayref containing any col prefixes (parallels cols)
315                                                   #       is_unique    => 1 if the col is UNIQUE or PRIMARY
316                                                   #       is_nullable  => true (> 0) if one or more col can be NULL
317                                                   #       is_col       => hashref with key for each col=>1
318                                                   #       ddl          => original key def string
319                                                   #     },
320                                                   #   },
321                                                   #   'PRIMARY',   # clustered key
322                                                   #
323                                                   # Foreign keys are ignored; use get_fks() instead.
324                                                   sub get_keys {
325   ***     23                   23      0    201      my ( $self, $ddl, $opts, $is_nullable ) = @_;
326           23                                142      my $engine        = $self->get_engine($ddl);
327           23                                106      my $keys          = {};
328           23                                 79      my $clustered_key = undef;
329                                                   
330                                                      KEY:
331           23                                508      foreach my $key ( $ddl =~ m/^  ((?:[A-Z]+ )?KEY .*)$/gm ) {
332                                                   
333                                                         # If you want foreign keys, use get_fks() below.
334   ***     45     50                         284         next KEY if $key =~ m/FOREIGN/;
335                                                   
336           45                                193         my $key_ddl = $key;
337           45                                135         MKDEBUG && _d('Parsed key:', $key_ddl);
338                                                   
339                                                         # Make allowances for HASH bugs in SHOW CREATE TABLE.  A non-MEMORY table
340                                                         # will report its index as USING HASH even when this is not supported.
341                                                         # The true type should be BTREE.  See
342                                                         # http://bugs.mysql.com/bug.php?id=22632
343   ***     45     50                         392         if ( $engine !~ m/MEMORY|HEAP/ ) {
344           45                                214            $key =~ s/USING HASH/USING BTREE/;
345                                                         }
346                                                   
347                                                         # Determine index type
348           45                                557         my ( $type, $cols ) = $key =~ m/(?:USING (\w+))? \((.+)\)/;
349           45                                321         my ( $special ) = $key =~ m/(FULLTEXT|SPATIAL)/;
350   ***     45            33                  846         $type = $type || $special || 'BTREE';
      ***                   50                        
351   ***     45     50     33                  462         if ( $opts->{mysql_version} && $opts->{mysql_version} lt '004001000'
      ***                   33                        
352                                                            && $engine =~ m/HEAP|MEMORY/i )
353                                                         {
354   ***      0                                  0            $type = 'HASH'; # MySQL pre-4.1 supports only HASH indexes on HEAP
355                                                         }
356                                                   
357           45                                496         my ($name) = $key =~ m/(PRIMARY|`[^`]*`)/;
358           45    100                         374         my $unique = $key =~ m/PRIMARY|UNIQUE/ ? 1 : 0;
359           45                                148         my @cols;
360           45                                137         my @col_prefixes;
361           45                                443         foreach my $col_def ( $cols =~ m/`[^`]+`(?:\(\d+\))?/g ) {
362                                                            # Parse columns of index including potential column prefixes
363                                                            # E.g.: `a`,`b`(20)
364           52                                452            my ($name, $prefix) = $col_def =~ m/`([^`]+)`(?:\((\d+)\))?/;
365           52                                283            push @cols, $name;
366           52                                312            push @col_prefixes, $prefix;
367                                                         }
368           45                                312         $name =~ s/`//g;
369                                                   
370           45                                138         MKDEBUG && _d( $name, 'key cols:', join(', ', map { "`$_`" } @cols));
371                                                   
372           52                                349         $keys->{$name} = {
373                                                            name         => $name,
374                                                            type         => $type,
375                                                            colnames     => $cols,
376                                                            cols         => \@cols,
377                                                            col_prefixes => \@col_prefixes,
378                                                            is_unique    => $unique,
379           52                                902            is_nullable  => scalar(grep { $is_nullable->{$_} } @cols),
380           45                                390            is_col       => { map { $_ => 1 } @cols },
381                                                            ddl          => $key_ddl,
382                                                         };
383                                                   
384                                                         # Find clustered key (issue 295).
385           45    100    100                  784         if ( $engine =~ m/InnoDB/i && !$clustered_key ) {
386           24                                133            my $this_key = $keys->{$name};
387           24    100    100                  288            if ( $this_key->{name} eq 'PRIMARY' ) {
                    100                               
388            8                                 34               $clustered_key = 'PRIMARY';
389                                                            }
390                                                            elsif ( $this_key->{is_unique} && !$this_key->{is_nullable} ) {
391            1                                 42               $clustered_key = $this_key->{name};
392                                                            }
393           24                                144            MKDEBUG && $clustered_key && _d('This key is the clustered key');
394                                                         }
395                                                      }
396                                                   
397           23                                187      return $keys, $clustered_key;
398                                                   }
399                                                   
400                                                   # Like get_keys() above but only returns a hash of foreign keys.
401                                                   sub get_fks {
402   ***      4                    4      0     85      my ( $self, $ddl, $opts ) = @_;
403            4                                 19      my $fks = {};
404                                                   
405            4                                 61      foreach my $fk (
406                                                         $ddl =~ m/CONSTRAINT .* FOREIGN KEY .* REFERENCES [^\)]*\)/mg )
407                                                      {
408            4                                 37         my ( $name ) = $fk =~ m/CONSTRAINT `(.*?)`/;
409            4                                 32         my ( $cols ) = $fk =~ m/FOREIGN KEY \(([^\)]+)\)/;
410            4                                 40         my ( $parent, $parent_cols ) = $fk =~ m/REFERENCES (\S+) \(([^\)]+)\)/;
411                                                   
412   ***      4    100     66                   76         if ( $parent !~ m/\./ && $opts->{database} ) {
413            1                                  7            $parent = "`$opts->{database}`.$parent";
414                                                         }
415                                                   
416            4                                 25         $fks->{$name} = {
417                                                            name           => $name,
418                                                            colnames       => $cols,
419            4                                 36            cols           => [ map { s/[ `]+//g; $_; } split(',', $cols) ],
               4                                 19   
420                                                            parent_tbl     => $parent,
421                                                            parent_colnames=> $parent_cols,
422            4                                 31            parent_cols    => [ map { s/[ `]+//g; $_; } split(',', $parent_cols) ],
               4                                 57   
423                                                            ddl            => $fk,
424                                                         };
425                                                      }
426                                                   
427            4                                 70      return $fks;
428                                                   }
429                                                   
430                                                   # Removes the AUTO_INCREMENT property from the end of SHOW CREATE TABLE.  A
431                                                   # sample:
432                                                   # ) ENGINE=InnoDB AUTO_INCREMENT=201 DEFAULT CHARSET=utf8;
433                                                   sub remove_auto_increment {
434   ***      1                    1      0      9      my ( $self, $ddl ) = @_;
435            1                                 27      $ddl =~ s/(^\).*?) AUTO_INCREMENT=\d+\b/$1/m;
436            1                                 12      return $ddl;
437                                                   }
438                                                   
439                                                   sub remove_secondary_indexes {
440   ***      9                    9      0     85      my ( $self, $ddl ) = @_;
441            9                                 36      my $sec_indexes_ddl;
442            9                                 67      my $tbl_struct = $self->parse($ddl);
443                                                   
444   ***      9    100     50                  132      if ( ($tbl_struct->{engine} || '') =~ m/InnoDB/i ) {
445            7                                 40         my $clustered_key = $tbl_struct->{clustered_key};
446            7           100                   41         $clustered_key  ||= '';
447                                                   
448           18                                111         my @sec_indexes   = map {
449                                                            # Remove key from CREATE TABLE ddl.
450           22                                149            my $key_def = $_->{ddl};
451                                                            # Escape ( ) in the key def so Perl treats them literally.
452           18                                279            $key_def =~ s/([\(\)])/\\$1/g;
453           18                                801            $ddl =~ s/\s+$key_def//i;
454                                                   
455           18                                121            my $key_ddl = "ADD $_->{ddl}";
456                                                            # Last key in table won't have trailing comma, but since
457                                                            # we're iterating through a hash the last key may not be
458                                                            # the last in the list we're creating.
459                                                            # http://code.google.com/p/maatkit/issues/detail?id=833
460           18    100                         136            $key_ddl   .= ',' unless $key_ddl =~ m/,$/;
461           18                                133            $key_ddl;
462                                                         }
463            7                                 65         grep { $_->{name} ne $clustered_key }
464            7                                 31         values %{$tbl_struct->{keys}};
465            7                                 30         MKDEBUG && _d('Secondary indexes:', Dumper(\@sec_indexes));
466                                                   
467            7    100                          48         if ( @sec_indexes ) {
468            6                                 50            $sec_indexes_ddl = join(' ', @sec_indexes);
469            6                                 42            $sec_indexes_ddl =~ s/,$//;
470                                                         }
471                                                   
472                                                         # Remove trailing comma on last key.  Cases like:
473                                                         #   PK,
474                                                         #   KEY,
475                                                         # ) ENGINE=...
476                                                         # will leave a trailing comma on PK.
477            7                                 89         $ddl =~ s/,(\n\) )/$1/s;
478                                                      }
479                                                      else {
480            2                                  7         MKDEBUG && _d('Not removing secondary indexes from',
481                                                            $tbl_struct->{engine}, 'table');
482                                                      }
483                                                   
484            9                                110      return $ddl, $sec_indexes_ddl, $tbl_struct;
485                                                   }
486                                                   
487                                                   sub _d {
488   ***      0                    0                    my ($package, undef, $line) = caller 0;
489   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
490   ***      0                                              map { defined $_ ? $_ : 'undef' }
491                                                           @_;
492   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
493                                                   }
494                                                   
495                                                   1;
496                                                   
497                                                   # ###########################################################################
498                                                   # End TableParser package
499                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
37    ***     50      0      1   unless $args{$arg}
57           100      1     24   unless $ddl
58    ***     50      0     24   if (ref $ddl eq 'ARRAY')
59    ***      0      0      0   if (lc $$ddl[0] eq 'table') { }
69           100      2     22   if (not $ddl =~ /CREATE (?:TEMPORARY )?TABLE `/)
75    ***     50     22      0   if $name
98    ***     50      0     96   unless $type
100          100     59     37   if ($type =~ /(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/)
104          100     44     52   if (not $def =~ /NOT NULL/)
108          100      8     88   $def =~ /AUTO_INCREMENT/i ? :
145          100      2      6   unless ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'} or $$tbl{'keys'}{$a}{'is_nullable'} <=> $$tbl{'keys'}{$b}{'is_nullable'}
161          100      2      1   if ($index)
164          100      2      1   if (not $best)
165          100      1      1   if ($index) { }
186   ***     50      0      2   unless $where
193   ***     50      2      0   if ($$expl{'possible_keys'}) { }
197   ***     50      2      0   if ($$expl{'key'})
230   ***     50      0     24   unless $args{$arg}
244          100      2      6   if ($EVAL_ERROR)
248          100      1      5   if (not $$row[0] or $$row[0] ne $tbl)
255          100      3      2   unless $args{'all_privs'}
263   ***     50      0      2   if ($EVAL_ERROR)
267   ***     50      0      2   if (not scalar keys %$row)
280          100      1      1   $EVAL_ERROR ? :
286          100      1      1   if (not $privs =~ /select/ && $privs =~ /insert/ && $privs =~ /update/ && $can_delete)
334   ***     50      0     45   if $key =~ /FOREIGN/
343   ***     50     45      0   if (not $engine =~ /MEMORY|HEAP/)
351   ***     50      0     45   if ($$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000' and $engine =~ /HEAP|MEMORY/i)
358          100     15     30   $key =~ /PRIMARY|UNIQUE/ ? :
385          100     24     21   if ($engine =~ /InnoDB/i and not $clustered_key)
387          100      8     16   if ($$this_key{'name'} eq 'PRIMARY') { }
             100      1     15   elsif ($$this_key{'is_unique'} and not $$this_key{'is_nullable'}) { }
412          100      1      3   if (not $parent =~ /\./ and $$opts{'database'})
444          100      7      2   if (($$tbl_struct{'engine'} || '') =~ /InnoDB/i) { }
460          100      4     14   unless $key_ddl =~ /,$/
467          100      6      1   if (@sec_indexes)
489   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
286   ***     66      0      1      1   $privs =~ /select/ && $privs =~ /insert/
      ***     66      1      0      1   $privs =~ /select/ && $privs =~ /insert/ && $privs =~ /update/
      ***     66      1      0      1   $privs =~ /select/ && $privs =~ /insert/ && $privs =~ /update/ && $can_delete
351   ***     33     45      0      0   $$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000'
      ***     33     45      0      0   $$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000' and $engine =~ /HEAP|MEMORY/i
385          100      8     13     24   $engine =~ /InnoDB/i and not $clustered_key
387          100     13      2      1   $$this_key{'is_unique'} and not $$this_key{'is_nullable'}
412   ***     66      0      3      1   not $parent =~ /\./ and $$opts{'database'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0
300   ***     50     45      0   $engine || undef
350   ***     50      0     45   $type || $special || 'BTREE'
444   ***     50      9      0   $$tbl_struct{'engine'} || ''
446          100      4      3   $clustered_key ||= ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
145   ***     66      4      0      4   ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'}
             100      4      2      2   ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'} or $$tbl{'keys'}{$a}{'is_nullable'} <=> $$tbl{'keys'}{$b}{'is_nullable'}
248   ***     66      1      0      5   not $$row[0] or $$row[0] ne $tbl
272   ***     33      0      2      0   $$row{'privileges'} || $$row{'Privileges'}
350   ***     33      0      0     45   $type || $special


Covered Subroutines
-------------------

Subroutine               Count Pod Location                                          
------------------------ ----- --- --------------------------------------------------
BEGIN                        1     /home/daniel/dev/maatkit/common/TableParser.pm:22 
BEGIN                        1     /home/daniel/dev/maatkit/common/TableParser.pm:23 
BEGIN                        1     /home/daniel/dev/maatkit/common/TableParser.pm:24 
BEGIN                        1     /home/daniel/dev/maatkit/common/TableParser.pm:25 
BEGIN                        1     /home/daniel/dev/maatkit/common/TableParser.pm:30 
check_table                  8   0 /home/daniel/dev/maatkit/common/TableParser.pm:227
find_best_index              3   0 /home/daniel/dev/maatkit/common/TableParser.pm:159
find_possible_keys           2   0 /home/daniel/dev/maatkit/common/TableParser.pm:185
get_engine                  45   0 /home/daniel/dev/maatkit/common/TableParser.pm:297
get_fks                      4   0 /home/daniel/dev/maatkit/common/TableParser.pm:402
get_keys                    23   0 /home/daniel/dev/maatkit/common/TableParser.pm:325
new                          1   0 /home/daniel/dev/maatkit/common/TableParser.pm:34 
parse                       25   0 /home/daniel/dev/maatkit/common/TableParser.pm:56 
remove_auto_increment        1   0 /home/daniel/dev/maatkit/common/TableParser.pm:434
remove_secondary_indexes     9   0 /home/daniel/dev/maatkit/common/TableParser.pm:440
sort_indexes                 2   0 /home/daniel/dev/maatkit/common/TableParser.pm:138

Uncovered Subroutines
---------------------

Subroutine               Count Pod Location                                          
------------------------ ----- --- --------------------------------------------------
_d                           0     /home/daniel/dev/maatkit/common/TableParser.pm:488


TableParser.t

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
               1                                  3   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            11   use Test::More tests => 54;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            11   use TableParser;
               1                                  2   
               1                                 13   
15             1                    1            51   use Quoter;
               1                                  3   
               1                                  9   
16             1                    1            18   use DSNParser;
               1                                  3   
               1                                 12   
17             1                    1            14   use Sandbox;
               1                                  3   
               1                                 10   
18             1                    1            12   use MaatkitTest;
               1                                  4   
               1                                 40   
19                                                    
20             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
21             1                                238   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
22             1                                 59   my $dbh = $sb->get_dbh_for('master');
23             1                                357   my $q   = new Quoter();
24             1                                 33   my $tp  = new TableParser(Quoter=>$q);
25             1                                  4   my $tbl;
26             1                                  3   my $sample = "common/t/samples/tables/";
27                                                    
28             1                                  3   eval {
29             1                                 10      $tp->parse( load_file('common/t/samples/noquotes.sql') );
30                                                    };
31             1                                 33   like($EVAL_ERROR, qr/quoting/, 'No quoting');
32                                                    
33             1                                 11   eval {
34             1                                  6      $tp->parse( load_file('common/t/samples/ansi_quotes.sql') );
35                                                    };
36             1                                 14   like($EVAL_ERROR, qr/quoting/, 'ANSI quoting');
37                                                    
38             1                                  9   $tbl = $tp->parse( load_file('common/t/samples/t1.sql') );
39             1                                 38   is_deeply(
40                                                       $tbl,
41                                                       {  cols         => [qw(a)],
42                                                          col_posn     => { a => 0 },
43                                                          is_col       => { a => 1 },
44                                                          is_autoinc   => { a => 0 },
45                                                          null_cols    => [qw(a)],
46                                                          is_nullable  => { a => 1 },
47                                                          clustered_key => undef,
48                                                          keys         => {},
49                                                          defs         => { a => '  `a` int(11) default NULL' },
50                                                          numeric_cols => [qw(a)],
51                                                          is_numeric   => { a => 1 },
52                                                          engine       => 'MyISAM',
53                                                          type_for     => { a => 'int' },
54                                                          name         => 't1',
55                                                       },
56                                                       'Basic table is OK',
57                                                    );
58                                                    
59             1                                 16   $tbl = $tp->parse( load_file('common/t/samples/TableParser-prefix_idx.sql') );
60             1                                 53   is_deeply(
61                                                       $tbl,
62                                                       {
63                                                          name           => 't1',
64                                                          cols           => [ 'a', 'b' ],
65                                                          col_posn       => { a => 0, b => 1 },
66                                                          is_col         => { a => 1, b => 1 },
67                                                          is_autoinc     => { 'a' => 0, 'b' => 0 },
68                                                          null_cols      => [ 'a', 'b' ],
69                                                          is_nullable    => { 'a' => 1, 'b' => 1 },
70                                                          clustered_key  => undef,
71                                                          keys           => {
72                                                             prefix_idx => {
73                                                                is_unique => 0,
74                                                                is_col => {
75                                                                   a => 1,
76                                                                   b => 1,
77                                                                },
78                                                                name => 'prefix_idx',
79                                                                type => 'BTREE',
80                                                                is_nullable => 2,
81                                                                colnames => '`a`(10),`b`(20)',
82                                                                cols => [ 'a', 'b' ],
83                                                                col_prefixes => [ 10, 20 ],
84                                                                ddl => 'KEY `prefix_idx` (`a`(10),`b`(20)),',
85                                                             },
86                                                             mix_idx => {
87                                                                is_unique => 0,
88                                                                is_col => {
89                                                                   a => 1,
90                                                                   b => 1,
91                                                                },
92                                                                name => 'mix_idx',
93                                                                type => 'BTREE',
94                                                                is_nullable => 2,
95                                                                colnames => '`a`,`b`(20)',
96                                                                cols => [ 'a', 'b' ],
97                                                                col_prefixes => [ undef, 20 ],
98                                                                ddl => 'KEY `mix_idx` (`a`,`b`(20))',
99                                                             },
100                                                         },
101                                                         defs           => {
102                                                            a => '  `a` varchar(64) default NULL',
103                                                            b => '  `b` varchar(64) default NULL'
104                                                         },
105                                                         numeric_cols   => [],
106                                                         is_numeric     => {},
107                                                         engine         => 'MyISAM',
108                                                         type_for       => { a => 'varchar', b => 'varchar' },
109                                                      },
110                                                      'Indexes with prefixes parse OK (fixes issue 1)'
111                                                   );
112                                                   
113            1                                 34   $tbl = $tp->parse( load_file('common/t/samples/sakila.film.sql') );
114            1                                172   is_deeply(
115                                                      $tbl,
116                                                      {  cols => [
117                                                            qw(film_id title description release_year language_id
118                                                               original_language_id rental_duration rental_rate
119                                                               length replacement_cost rating special_features
120                                                               last_update)
121                                                         ],
122                                                         col_posn => {
123                                                            film_id              => 0,
124                                                            title                => 1,
125                                                            description          => 2,
126                                                            release_year         => 3,
127                                                            language_id          => 4,
128                                                            original_language_id => 5,
129                                                            rental_duration      => 6,
130                                                            rental_rate          => 7,
131                                                            length               => 8,
132                                                            replacement_cost     => 9,
133                                                            rating               => 10,
134                                                            special_features     => 11,
135                                                            last_update          => 12,
136                                                         },
137                                                         is_autoinc => {
138                                                            film_id              => 1,
139                                                            title                => 0,
140                                                            description          => 0,
141                                                            release_year         => 0,
142                                                            language_id          => 0,
143                                                            original_language_id => 0,
144                                                            rental_duration      => 0,
145                                                            rental_rate          => 0,
146                                                            length               => 0,
147                                                            replacement_cost     => 0,
148                                                            rating               => 0,
149                                                            special_features     => 0,
150                                                            last_update          => 0,
151                                                         },
152                                                         is_col => {
153                                                            film_id              => 1,
154                                                            title                => 1,
155                                                            description          => 1,
156                                                            release_year         => 1,
157                                                            language_id          => 1,
158                                                            original_language_id => 1,
159                                                            rental_duration      => 1,
160                                                            rental_rate          => 1,
161                                                            length               => 1,
162                                                            replacement_cost     => 1,
163                                                            rating               => 1,
164                                                            special_features     => 1,
165                                                            last_update          => 1,
166                                                         },
167                                                         null_cols   => [qw(description release_year original_language_id length rating special_features )],
168                                                         is_nullable => {
169                                                            description          => 1,
170                                                            release_year         => 1,
171                                                            original_language_id => 1,
172                                                            length               => 1,
173                                                            special_features     => 1,
174                                                            rating               => 1,
175                                                         },
176                                                         clustered_key => 'PRIMARY',
177                                                         keys => {
178                                                            PRIMARY => {
179                                                               colnames     => '`film_id`',
180                                                               cols         => [qw(film_id)],
181                                                               col_prefixes => [undef],
182                                                               is_col       => { film_id => 1 },
183                                                               is_nullable  => 0,
184                                                               is_unique    => 1,
185                                                               type         => 'BTREE',
186                                                               name         => 'PRIMARY',
187                                                               ddl          => 'PRIMARY KEY  (`film_id`),',
188                                                            },
189                                                            idx_title => {
190                                                               colnames     => '`title`',
191                                                               cols         => [qw(title)],
192                                                               col_prefixes => [undef],
193                                                               is_col       => { title => 1, },
194                                                               is_nullable  => 0,
195                                                               is_unique    => 0,
196                                                               type         => 'BTREE',
197                                                               name         => 'idx_title',
198                                                               ddl          => 'KEY `idx_title` (`title`),',
199                                                            },
200                                                            idx_fk_language_id => {
201                                                               colnames     => '`language_id`',
202                                                               cols         => [qw(language_id)],
203                                                               col_prefixes => [undef],
204                                                               is_unique    => 0,
205                                                               is_col       => { language_id => 1 },
206                                                               is_nullable  => 0,
207                                                               type         => 'BTREE',
208                                                               name         => 'idx_fk_language_id',
209                                                               ddl          => 'KEY `idx_fk_language_id` (`language_id`),',
210                                                            },
211                                                            idx_fk_original_language_id => {
212                                                               colnames     => '`original_language_id`',
213                                                               cols         => [qw(original_language_id)],
214                                                               col_prefixes => [undef],
215                                                               is_unique    => 0,
216                                                               is_col       => { original_language_id => 1 },
217                                                               is_nullable  => 1,
218                                                               type         => 'BTREE',
219                                                               name         => 'idx_fk_original_language_id',
220                                                               ddl          => 'KEY `idx_fk_original_language_id` (`original_language_id`),',
221                                                            },
222                                                         },
223                                                         defs => {
224                                                            film_id      => "  `film_id` smallint(5) unsigned NOT NULL auto_increment",
225                                                            title        => "  `title` varchar(255) NOT NULL",
226                                                            description  => "  `description` text",
227                                                            release_year => "  `release_year` year(4) default NULL",
228                                                            language_id  => "  `language_id` tinyint(3) unsigned NOT NULL",
229                                                            original_language_id =>
230                                                               "  `original_language_id` tinyint(3) unsigned default NULL",
231                                                            rental_duration =>
232                                                               "  `rental_duration` tinyint(3) unsigned NOT NULL default '3'",
233                                                            rental_rate      => "  `rental_rate` decimal(4,2) NOT NULL default '4.99'",
234                                                            length           => "  `length` smallint(5) unsigned default NULL",
235                                                            replacement_cost => "  `replacement_cost` decimal(5,2) NOT NULL default '19.99'",
236                                                            rating           => "  `rating` enum('G','PG','PG-13','R','NC-17') default 'G'",
237                                                            special_features =>
238                                                               "  `special_features` set('Trailers','Commentaries','Deleted Scenes','Behind the Scenes') default NULL",
239                                                            last_update =>
240                                                               "  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP",
241                                                         },
242                                                         numeric_cols => [
243                                                            qw(film_id release_year language_id original_language_id rental_duration
244                                                               rental_rate length replacement_cost)
245                                                         ],
246                                                         is_numeric => {
247                                                            film_id              => 1,
248                                                            release_year         => 1,
249                                                            language_id          => 1,
250                                                            original_language_id => 1,
251                                                            rental_duration      => 1,
252                                                            rental_rate          => 1,
253                                                            length               => 1,
254                                                            replacement_cost     => 1,
255                                                         },
256                                                         engine   => 'InnoDB',
257                                                         type_for => {
258                                                            film_id              => 'smallint',
259                                                            title                => 'varchar',
260                                                            description          => 'text',
261                                                            release_year         => 'year',
262                                                            language_id          => 'tinyint',
263                                                            original_language_id => 'tinyint',
264                                                            rental_duration      => 'tinyint',
265                                                            rental_rate          => 'decimal',
266                                                            length               => 'smallint',
267                                                            replacement_cost     => 'decimal',
268                                                            rating               => 'enum',
269                                                            special_features     => 'set',
270                                                            last_update          => 'timestamp',
271                                                         },
272                                                         name => 'film',
273                                                      },
274                                                      'sakila.film',
275                                                   );
276                                                   
277            1                                 35   is_deeply(
278                                                      [$tp->sort_indexes($tbl)],
279                                                      [qw(PRIMARY idx_fk_language_id idx_title idx_fk_original_language_id)],
280                                                      'Sorted indexes OK'
281                                                   );
282                                                   
283            1                                 19   is($tp->find_best_index($tbl), 'PRIMARY', 'Primary key is best');
284            1                                  6   is($tp->find_best_index($tbl, 'idx_title'), 'idx_title', 'Specified key is best');
285                                                   throws_ok (
286            1                    1            15      sub { $tp->find_best_index($tbl, 'foo') },
287            1                                 19      qr/does not exist/,
288                                                      'Index does not exist',
289                                                   );
290                                                   
291            1                                 13   $tbl = $tp->parse( load_file('common/t/samples/temporary_table.sql') );
292            1                                 56   is_deeply(
293                                                      $tbl,
294                                                      {  cols         => [qw(a)],
295                                                         col_posn     => { a => 0 },
296                                                         is_col       => { a => 1 },
297                                                         is_autoinc   => { a => 0 },
298                                                         null_cols    => [qw(a)],
299                                                         is_nullable  => { a => 1 },
300                                                         clustered_key => undef,
301                                                         keys         => {},
302                                                         defs         => { a => '  `a` int(11) default NULL' },
303                                                         numeric_cols => [qw(a)],
304                                                         is_numeric   => { a => 1 },
305                                                         engine       => 'MyISAM',
306                                                         type_for     => { a => 'int' },
307                                                         name         => 't',
308                                                      },
309                                                      'Temporary table',
310                                                   );
311                                                   
312            1                                 16   $tbl = $tp->parse( load_file('common/t/samples/hyphentest.sql') );
313            1                                 52   is_deeply(
314                                                      $tbl,
315                                                      {  'is_autoinc' => {
316                                                            'sort_order'                => 0,
317                                                            'pfk-source_instrument_id'  => 0,
318                                                            'pfk-related_instrument_id' => 0
319                                                         },
320                                                         'null_cols'    => [],
321                                                         'numeric_cols' => [
322                                                            'pfk-source_instrument_id', 'pfk-related_instrument_id',
323                                                            'sort_order'
324                                                         ],
325                                                         'cols' => [
326                                                            'pfk-source_instrument_id', 'pfk-related_instrument_id',
327                                                            'sort_order'
328                                                         ],
329                                                         'col_posn' => {
330                                                            'sort_order'                => 2,
331                                                            'pfk-source_instrument_id'  => 0,
332                                                            'pfk-related_instrument_id' => 1
333                                                         },
334                                                         clustered_key => 'PRIMARY',
335                                                         'keys' => {
336                                                            'sort_order' => {
337                                                               'is_unique'    => 0,
338                                                               'is_col'       => { 'sort_order' => 1 },
339                                                               'name'         => 'sort_order',
340                                                               'type'         => 'BTREE',
341                                                               'col_prefixes' => [ undef ],
342                                                               'is_nullable'  => 0,
343                                                               'colnames'     => '`sort_order`',
344                                                               'cols'         => [ 'sort_order' ],
345                                                               ddl            => 'KEY `sort_order` (`sort_order`)',
346                                                            },
347                                                            'PRIMARY' => {
348                                                               'is_unique' => 1,
349                                                               'is_col' => {
350                                                                  'pfk-source_instrument_id'  => 1,
351                                                                  'pfk-related_instrument_id' => 1
352                                                               },
353                                                               'name'         => 'PRIMARY',
354                                                               'type'         => 'BTREE',
355                                                               'col_prefixes' => [ undef, undef ],
356                                                               'is_nullable'  => 0,
357                                                               'colnames' =>
358                                                                  '`pfk-source_instrument_id`,`pfk-related_instrument_id`',
359                                                               'cols' =>
360                                                                  [ 'pfk-source_instrument_id', 'pfk-related_instrument_id' ],
361                                                               ddl => 'PRIMARY KEY  (`pfk-source_instrument_id`,`pfk-related_instrument_id`),',
362                                                            }
363                                                         },
364                                                         'defs' => {
365                                                            'sort_order' => '  `sort_order` int(11) NOT NULL',
366                                                            'pfk-source_instrument_id' =>
367                                                               '  `pfk-source_instrument_id` int(10) unsigned NOT NULL',
368                                                            'pfk-related_instrument_id' =>
369                                                               '  `pfk-related_instrument_id` int(10) unsigned NOT NULL'
370                                                         },
371                                                         'engine' => 'InnoDB',
372                                                         'is_col' => {
373                                                            'sort_order'                => 1,
374                                                            'pfk-source_instrument_id'  => 1,
375                                                            'pfk-related_instrument_id' => 1
376                                                         },
377                                                         'is_numeric' => {
378                                                            'sort_order'                => 1,
379                                                            'pfk-source_instrument_id'  => 1,
380                                                            'pfk-related_instrument_id' => 1
381                                                         },
382                                                         'type_for' => {
383                                                            'sort_order'                => 'int',
384                                                            'pfk-source_instrument_id'  => 'int',
385                                                            'pfk-related_instrument_id' => 'int'
386                                                         },
387                                                         'is_nullable' => {},
388                                                         name => 'instrument_relation',
389                                                      },
390                                                      'Hyphens in indexed columns',
391                                                   );
392                                                   
393            1                                 28   $tbl = $tp->parse( load_file('common/t/samples/ndb_table.sql') );
394            1                                 44   is_deeply(
395                                                      $tbl,
396                                                      {  cols        => [qw(id)],
397                                                         col_posn    => { id => 0 },
398                                                         is_col      => { id => 1 },
399                                                         is_autoinc  => { id => 1 },
400                                                         null_cols   => [],
401                                                         is_nullable => {},
402                                                         clustered_key => undef,
403                                                         keys        => {
404                                                            PRIMARY => {
405                                                               cols         => [qw(id)],
406                                                               is_unique    => 1,
407                                                               is_col       => { id => 1 },
408                                                               name         => 'PRIMARY',
409                                                               type         => 'BTREE',
410                                                               col_prefixes => [undef],
411                                                               is_nullable  => 0,
412                                                               colnames     => '`id`',
413                                                               ddl          => 'PRIMARY KEY (`id`)',
414                                                            }
415                                                         },
416                                                         defs => { id => '  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT' },
417                                                         numeric_cols => [qw(id)],
418                                                         is_numeric   => { id => 1 },
419                                                         engine       => 'ndbcluster',
420                                                         type_for     => { id => 'bigint' },
421                                                         name         => 'pipo',
422                                                      },
423                                                      'NDB table',
424                                                   );
425                                                   
426            1                                 18   $tbl = $tp->parse( load_file('common/t/samples/mixed-case.sql') );
427            1                                 47   is_deeply(
428                                                      $tbl,
429                                                      {  cols         => [qw(a b mixedcol)],
430                                                         col_posn     => { a => 0, b => 1, mixedcol => 2 },
431                                                         is_col       => { a => 1, b => 1, mixedcol => 1 },
432                                                         is_autoinc   => { a => 0, b => 0, mixedcol => 0 },
433                                                         null_cols    => [qw(a b mixedcol)],
434                                                         is_nullable  => { a => 1, b => 1, mixedcol => 1 },
435                                                         clustered_key => undef,
436                                                         keys         => {
437                                                            mykey => {
438                                                               colnames     => '`a`,`b`,`mixedcol`',
439                                                               cols         => [qw(a b mixedcol)],
440                                                               col_prefixes => [undef, undef, undef],
441                                                               is_col       => { a => 1, b => 1, mixedcol => 1 },
442                                                               is_nullable  => 3,
443                                                               is_unique    => 0,
444                                                               type         => 'BTREE',
445                                                               name         => 'mykey',
446                                                               ddl          => 'KEY `mykey` (`a`,`b`,`mixedcol`)',
447                                                            },
448                                                         },
449                                                         defs         => {
450                                                            a => '  `a` int(11) default NULL',
451                                                            b => '  `b` int(11) default NULL',
452                                                            mixedcol => '  `mixedcol` int(11) default NULL',
453                                                         },
454                                                         numeric_cols => [qw(a b mixedcol)],
455                                                         is_numeric   => { a => 1, b => 1, mixedcol => 1 },
456                                                         engine       => 'MyISAM',
457                                                         type_for     => { a => 'int', b => 'int', mixedcol => 'int' },
458                                                         name         => 't',
459                                                      },
460                                                      'Mixed-case identifiers',
461                                                   );
462                                                   
463            1                                 28   $tbl = $tp->parse( load_file('common/t/samples/one_key.sql') );
464            1                                 60   is_deeply(
465                                                      $tbl,
466                                                      {  cols          => [qw(a b)],
467                                                         col_posn      => { a => 0, b => 1 },
468                                                         is_col        => { a => 1, b => 1 },
469                                                         is_autoinc    => { a => 0, b => 0 },
470                                                         null_cols     => [qw(b)],
471                                                         is_nullable   => { b => 1 },
472                                                         clustered_key => undef,
473                                                         keys          => {
474                                                            PRIMARY => {
475                                                               colnames     => '`a`',
476                                                               cols         => [qw(a)],
477                                                               col_prefixes => [undef],
478                                                               is_col       => { a => 1 },
479                                                               is_nullable  => 0,
480                                                               is_unique    => 1,
481                                                               type         => 'BTREE',
482                                                               name         => 'PRIMARY',
483                                                               ddl          => 'PRIMARY KEY  (`a`)',
484                                                            },
485                                                         },
486                                                         defs         => {
487                                                            a => '  `a` int(11) NOT NULL',
488                                                            b => '  `b` char(50) default NULL',
489                                                         },
490                                                         numeric_cols => [qw(a)],
491                                                         is_numeric   => { a => 1 },
492                                                         engine       => 'MyISAM',
493                                                         type_for     => { a => 'int', b => 'char' },
494                                                         name         => 't2',
495                                                      },
496                                                      'No clustered key on MyISAM table'
497                                                   );
498                                                   
499                                                   # #############################################################################
500                                                   # Test get_fks()
501                                                   # #############################################################################
502            1                                 30   is_deeply(
503                                                      $tp->get_fks( load_file('common/t/samples/one_key.sql') ),
504                                                      {},
505                                                      'no fks'
506                                                   );
507                                                   
508            1                                 14   is_deeply(
509                                                      $tp->get_fks( load_file('common/t/samples/one_fk.sql') ),   
510                                                      {
511                                                         't1_ibfk_1' => {
512                                                            name            => 't1_ibfk_1',
513                                                            colnames        => '`a`',
514                                                            cols            => ['a'],
515                                                            parent_tbl      => '`t2`',
516                                                            parent_colnames => '`a`',
517                                                            parent_cols     => ['a'],
518                                                            ddl             => 'CONSTRAINT `t1_ibfk_1` FOREIGN KEY (`a`) REFERENCES `t2` (`a`)',
519                                                         },
520                                                      },
521                                                      'one fk'
522                                                   );
523                                                   
524            1                                 20   is_deeply(
525                                                      $tp->get_fks( load_file('common/t/samples/one_fk.sql'), {database=>'foo'} ),   
526                                                      {
527                                                         't1_ibfk_1' => {
528                                                            name            => 't1_ibfk_1',
529                                                            colnames        => '`a`',
530                                                            cols            => ['a'],
531                                                            parent_tbl      => '`foo`.`t2`',
532                                                            parent_colnames => '`a`',
533                                                            parent_cols     => ['a'],
534                                                            ddl             => 'CONSTRAINT `t1_ibfk_1` FOREIGN KEY (`a`) REFERENCES `t2` (`a`)',
535                                                         },
536                                                      },
537                                                      'one fk with default database'
538                                                   );
539                                                   
540            1                                 21   is_deeply(
541                                                      $tp->get_fks( load_file('common/t/samples/issue_331.sql') ),   
542                                                      {
543                                                         'fk_1' => {
544                                                            name            => 'fk_1',
545                                                            colnames        => '`id`',
546                                                            cols            => ['id'],
547                                                            parent_tbl      => '`issue_331_t1`',
548                                                            parent_colnames => '`t1_id`',
549                                                            parent_cols     => ['t1_id'],
550                                                            ddl             => 'CONSTRAINT `fk_1` FOREIGN KEY (`id`) REFERENCES `issue_331_t1` (`t1_id`)',
551                                                         },
552                                                         'fk_2' => {
553                                                            name            => 'fk_2',
554                                                            colnames        => '`id`',
555                                                            cols            => ['id'],
556                                                            parent_tbl      => '`issue_331_t1`',
557                                                            parent_colnames => '`t1_id`',
558                                                            parent_cols     => ['t1_id'],
559                                                            ddl             => 'CONSTRAINT `fk_2` FOREIGN KEY (`id`) REFERENCES `issue_331_t1` (`t1_id`)',
560                                                         }
561                                                      },
562                                                      'two fks (issue 331)'
563                                                   );
564                                                   
565                                                   # #############################################################################
566                                                   # Test remove_secondary_indexes().
567                                                   # #############################################################################
568                                                   sub test_rsi {
569            9                    9            92      my ( $file, $des, $new_ddl, $indexes ) = @_;
570            9                                 77      my $ddl = load_file($file);
571            9                                209      my ($got_new_ddl, $got_indexes) = $tp->remove_secondary_indexes($ddl);
572            9                                288      is(
573                                                         $got_indexes,
574                                                         $indexes,
575                                                         "$des - secondary indexes $file"
576                                                      );
577            9                                 86      is(
578                                                         $got_new_ddl,
579                                                         $new_ddl,
580                                                         "$des - new ddl $file"
581                                                      );
582            9                                 50      return;
583                                                   }
584                                                   
585            1                                 27   test_rsi(
586                                                      'common/t/samples/t1.sql',
587                                                      'MyISAM table, no indexes',
588                                                   "CREATE TABLE `t1` (
589                                                     `a` int(11) default NULL
590                                                   ) ENGINE=MyISAM DEFAULT CHARSET=latin1
591                                                   ",
592                                                      undef
593                                                   );
594                                                   
595            1                                  7   test_rsi(
596                                                      'common/t/samples/one_key.sql',
597                                                      'MyISAM table, one pk',
598                                                   "CREATE TABLE `t2` (
599                                                     `a` int(11) NOT NULL,
600                                                     `b` char(50) default NULL,
601                                                     PRIMARY KEY  (`a`)
602                                                   ) ENGINE=MyISAM DEFAULT CHARSET=latin1;
603                                                   ",
604                                                      undef
605                                                   );
606                                                   
607            1                                  8   test_rsi(
608                                                      'common/t/samples/date.sql',
609                                                      'one pk',
610                                                   "CREATE TABLE `checksum_test_5` (
611                                                     `a` date NOT NULL,
612                                                     `b` int(11) default NULL,
613                                                     PRIMARY KEY  (`a`)
614                                                   ) ENGINE=InnoDB DEFAULT CHARSET=latin1
615                                                   ",
616                                                      undef
617                                                   );
618                                                   
619            1                                  7   test_rsi(
620                                                      'common/t/samples/auto-increment-actor.sql',
621                                                      'pk, key (no trailing comma)',
622                                                   "CREATE TABLE `actor` (
623                                                     `actor_id` smallint(5) unsigned NOT NULL auto_increment,
624                                                     `first_name` varchar(45) NOT NULL,
625                                                     `last_name` varchar(45) NOT NULL,
626                                                     `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
627                                                     PRIMARY KEY  (`actor_id`)
628                                                   ) ENGINE=InnoDB AUTO_INCREMENT=201 DEFAULT CHARSET=utf8;
629                                                   ",
630                                                      'ADD KEY `idx_actor_last_name` (`last_name`)'
631                                                   );
632                                                   
633            1                                  8   test_rsi(
634                                                      'common/t/samples/one_fk.sql',
635                                                      'key, fk, no clustered key',
636                                                   "CREATE TABLE `t1` (
637                                                     `a` int(11) NOT NULL,
638                                                     `b` char(50) default NULL,
639                                                     CONSTRAINT `t1_ibfk_1` FOREIGN KEY (`a`) REFERENCES `t2` (`a`)
640                                                   ) ENGINE=InnoDB DEFAULT CHARSET=latin1
641                                                   ",
642                                                      'ADD KEY `a` (`a`)',
643                                                   );
644                                                   
645            1                                 10   test_rsi(
646                                                      'common/t/samples/sakila.film.sql',
647                                                      'pk, keys and fks',
648                                                   "CREATE TABLE `film` (
649                                                     `film_id` smallint(5) unsigned NOT NULL auto_increment,
650                                                     `title` varchar(255) NOT NULL,
651                                                     `description` text,
652                                                     `release_year` year(4) default NULL,
653                                                     `language_id` tinyint(3) unsigned NOT NULL,
654                                                     `original_language_id` tinyint(3) unsigned default NULL,
655                                                     `rental_duration` tinyint(3) unsigned NOT NULL default '3',
656                                                     `rental_rate` decimal(4,2) NOT NULL default '4.99',
657                                                     `length` smallint(5) unsigned default NULL,
658                                                     `replacement_cost` decimal(5,2) NOT NULL default '19.99',
659                                                     `rating` enum('G','PG','PG-13','R','NC-17') default 'G',
660                                                     `special_features` set('Trailers','Commentaries','Deleted Scenes','Behind the Scenes') default NULL,
661                                                     `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
662                                                     PRIMARY KEY  (`film_id`),
663                                                     CONSTRAINT `fk_film_language` FOREIGN KEY (`language_id`) REFERENCES `language` (`language_id`) ON UPDATE CASCADE,
664                                                     CONSTRAINT `fk_film_language_original` FOREIGN KEY (`original_language_id`) REFERENCES `language` (`language_id`) ON UPDATE CASCADE
665                                                   ) ENGINE=InnoDB DEFAULT CHARSET=utf8
666                                                   ",
667                                                      'ADD KEY `idx_fk_original_language_id` (`original_language_id`), ADD KEY `idx_fk_language_id` (`language_id`), ADD KEY `idx_title` (`title`)'
668                                                   );
669                                                   
670            1                                  9   test_rsi(
671                                                      'common/t/samples/issue_729.sql',
672                                                      'issue 729',
673                                                   "CREATE TABLE `posts` (
674                                                     `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
675                                                     `template_id` smallint(5) unsigned NOT NULL DEFAULT '0',
676                                                     `other_id` bigint(20) unsigned NOT NULL DEFAULT '0',
677                                                     `date` int(10) unsigned NOT NULL DEFAULT '0',
678                                                     `private` tinyint(3) unsigned NOT NULL DEFAULT '0',
679                                                     PRIMARY KEY (`id`)
680                                                   ) ENGINE=InnoDB AUTO_INCREMENT=15417 DEFAULT CHARSET=latin1;
681                                                   ",
682                                                     'ADD KEY `other_id` (`other_id`)',
683                                                   );
684                                                   
685            1                                  9   test_rsi(
686                                                      'mk-parallel-restore/t/samples/issue_833/00_geodb_coordinates.sql',
687                                                      'issue 833',
688                                                   "CREATE TABLE `geodb_coordinates` (
689                                                     `loc_id` int(11) NOT NULL default '0',
690                                                     `lon` double default NULL,
691                                                     `lat` double default NULL,
692                                                     `sin_lon` double default NULL,
693                                                     `sin_lat` double default NULL,
694                                                     `cos_lon` double default NULL,
695                                                     `cos_lat` double default NULL,
696                                                     `coord_type` int(11) NOT NULL default '0',
697                                                     `coord_subtype` int(11) default NULL,
698                                                     `valid_since` date default NULL,
699                                                     `date_type_since` int(11) default NULL,
700                                                     `valid_until` date NOT NULL default '0000-00-00',
701                                                     `date_type_until` int(11) NOT NULL default '0'
702                                                   ) ENGINE=InnoDB DEFAULT CHARSET=latin1",
703                                                      'ADD KEY `coord_lon_idx` (`lon`), ADD KEY `coord_loc_id_idx` (`loc_id`), ADD KEY `coord_stype_idx` (`coord_subtype`), ADD KEY `coord_until_idx` (`valid_until`), ADD KEY `coord_lat_idx` (`lat`), ADD KEY `coord_slon_idx` (`sin_lon`), ADD KEY `coord_clon_idx` (`cos_lon`), ADD KEY `coord_slat_idx` (`sin_lat`), ADD KEY `coord_clat_idx` (`cos_lat`), ADD KEY `coord_type_idx` (`coord_type`), ADD KEY `coord_since_idx` (`valid_since`)',
704                                                   );
705                                                   
706                                                   # Column and index names are case-insensitive so remove_secondary_indexes()
707                                                   # returns "ADD KEY `foo_bar` (`i`,`j`)" for "KEY `Foo_Bar` (`i`,`J`)".
708            1                                  9   test_rsi(
709                                                      'common/t/samples/issue_956.sql',
710                                                      'issue 956',
711                                                   "CREATE TABLE `t` (
712                                                     `i` int(11) default NULL,
713                                                     `J` int(11) default NULL
714                                                   ) ENGINE=InnoDB
715                                                   ",
716                                                      'ADD KEY `foo_bar` (`i`,`j`)',
717                                                   );
718                                                   
719                                                   # #############################################################################
720                                                   # Sandbox tests
721                                                   # #############################################################################
722   ***      1     50                          11   SKIP: {
723            1                                  4      skip 'Cannot connect to sandbox master', 8 unless $dbh;
724                                                   
725            1                                 12      $sb->load_file('master', 'common/t/samples/check_table.sql');
726                                                   
727                                                      # msandbox user does not have GRANT privs.
728            1                             530447      my $root_dbh = DBI->connect(
729                                                         "DBI:mysql:host=127.0.0.1;port=12345", 'root', 'msandbox',
730                                                         { PrintError => 0, RaiseError => 1 });
731            1                                605      $root_dbh->do("GRANT SELECT ON test.* TO 'user'\@'\%'");
732            1                                434      $root_dbh->do('FLUSH PRIVILEGES');
733            1                                104      $root_dbh->disconnect();
734                                                   
735            1                                 19      my $user_dbh = DBI->connect(
736                                                         "DBI:mysql:host=127.0.0.1;port=12345", 'user', undef,
737                                                         { PrintError => 0, RaiseError => 1 });
738            1                                 37      ok(
739                                                         $tp->check_table(
740                                                            dbh => $dbh,
741                                                            db  => 'mysql',
742                                                            tbl => 'db',
743                                                         ),
744                                                         'Table exists'
745                                                      );
746            1                                 13      ok(
747                                                         !$tp->check_table(
748                                                            dbh => $dbh,
749                                                            db  => 'mysql',
750                                                            tbl => 'blahbleh',
751                                                         ),
752                                                         'Table does not exist'
753                                                      );
754            1                                 13      ok(
755                                                         !$tp->check_table(
756                                                            dbh => $user_dbh,
757                                                            db  => 'mysql',
758                                                            tbl => 'db',
759                                                         ),
760                                                         "Table exists but user can't see it"
761                                                      );
762            1                                 32      ok(
763                                                         !$tp->check_table(
764                                                            dbh => $user_dbh,
765                                                            db  => 'mysql',
766                                                            tbl => 'blahbleh',
767                                                         ),
768                                                         "Table does not exist and user can't see it"
769                                                      );
770            1                                 13      ok(
771                                                         $tp->check_table(
772                                                            dbh       => $dbh,
773                                                            db        => 'test',
774                                                            tbl       => 't',
775                                                            all_privs => 1,
776                                                         ),
777                                                         "Table exists and user has full privs"
778                                                      );
779            1                                 13      ok(
780                                                         !$tp->check_table(
781                                                            dbh       => $user_dbh,
782                                                            db        => 'test',
783                                                            tbl       => 't',
784                                                            all_privs => 1,
785                                                         ),
786                                                         "Table exists but user doesn't have full privs"
787                                                      );
788                                                   
789            1                                 20      ok(
790                                                         $tp->check_table(
791                                                            dbh => $dbh,
792                                                            db  => 'test',
793                                                            tbl => 't_',
794                                                         ),
795                                                         'Table t_ exists'
796                                                      );
797            1                                 13      ok(
798                                                         $tp->check_table(
799                                                            dbh => $dbh,
800                                                            db  => 'test',
801                                                            tbl => 't%_',
802                                                         ),
803                                                         'Table t%_ exists'
804                                                      );
805                                                   
806            1                                241      $user_dbh->disconnect();
807                                                   };
808                                                   
809            1                                  5   SKIP: {
810            1                                  7      skip 'Sandbox master does not have the sakila database', 2
811   ***      1     50     33                   19         unless $dbh && @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};
812            1                                649      is_deeply(
813                                                         [$tp->find_possible_keys(
814                                                            $dbh, 'sakila', 'film_actor', $q, 'film_id > 990  and actor_id > 1')],
815                                                         [qw(idx_fk_film_id PRIMARY)],
816                                                         'Best index for WHERE clause'
817                                                      );
818            1                                 27      is_deeply(
819                                                         [$tp->find_possible_keys(
820                                                            $dbh, 'sakila', 'film_actor', $q, 'film_id > 990 or actor_id > 1')],
821                                                         [qw(idx_fk_film_id PRIMARY)],
822                                                         'Best index for WHERE clause with sort_union'
823                                                      );
824                                                   };
825                                                   
826                                                   # #############################################################################
827                                                   # Issue 109: Test schema changes in 5.1
828                                                   # #############################################################################
829                                                   sub cmp_ddls {
830            1                    1            10      my ( $desc, $v1, $v2 ) = @_;
831                                                   
832            1                                 25      $tbl = $tp->parse( load_file($v1) );
833            1                                 89      my $tbl2 = $tp->parse( load_file($v2) );
834                                                   
835                                                      # The defs for each will differ due to string case: 'default' vs. 'DEFAULT'.
836                                                      # Everything else should be identical, though. So we'll chop out the defs,
837                                                      # compare them later, and check the rest first.
838            1                                 10      my %defs  = %{$tbl->{defs}};
               1                                 32   
839            1                                 10      my %defs2 = %{$tbl2->{defs}};
               1                                 23   
840            1                                 10      $tbl->{defs}  = ();
841            1                                  9      $tbl2->{defs} = ();
842            1                                 15      is_deeply($tbl, $tbl2, "$desc SHOW CREATE parse identically");
843                                                   
844            1                                 13      my $defstr  = '';
845            1                                  6      my $defstr2 = '';
846            1                                 17      foreach my $col ( keys %defs ) {
847           11                                 64         $defstr  .= lc $defs{$col};
848           11                                 66         $defstr2 .= lc $defs2{$col};
849                                                      }
850            1                                 15      is($defstr, $defstr2, "$desc defs are identical (except for case)");
851                                                   
852            1                                 54      return;
853                                                   }
854                                                   
855            1                                 38   cmp_ddls('v5.0 vs. v5.1', 'common/t/samples/issue_109-01-v50.sql', 'common/t/samples/issue_109-01-v51.sql');
856                                                   
857                                                   # #############################################################################
858                                                   # Issue 132: mk-parallel-dump halts with error when enum contains backtick
859                                                   # #############################################################################
860            1                                 11   $tbl = $tp->parse( load_file('common/t/samples/issue_132.sql') );
861            1                                 83   is_deeply(
862                                                      $tbl,
863                                                      {  cols         => [qw(country)],
864                                                         col_posn     => { country => 0 },
865                                                         is_col       => { country => 1 },
866                                                         is_autoinc   => { country => 0 },
867                                                         null_cols    => [qw(country)],
868                                                         is_nullable  => { country => 1 },
869                                                         clustered_key => undef,
870                                                         keys         => {},
871                                                         defs         => { country => "  `country` enum('','Cote D`ivoire') default NULL"},
872                                                         numeric_cols => [],
873                                                         is_numeric   => {},
874                                                         engine       => 'MyISAM',
875                                                         type_for     => { country => 'enum' },
876                                                         name         => 'issue_132',
877                                                      },
878                                                      'ENUM col with backtick in value (issue 132)'
879                                                   );
880                                                   
881                                                   # #############################################################################
882                                                   # issue 328: remove AUTO_INCREMENT from schema for checksumming.
883                                                   # #############################################################################
884            1                                 34   my $schema1 = load_file('common/t/samples/auto-increment-actor.sql');
885            1                                 18   my $schema2 = load_file('common/t/samples/no-auto-increment-actor.sql');
886            1                                 27   is(
887                                                      $tp->remove_auto_increment($schema1),
888                                                      $schema2,
889                                                      'AUTO_INCREMENT is gone',
890                                                   );
891                                                   
892                                                   # #############################################################################
893                                                   # Issue 330: mk-parallel-dump halts with error when comments contain pairing `
894                                                   # #############################################################################
895            1                                 10   $tbl = $tp->parse( load_file('common/t/samples/issue_330_backtick_pair_in_col_comments.sql') );
896            1                                 54   is_deeply(
897                                                      $tbl,
898                                                      {  cols         => [qw(a)],
899                                                         col_posn     => { a => 0 },
900                                                         is_col       => { a => 1 },
901                                                         is_autoinc   => { a => 0 },
902                                                         null_cols    => [qw(a)],
903                                                         is_nullable  => { a => 1 },
904                                                         clustered_key => undef,
905                                                         keys         => {},
906                                                         defs         => { a => "  `a` int(11) DEFAULT NULL COMMENT 'issue_330 `alex`'" },
907                                                         numeric_cols => [qw(a)],
908                                                         is_numeric   => { a => 1 },
909                                                         engine       => 'MyISAM',
910                                                         type_for     => { a => 'int' },
911                                                         name         => 'issue_330',
912                                                      },
913                                                      'issue with pairing backticks in column comments (issue 330)'
914                                                   );
915                                                   
916                                                   # #############################################################################
917                                                   # Issue 170: mk-parallel-dump dies when table-status Data_length is NULL
918                                                   # #############################################################################
919                                                   
920                                                   # The underlying problem for issue 170 is that MySQLDump doesn't eval some
921                                                   # of its queries so when MySQLFind uses it and hits a broken table it dies.
922                                                   
923            1                                 25   eval {
924            1                                  9      $tp->parse(undef);
925                                                   };
926            1                                  9   is(
927                                                      $EVAL_ERROR,
928                                                      '',
929                                                      'No error parsing undef ddl'
930                                                   );
931                                                   
932                                                   
933                                                   # #############################################################################
934                                                   # Issue 295: Enhance rules for clustered keys in mk-duplicate-key-checker
935                                                   # #############################################################################
936                                                   
937                                                   # Make sure get_keys() gets a clustered index that's not the primary key.
938            1                                  9   my $ddl = load_file('common/t/samples/non_pk_ck.sql');
939            1                                 41   my (undef, $ck) = $tp->get_keys($ddl, {}, {i=>0,j=>1});
940            1                                 34   is(
941                                                      $ck,
942                                                      'i_idx',
943                                                      'Get first unique, non-nullable index as clustered key'
944                                                   );
945                                                   
946                                                   
947                                                   # #############################################################################
948                                                   # Issue 388: mk-table-checksum crashes when column with comma in the
949                                                   # name is used in a key
950                                                   # #############################################################################
951            1                                 13   $tbl = $tp->parse( load_file("$sample/issue-388.sql") );
952            1                                102   is_deeply(
953                                                      $tbl,
954                                                      {
955                                                         clustered_key  => undef,
956                                                         col_posn       => { 'first, last' => 1, id => 0  },
957                                                         cols           => [ 'id', 'first, last' ],
958                                                         defs           => {
959                                                            'first, last' => '  `first, last` varchar(32) default NULL',
960                                                            id            => '  `id` int(11) NOT NULL auto_increment',
961                                                         },
962                                                         engine         => 'MyISAM',
963                                                         is_autoinc     => { 'first, last' => 0, id => 1 },
964                                                         is_col         => { 'first, last' => 1, id => 1 },
965                                                         is_nullable    => { 'first, last' => 1          },
966                                                         is_numeric     => {                     id => 1 },
967                                                         name           => 'foo',
968                                                         null_cols      => [ 'first, last' ],
969                                                         numeric_cols   => [ 'id' ],
970                                                         type_for       => {
971                                                            'first, last' => 'varchar',
972                                                            id            => 'int',
973                                                         },
974                                                         keys           => {
975                                                            PRIMARY => {
976                                                               col_prefixes => [ undef ],
977                                                               colnames     => '`id`',
978                                                               cols         => [ 'id' ],
979                                                               ddl          => 'PRIMARY KEY  (`id`),',
980                                                               is_col       => { id => 1 },
981                                                               is_nullable  => 0,
982                                                               is_unique    => 1,
983                                                               name         => 'PRIMARY',
984                                                               type         => 'BTREE',
985                                                            },
986                                                            nameindex => {
987                                                               col_prefixes => [ undef ],
988                                                               colnames     => '`first, last`',
989                                                               cols         => [ 'first, last' ],
990                                                               ddl          => 'KEY `nameindex` (`first, last`)',
991                                                               is_col       => { 'first, last' => 1 },
992                                                               is_nullable  => 1,
993                                                               is_unique    => 0,
994                                                               name         => 'nameindex',
995                                                               type         => 'BTREE',
996                                                            },
997                                                         },
998                                                      },
999                                                      'Index with comma in its name (issue 388)'
1000                                                  );
1001                                                  
1002                                                  # #############################################################################
1003                                                  # Done.
1004                                                  # #############################################################################
1005  ***      1     50                          66   $sb->wipe_clean($dbh) if $dbh;
1006           1                                  7   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
722   ***     50      0      1   unless $dbh
811   ***     50      0      1   unless $dbh and @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"');}
1005  ***     50      1      0   if $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
811   ***     33      0      0      1   $dbh and @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"');}


Covered Subroutines
-------------------

Subroutine Count Location         
---------- ----- -----------------
BEGIN          1 TableParser.t:10 
BEGIN          1 TableParser.t:11 
BEGIN          1 TableParser.t:12 
BEGIN          1 TableParser.t:14 
BEGIN          1 TableParser.t:15 
BEGIN          1 TableParser.t:16 
BEGIN          1 TableParser.t:17 
BEGIN          1 TableParser.t:18 
BEGIN          1 TableParser.t:4  
BEGIN          1 TableParser.t:9  
__ANON__       1 TableParser.t:286
cmp_ddls       1 TableParser.t:830
test_rsi       9 TableParser.t:569


