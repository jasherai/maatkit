---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryExecutor.pm   78.8   45.5    n/a   92.9    n/a  100.0   72.9
Total                          78.8   45.5    n/a   92.9    n/a  100.0   72.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryExecutor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:08 2009
Finish:       Fri Jul 31 18:53:08 2009

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
18                                                    # QueryExecutor package $Revision: 4219 $
19                                                    # ###########################################################################
20                                                    package QueryExecutor;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1            11   use Time::HiRes qw(time);
               1                                  3   
               1                                  5   
27             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32             1                    1             5   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 23   
33                                                    
34                                                    sub new {
35             1                    1           342      my ( $class, %args ) = @_;
36             1                                 13      foreach my $arg ( qw() ) {
37    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
38                                                       }
39             1                                  6      my $self = {};
40             1                                 34      return bless $self, $class;
41                                                    }
42                                                    
43                                                    # Executes a query on the given host dbhs, calling pre- and post-execution
44                                                    # callbacks for each host.  Returns an array of hashrefs, one for each host,
45                                                    # with results from whatever the callbacks return.  Each callback usually
46                                                    # returns a name (of what its results are called) and hashref with values
47                                                    # for its results.  Or, a callback my return nothing in which case it's
48                                                    # ignored (to allow setting MySQL vars, etc.)
49                                                    #
50                                                    # All callbacks are passed the query and the current host's dbh.  Post-exec
51                                                    # callbacks get an extra args: Query_time which is the query's execution time
52                                                    # rounded to six places (microsecond precision).
53                                                    #
54                                                    # Some common callbacks are provided in this package: get_Query_time(),
55                                                    # get_warnings(), clear_warnings(), checksum_results().
56                                                    #
57                                                    # If the query cannot be executed on a host, an error string is returned
58                                                    # for that host instead of a hashref of results.
59                                                    #
60                                                    # Required arguments:
61                                                    #   * query                The query to execute
62                                                    #   * pre_exec_callbacks   Arrayref of pre-exec query callback subs
63                                                    #   * post_exec_callbacks  Arrayref of post-exec query callback subs
64                                                    #   * dbhs                 Arrayref of host dbhs
65                                                    #
66                                                    sub exec {
67             7                    7          1045      my ( $self, %args ) = @_;
68             7                                 34      foreach my $arg ( qw(query dbhs pre_exec_callbacks post_exec_callbacks) ) {
69    ***     28     50                         127         die "I need a $arg argument" unless $args{$arg};
70                                                       }
71             7                                 26      my $query = $args{query};
72             7                                 22      my $dbhs  = $args{dbhs};
73             7                                 21      my $pre   = $args{pre_exec_callbacks};
74             7                                 21      my $post  = $args{post_exec_callbacks};
75                                                    
76             7                                 19      MKDEBUG && _d('exec:', $query);
77                                                    
78             7                                 19      my @results;
79             7                                 20      my $hostno = -1;
80                                                       HOST:
81             7                                 24      foreach my $dbh ( @$dbhs ) {
82            14                                 35         $hostno++;  # Increment this now because we might not reach loop's end.
83            14                                 52         $results[$hostno] = {};
84            14                                 44         my $results = $results[$hostno];
85                                                    
86                                                          # Call pre-exec callbacks.
87            14                                 49         foreach my $callback ( @$pre ) {
88             8                                 24            my ($name, $res);
89             8                                 20            eval {
90             8                                 45               ($name, $res) = $callback->(
91                                                                   query => $query,
92                                                                   dbh   => $dbh
93                                                                );
94                                                             };
95    ***      8     50                         395            if ( $EVAL_ERROR ) {
96    ***      0                                  0               MKDEBUG && _d('Error during pre-exec callback:', $EVAL_ERROR);
97    ***      0                                  0               $results = $EVAL_ERROR;
98    ***      0                                  0               next HOST;
99                                                             }
100   ***      8     50                          43            $results->{$name} = $res if $name;
101                                                         }
102                                                   
103                                                         # Execute the query on this host. 
104           14                                 43         my ( $start, $end, $query_time );
105           14                                 37         eval {
106           14                                 91            $start = time();
107           14                              67385            $dbh->do($query);
108           14                                154            $end   = time();
109           14                                255            $query_time = sprintf '%.6f', $end - $start;
110                                                         };
111   ***     14     50                          65         if ( $EVAL_ERROR ) {
112   ***      0                                  0            MKDEBUG && _d('Error executing query on host', $hostno, ':',
113                                                               $EVAL_ERROR);
114   ***      0                                  0            $results = $EVAL_ERROR;
115   ***      0                                  0            next HOST;
116                                                         }
117                                                   
118                                                         # Call post-exec callbacks.
119           14                                 67         foreach my $callback ( @$post ) {
120           16                                 51            my ($name, $res);
121           16                                 46            eval {
122           16                                 89               ($name, $res) = $callback->(
123                                                                  query      => $query,
124                                                                  dbh        => $dbh,
125                                                                  Query_time => $query_time,
126                                                               );
127                                                            };
128   ***     16     50                         447            if ( $EVAL_ERROR ) {
129   ***      0                                  0               MKDEBUG && _d('Error during post-exec callback:', $EVAL_ERROR);
130   ***      0                                  0               $results = $EVAL_ERROR;
131   ***      0                                  0               next HOST;
132                                                            }
133           16    100                         117            $results->{$name} = $res if $name;
134                                                         }
135                                                      } # HOST
136                                                   
137            7                                 20      MKDEBUG && _d('results:', Dumper(\@results));
138            7                                 80      return @results;
139                                                   }
140                                                   
141                                                   sub get_query_time {
142            4                    4            74      my ( $self, %args ) = @_;
143            4                                 21      foreach my $arg ( qw(Query_time) ) {
144   ***      4     50                          24         die "I need a $arg argument" unless $args{$arg};
145                                                      }
146            4                                 13      my $name = 'Query_time';
147            4                                  8      MKDEBUG && _d($name);
148            4                                 31      return $name, $args{Query_time};
149                                                   }
150                                                   
151                                                   # Returns an array with its name and a hashref with warnings/errors:
152                                                   # (
153                                                   #   warnings,
154                                                   #   {
155                                                   #     count => 3,         # @@warning_count,
156                                                   #     codes => {          # SHOW WARNINGS
157                                                   #       1062 => {
158                                                   #         Level   => "Error",
159                                                   #         Code    => "1062",
160                                                   #         Message => "Duplicate entry '1' for key 1",
161                                                   #       }
162                                                   #     },
163                                                   #   }
164                                                   # )
165                                                   sub get_warnings {
166            4                    4            50      my ( $self, %args ) = @_;
167            4                                 17      foreach my $arg ( qw(dbh) ) {
168   ***      4     50                          23         die "I need a $arg argument" unless $args{$arg};
169                                                      }
170            4                                 12      my $dbh = $args{dbh};
171                                                   
172            4                                 12      my $name = 'warnings';
173            4                                  9      MKDEBUG && _d($name);
174                                                   
175            4                                  9      my $warnings;
176            4                                 10      my $warning_count;
177            4                                 11      eval {
178            4                                  9         $warnings      = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
179            4                                 46         $warning_count = $dbh->selectall_arrayref('SELECT @@warning_count',
180                                                            { Slice => {} });
181                                                      };
182   ***      4     50                          33      if ( $EVAL_ERROR ) {
183   ***      0                                  0         MKDEBUG && _d('Error getting warnings:', $EVAL_ERROR);
184   ***      0                                  0         return $name, $EVAL_ERROR;
185                                                      }
186            4                                 29      my $results = {
187                                                         codes => $warnings,
188                                                         count => $warning_count->[0]->{'@@warning_count'},
189                                                      };
190                                                   
191            4                                 30      return $name, $results;
192                                                   }
193                                                   
194                                                   sub clear_warnings {
195   ***      0                    0             0      my ( $self, %args ) = @_;
196   ***      0                                  0      foreach my $arg ( qw(dbh query QueryParser) ) {
197   ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
198                                                      }
199   ***      0                                  0      my $dbh     = $args{dbh};
200   ***      0                                  0      my $query   = $args{query};
201   ***      0                                  0      my $qparser = $args{QueryParser};
202                                                   
203   ***      0                                  0      MKDEBUG && _d('clear_warnings');
204                                                   
205                                                      # On some systems, MySQL doesn't always clear the warnings list
206                                                      # after a good query.  This causes good queries to show warnings
207                                                      # from previous bad queries.  A work-around/hack is to
208                                                      # SELECT * FROM table LIMIT 0 which seems to always clear warnings.
209   ***      0                                  0      my @tables = $qparser->get_tables($query);
210   ***      0      0                           0      if ( @tables ) {
211   ***      0                                  0         MKDEBUG && _d('tables:', @tables);
212   ***      0                                  0         my $sql = "SELECT * FROM $tables[0] LIMIT 0";
213   ***      0                                  0         MKDEBUG && _d($sql);
214   ***      0                                  0         $dbh->do($sql);
215                                                      }
216                                                      else {
217   ***      0                                  0         warn "Cannot clear warnings because the tables for this query cannot "
218                                                            . "be parsed: $query";
219                                                      }
220   ***      0                                  0      return;
221                                                   }
222                                                   
223                                                   # This sub and checksum_results() require that you append
224                                                   # "CREATE TEMPORARY TABLE database.tmp_table AS" to the query before
225                                                   # calling exec().  This sub drops an old tmp table if it exists,
226                                                   # and sets the default storage engine to MyISAM.
227                                                   sub pre_checksum_results {
228            4                    4            84      my ( $self, %args ) = @_;
229            4                                 20      foreach my $arg ( qw(dbh tmp_table Quoter) ) {
230   ***     12     50                          56         die "I need a $arg argument" unless $args{$arg};
231                                                      }
232            4                                 14      my $dbh     = $args{dbh};
233            4                                 13      my $tmp_tbl = $args{tmp_table};
234            4                                 11      my $q       = $args{Quoter};
235                                                   
236            4                                 10      MKDEBUG && _d('pre_checksum_results');
237                                                   
238            4                                 10      eval {
239            4                                656         $dbh->do("DROP TABLE IF EXISTS $tmp_tbl");
240            4                                334         $dbh->do("SET storage_engine=MyISAM");
241                                                      };
242   ***      4     50                          22      die $EVAL_ERROR if $EVAL_ERROR;
243            4                                 29      return;
244                                                   }
245                                                   
246                                                   # Either call pre_check_results() as a pre-exec callback to exec() or
247                                                   # do what it does manually before calling this sub as a post-exec callback.
248                                                   # This sub checksums the tmp table created when the query was executed
249                                                   # with "CREATE TEMPORARY TABLE database.tmp_table AS" alreay appended to it.
250                                                   sub checksum_results {
251            4                    4           103      my ( $self, %args ) = @_;
252            4                                 25      foreach my $arg ( qw(dbh tmp_table MySQLDump TableParser Quoter) ) {
253   ***     20     50                          91         die "I need a $arg argument" unless $args{$arg};
254                                                      }
255            4                                 16      my $dbh     = $args{dbh};
256            4                                 12      my $tmp_tbl = $args{tmp_table};
257            4                                 13      my $du      = $args{MySQLDump};
258            4                                 14      my $tp      = $args{TableParser};
259            4                                 12      my $q       = $args{Quoter};
260                                                   
261            4                                 14      my $name = 'results';
262            4                                  9      MKDEBUG && _d($name);
263                                                   
264            4                                  9      my $n_rows;
265            4                                 10      my $tbl_checksum;
266            4                                 11      eval {
267            4                                 10         $n_rows = $dbh->selectall_arrayref("SELECT COUNT(*) FROM $tmp_tbl");
268            4                                 10         $tbl_checksum = $dbh->selectall_arrayref("CHECKSUM TABLE $tmp_tbl");
269                                                      };
270   ***      4     50                         486      if ( $EVAL_ERROR ) {
271   ***      0                                  0         MKDEBUG && _d('Error counting rows or checksumming', $tmp_tbl, ':',
272                                                            $EVAL_ERROR);
273   ***      0                                  0         return $name, $EVAL_ERROR;
274                                                      }
275                                                   
276                                                      # Get parse the tmp table's struct if we can.
277            4                                 11      my $tbl_struct;
278            4                                 17      my $db = $args{database};
279   ***      4     50                          16      if ( !$db ) {
280                                                         # No db given so check if tmp has db.
281   ***      0                                  0         ($db, undef) = $q->split_unquote($tmp_tbl);
282                                                      }
283   ***      4     50                          15      if ( $db ) {
284            4                                 30         my $ddl = $du->get_create_table($dbh, $q, $db, $tmp_tbl);
285   ***      4     50                          24         if ( $ddl->[0] eq 'table' ) {
286            4                                 12            eval {
287            4                                 24               $tbl_struct = $tp->parse($ddl)
288                                                            };
289   ***      4     50                          22            if ( $EVAL_ERROR ) {
290   ***      0                                  0               MKDEBUG && _d('Failed to parse', $tmp_tbl, ':', $EVAL_ERROR);
291   ***      0                                  0               return $name, $EVAL_ERROR;
292                                                            }
293                                                         }
294                                                      }
295                                                      else {
296   ***      0                                  0         MKDEBUG && _d('Cannot parse', $tmp_tbl, 'because no database');
297                                                      }
298                                                   
299            4                                 18      my $sql = "DROP TABLE IF EXISTS $tmp_tbl";
300            4                                 10      eval { $dbh->do($sql); };
               4                                945   
301   ***      4     50                          22      if ( $EVAL_ERROR ) {
302   ***      0                                  0         warn "Cannot $sql: $EVAL_ERROR";
303                                                      }
304                                                   
305            4                                 45      my $results = {
306                                                         checksum     => $tbl_checksum->[0]->[1],
307                                                         n_rows       => $n_rows->[0]->[0],
308                                                         table_struct => $tbl_struct,
309                                                      };
310                                                   
311            4                                 47      return $name, $results;
312                                                   }   
313                                                   
314                                                   sub _d {
315            1                    1            26      my ($package, undef, $line) = caller 0;
316   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 10   
               2                                 11   
317            1                                  5           map { defined $_ ? $_ : 'undef' }
318                                                           @_;
319            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
320                                                   }
321                                                   
322                                                   1;
323                                                   
324                                                   # ###########################################################################
325                                                   # End QueryExecutor package
326                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
37    ***      0      0      0   unless $args{$arg}
69    ***     50      0     28   unless $args{$arg}
95    ***     50      0      8   if ($EVAL_ERROR)
100   ***     50      0      8   if $name
111   ***     50      0     14   if ($EVAL_ERROR)
128   ***     50      0     16   if ($EVAL_ERROR)
133          100     12      4   if $name
144   ***     50      0      4   unless $args{$arg}
168   ***     50      0      4   unless $args{$arg}
182   ***     50      0      4   if ($EVAL_ERROR)
197   ***      0      0      0   unless $args{$arg}
210   ***      0      0      0   if (@tables) { }
230   ***     50      0     12   unless $args{$arg}
242   ***     50      0      4   if $EVAL_ERROR
253   ***     50      0     20   unless $args{$arg}
270   ***     50      0      4   if ($EVAL_ERROR)
279   ***     50      0      4   if (not $db)
283   ***     50      4      0   if ($db) { }
285   ***     50      4      0   if ($$ddl[0] eq 'table')
289   ***     50      0      4   if ($EVAL_ERROR)
301   ***     50      0      4   if ($EVAL_ERROR)
316   ***     50      2      0   defined $_ ? :


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
_d                       1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:315
checksum_results         4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:251
exec                     7 /home/daniel/dev/maatkit/common/QueryExecutor.pm:67 
get_query_time           4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:142
get_warnings             4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:166
new                      1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:35 
pre_checksum_results     4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:228

Uncovered Subroutines
---------------------

Subroutine           Count Location                                            
-------------------- ----- ----------------------------------------------------
clear_warnings           0 /home/daniel/dev/maatkit/common/QueryExecutor.pm:195


