---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableParser.pm   91.8   74.0   56.7   93.3    n/a  100.0   84.5
Total                          91.8   74.0   56.7   93.3    n/a  100.0   84.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:04:01 2009
Finish:       Sat Aug 29 15:04:01 2009

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
18                                                    # TableParser package $Revision: 4397 $
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
               1                                  2   
               1                                  8   
25                                                    
26             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
27                                                    
28                                                    sub new {
29             1                    1            14      my ( $class ) = @_;
30             1                                 15      return bless {}, $class;
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
46            14                   14           238      my ( $self, $ddl, $opts ) = @_;
47            14    100                          93      return unless $ddl;
48    ***     13     50                          57      if ( ref $ddl eq 'ARRAY' ) {
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
59            13    100                         111      if ( $ddl !~ m/CREATE (?:TEMPORARY )?TABLE `/ ) {
60             2                                  6         die "Cannot parse table definition; is ANSI quoting "
61                                                             . "enabled or SQL_QUOTE_SHOW_CREATE disabled?";
62                                                       }
63                                                    
64                                                       # Lowercase identifiers to avoid issues with case-sensitivity in Perl.
65                                                       # (Bug #1910276).
66            11                                367      $ddl =~ s/(`[^`]+`)/\L$1/g;
67                                                    
68            11                                 58      my $engine = $self->get_engine($ddl);
69                                                    
70            11                                363      my @defs   = $ddl =~ m/^(\s+`.*?),?$/gm;
71            11                                 52      my @cols   = map { $_ =~ m/`([^`]+)`/ } @defs;
              48                                246   
72            11                                 31      MKDEBUG && _d('Columns:', join(', ', @cols));
73                                                    
74                                                       # Save the column definitions *exactly*
75            11                                 28      my %def_for;
76            11                                 78      @def_for{@cols} = @defs;
77                                                    
78                                                       # Find column types, whether numeric, whether nullable, whether
79                                                       # auto-increment.
80            11                                 35      my (@nums, @null);
81            11                                 38      my (%type_for, %is_nullable, %is_numeric, %is_autoinc);
82            11                                 48      foreach my $col ( @cols ) {
83            48                                150         my $def = $def_for{$col};
84            48                                280         my ( $type ) = $def =~ m/`[^`]+`\s([a-z]+)/;
85    ***     48     50                         177         die "Can't determine column type for $def" unless $type;
86            48                                156         $type_for{$col} = $type;
87            48    100                         300         if ( $type =~ m/(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/ ) {
88            26                                 83            push @nums, $col;
89            26                                 86            $is_numeric{$col} = 1;
90                                                          }
91            48    100                         200         if ( $def !~ m/NOT NULL/ ) {
92            21                                 68            push @null, $col;
93            21                                 69            $is_nullable{$col} = 1;
94                                                          }
95            48    100                         269         $is_autoinc{$col} = $def =~ m/AUTO_INCREMENT/i ? 1 : 0;
96                                                       }
97                                                    
98                                                       # TODO: passing is_nullable this way is just a quick hack. Ultimately,
99                                                       # we probably should decompose this sub further, taking out the block
100                                                      # above that parses col props like nullability, auto_inc, type, etc.
101           11                                 66      my ($keys, $clustered_key) = $self->get_keys($ddl, $opts, \%is_nullable);
102                                                   
103                                                      return {
104           48                                249         cols           => \@cols,
105           48                                325         col_posn       => { map { $cols[$_] => $_ } 0..$#cols },
106           11                                100         is_col         => { map { $_ => 1 } @cols },
107                                                         null_cols      => \@null,
108                                                         is_nullable    => \%is_nullable,
109                                                         is_autoinc     => \%is_autoinc,
110                                                         clustered_key  => $clustered_key,
111                                                         keys           => $keys,
112                                                         defs           => \%def_for,
113                                                         numeric_cols   => \@nums,
114                                                         is_numeric     => \%is_numeric,
115                                                         engine         => $engine,
116                                                         type_for       => \%type_for,
117                                                      };
118                                                   }
119                                                   
120                                                   # Sorts indexes in this order: PRIMARY, unique, non-nullable, any (shortest
121                                                   # first, alphabetical).  Only BTREE indexes are considered.
122                                                   # TODO: consider length as # of bytes instead of # of columns.
123                                                   sub sort_indexes {
124            2                    2            48      my ( $self, $tbl ) = @_;
125                                                   
126                                                      my @indexes
127            2                                 10         = sort {
128            8                                 32            (($a ne 'PRIMARY') <=> ($b ne 'PRIMARY'))
129                                                            || ( !$tbl->{keys}->{$a}->{is_unique} <=> !$tbl->{keys}->{$b}->{is_unique} )
130                                                            || ( $tbl->{keys}->{$a}->{is_nullable} <=> $tbl->{keys}->{$b}->{is_nullable} )
131   ***      8    100     66                  110            || ( scalar(@{$tbl->{keys}->{$a}->{cols}}) <=> scalar(@{$tbl->{keys}->{$b}->{cols}}) )
               2           100                   12   
132                                                         }
133                                                         grep {
134            2                                 20            $tbl->{keys}->{$_}->{type} eq 'BTREE'
135                                                         }
136            2                                  7         sort keys %{$tbl->{keys}};
137                                                   
138            2                                 14      MKDEBUG && _d('Indexes sorted best-first:', join(', ', @indexes));
139            2                                 14      return @indexes;
140                                                   }
141                                                   
142                                                   # Finds the 'best' index; if the user specifies one, dies if it's not in the
143                                                   # table.
144                                                   sub find_best_index {
145            3                    3            15      my ( $self, $tbl, $index ) = @_;
146            3                                  6      my $best;
147            3    100                          13      if ( $index ) {
148            2                                  6         ($best) = grep { uc $_ eq uc $index } keys %{$tbl->{keys}};
               8                                 31   
               2                                 10   
149                                                      }
150            3    100                          13      if ( !$best ) {
151            2    100                           8         if ( $index ) {
152                                                            # The user specified an index, so we can't choose our own.
153            1                                  3            die "Index '$index' does not exist in table";
154                                                         }
155                                                         else {
156                                                            # Try to pick the best index.
157                                                            # TODO: eliminate indexes that have column prefixes.
158            1                                  4            ($best) = $self->sort_indexes($tbl);
159                                                         }
160                                                      }
161            2                                  6      MKDEBUG && _d('Best index found is', $best);
162            2                                 12      return $best;
163                                                   }
164                                                   
165                                                   # Takes a dbh, database, table, quoter, and WHERE clause, and reports the
166                                                   # indexes MySQL thinks are best for EXPLAIN SELECT * FROM that table.  If no
167                                                   # WHERE, just returns an empty list.  If no possible_keys, returns empty list,
168                                                   # even if 'key' is not null.  Only adds 'key' to the list if it's included in
169                                                   # possible_keys.
170                                                   sub find_possible_keys {
171            2                    2           520      my ( $self, $dbh, $database, $table, $quoter, $where ) = @_;
172   ***      2     50                          10      return () unless $where;
173            2                                 12      my $sql = 'EXPLAIN SELECT * FROM ' . $quoter->quote($database, $table)
174                                                         . ' WHERE ' . $where;
175            2                                  6      MKDEBUG && _d($sql);
176            2                                  5      my $expl = $dbh->selectrow_hashref($sql);
177                                                      # Normalize columns to lowercase
178            2                                 20      $expl = { map { lc($_) => $expl->{$_} } keys %$expl };
              20                                 91   
179   ***      2     50                          16      if ( $expl->{possible_keys} ) {
180            2                                  5         MKDEBUG && _d('possible_keys =', $expl->{possible_keys});
181            2                                 19         my @candidates = split(',', $expl->{possible_keys});
182            2                                  7         my %possible   = map { $_ => 1 } @candidates;
               4                                 19   
183   ***      2     50                          10         if ( $expl->{key} ) {
184            2                                  5            MKDEBUG && _d('MySQL chose', $expl->{key});
185            2                                  9            unshift @candidates, grep { $possible{$_} } split(',', $expl->{key});
               3                                 13   
186            2                                  5            MKDEBUG && _d('Before deduping:', join(', ', @candidates));
187            2                                  5            my %seen;
188            2                                  6            @candidates = grep { !$seen{$_}++ } @candidates;
               7                                 32   
189                                                         }
190            2                                  6         MKDEBUG && _d('Final list:', join(', ', @candidates));
191            2                                 26         return @candidates;
192                                                      }
193                                                      else {
194   ***      0                                  0         MKDEBUG && _d('No keys in possible_keys');
195   ***      0                                  0         return ();
196                                                      }
197                                                   }
198                                                   
199                                                   # Returns true if the table exists.  If $can_insert is set, also checks whether
200                                                   # the user can insert into the table.
201                                                   sub table_exists {
202            3                    3            30      my ( $self, $dbh, $db, $tbl, $q, $can_insert ) = @_;
203            3                                 10      my $result = 0;
204            3                                 16      my $db_tbl = $q->quote($db, $tbl);
205            3                                 12      my $sql    = "SHOW FULL COLUMNS FROM $db_tbl";
206            3                                  8      MKDEBUG && _d($sql);
207            3                                  8      eval {
208            3                                  6         my $sth = $dbh->prepare($sql);
209            3                                573         $sth->execute();
210            1                                  5         my @columns = @{$sth->fetchall_arrayref({})};
               1                                 30   
211   ***      1     50                          11         if ( $can_insert ) {
212   ***      0             0                    0            $result = grep { ($_->{Privileges} || '') =~ m/insert/ } @columns;
      ***      0                                  0   
213                                                         }
214                                                         else {
215            1                                 22            $result = 1;
216                                                         }
217                                                      };
218            3                                 21      if ( MKDEBUG && $EVAL_ERROR ) {
219                                                         _d($EVAL_ERROR);
220                                                      }
221            3                                 23      return $result;
222                                                   }
223                                                   
224                                                   sub get_engine {
225           23                   23           117      my ( $self, $ddl, $opts ) = @_;
226           23                                386      my ( $engine ) = $ddl =~ m/\).*?(?:ENGINE|TYPE)=(\w+)/;
227           23                                 68      MKDEBUG && _d('Storage engine:', $engine);
228   ***     23            50                  116      return $engine || undef;
229                                                   }
230                                                   
231                                                   # $ddl is a SHOW CREATE TABLE returned from MySQLDumper::get_create_table().
232                                                   # The general format of a key is
233                                                   # [FOREIGN|UNIQUE|PRIMARY|FULLTEXT|SPATIAL] KEY `name` [USING BTREE|HASH] (`cols`).
234                                                   # Returns a hashref of keys and their properties and the clustered key (if
235                                                   # the engine is InnoDB):
236                                                   #   {
237                                                   #     key => {
238                                                   #       type         => BTREE, FULLTEXT or  SPATIAL
239                                                   #       name         => column name, like: "foo_key"
240                                                   #       colnames     => original col def string, like: "(`a`,`b`)"
241                                                   #       cols         => arrayref containing the col names, like: [qw(a b)]
242                                                   #       col_prefixes => arrayref containing any col prefixes (parallels cols)
243                                                   #       is_unique    => 1 if the col is UNIQUE or PRIMARY
244                                                   #       is_nullable  => true (> 0) if one or more col can be NULL
245                                                   #       is_col       => hashref with key for each col=>1
246                                                   #     },
247                                                   #   },
248                                                   #   'PRIMARY',   # clustered key
249                                                   #
250                                                   # Foreign keys are ignored; use get_fks() instead.
251                                                   sub get_keys {
252           12                   12            89      my ( $self, $ddl, $opts, $is_nullable ) = @_;
253           12                                 50      my $engine        = $self->get_engine($ddl);
254           12                                 38      my $keys          = {};
255           12                                 32      my $clustered_key = undef;
256                                                   
257                                                      KEY:
258           12                                154      foreach my $key ( $ddl =~ m/^  ((?:[A-Z]+ )?KEY .*)$/gm ) {
259                                                   
260                                                         # If you want foreign keys, use get_fks() below.
261   ***     19     50                          80         next KEY if $key =~ m/FOREIGN/;
262                                                   
263           19                                 43         MKDEBUG && _d('Parsed key:', $key);
264                                                   
265                                                         # Make allowances for HASH bugs in SHOW CREATE TABLE.  A non-MEMORY table
266                                                         # will report its index as USING HASH even when this is not supported.
267                                                         # The true type should be BTREE.  See
268                                                         # http://bugs.mysql.com/bug.php?id=22632
269   ***     19     50                         100         if ( $engine !~ m/MEMORY|HEAP/ ) {
270           19                                 61            $key =~ s/USING HASH/USING BTREE/;
271                                                         }
272                                                   
273                                                         # Determine index type
274           19                                138         my ( $type, $cols ) = $key =~ m/(?:USING (\w+))? \((.+)\)/;
275           19                                 83         my ( $special ) = $key =~ m/(FULLTEXT|SPATIAL)/;
276   ***     19            33                  198         $type = $type || $special || 'BTREE';
      ***                   50                        
277   ***     19     50     33                  123         if ( $opts->{mysql_version} && $opts->{mysql_version} lt '004001000'
      ***                   33                        
278                                                            && $engine =~ m/HEAP|MEMORY/i )
279                                                         {
280   ***      0                                  0            $type = 'HASH'; # MySQL pre-4.1 supports only HASH indexes on HEAP
281                                                         }
282                                                   
283           19                                133         my ($name) = $key =~ m/(PRIMARY|`[^`]*`)/;
284           19    100                         109         my $unique = $key =~ m/PRIMARY|UNIQUE/ ? 1 : 0;
285           19                                 46         my @cols;
286           19                                 43         my @col_prefixes;
287           19                                 95         foreach my $col_def ( split(',', $cols) ) {
288                                                            # Parse columns of index including potential column prefixes
289                                                            # E.g.: `a`,`b`(20)
290           25                                161            my ($name, $prefix) = $col_def =~ m/`([^`]+)`(?:\((\d+)\))?/;
291           25                                 86            push @cols, $name;
292           25                                 95            push @col_prefixes, $prefix;
293                                                         }
294           19                                 85         $name =~ s/`//g;
295                                                   
296           19                                 44         MKDEBUG && _d('Key', $name, 'cols:', join(', ', @cols));
297                                                   
298           25                                106         $keys->{$name} = {
299                                                            name         => $name,
300                                                            type         => $type,
301                                                            colnames     => $cols,
302                                                            cols         => \@cols,
303                                                            col_prefixes => \@col_prefixes,
304                                                            is_unique    => $unique,
305           25                                212            is_nullable  => scalar(grep { $is_nullable->{$_} } @cols),
306           19                                108            is_col       => { map { $_ => 1 } @cols },
307                                                         };
308                                                   
309                                                         # Find clustered key (issue 295).
310           19    100    100                  195         if ( $engine =~ m/InnoDB/i && !$clustered_key ) {
311            7                                 26            my $this_key = $keys->{$name};
312   ***      7    100     66                   53            if ( $this_key->{name} eq 'PRIMARY' ) {
                    100                               
313            4                                 12               $clustered_key = 'PRIMARY';
314                                                            }
315                                                            elsif ( $this_key->{is_unique} && !$this_key->{is_nullable} ) {
316            1                                  4               $clustered_key = $this_key->{name};
317                                                            }
318            7                                 28            MKDEBUG && $clustered_key && _d('This key is the clustered key');
319                                                         }
320                                                      }
321                                                   
322           12                                 67      return $keys, $clustered_key;
323                                                   }
324                                                   
325                                                   # Like get_keys() above but only returns a hash of foreign keys.
326                                                   sub get_fks {
327            4                    4            53      my ( $self, $ddl, $opts ) = @_;
328            4                                 14      my $fks = {};
329                                                   
330            4                                 45      foreach my $fk (
331                                                         $ddl =~ m/CONSTRAINT .* FOREIGN KEY .* REFERENCES [^\)]*\)/mg )
332                                                      {
333            4                                 28         my ( $name ) = $fk =~ m/CONSTRAINT `(.*?)`/;
334            4                                 23         my ( $cols ) = $fk =~ m/FOREIGN KEY \(([^\)]+)\)/;
335            4                                 27         my ( $parent, $parent_cols ) = $fk =~ m/REFERENCES (\S+) \(([^\)]+)\)/;
336                                                   
337   ***      4    100     66                   46         if ( $parent !~ m/\./ && $opts->{database} ) {
338            1                                  7            $parent = "`$opts->{database}`.$parent";
339                                                         }
340                                                   
341            4                                 21         $fks->{$name} = {
342                                                            name           => $name,
343                                                            colnames       => $cols,
344            4                                 25            cols           => [ map { s/[ `]+//g; $_; } split(',', $cols) ],
               4                                 14   
345                                                            parent_tbl     => $parent,
346                                                            parent_colnames=> $parent_cols,
347            4                                 23            parent_cols    => [ map { s/[ `]+//g; $_; } split(',', $parent_cols) ],
               4                                 41   
348                                                         };
349                                                      }
350                                                   
351            4                                 61      return $fks;
352                                                   }
353                                                   
354                                                   # Removes the AUTO_INCREMENT property from the end of SHOW CREATE TABLE.  A
355                                                   # sample:
356                                                   # ) ENGINE=InnoDB AUTO_INCREMENT=201 DEFAULT CHARSET=utf8;
357                                                   sub remove_auto_increment {
358            1                    1            15      my ( $self, $ddl ) = @_;
359            1                                 15      $ddl =~ s/(^\).*?) AUTO_INCREMENT=\d+\b/$1/m;
360            1                                  7      return $ddl;
361                                                   }
362                                                   
363                                                   sub _d {
364   ***      0                    0                    my ($package, undef, $line) = caller 0;
365   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
366   ***      0                                              map { defined $_ ? $_ : 'undef' }
367                                                           @_;
368   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
369                                                   }
370                                                   
371                                                   1;
372                                                   
373                                                   # ###########################################################################
374                                                   # End TableParser package
375                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
47           100      1     13   unless $ddl
48    ***     50      0     13   if (ref $ddl eq 'ARRAY')
49    ***      0      0      0   if (lc $$ddl[0] eq 'table') { }
59           100      2     11   if (not $ddl =~ /CREATE (?:TEMPORARY )?TABLE `/)
85    ***     50      0     48   unless $type
87           100     26     22   if ($type =~ /(?:(?:tiny|big|medium|small)?int|float|double|decimal|year)/)
91           100     21     27   if (not $def =~ /NOT NULL/)
95           100      4     44   $def =~ /AUTO_INCREMENT/i ? :
131          100      2      6   unless ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'} or $$tbl{'keys'}{$a}{'is_nullable'} <=> $$tbl{'keys'}{$b}{'is_nullable'}
147          100      2      1   if ($index)
150          100      2      1   if (not $best)
151          100      1      1   if ($index) { }
172   ***     50      0      2   unless $where
179   ***     50      2      0   if ($$expl{'possible_keys'}) { }
183   ***     50      2      0   if ($$expl{'key'})
211   ***     50      0      1   if ($can_insert) { }
261   ***     50      0     19   if $key =~ /FOREIGN/
269   ***     50     19      0   if (not $engine =~ /MEMORY|HEAP/)
277   ***     50      0     19   if ($$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000' and $engine =~ /HEAP|MEMORY/i)
284          100      8     11   $key =~ /PRIMARY|UNIQUE/ ? :
310          100      7     12   if ($engine =~ /InnoDB/i and not $clustered_key)
312          100      4      3   if ($$this_key{'name'} eq 'PRIMARY') { }
             100      1      2   elsif ($$this_key{'is_unique'} and not $$this_key{'is_nullable'}) { }
337          100      1      3   if (not $parent =~ /\./ and $$opts{'database'})
365   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
277   ***     33     19      0      0   $$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000'
      ***     33     19      0      0   $$opts{'mysql_version'} and $$opts{'mysql_version'} lt '004001000' and $engine =~ /HEAP|MEMORY/i
310          100      4      8      7   $engine =~ /InnoDB/i and not $clustered_key
312   ***     66      0      2      1   $$this_key{'is_unique'} and not $$this_key{'is_nullable'}
337   ***     66      0      3      1   not $parent =~ /\./ and $$opts{'database'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
212   ***      0      0      0   $$_{'Privileges'} || ''
228   ***     50     23      0   $engine || undef
276   ***     50      0     19   $type || $special || 'BTREE'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
131   ***     66      4      0      4   ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'}
             100      4      2      2   ($a ne 'PRIMARY') <=> ($b ne 'PRIMARY') or !$$tbl{'keys'}{$a}{'is_unique'} <=> !$$tbl{'keys'}{$b}{'is_unique'} or $$tbl{'keys'}{$a}{'is_nullable'} <=> $$tbl{'keys'}{$b}{'is_nullable'}
276   ***     33      0      0     19   $type || $special


Covered Subroutines
-------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:22 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:23 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:24 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableParser.pm:26 
find_best_index           3 /home/daniel/dev/maatkit/common/TableParser.pm:145
find_possible_keys        2 /home/daniel/dev/maatkit/common/TableParser.pm:171
get_engine               23 /home/daniel/dev/maatkit/common/TableParser.pm:225
get_fks                   4 /home/daniel/dev/maatkit/common/TableParser.pm:327
get_keys                 12 /home/daniel/dev/maatkit/common/TableParser.pm:252
new                       1 /home/daniel/dev/maatkit/common/TableParser.pm:29 
parse                    14 /home/daniel/dev/maatkit/common/TableParser.pm:46 
remove_auto_increment     1 /home/daniel/dev/maatkit/common/TableParser.pm:358
sort_indexes              2 /home/daniel/dev/maatkit/common/TableParser.pm:124
table_exists              3 /home/daniel/dev/maatkit/common/TableParser.pm:202

Uncovered Subroutines
---------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
_d                        0 /home/daniel/dev/maatkit/common/TableParser.pm:364


