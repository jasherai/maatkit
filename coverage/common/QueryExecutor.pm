---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryExecutor.pm   78.9   54.7   76.5   94.1    n/a  100.0   74.8
Total                          78.9   54.7   76.5   94.1    n/a  100.0   74.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryExecutor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:30 2009
Finish:       Sat Aug 29 15:03:30 2009

/home/daniel/dev/maatkit/common/QueryExecutor.pm

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
18                                                    # QueryExecutor package $Revision: 4552 $
19                                                    # ###########################################################################
20                                                    package QueryExecutor;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26             1                    1            11   use Time::HiRes qw(time);
               1                                  3   
               1                                  5   
27             1                    1             9   use Data::Dumper;
               1                                  2   
               1                                  8   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
33                                                    
34                                                    sub new {
35             1                    1           344      my ( $class, %args ) = @_;
36             1                                 12      foreach my $arg ( qw() ) {
37    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
38                                                       }
39             1                                  7      my $self = {};
40             1                                 37      return bless $self, $class;
41                                                    }
42                                                    
43                                                    # Executes a query on the given hosts, calling an array of callbacks for
44                                                    # each host.  The idea is to collect results from various operations pertaining
45                                                    # to the same query when ran on multiple hosts.  For example, the most basic
46                                                    # operation called Query_time times how long the query takes to execute.  Other
47                                                    # operations do things like check for warnings after execution.
48                                                    #
49                                                    # Each operation is performed via a callback and is expected to return a
50                                                    # key=>value pair where the key is the name of the operation and the value
51                                                    # is the operation's results.  The results are a hashref with other
52                                                    # operation-specific key=>value pairs; there should always be at least an
53                                                    # error key that is undef for no error or a string saying what failed and
54                                                    # possibly also an errors key that is an arrayref of strings with more
55                                                    # specific errors if lots of things failed.
56                                                    #
57                                                    # All callbacks are passed the query, the current host's dbh, dsn and name,
58                                                    # and the results from preceding operations.  Each callback is expected to
59                                                    # handle its own errors, so do not die inside a callback!
60                                                    #
61                                                    # All callbacks are ran no matter what.  But since each callback gets the
62                                                    # results off prior callbacks, you can fail gracefully in a callback by looking
63                                                    # to see if some expected prior callback had an error or not.  So the important
64                                                    # point for callbacks is: NEVER ASSUME SUCCESS AND NEVER FAIL SILENTLY.
65                                                    #
66                                                    # In fact, operations are checked and if something looks amiss, the module
67                                                    # will complain and die loudly.
68                                                    #
69                                                    # Obviously, one callback should actually execute the query.  The Query_time
70                                                    # sub is provided for you which does this, or you can use your own sub.
71                                                    # Other common callbacks/operations provided in this package:
72                                                    #   get_warnings(), clear_warnings(), checksum_results().
73                                                    #
74                                                    # Required arguments:
75                                                    #   * query                The query to execute
76                                                    #   * callbacks            Arrayref of callback subs
77                                                    #   * hosts                Arrayref of hosts, each of which is a hashref like:
78                                                    #       {
79                                                    #         dbh              (req) Already connected DBH
80                                                    #         dsn              DSN for more verbose debug messages
81                                                    #       }
82                                                    # Optional arguments:
83                                                    #   * DSNParser            DSNParser obj in case any host dsns are given
84                                                    #
85                                                    sub exec {
86             9                    9          1626      my ( $self, %args ) = @_;
87             9                                 46      foreach my $arg ( qw(query hosts callbacks) ) {
88    ***     27     50                         133         die "I need a $arg argument" unless $args{$arg};
89                                                       }
90             9                                 34      my $query      = $args{query};
91             9                                 30      my $callbacks  = $args{callbacks};
92             9                                 35      my $hosts      = $args{hosts};
93             9                                 32      my $dp         = $args{DSNParser};
94                                                    
95             9                                 21      MKDEBUG && _d('Executing query:', $query);
96                                                    
97             9                                 21      my @results;
98             9                                 25      my $hostno = -1;
99                                                       HOST:
100            9                                 36      foreach my $host ( @$hosts ) {
101           18                                 54         $hostno++;  # Increment this now because we might not reach loop's end.
102           18                                 72         $results[$hostno] = {};
103           18                                 59         my $results       = $results[$hostno];
104           18                                 63         my $dbh           = $host->{dbh};
105           18                                 55         my $dsn           = $host->{dsn};
106   ***     18     50     33                  114         my $host_name     = $dp && $dsn ? $dp->as_string($dsn) : $hostno + 1;
107           18                                125         my %callback_args = (
108                                                            query     => $query,
109                                                            dbh       => $dbh,
110                                                            dsn       => $dsn,
111                                                            host_name => $host_name,
112                                                            results   => $results,
113                                                         );
114                                                   
115           18                                 41         MKDEBUG && _d('Starting execution on host', $host_name);
116           18                                 73         foreach my $callback ( @$callbacks ) {
117           38                                116            my ($name, $res);
118           38                                104            eval {
119           38                                258               ($name, $res) = $callback->(%callback_args);
120                                                            };
121   ***     38     50                        3439            if ( $EVAL_ERROR ) {
122                                                               # This shouldn't happen, but in case of a bad callback...
123   ***      0                                  0               __die(
124                                                                  "A callback sub had an unhandled error: $EVAL_ERROR",
125                                                                  $name,
126                                                                  $res,
127                                                                  $host_name,
128                                                                  \@results
129                                                               );
130                                                            };
131           38                                220            _check_results($name, $res, $host_name, \@results);
132           38                                217            $results->{$name} = $res;
133                                                         }
134           18                                 99         MKDEBUG && _d('Results for host', $host_name, ':', Dumper($results));
135                                                      } # HOST
136                                                   
137            9                                129      return @results;
138                                                   }
139                                                   
140                                                   sub Query_time {
141           16                   16           188      my ( $self, %args ) = @_;
142           16                                 79      foreach my $arg ( qw(query dbh) ) {
143   ***     32     50                         158         die "I need a $arg argument" unless $args{$arg};
144                                                      }
145           16                                 55      my $query = $args{query};
146           16                                 50      my $dbh   = $args{dbh};
147           16                                 44      my $error = undef;
148           16                                 47      my $name  = 'Query_time';
149           16                                 75      my $res   = { error => undef, Query_time => -1, };
150           16                                 37      MKDEBUG && _d($name);
151                                                   
152           16                                 49      my ( $start, $end, $query_time );
153           16                                 41      eval {
154           16                                113         $start = time();
155           16                              57070         $dbh->do($query);
156           14                                115         $end   = time();
157           14                                239         $query_time = sprintf '%.6f', $end - $start;
158                                                      };
159           16    100                          80      if ( $EVAL_ERROR ) {
160            2                                  5         MKDEBUG && _d('Error executing query on host', $args{host_name}, ':',
161                                                            $EVAL_ERROR);
162            2                                  9         $res->{error} = $EVAL_ERROR;
163                                                      }
164                                                      else {
165           14                                 80         $res->{Query_time} = $query_time;
166                                                      }
167                                                   
168           16                                171      return $name, $res;
169                                                   }
170                                                   
171                                                   # Returns an array with its name and a hashref with warnings/errors:
172                                                   # (
173                                                   #   warnings,
174                                                   #   {
175                                                   #     error => undef|string,
176                                                   #     count => 3,         # @@warning_count,
177                                                   #     codes => {          # SHOW WARNINGS
178                                                   #       1062 => {
179                                                   #         Level   => "Error",
180                                                   #         Code    => "1062",
181                                                   #         Message => "Duplicate entry '1' for key 1",
182                                                   #       }
183                                                   #     },
184                                                   #   }
185                                                   # )
186                                                   sub get_warnings {
187            4                    4            54      my ( $self, %args ) = @_;
188            4                                 22      foreach my $arg ( qw(dbh) ) {
189   ***      4     50                          25         die "I need a $arg argument" unless $args{$arg};
190                                                      }
191            4                                 13      my $dbh   = $args{dbh};
192            4                                 10      my $error = undef;
193            4                                 13      my $name  = 'warnings';
194            4                                 11      MKDEBUG && _d($name);
195                                                   
196            4                                 10      my $warnings;
197            4                                 11      my $warning_count;
198            4                                 11      eval {
199            4                                  8         $warnings      = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
200            4                                 43         $warning_count = $dbh->selectall_arrayref('SELECT @@warning_count',
201                                                            { Slice => {} });
202                                                      };
203   ***      4     50                          32      if ( $EVAL_ERROR ) {
204   ***      0                                  0         MKDEBUG && _d('Error getting warnings:', $EVAL_ERROR);
205   ***      0                                  0         $error = $EVAL_ERROR;
206                                                      }
207                                                   
208            4           100                   46      my $results = {
209                                                         error => $error,
210                                                         codes => $warnings,
211                                                         count => $warning_count->[0]->{'@@warning_count'} || 0,
212                                                      };
213            4                                 33      return $name, $results;
214                                                   }
215                                                   
216                                                   sub clear_warnings {
217   ***      0                    0             0      my ( $self, %args ) = @_;
218   ***      0                                  0      foreach my $arg ( qw(dbh query QueryParser) ) {
219   ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
220                                                      }
221   ***      0                                  0      my $dbh     = $args{dbh};
222   ***      0                                  0      my $query   = $args{query};
223   ***      0                                  0      my $qparser = $args{QueryParser};
224   ***      0                                  0      my $error   = undef;
225   ***      0                                  0      my $name    = 'clear_warnings';
226   ***      0                                  0      MKDEBUG && _d($name);
227                                                   
228                                                      # On some systems, MySQL doesn't always clear the warnings list
229                                                      # after a good query.  This causes good queries to show warnings
230                                                      # from previous bad queries.  A work-around/hack is to
231                                                      # SELECT * FROM table LIMIT 0 which seems to always clear warnings.
232   ***      0                                  0      my @tables = $qparser->get_tables($query);
233   ***      0      0                           0      if ( @tables ) {
234   ***      0                                  0         MKDEBUG && _d('tables:', @tables);
235   ***      0                                  0         my $sql = "SELECT * FROM $tables[0] LIMIT 0";
236   ***      0                                  0         MKDEBUG && _d($sql);
237   ***      0                                  0         eval {
238   ***      0                                  0            $dbh->do($sql);
239                                                         };
240   ***      0      0                           0         if ( $EVAL_ERROR ) {
241   ***      0                                  0            MKDEBUG && _d('Error clearning warnings:', $EVAL_ERROR);
242   ***      0                                  0            $error = $EVAL_ERROR;
243                                                         }
244                                                      }
245                                                      else {
246   ***      0                                  0         $error = "Cannot clear warnings because the tables for this query cannot "
247                                                            . "be parsed.";
248                                                      }
249                                                   
250   ***      0                                  0      return $name, { error=>$error };
251                                                   }
252                                                   
253                                                   # This sub and checksum_results() require that you append
254                                                   # "CREATE TEMPORARY TABLE database.tmp_table AS" to the query before
255                                                   # calling exec().  This sub drops an old tmp table if it exists,
256                                                   # and sets the default storage engine to MyISAM.
257                                                   sub pre_checksum_results {
258            4                    4            91      my ( $self, %args ) = @_;
259            4                                 26      foreach my $arg ( qw(dbh database tmp_table Quoter) ) {
260   ***     16     50                          75         die "I need a $arg argument" unless $args{$arg};
261                                                      }
262            4                                 23      my $dbh     = $args{dbh};
263            4                                 15      my $db      = $args{database};
264            4                                 14      my $tmp_tbl = $args{tmp_table};
265            4                                 14      my $q       = $args{Quoter};
266            4                                 11      my $error   = undef;
267            4                                 12      my $name    = 'pre_checksum_results';
268            4                                 10      MKDEBUG && _d($name);
269                                                   
270            4                                 22      my $tmp_db_tbl = $q->quote($db, $tmp_tbl);
271            4                                 12      eval {
272            4                                938         $dbh->do("DROP TABLE IF EXISTS $tmp_db_tbl");
273            4                                378         $dbh->do("SET storage_engine=MyISAM");
274                                                      };
275   ***      4     50                          24      if ( $EVAL_ERROR ) {
276   ***      0                                  0         MKDEBUG && _d('Error dropping table', $tmp_db_tbl, ':', $EVAL_ERROR);
277   ***      0                                  0         $error = $EVAL_ERROR;
278                                                      }
279            4                                 48      return $name, { error=>$error };
280                                                   }
281                                                   
282                                                   # Either call pre_check_results() as a pre-exec callback to exec() or
283                                                   # do what it does manually before calling this sub as a post-exec callback.
284                                                   # This sub checksums the tmp table created when the query was executed
285                                                   # with "CREATE TEMPORARY TABLE database.tmp_table AS" alreay appended to it.
286                                                   # Since a lot can go wrong in this operation, the returned error will be the
287                                                   # last error and errors will have all errors.
288                                                   sub checksum_results {
289            4                    4           108      my ( $self, %args ) = @_;
290            4                                 27      foreach my $arg ( qw(dbh database tmp_table MySQLDump TableParser Quoter) ) {
291   ***     24     50                         107         die "I need a $arg argument" unless $args{$arg};
292                                                      }
293            4                                 16      my $dbh     = $args{dbh};
294            4                                 14      my $db      = $args{database};
295            4                                 13      my $tmp_tbl = $args{tmp_table};
296            4                                 16      my $du      = $args{MySQLDump};
297            4                                 12      my $tp      = $args{TableParser};
298            4                                 12      my $q       = $args{Quoter};
299            4                                 12      my $error   = undef;
300            4                                 16      my @errors  = ();
301            4                                 10      my $name    = 'checksum_results';
302            4                                 11      MKDEBUG && _d($name);
303                                                   
304            4                                 23      my $tmp_db_tbl = $q->quote($db, $tmp_tbl);
305            4                                 11      my $tbl_checksum;
306            4                                 10      my $n_rows;
307            4                                 11      my $tbl_struct;
308            4                                 12      eval {
309            4                                 10         $n_rows = $dbh->selectall_arrayref("SELECT COUNT(*) FROM $tmp_db_tbl")->[0]->[0];
310            4                                 11         $tbl_checksum = $dbh->selectall_arrayref("CHECKSUM TABLE $tmp_db_tbl")->[0]->[1];
311                                                      };
312   ***      4     50                         950      if ( $EVAL_ERROR ) {
313   ***      0                                  0         MKDEBUG && _d('Error counting rows or checksumming', $tmp_db_tbl, ':',
314                                                            $EVAL_ERROR);
315   ***      0                                  0         $error = $EVAL_ERROR;
316   ***      0                                  0         push @errors, $error;
317                                                      }
318                                                      else {
319                                                         # Parse the tmp table's struct.
320            4                                 15         eval {
321            4                                 39            my $ddl = $du->get_create_table($dbh, $q, $db, $tmp_tbl);
322            4                                 12            MKDEBUG && _d('tmp table ddl:', Dumper($ddl));
323   ***      4     50                          22            if ( $ddl->[0] eq 'table' ) {
324            4                                 87               $tbl_struct = $tp->parse($ddl)
325                                                            }
326                                                         };
327   ***      4     50                          23         if ( $EVAL_ERROR ) {
328   ***      0                                  0            MKDEBUG && _d('Failed to parse', $tmp_db_tbl, ':', $EVAL_ERROR); 
329   ***      0                                  0            $error = $EVAL_ERROR;
330   ***      0                                  0            push @errors, $error;
331                                                         }
332                                                      }
333                                                   
334                                                      # Event if CHECKSUM TABLE or parsing the tmp table fails, let's try
335                                                      # to drop the tmp table so we don't waste space.
336            4                                 20      my $sql = "DROP TABLE IF EXISTS $tmp_db_tbl";
337            4                                  8      MKDEBUG && _d($sql);
338            4                                 11      eval { $dbh->do($sql); };
               4                               1709   
339   ***      4     50                          28      if ( $EVAL_ERROR ) {
340   ***      0                                  0         MKDEBUG && _d('Error dropping tmp table:', $EVAL_ERROR);
341   ***      0                                  0         $error = $EVAL_ERROR;
342   ***      0                                  0         push @errors, $error;
343                                                      }
344                                                   
345                                                      # These errors are more important so save them till the end in case
346                                                      # someone only looks at the last error and not all errors.
347   ***      4     50                          28      if ( !defined $n_rows ) { # 0 rows returned is ok.
348   ***      0                                  0         $error = "SELECT COUNT(*) for getting the number of rows didn't return a value";
349   ***      0                                  0         push @errors, $error;
350   ***      0                                  0         MKDEBUG && _d($error);
351                                                      }
352   ***      4     50                          18      if ( !$tbl_checksum ) {
353   ***      0                                  0         $error = "CHECKSUM TABLE didn't return a value";
354   ***      0                                  0         push @errors, $error;
355   ***      0                                  0         MKDEBUG && _d($error);
356                                                      }
357                                                   
358                                                      # Avoid redundant error reporting.
359   ***      4     50                          24      @errors = () if @errors == 1;
360                                                   
361   ***      4            50                   51      my $results = {
      ***                   50                        
362                                                         error        => $error,
363                                                         errors       => \@errors,
364                                                         checksum     => $tbl_checksum || 0,
365                                                         n_rows       => $n_rows || 0,
366                                                         table_struct => $tbl_struct,
367                                                      };
368            4                                 61      return $name, $results;
369                                                   }
370                                                   
371                                                   
372                                                   # get_row_sths() implements part of an idea discussed by Mark Callaghan,
373                                                   # Baron Schwartz and Daniel Nichter.  See:
374                                                   # http://groups.google.com/group/maatkit-discuss/browse_thread/thread/5d0f208f4e76ec0f 
375                                                   # http://groups.google.com/group/maatkit-discuss/browse_thread/thread/49f4564111c78a2f
376                                                   
377                                                   # The big picture is to execute the query, simultaneously write its rows to
378                                                   # an outfile and compare them with MockSyncStream.  If no differences are
379                                                   # found, all is well.  If a difference is found, we stop comparing, write all
380                                                   # rows to an outfile and later mk_upgrade::diff_rows() will handle the rest.
381                                                   # For now, however, we just get a statement handle for the executed query
382                                                   # because QueryExecutor does hosts one-by-one but we need two sths at once.
383                                                   # See mk_upgrade::rank_row_sths() for how these sths are ranked/compared.
384                                                   sub get_row_sths {
385            2                    2            25      my ( $self, %args ) = @_;
386            2                                 11      foreach my $arg ( qw(query dbh) ) {
387   ***      4     50                          20         die "I need a $arg argument" unless $args{$arg};
388                                                      }
389            2                                  8      my $query      = $args{query};
390            2                                  7      my $dbh        = $args{dbh};
391            2                                  5      my $error      = undef;
392            2                                  6      my $name       = 'get_row_sths';
393            2                                  9      my $Query_time = { error => undef, Query_time => -1, };
394            2                                  6      my ( $start, $end, $query_time );
395            2                                  3      MKDEBUG && _d($name);
396                                                   
397            2                                  6      my $sth;
398            2                                  5      eval {
399            2                                  4         $sth = $dbh->prepare($query);
400                                                      };
401   ***      2     50                          12      if ( $EVAL_ERROR ) {
402   ***      0                                  0         MKDEBUG && _d('Error on prepare:', $EVAL_ERROR);
403   ***      0                                  0         $error = $EVAL_ERROR;
404                                                      }
405                                                      else {
406            2                                  6         eval {
407            2                                 12            $start = time();
408            2                                419            $sth->execute();
409            2                                 13            $end   = time();
410            2                                 27            $query_time = sprintf '%.6f', $end - $start;
411                                                         };
412   ***      2     50                           9         if ( $EVAL_ERROR ) {
413   ***      0                                  0            MKDEBUG && _d('Error on execute:', $EVAL_ERROR);
414   ***      0                                  0            $error = $EVAL_ERROR;
415   ***      0                                  0            $Query_time->{error} = $error;
416                                                         }
417                                                         else {
418            2                                  9            $Query_time->{Query_time} = $query_time;
419                                                         }
420                                                      }
421                                                   
422   ***      2     50                          15      my $results = {
423                                                         error      => $error,
424                                                         sth        => $error ? undef : $sth,  # Only pass sth if no errors.
425                                                         Query_time => $Query_time,
426                                                      };
427            2                                 16      return $name, $results;
428                                                   }
429                                                   
430                                                   sub _check_results {
431           44                   44           222      my ( $name, $res, $host_name, $all_res ) = @_;
432           44    100                         184      __die('Operation did not return a name!', @_)
433                                                         unless $name;
434           43    100    100                  217      __die('Operation did not return any results!', @_)
435                                                         unless $res || (scalar keys %$res);
436           42    100                         207      __die("Operation results do no have an 'error' key")
437                                                         unless exists $res->{error};
438           41    100    100                  275      __die("Operation error is blank string!")
439                                                         if defined $res->{error} && !$res->{error};
440           40    100    100                  251      __die("Operation errors is not an arrayref!")
441                                                         if $res->{errors} && ref $res->{errors} ne 'ARRAY';
442           39                                104      return;
443                                                   }
444                                                   
445                                                   # Die and print helpful info about what was going on
446                                                   # at the time of our death.
447                                                   sub __die {
448            5                    5            28      my ( $msg, $name, $res, $host_name, $all_res ) = @_;
449            5    100                          48      die "$msg\n"
450                                                         . "Host name: " . ($host_name ? $host_name : 'UNKNOWN') . "\n"
451                                                         . "Current results: " . Dumper($res)
452                                                         . "Prior results: "   . Dumper($all_res)
453                                                   }
454                                                   
455                                                   sub _d {
456            1                    1            30      my ($package, undef, $line) = caller 0;
457   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 12   
458            1                                  6           map { defined $_ ? $_ : 'undef' }
459                                                           @_;
460            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
461                                                   }
462                                                   
463                                                   1;
464                                                   
465                                                   # ###########################################################################
466                                                   # End QueryExecutor package
467                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
37    ***      0      0      0   unless $args{$arg}
88    ***     50      0     27   unless $args{$arg}
106   ***     50      0     18   $dp && $dsn ? :
121   ***     50      0     38   if ($EVAL_ERROR)
143   ***     50      0     32   unless $args{$arg}
159          100      2     14   if ($EVAL_ERROR) { }
189   ***     50      0      4   unless $args{$arg}
203   ***     50      0      4   if ($EVAL_ERROR)
219   ***      0      0      0   unless $args{$arg}
233   ***      0      0      0   if (@tables) { }
240   ***      0      0      0   if ($EVAL_ERROR)
260   ***     50      0     16   unless $args{$arg}
275   ***     50      0      4   if ($EVAL_ERROR)
291   ***     50      0     24   unless $args{$arg}
312   ***     50      0      4   if ($EVAL_ERROR) { }
323   ***     50      4      0   if ($$ddl[0] eq 'table')
327   ***     50      0      4   if ($EVAL_ERROR)
339   ***     50      0      4   if ($EVAL_ERROR)
347   ***     50      0      4   if (not defined $n_rows)
352   ***     50      0      4   if (not $tbl_checksum)
359   ***     50      0      4   if @errors == 1
387   ***     50      0      4   unless $args{$arg}
401   ***     50      0      2   if ($EVAL_ERROR) { }
412   ***     50      0      2   if ($EVAL_ERROR) { }
422   ***     50      0      2   $error ? :
432          100      1     43   unless $name
434          100      1     42   unless $res or scalar keys %$res
436          100      1     41   unless exists $$res{'error'}
438          100      1     40   if defined $$res{'error'} and not $$res{'error'}
440          100      1     39   if $$res{'errors'} and ref $$res{'errors'} ne 'ARRAY'
449          100      2      3   $host_name ? :
457   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
106   ***     33     18      0      0   $dp && $dsn
438          100     36      4      1   defined $$res{'error'} and not $$res{'error'}
440          100     34      5      1   $$res{'errors'} and ref $$res{'errors'} ne 'ARRAY'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
208          100      2      2   $$warning_count[0]{'@@warning_count'} || 0
361   ***     50      4      0   $tbl_checksum || 0
      ***     50      4      0   $n_rows || 0
434          100     42      1   $res or scalar keys %$res


Covered Subroutines
-------------------

Subroutine           Count Location                                            
-------------------- ----- ----------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:22 
BEGIN                    1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:23 
BEGIN                    1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:25 
BEGIN                    1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:26 
BEGIN                    1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:27 
BEGIN                    1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:32 
Query_time              16 /home/daniel/dev/maatkit/common/QueryExecutor.pm:141
__die                    5 /home/daniel/dev/maatkit/common/QueryExecutor.pm:448
_check_results          44 /home/daniel/dev/maatkit/common/QueryExecutor.pm:431
_d                       1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:456
checksum_results         4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:289
exec                     9 /home/daniel/dev/maatkit/common/QueryExecutor.pm:86 
get_row_sths             2 /home/daniel/dev/maatkit/common/QueryExecutor.pm:385
get_warnings             4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:187
new                      1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:35 
pre_checksum_results     4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:258

Uncovered Subroutines
---------------------

Subroutine           Count Location                                            
-------------------- ----- ----------------------------------------------------
clear_warnings           0 /home/daniel/dev/maatkit/common/QueryExecutor.pm:217


