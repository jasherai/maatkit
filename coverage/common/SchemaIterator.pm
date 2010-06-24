---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/SchemaIterator.pm   95.4   81.8   73.8   92.9    0.0    7.0   86.0
SchemaIterator.t              100.0   50.0   40.0  100.0    n/a   93.0   97.3
Total                          98.0   79.8   71.2   96.7    0.0  100.0   90.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:29 2010
Finish:       Thu Jun 24 19:36:29 2010

Run:          SchemaIterator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:31 2010
Finish:       Thu Jun 24 19:36:32 2010

/home/daniel/dev/maatkit/common/SchemaIterator.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
18                                                    # SchemaIterator package $Revision: 5473 $
19                                                    # ###########################################################################
20                                                    package SchemaIterator;
21                                                    
22             1                    1             4   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                 15   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
32                                                    
33                                                    sub new {
34    ***      1                    1      0      7      my ( $class, %args ) = @_;
35             1                                  5      foreach my $arg ( qw(Quoter) ) {
36    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38             1                                  8      my $self = {
39                                                          %args,
40                                                          filter => undef,
41                                                          dbs    => [],
42                                                       };
43             1                                 13      return bless $self, $class;
44                                                    }
45                                                    
46                                                    # Required args:
47                                                    #   * o  obj: OptionParser module
48                                                    # Returns: subref
49                                                    # Can die: yes
50                                                    # make_filter() uses an OptionParser obj and the following standard filter
51                                                    # options to make a filter sub suitable for set_filter():
52                                                    #   --databases -d            List of allowed databases
53                                                    #   --ignore-databases        List of databases to ignore
54                                                    #   --databases-regex         List of allowed databases that match pattern
55                                                    #   --ignore-databases-regex  List of ignored database that match pattern
56                                                    #   --tables    -t            List of allowed tables
57                                                    #   --ignore-tables           List of tables to ignore
58                                                    #   --tables-regex            List of allowed tables that match pattern
59                                                    #   --ignore-tables-regex     List of ignored tables that match pattern
60                                                    #   --engines   -e            List of allowed engines
61                                                    #   --ignore-engines          List of engines to ignore 
62                                                    # The filters in the sub are created in that order for efficiency.  For
63                                                    # example, the table filters are not checked if the database doesn't first
64                                                    # pass its filters.  Each filter is only created if specified.  Since the
65                                                    # database and tables are given separately we no longer have to worry about
66                                                    # splitting db.tbl to match db and/or tbl.  The filter returns true if the
67                                                    # schema object is allowed.
68                                                    sub make_filter {
69    ***     22                   22      0    118      my ( $self, $o ) = @_;
70            22                                128      my @lines = (
71                                                          'sub {',
72                                                          '   my ( $dbh, $db, $tbl ) = @_;',
73                                                          '   my $engine = undef;',
74                                                       );
75                                                    
76                                                       # Filter schema objs in this order: db, tbl, engine.  It's not efficient
77                                                       # to check the table if, for example, the database isn't allowed.
78                                                    
79    ***     22     50                         115      my @permit_dbs = _make_filter('unless', '$db', $o->get('databases'))
80                                                          if $o->has('databases');
81    ***     22     50                         115      my @reject_dbs = _make_filter('if', '$db', $o->get('ignore-databases'))
82                                                          if $o->has('ignore-databases');
83            22                                 82      my @dbs_regex;
84    ***     22    100     66                  107      if ( $o->has('databases-regex') && (my $p = $o->get('databases-regex')) ) {
85             1                                  6         push @dbs_regex, "      return 0 unless \$db && (\$db =~ m/$p/o);";
86                                                       }
87            22                                 66      my @reject_dbs_regex;
88    ***     22    100     66                  102      if ( $o->has('ignore-databases-regex')
89                                                            && (my $p = $o->get('ignore-databases-regex')) ) {
90             1                                 21         push @reject_dbs_regex, "      return 0 if \$db && (\$db =~ m/$p/o);";
91                                                       }
92            22    100    100                  309      if ( @permit_dbs || @reject_dbs || @dbs_regex || @reject_dbs_regex ) {
                           100                        
                           100                        
93            13    100                         133         push @lines,
                    100                               
                    100                               
                    100                               
94                                                             '   if ( $db ) {',
95                                                                (@permit_dbs        ? @permit_dbs       : ()),
96                                                                (@reject_dbs        ? @reject_dbs       : ()),
97                                                                (@dbs_regex         ? @dbs_regex        : ()),
98                                                                (@reject_dbs_regex  ? @reject_dbs_regex : ()),
99                                                             '   }';
100                                                      }
101                                                   
102   ***     22     50     33                  108      if ( $o->has('tables') || $o->has('ignore-tables')
      ***                   33                        
103                                                           || $o->has('ignore-tables-regex') ) {
104                                                   
105                                                         # Have created the "my $qtbls = ..." line for db-qualified tbls.
106                                                         # http://code.google.com/p/maatkit/issues/detail?id=806
107           22                                550         my $have_qtbl       = 0;
108           22                                 67         my $have_only_qtbls = 0;
109           22                                 64         my %qtbls;
110                                                   
111           22                                 52         my @permit_tbls;
112           22                                 52         my @permit_qtbls;
113           22                                 56         my %permit_qtbls;
114           22    100                         115         if ( $o->get('tables') ) {
115            9                                219            my %tbls;
116                                                            map {
117           13    100                         245               if ( $_ =~ m/\./ ) {
               9                                 36   
118                                                                  # Table is db-qualified (db.tbl).
119           12                                 52                  $permit_qtbls{$_} = 1;
120                                                               }
121                                                               else {
122            1                                  5                  $tbls{$_} = 1;
123                                                               }
124            9                                 26            } keys %{ $o->get('tables') };
125            9                                 41            @permit_tbls  = _make_filter('unless', '$tbl', \%tbls);
126            9                                 39            @permit_qtbls = _make_filter('unless', '$qtbl', \%permit_qtbls);
127                                                   
128            9    100                          42            if ( @permit_qtbls ) {
129            8                                 26               push @lines,
130                                                                  '   my $qtbl   = ($db ? "$db." : "") . ($tbl ? $tbl : "");';
131            8                                 29               $have_qtbl = 1;
132                                                            }
133                                                         }
134                                                   
135           22                                381         my @reject_tbls;
136           22                                 58         my @reject_qtbls;
137           22                                 61         my %reject_qtbls;
138   ***     22     50                         104         if ( $o->get('ignore-tables') ) {
139           22                                560            my %tbls;
140                                                            map {
141            5    100                          92               if ( $_ =~ m/\./ ) {
              22                                 95   
142                                                                  # Table is db-qualified (db.tbl).
143            1                                  5                  $reject_qtbls{$_} = 1;
144                                                               }
145                                                               else {
146            4                                 18                  $tbls{$_} = 1;
147                                                               }
148           22                                 63            } keys %{ $o->get('ignore-tables') };
149           22                                541            @reject_tbls= _make_filter('if', '$tbl', \%tbls);
150           22                                 95            @reject_qtbls = _make_filter('if', '$qtbl', \%reject_qtbls);
151                                                   
152   ***     22    100     66                  137            if ( @reject_qtbls && !$have_qtbl ) {
153            1                                  5               push @lines,
154                                                                  '   my $qtbl   = ($db ? "$db." : "") . ($tbl ? $tbl : "");';
155                                                            }
156                                                         }
157                                                   
158                                                         # If all -t are db-qualified but there are no explicit -d, then
159                                                         # we add all unique dbs from the -t to -d and recurse.  This
160                                                         # prevents wasted effort looking at db that are implicitly filtered
161                                                         # by the db-qualified -t.
162           22    100    100                  163         if ( keys %permit_qtbls  && !@permit_dbs ) {
163            3                                 11            my $dbs = {};
164            5                                 27            map {
165            3                                 12               my ($db, undef) = split(/\./, $_);
166            5                                 24               $dbs->{$db} = 1;
167                                                            } keys %permit_qtbls;
168            3                                  9            MKDEBUG && _d('Adding restriction "--databases',
169                                                                  (join(',', keys %$dbs) . '"'));
170   ***      3     50                          17            if ( keys %$dbs ) {
171                                                               # Only recurse if extracting the dbs worked. Else, the
172                                                               # following code will still work and we just lose this
173                                                               # optimization.
174            3                                 19               $o->set('databases', $dbs);
175            3                                104               return $self->make_filter($o);
176                                                            }
177                                                         }
178                                                   
179           19                                 56         my @tbls_regex;
180   ***     19    100     66                   96         if ( $o->has('tables-regex') && (my $p = $o->get('tables-regex')) ) {
181            1                                  5            push @tbls_regex, "      return 0 unless \$tbl && (\$tbl =~ m/$p/o);";
182                                                         }
183           19                                 56         my @reject_tbls_regex;
184   ***     19    100     66                   98         if ( $o->has('ignore-tables-regex')
185                                                              && (my $p = $o->get('ignore-tables-regex')) ) {
186            1                                  5            push @reject_tbls_regex,
187                                                               "      return 0 if \$tbl && (\$tbl =~ m/$p/o);";
188                                                         }
189                                                   
190           19                                 53         my @get_eng;
191           19                                 46         my @permit_engs;
192           19                                 57         my @reject_engs;
193   ***     19     50     66                   89         if ( ($o->has('engines') && $o->get('engines'))
      ***                   33                        
      ***                   66                        
194                                                              || ($o->has('ignore-engines') && $o->get('ignore-engines')) ) {
195           19                                136            push @get_eng,
196                                                               '      my $sql = "SHOW TABLE STATUS "',
197                                                               '              . ($db ? "FROM `$db`" : "")',
198                                                               '              . " LIKE \'$tbl\'";',
199                                                               '      MKDEBUG && _d($sql);',
200                                                               '      eval {',
201                                                               '         $engine = $dbh->selectrow_hashref($sql)->{engine};',
202                                                               '      };',
203                                                               '      MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);',
204                                                               '      MKDEBUG && _d($tbl, "uses engine", $engine);',
205                                                               '      $engine = lc $engine if $engine;',
206                                                            @permit_engs
207                                                               = _make_filter('unless', '$engine', $o->get('engines'), 1);
208                                                            @reject_engs
209           19                                108               = _make_filter('if', '$engine', $o->get('ignore-engines'), 1)
210                                                         }
211                                                   
212   ***     19     50    100                  481         if ( @permit_tbls || @reject_tbls || @tbls_regex || @reject_tbls_regex
                           100                        
                           100                        
                           100                        
      ***                   66                        
213                                                              || @permit_engs || @reject_engs ) {
214           19    100                         360            push @lines,
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
      ***            50                               
                    100                               
      ***            50                               
215                                                               '   if ( $tbl ) {',
216                                                                  (@permit_tbls       ? @permit_tbls        : ()),
217                                                                  (@reject_tbls       ? @reject_tbls        : ()),
218                                                                  (@tbls_regex        ? @tbls_regex         : ()),
219                                                                  (@reject_tbls_regex ? @reject_tbls_regex  : ()),
220                                                                  (@permit_qtbls      ? @permit_qtbls       : ()),
221                                                                  (@reject_qtbls      ? @reject_qtbls       : ()),
222                                                                  (@get_eng           ? @get_eng            : ()),
223                                                                  (@permit_engs       ? @permit_engs        : ()),
224                                                                  (@reject_engs       ? @reject_engs        : ()),
225                                                               '   }';
226                                                         }
227                                                      }
228                                                   
229           19                                105      push @lines,
230                                                         '   MKDEBUG && _d(\'Passes filters:\', $db, $tbl, $engine, $dbh);',
231                                                         '   return 1;',  '}';
232                                                   
233                                                      # Make the subroutine.
234           19                                156      my $code = join("\n", @lines);
235           19                                 51      MKDEBUG && _d('filter sub:', $code);
236   ***     19     50                        4868      my $filter_sub= eval $code
237                                                         or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";
238                                                   
239           19                                176      return $filter_sub;
240                                                   }
241                                                   
242                                                   # Required args:
243                                                   #   * filter_sub  subref: Filter sub, usually from make_filter()
244                                                   # Returns: undef
245                                                   # Can die: no
246                                                   # set_filter() sets the filter sub that get_db_itr() and get_tbl_itr()
247                                                   # use to filter the schema objects they find.  If no filter sub is set
248                                                   # then every possible schema object is returned by the iterators.  The
249                                                   # filter should return true if the schema object is allowed.
250                                                   sub set_filter {
251   ***     19                   19      0     99      my ( $self, $filter_sub ) = @_;
252           19                                 86      $self->{filter} = $filter_sub;
253           19                                511      MKDEBUG && _d('Set filter sub');
254           19                                 67      return;
255                                                   }
256                                                   
257                                                   # Required args:
258                                                   #   * dbh  dbh: an active dbh
259                                                   # Returns: itr
260                                                   # Can die: no
261                                                   # get_db_itr() returns an iterator which returns the next db found,
262                                                   # according to any set filters, when called successively.
263                                                   sub get_db_itr {
264   ***     13                   13      0    104      my ( $self, %args ) = @_;
265           13                                 66      my @required_args = qw(dbh);
266           13                                 62      foreach my $arg ( @required_args ) {
267   ***     13     50                         113         die "I need a $arg argument" unless $args{$arg};
268                                                      }
269           13                                 70      my ($dbh) = @args{@required_args};
270                                                   
271           13                                 52      my $filter = $self->{filter};
272           13                                 45      my @dbs;
273           13                                 45      eval {
274           13                                 48         my $sql = 'SHOW DATABASES';
275           13                                 32         MKDEBUG && _d($sql);
276           78    100                        7832         @dbs =  grep {
277           13                                 42            my $ok = $filter ? $filter->($dbh, $_, undef) : 1;
278           78    100                         437            $ok = 0 if $_ =~ m/information_schema|lost\+found/;
279           78                                278            $ok;
280           13                                 48         } @{ $dbh->selectcol_arrayref($sql) };
281           13                                 61         MKDEBUG && _d('Found', scalar @dbs, 'databases');
282                                                      };
283           13                                 34      MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
284                                                      return sub {
285           42                   42           262         return shift @dbs;
286           13                                143      };
287                                                   }
288                                                   
289                                                   # Required args:
290                                                   #   * dbh    dbh: an active dbh
291                                                   #   * db     scalar: database name
292                                                   # Optional args:
293                                                   #   * views  bool: Permit/return views (default no)
294                                                   # Returns: itr
295                                                   # Can die: no
296                                                   # get_tbl_itr() returns an iterator which returns the next table found,
297                                                   # in the given db, according to any set filters, when called successively.
298                                                   # Make sure $dbh->{FetchHashKeyName} = 'NAME_lc' was set, else engine
299                                                   # filters won't work.
300                                                   sub get_tbl_itr {
301   ***     26                   26      0    209      my ( $self, %args ) = @_;
302           26                                140      my @required_args = qw(dbh db);
303           26                                114      foreach my $arg ( @required_args ) {
304   ***     52     50                         283         die "I need a $arg argument" unless $args{$arg};
305                                                      }
306           26                                163      my ($dbh, $db, $views) = @args{@required_args, 'views'};
307                                                   
308           26                                100      my $filter = $self->{filter};
309           26                                 76      my @tbls;
310   ***     26     50                         114      if ( $db ) {
311           26                                 79         eval {
312           26                                227            my $sql = 'SHOW /*!50002 FULL*/ TABLES FROM '
313                                                                    . $self->{Quoter}->quote($db);
314           26                                900            MKDEBUG && _d($sql);
315           72                                358            @tbls = map {
316          102                               8345               $_->[0]
317                                                            }
318                                                            grep {
319           26                                 68               my ($tbl, $type) = @$_;
320          102    100                         618               my $ok = $filter ? $filter->($dbh, $db, $tbl) : 1;
321          102    100                         472               if ( !$views ) {
322                                                                  # We don't want views therefore we have to check the table
323                                                                  # type.  Views are actually available in 5.0.1 but "FULL"
324                                                                  # in SHOW FULL TABLES was not added until 5.0.2.  So 5.0.1
325                                                                  # is an edge case that we ignore.  If >=5.0.2 then there
326                                                                  # might be views and $type will be Table_type and we check
327                                                                  # as normal.  Else, there cannot be views so there will be
328                                                                  # no $type.
329   ***     79    100     50                  457                  $ok = 0 if ($type || '') eq 'VIEW';
330                                                               }
331          102                                376               $ok;
332                                                            }
333           26                                 89            @{ $dbh->selectall_arrayref($sql) };
334           26                               1016            MKDEBUG && _d('Found', scalar @tbls, 'tables in', $db);
335                                                         };
336           26                                 87         MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
337                                                      }
338                                                      else {
339   ***      0                                  0         MKDEBUG && _d('No db given so no tables');
340                                                      }
341                                                      return sub {
342           98                   98           563         return shift @tbls;
343           26                                325      };
344                                                   }
345                                                   
346                                                   # Required args:
347                                                   #   * cond      scalar: condition for check, "if" or "unless"
348                                                   #   * var_name  scalar: literal var name to compare to obj values
349                                                   #   * objs      hashref: object values (as the hash keys)
350                                                   # Optional args:
351                                                   #   * lc  bool: lowercase object values
352                                                   # Returns: scalar
353                                                   # Can die: no
354                                                   # _make_filter() return a test condtion like "$var eq 'foo' || $var eq 'bar'".
355                                                   sub _make_filter {
356          144                  144          1531      my ( $cond, $var_name, $objs, $lc ) = @_;
357          144                                382      my @lines;
358          144    100                         641      if ( scalar keys %$objs ) {
359           75    100                         486         my $test = join(' || ',
360           44                                190            map { "$var_name eq '" . ($lc ? lc $_ : $_) ."'" } keys %$objs);
361           44                                309         push @lines, "      return 0 $cond $var_name && ($test);",
362                                                      }
363          144                                807      return @lines;
364                                                   }
365                                                   
366                                                   sub _d {
367   ***      0                    0                    my ($package, undef, $line) = caller 0;
368   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
369   ***      0                                              map { defined $_ ? $_ : 'undef' }
370                                                           @_;
371   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
372                                                   }
373                                                   
374                                                   1;
375                                                   
376                                                   # ###########################################################################
377                                                   # End SchemaIterator package
378                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0      1   unless $args{$arg}
79    ***     50     22      0   if $o->has('databases')
81    ***     50     22      0   if $o->has('ignore-databases')
84           100      1     21   if ($o->has('databases-regex') and my $p = $o->get('databases-regex'))
88           100      1     21   if ($o->has('ignore-databases-regex') and my $p = $o->get('ignore-databases-regex'))
92           100     13      9   if (@permit_dbs or @reject_dbs or @dbs_regex or @reject_dbs_regex)
93           100      8      5   @permit_dbs ? :
             100      3     10   @reject_dbs ? :
             100      1     12   @dbs_regex ? :
             100      1     12   @reject_dbs_regex ? :
102   ***     50     22      0   if ($o->has('tables') or $o->has('ignore-tables') or $o->has('ignore-tables-regex'))
114          100      9     13   if ($o->get('tables'))
117          100     12      1   if ($_ =~ /\./) { }
128          100      8      1   if (@permit_qtbls)
138   ***     50     22      0   if ($o->get('ignore-tables'))
141          100      1      4   if ($_ =~ /\./) { }
152          100      1     21   if (@reject_qtbls and not $have_qtbl)
162          100      3     19   if (keys %permit_qtbls and not @permit_dbs)
170   ***     50      3      0   if (keys %$dbs)
180          100      1     18   if ($o->has('tables-regex') and my $p = $o->get('tables-regex'))
184          100      1     18   if ($o->has('ignore-tables-regex') and my $p = $o->get('ignore-tables-regex'))
193   ***     50     19      0   if ($o->has('engines') and $o->get('engines') or $o->has('ignore-engines') and $o->get('ignore-engines'))
212   ***     50     19      0   if (@permit_tbls or @reject_tbls or @tbls_regex or @reject_tbls_regex or @permit_engs or @reject_engs)
214          100      1     18   @permit_tbls ? :
             100      2     17   @reject_tbls ? :
             100      1     18   @tbls_regex ? :
             100      1     18   @reject_tbls_regex ? :
             100      5     14   @permit_qtbls ? :
             100      1     18   @reject_qtbls ? :
      ***     50     19      0   @get_eng ? :
             100      2     17   @permit_engs ? :
      ***     50     19      0   @reject_engs ? :
236   ***     50      0     19   unless my $filter_sub = eval $code
267   ***     50      0     13   unless $args{$arg}
276          100     72      6   $filter ? :
278          100     13     65   if $_ =~ /information_schema|lost\+found/
304   ***     50      0     52   unless $args{$arg}
310   ***     50     26      0   if ($db) { }
320          100     98      4   $filter ? :
321          100     79     23   if (not $views)
329          100      7     72   if ($type || '') eq 'VIEW'
358          100     44    100   if (scalar keys %$objs)
359          100     38     37   $lc ? :
368   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
84    ***     66      0     21      1   $o->has('databases-regex') and my $p = $o->get('databases-regex')
88    ***     66      0     21      1   $o->has('ignore-databases-regex') and my $p = $o->get('ignore-databases-regex')
152   ***     66     21      0      1   @reject_qtbls and not $have_qtbl
162          100     14      5      3   keys %permit_qtbls and not @permit_dbs
180   ***     66      0     18      1   $o->has('tables-regex') and my $p = $o->get('tables-regex')
184   ***     66      0     18      1   $o->has('ignore-tables-regex') and my $p = $o->get('ignore-tables-regex')
193   ***     66      0     17      2   $o->has('engines') and $o->get('engines')
      ***     33      0      0     17   $o->has('ignore-engines') and $o->get('ignore-engines')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
329   ***     50     79      0   $type || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
92           100      8      3     11   @permit_dbs or @reject_dbs
             100     11      1     10   @permit_dbs or @reject_dbs or @dbs_regex
             100     12      1      9   @permit_dbs or @reject_dbs or @dbs_regex or @reject_dbs_regex
102   ***     33     22      0      0   $o->has('tables') or $o->has('ignore-tables')
      ***     33     22      0      0   $o->has('tables') or $o->has('ignore-tables') or $o->has('ignore-tables-regex')
193   ***     66      2     17      0   $o->has('engines') and $o->get('engines') or $o->has('ignore-engines') and $o->get('ignore-engines')
212          100      1      2     16   @permit_tbls or @reject_tbls
             100      3      1     15   @permit_tbls or @reject_tbls or @tbls_regex
             100      4      1     14   @permit_tbls or @reject_tbls or @tbls_regex or @reject_tbls_regex
             100      5      2     12   @permit_tbls or @reject_tbls or @tbls_regex or @reject_tbls_regex or @permit_engs
      ***     66      7     12      0   @permit_tbls or @reject_tbls or @tbls_regex or @reject_tbls_regex or @permit_engs or @reject_engs


Covered Subroutines
-------------------

Subroutine   Count Pod Location                                             
------------ ----- --- -----------------------------------------------------
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaIterator.pm:22 
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaIterator.pm:23 
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaIterator.pm:25 
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaIterator.pm:26 
BEGIN            1     /home/daniel/dev/maatkit/common/SchemaIterator.pm:31 
__ANON__        42     /home/daniel/dev/maatkit/common/SchemaIterator.pm:285
__ANON__        98     /home/daniel/dev/maatkit/common/SchemaIterator.pm:342
_make_filter   144     /home/daniel/dev/maatkit/common/SchemaIterator.pm:356
get_db_itr      13   0 /home/daniel/dev/maatkit/common/SchemaIterator.pm:264
get_tbl_itr     26   0 /home/daniel/dev/maatkit/common/SchemaIterator.pm:301
make_filter     22   0 /home/daniel/dev/maatkit/common/SchemaIterator.pm:69 
new              1   0 /home/daniel/dev/maatkit/common/SchemaIterator.pm:34 
set_filter      19   0 /home/daniel/dev/maatkit/common/SchemaIterator.pm:251

Uncovered Subroutines
---------------------

Subroutine   Count Pod Location                                             
------------ ----- --- -----------------------------------------------------
_d               0     /home/daniel/dev/maatkit/common/SchemaIterator.pm:367


SchemaIterator.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 34;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1             6   use List::Util qw(max);
               1                                  3   
               1                                 11   
15                                                    
16             1                    1            13   use SchemaIterator;
               1                                  2   
               1                                 12   
17             1                    1            10   use Quoter;
               1                                  3   
               1                                 10   
18             1                    1            10   use DSNParser;
               1                                  3   
               1                                 13   
19             1                    1            14   use Sandbox;
               1                                  3   
               1                                  9   
20             1                    1            11   use OptionParser;
               1                                  4   
               1                                 17   
21             1                    1            14   use MaatkitTest;
               1                                  5   
               1                                 48   
22                                                    
23    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  4   
               1                                 24   
24                                                    
25             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  5   
26             1                                  4   $Data::Dumper::Indent    = 1;
27             1                                  4   $Data::Dumper::Sortkeys  = 1;
28             1                                  4   $Data::Dumper::Quotekeys = 0;
29                                                    
30             1                                 11   my $q   = new Quoter();
31             1                                 27   my $dp  = new DSNParser(opts=>$dsn_opts);
32             1                                227   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
33    ***      1     50                          53   my $dbh = $sb->get_dbh_for('master')
34                                                       or BAIL_OUT('Cannot connect to sandbox master');
35             1                                  8   $dbh->{FetchHashKeyName} = 'NAME_lc';
36                                                    
37             1                                 14   my $si = new SchemaIterator(
38                                                       Quoter        => $q,
39                                                    );
40             1                                 11   isa_ok($si, 'SchemaIterator');
41                                                    
42                                                    sub get_all {
43            24                   24           117      my ( $itr ) = @_;
44            24                                 75      my @objs;
45            24                                119      while ( my $obj = $itr->() ) {
46            83                                187         MKDEBUG && SchemaIterator::_d('Iterator returned', Dumper($obj));
47            83                                448         push @objs, $obj;
48                                                       }
49            24                                168      @objs = sort @objs;
50            24                                248      return \@objs;
51                                                    }
52                                                    
53                                                    sub get_all_db_tbls {
54             6                    6            23      my ( $dbh, $si ) = @_;
55             6                                 20      my @db_tbls;
56             6                                 31      my $next_db = $si->get_db_itr(dbh=>$dbh);
57             6                                 27      while ( my $db = $next_db->() ) {
58             9                                 58         my $next_tbl = $si->get_tbl_itr(
59                                                             dbh   => $dbh,
60                                                             db    => $db,
61                                                             views => 0,
62                                                          );
63             9                                 44         while ( my $tbl = $next_tbl->() ) {
64             9                                 53            push @db_tbls, "$db.$tbl";
65                                                          }
66                                                       }
67             6                                 70      return \@db_tbls;
68                                                    }
69                                                    
70                                                    # ###########################################################################
71                                                    # Test simple, unfiltered get_db_itr().
72                                                    # ###########################################################################
73                                                    
74             1                                 11   $sb->load_file('master', 'common/t/samples/SchemaIterator.sql');
75             1                             493185   my @dbs = sort grep { $_ !~ m/information_schema|lost\+found/; } map { $_->[0] } @{ $dbh->selectall_arrayref('show databases') };
               6                                 75   
               6                                667   
               1                                  5   
76                                                    
77             1                                 81   my $next_db = $si->get_db_itr(dbh=>$dbh);
78             1                                 22   is(
79                                                       ref $next_db,
80                                                       'CODE',
81                                                       'get_db_iter() returns a subref'
82                                                    );
83                                                    
84             1                                 17   is_deeply(
85                                                       get_all($next_db),
86                                                       \@dbs,
87                                                       'get_db_iter() found the databases'
88                                                    );
89                                                    
90                                                    # ###########################################################################
91                                                    # Test simple, unfiltered get_tbl_itr().
92                                                    # ###########################################################################
93                                                    
94             1                                 28   my $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
95             1                                 13   is(
96                                                       ref $next_tbl,
97                                                       'CODE',
98                                                       'get_tbl_iter() returns a subref'
99                                                    );
100                                                   
101            1                                 10   is_deeply(
102                                                      get_all($next_tbl),
103                                                      [qw(t1 t2 t3)],
104                                                      'get_tbl_itr() found the db1 tables'
105                                                   );
106                                                   
107            1                                 21   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d2');
108            1                                 13   is_deeply(
109                                                      get_all($next_tbl),
110                                                      [qw(t1)],
111                                                      'get_tbl_itr() found the db2 table'
112                                                   );
113                                                   
114            1                                 22   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d3');
115            1                                 12   is_deeply(
116                                                      get_all($next_tbl),
117                                                      [],
118                                                      'get_tbl_itr() found no db3 tables'
119                                                   );
120                                                   
121                                                   
122                                                   # #############################################################################
123                                                   # Test make_filter().
124                                                   # #############################################################################
125            1                                 33   my $o = new OptionParser(
126                                                      description => 'SchemaIterator'
127                                                   );
128            1                                372   $o->get_specs("$trunk/mk-parallel-dump/mk-parallel-dump");
129            1                                 42   $o->get_opts();
130                                                   
131            1                              18844   my $filter = $si->make_filter($o);
132            1                                 12   is(
133                                                      ref $filter,
134                                                      'CODE',
135                                                      'make_filter() returns a coderef'
136                                                   );
137                                                   
138            1                                 16   $si->set_filter($filter);
139                                                   
140            1                                  8   $next_db = $si->get_db_itr(dbh=>$dbh);
141            1                                 12   is_deeply(
142                                                      get_all($next_db),
143                                                      \@dbs,
144                                                      'Database not filtered',
145                                                   );
146                                                   
147            1                                 22   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
148            1                                 14   is_deeply(
149                                                      get_all($next_tbl),
150                                                      [qw(t1 t2 t3)],
151                                                      'Tables not filtered'
152                                                   );
153                                                   
154                                                   # Filter by --databases (-d).
155            1                                 18   @ARGV=qw(--d d1);
156            1                                 12   $o->get_opts();
157            1                               4607   $si->set_filter($si->make_filter($o));
158                                                   
159            1                                  9   $next_db = $si->get_db_itr(dbh=>$dbh);
160            1                                  9   is_deeply(
161                                                      get_all($next_db),
162                                                      ['d1'],
163                                                      '--databases'
164                                                   );
165                                                   
166            1                                 13   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
167            1                                  9   is_deeply(
168                                                      get_all($next_tbl),
169                                                      [qw(t1 t2 t3)],
170                                                      '--database filter does not affect tables'
171                                                   );
172                                                   
173                                                   # Filter by --databases (-d) and --tables (-t).
174            1                                 11   @ARGV=qw(-d d1 -t t2);
175            1                                  8   $o->get_opts();
176            1                               2312   $si->set_filter($si->make_filter($o));
177                                                   
178            1                                  8   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
179            1                                  8   is_deeply(
180                                                      get_all($next_tbl),
181                                                      ['t2'],
182                                                      '--databases and --tables'
183                                                   );
184                                                   
185                                                   # Ignore some dbs and tbls.
186            1                                 10   @ARGV=('--ignore-databases', 'mysql,sakila,d1,d3');
187            1                                  8   $o->get_opts();
188            1                               2317   $si->set_filter($si->make_filter($o));
189                                                   
190            1                                  5   $next_db = $si->get_db_itr(dbh=>$dbh);
191            1                                  8   is_deeply(
192                                                      get_all($next_db),
193                                                      ['d2'],
194                                                      '--ignore-databases'
195                                                   );
196                                                   
197            1                                 12   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d2');
198            1                                  9   is_deeply(
199                                                      get_all($next_tbl),
200                                                      ['t1'],
201                                                      '--ignore-databases filter does not affect tables'
202                                                   );
203                                                   
204            1                                 12   @ARGV=('--ignore-databases', 'mysql,sakila,d2,d3',
205                                                          '--ignore-tables', 't1,t2');
206            1                                  8   $o->get_opts();
207            1                               2355   $si->set_filter($si->make_filter($o));
208                                                   
209            1                                  6   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
210            1                                  9   is_deeply(
211                                                      get_all($next_tbl),
212                                                      ['t3'],
213                                                      '--ignore-databases and --ignore-tables'
214                                                   );
215                                                   
216                                                   # Select some dbs but ignore some tables.
217            1                                 11   @ARGV=('-d', 'd1', '--ignore-tables', 't1,t3');
218            1                                  9   $o->get_opts();
219            1                               2333   $si->set_filter($si->make_filter($o));
220                                                   
221            1                                  7   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
222            1                                  9   is_deeply(
223                                                      get_all($next_tbl),
224                                                      ['t2'],
225                                                      '--databases and --ignore-tables'
226                                                   );
227                                                   
228                                                   # Filter by engines, which requires extra work: SHOW TABLE STATUS.
229            1                                 10   @ARGV=qw(--engines InnoDB);
230            1                                  8   $o->get_opts();
231            1                               2311   $si->set_filter($si->make_filter($o));
232                                                   
233            1                                  6   $next_db = $si->get_db_itr(dbh=>$dbh);
234            1                                  8   is_deeply(
235                                                      get_all($next_db),
236                                                      \@dbs,
237                                                      '--engines does not affect databases'
238                                                   );
239                                                   
240            1                                 12   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
241            1                                 11   is_deeply(
242                                                      get_all($next_tbl),
243                                                      ['t2'],
244                                                      '--engines'
245                                                   );
246                                                   
247            1                                 11   @ARGV=qw(--ignore-engines MEMORY);
248            1                                  8   $o->get_opts();
249            1                               2299   $si->set_filter($si->make_filter($o));
250                                                   
251            1                                  6   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
252            1                                  9   is_deeply(
253                                                      get_all($next_tbl),
254                                                      [qw(t1 t2)],
255                                                      '--ignore-engines'
256                                                   );
257                                                   
258                                                   # ###########################################################################
259                                                   # Filter views.
260                                                   # ###########################################################################
261            1                                  2   SKIP: {
262            1                                 10      skip 'Sandbox master does not have the sakila database', 2
263   ***      1     50                           3         unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};
264                                                   
265            1                                351      my @sakila_tbls = map { $_->[0] } grep { $_->[1] eq 'BASE TABLE' } @{ $dbh->selectall_arrayref('show /*!50002 FULL*/ tables from sakila') };
              16                                 59   
              23                                504   
               1                                  2   
266                                                   
267            1                                 27      my @all_sakila_tbls = map { $_->[0] } @{ $dbh->selectall_arrayref('show /*!50002 FULL*/ tables from sakila') };
              23                                467   
               1                                  3   
268                                                   
269            1                                 27      @ARGV=();
270            1                                  8      $o->get_opts();
271            1                               9054      $si->set_filter($si->make_filter($o));
272                                                   
273            1                                  6      $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'sakila');
274            1                                 11      is_deeply(
275                                                         get_all($next_tbl),
276                                                         \@sakila_tbls,
277                                                         'Table itr does not return views by default'
278                                                      );
279                                                   
280            1                                 13      $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'sakila', views=>1);
281            1                                 10      is_deeply(
282                                                         get_all($next_tbl),
283                                                         \@all_sakila_tbls,
284                                                         'Table itr returns views if specified'
285                                                      );
286                                                   };
287                                                   
288                                                   # ###########################################################################
289                                                   # Make sure --engine filter is case-insensitive.
290                                                   # ###########################################################################
291                                                   
292                                                   # In MySQL 5.0 it's "MRG_MyISAM" but in 5.1 it's "MRG_MYISAM".  SiLlY.
293                                                   
294            1                                 24   @ARGV=qw(--engines InNoDb);
295            1                                 19   $o->get_opts();
296            1                               2582   $si->set_filter($si->make_filter($o));
297            1                                  6   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
298            1                                 10   is_deeply(
299                                                      get_all($next_tbl),
300                                                      ['t2'],
301                                                      '--engines is case-insensitive'
302                                                   );
303                                                   
304            1                                 10   @ARGV=qw(--ignore-engines InNoDb);
305            1                                  8   $o->get_opts();
306            1                               2346   $si->set_filter($si->make_filter($o));
307            1                                 11   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
308            1                                 10   is_deeply(
309                                                      get_all($next_tbl),
310                                                      ['t1','t3'],
311                                                      '--ignore-engines is case-insensitive'
312                                                   );
313                                                   
314                                                   # ###########################################################################
315                                                   # Filter by regex.
316                                                   # ###########################################################################
317            1                                 11   @ARGV=qw(--databases-regex d[13] --tables-regex t[^3]);
318            1                                  7   $o->get_opts();
319            1                               2334   $si->set_filter($si->make_filter($o));
320                                                   
321            1                                  6   $next_db = $si->get_db_itr(dbh=>$dbh);
322            1                                  9   is_deeply(
323                                                      get_all($next_db),
324                                                      [qw(d1 d3)],
325                                                      '--databases-regex'
326                                                   );
327                                                   
328            1                                 20   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
329            1                                 11   is_deeply(
330                                                      get_all($next_tbl),
331                                                      ['t1','t2'],
332                                                      '--tables-regex'
333                                                   );
334                                                   
335                                                   # ignore patterns
336            1                                 15   @ARGV=qw{--ignore-databases-regex (?:^d[23]|mysql|info|sakila) --ignore-tables-regex t[^23]};
337            1                                  8   $o->get_opts();
338            1                               2356   $si->set_filter($si->make_filter($o));
339                                                   
340            1                                  6   $next_db = $si->get_db_itr(dbh=>$dbh);
341            1                                 11   is_deeply(
342                                                      get_all($next_db),
343                                                      ['d1'],
344                                                      '--ignore-databases-regex'
345                                                   );
346                                                   
347            1                                 16   $next_tbl = $si->get_tbl_itr(dbh=>$dbh, db=>'d1');
348            1                                 11   is_deeply(
349                                                      get_all($next_tbl),
350                                                      [qw(t2 t3)],
351                                                      '--ignore-tables-regex'
352                                                   );
353                                                   
354                                                   
355                                                   # #############################################################################
356                                                   # Issue 806: mk-table-sync --tables does not honor schema qualier
357                                                   # #############################################################################
358                                                   
359                                                   # Filter by db-qualified table.  There is t1 in both d1 and d2.
360                                                   # We want only d1.t1.
361            1                                 12   @ARGV=qw(-t d1.t1);
362            1                                  8   $o->get_opts();
363            1                               2731   $si->set_filter($si->make_filter($o));
364                                                   
365            1                                  6   is_deeply(
366                                                      get_all_db_tbls($dbh, $si),
367                                                      [qw(d1.t1)],
368                                                      '-t d1.t1 (issue 806)'
369                                                   );
370                                                   
371            1                                 11   @ARGV=qw(-d d1 -t d1.t1);
372            1                                  7   $o->get_opts();
373            1                               2404   $si->set_filter($si->make_filter($o));
374                                                   
375            1                                  6   is_deeply(
376                                                      get_all_db_tbls($dbh, $si),
377                                                      [qw(d1.t1)],
378                                                      '-d d1 -t d1.t1 (issue 806)'
379                                                   );
380                                                   
381            1                                 12   @ARGV=qw(-d d2 -t d1.t1);
382            1                                  7   $o->get_opts();
383            1                               2347   $si->set_filter($si->make_filter($o));
384                                                   
385            1                                  6   is_deeply(
386                                                      get_all_db_tbls($dbh, $si),
387                                                      [],
388                                                      '-d d2 -t d1.t1 (issue 806)'
389                                                   );
390                                                   
391            1                                 17   @ARGV=('-t','d1.t1,d1.t3');
392            1                                 11   $o->get_opts();
393            1                               2331   $si->set_filter($si->make_filter($o));
394                                                   
395            1                                  6   is_deeply(
396                                                      get_all_db_tbls($dbh, $si),
397                                                      [qw(d1.t1 d1.t3)],
398                                                      '-t d1.t1,d1.t3 (issue 806)'
399                                                   );
400                                                   
401            1                                 11   @ARGV=('--ignore-databases', 'mysql,sakila', '--ignore-tables', 'd1.t2');
402            1                                  8   $o->get_opts();
403            1                               2413   $si->set_filter($si->make_filter($o));
404                                                   
405            1                                  6   is_deeply(
406                                                      get_all_db_tbls($dbh, $si),
407                                                      [qw(d1.t1 d1.t3 d2.t1)],
408                                                      '--ignore-tables d1.t2 (issue 806)'
409                                                   );
410                                                   
411            1                                 10   @ARGV=('-t','d1.t3,d2.t1');
412            1                                  7   $o->get_opts();
413            1                               2367   $si->set_filter($si->make_filter($o));
414                                                   
415            1                                 52   is_deeply(
416                                                      get_all_db_tbls($dbh, $si),
417                                                      [qw(d1.t3 d2.t1)],
418                                                      '-t d1.t3,d2.t1 (issue 806)'
419                                                   );
420                                                   
421                                                   # #############################################################################
422                                                   # Done.
423                                                   # #############################################################################
424            1                                 18   $sb->wipe_clean($dbh);
425            1                                  6   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
33    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')
263   ***     50      0      1   unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"');}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
23    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine      Count Location           
--------------- ----- -------------------
BEGIN               1 SchemaIterator.t:10
BEGIN               1 SchemaIterator.t:11
BEGIN               1 SchemaIterator.t:12
BEGIN               1 SchemaIterator.t:14
BEGIN               1 SchemaIterator.t:16
BEGIN               1 SchemaIterator.t:17
BEGIN               1 SchemaIterator.t:18
BEGIN               1 SchemaIterator.t:19
BEGIN               1 SchemaIterator.t:20
BEGIN               1 SchemaIterator.t:21
BEGIN               1 SchemaIterator.t:23
BEGIN               1 SchemaIterator.t:25
BEGIN               1 SchemaIterator.t:4 
BEGIN               1 SchemaIterator.t:9 
get_all            24 SchemaIterator.t:43
get_all_db_tbls     6 SchemaIterator.t:54


