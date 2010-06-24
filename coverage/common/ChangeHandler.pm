---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/ChangeHandler.pm   87.8   69.0   64.3   95.7    0.0    0.6   79.0
ChangeHandler.t                97.4   50.0   33.3   80.0    n/a   99.4   91.8
Total                          92.1   66.2   58.8   88.4    0.0  100.0   83.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:06 2010
Finish:       Thu Jun 24 19:32:06 2010

Run:          ChangeHandler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:08 2010
Finish:       Thu Jun 24 19:32:11 2010

/home/daniel/dev/maatkit/common/ChangeHandler.pm

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
18                                                    # ChangeHandler package $Revision: 6514 $
19                                                    # ###########################################################################
20                                                    package ChangeHandler;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1             9   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26                                                    my $DUPE_KEY  = qr/Duplicate entry/;
27                                                    our @ACTIONS  = qw(DELETE REPLACE INSERT UPDATE);
28                                                    
29    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  8   
               1                                 16   
30                                                    
31                                                    # Arguments:
32                                                    # * Quoter     Quoter object
33                                                    # * left_db    Left database (src by default)
34                                                    # * left_tbl   Left table (src by default)
35                                                    # * right_db   Right database (dst by default)
36                                                    # * right_tbl  Right table (dst by default)
37                                                    # * actions    arrayref of subroutines to call when handling a change.
38                                                    # * replace    Do UPDATE/INSERT as REPLACE.
39                                                    # * queue      Queue changes until process_rows is called with a greater
40                                                    #              queue level.
41                                                    # * tbl_struct (optional) Used to sort columns and detect binary columns
42                                                    # * hex_blob   (optional) HEX() BLOB columns (default yes)
43                                                    sub new {
44    ***     10                   10      0    225      my ( $class, %args ) = @_;
45            10                                 99      foreach my $arg ( qw(Quoter left_db left_tbl right_db right_tbl
46                                                                            replace queue) ) {
47            64    100                         452         die "I need a $arg argument" unless defined $args{$arg};
48                                                       }
49             9                                 45      my $q = $args{Quoter};
50                                                    
51             9                                147      my $self = {
52                                                          hex_blob     => 1,
53                                                          %args,
54                                                          left_db_tbl  => $q->quote(@args{qw(left_db left_tbl)}),
55                                                          right_db_tbl => $q->quote(@args{qw(right_db right_tbl)}),
56                                                       };
57                                                    
58                                                       # By default left is source and right is dest.  With bidirectional
59                                                       # syncing this can change.  See set_src().
60             9                                 73      $self->{src_db_tbl} = $self->{left_db_tbl};
61             9                                 57      $self->{dst_db_tbl} = $self->{right_db_tbl};
62                                                    
63                                                       # Init and zero changes for all actions.
64             9                                 52      map { $self->{$_} = [] } @ACTIONS;
              36                                239   
65             9                                 55      $self->{changes} = { map { $_ => 0 } @ACTIONS };
              36                                218   
66                                                    
67             9                                125      return bless $self, $class;
68                                                    }
69                                                    
70                                                    # If I'm supposed to fetch-back, that means I have to get the full row from the
71                                                    # database.  For example, someone might call me like so:
72                                                    # $me->change('UPDATE', { a => 1 })
73                                                    # but 'a' is only the primary key. I now need to select that row and make an
74                                                    # UPDATE statement with all of its columns.  The argument is the DB handle used
75                                                    # to fetch.
76                                                    sub fetch_back {
77    ***      3                    3      0     30      my ( $self, $dbh ) = @_;
78             3                                 23      $self->{fetch_back} = $dbh;
79             3                                 12      MKDEBUG && _d('Set fetch back dbh', $dbh);
80             3                                 19      return;
81                                                    }
82                                                    
83                                                    # For bidirectional syncing both tables are src and dst.  Internally,
84                                                    # we refer to the tables generically as the left and right.  Either
85                                                    # one can be src or dst, as set by this sub when called by the caller.
86                                                    # Other subs don't know to which table src or dst point.  They just
87                                                    # fetchback from src and change dst.  If the optional $dbh arg is
88                                                    # given, fetch_back() is set with it, too.
89                                                    sub set_src {
90    ***      1                    1      0      5      my ( $self, $src, $dbh ) = @_;
91    ***      1     50                           5      die "I need a src argument" unless $src;
92    ***      1     50                           8      if ( lc $src eq 'left' ) {
      ***            50                               
93    ***      0                                  0         $self->{src_db_tbl} = $self->{left_db_tbl};
94    ***      0                                  0         $self->{dst_db_tbl} = $self->{right_db_tbl};
95                                                       }
96                                                       elsif ( lc $src eq 'right' ) {
97             1                                  5         $self->{src_db_tbl} = $self->{right_db_tbl};
98             1                                  5         $self->{dst_db_tbl} = $self->{left_db_tbl}; 
99                                                       }
100                                                      else {
101   ***      0                                  0         die "src argument must be either 'left' or 'right'"
102                                                      }
103            1                                  2      MKDEBUG && _d('Set src to', $src);
104   ***      1     50                           9      $self->fetch_back($dbh) if $dbh;
105            1                                  3      return;
106                                                   }
107                                                   
108                                                   # Return current source db.tbl (could be left or right table).
109                                                   sub src {
110   ***      1                    1      0      5      my ( $self ) = @_;
111            1                                  8      return $self->{src_db_tbl};
112                                                   }
113                                                   
114                                                   # Return current destination db.tbl (could be left or right table).
115                                                   sub dst {
116   ***      1                    1      0      4      my ( $self ) = @_;
117            1                                  8      return $self->{dst_db_tbl};
118                                                   }
119                                                   
120                                                   # Arguments:
121                                                   #   * sql   scalar: a SQL statement
122                                                   #   * dbh   obj: (optional) dbh
123                                                   # This sub calls the user-provided actions, passing them an
124                                                   # action statement and an option dbh.  This sub is not called
125                                                   # directly, it's called by change() or process_rows().
126                                                   sub _take_action {
127           13                   13           232      my ( $self, $sql, $dbh ) = @_;
128           13                                 41      MKDEBUG && _d('Calling subroutines on', $dbh, $sql);
129           13                                 39      foreach my $action ( @{$self->{actions}} ) {
              13                                 83   
130           13                                 79         $action->($sql, $dbh);
131                                                      }
132           13                                 74      return;
133                                                   }
134                                                   
135                                                   # Arguments:
136                                                   #   * action   scalar: string, one of @ACTIONS
137                                                   #   * row      hashref: row data
138                                                   #   * cols     arrayref: column names
139                                                   #   * dbh      obj: (optional) dbh, passed to _take_action()
140                                                   # If not queueing, this sub makes an action SQL statment for the given
141                                                   # action, row and columns.  It calls _take_action(), passing the action
142                                                   # statement and the optional dbh.  If queueing, the args are saved and
143                                                   # the same work is done in process_rows().  Queueing does not work with
144                                                   # bidirectional syncs.
145                                                   sub change {
146   ***     14                   14      0    112      my ( $self, $action, $row, $cols, $dbh ) = @_;
147           14                                 54      MKDEBUG && _d($dbh, $action, 'where', $self->make_where_clause($row, $cols));
148                                                   
149                                                      # Undef action means don't do anything.  This allows deeply
150                                                      # nested callers to avoid/skip a change without dying.
151           14    100                          75      return unless $action;
152                                                   
153                                                      $self->{changes}->{
154   ***     13     50     33                  114         $self->{replace} && $action ne 'DELETE' ? 'REPLACE' : $action
155                                                      }++;
156           13    100                          70      if ( $self->{queue} ) {
157            4                                 24         $self->__queue($action, $row, $cols, $dbh);
158                                                      }
159                                                      else {
160            9                                 40         eval {
161            9                                 44            my $func = "make_$action";
162            9                                 91            $self->_take_action($self->$func($row, $cols), $dbh);
163                                                         };
164   ***      9     50                         111         if ( $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
      ***            50                               
165   ***      0                                  0            MKDEBUG && _d('Duplicate key violation; will queue and rewrite');
166   ***      0                                  0            $self->{queue}++;
167   ***      0                                  0            $self->{replace} = 1;
168   ***      0                                  0            $self->__queue($action, $row, $cols, $dbh);
169                                                         }
170                                                         elsif ( $EVAL_ERROR ) {
171   ***      0                                  0            die $EVAL_ERROR;
172                                                         }
173                                                      }
174           13                                 52      return;
175                                                   }
176                                                   
177                                                   sub __queue {
178            4                    4            22      my ( $self, $action, $row, $cols, $dbh ) = @_;
179            4                                 13      MKDEBUG && _d('Queueing change for later');
180   ***      4     50                          26      if ( $self->{replace} ) {
181   ***      0      0                           0         $action = $action eq 'DELETE' ? $action : 'REPLACE';
182                                                      }
183            4                                 10      push @{$self->{$action}}, [ $row, $cols, $dbh ];
               4                                 27   
184                                                   }
185                                                   
186                                                   # If called with 1, will process rows that have been deferred from instant
187                                                   # processing.  If no arg, will process all rows.  $trace_msg is an optional
188                                                   # string to append to each SQL statement for tracing them in binary logs.
189                                                   sub process_rows {
190   ***      6                    6      0     29      my ( $self, $queue_level, $trace_msg ) = @_;
191            6                                 21      my $error_count = 0;
192                                                      TRY: {
193            6    100    100                   16         if ( $queue_level && $queue_level < $self->{queue} ) { # see redo below!
               6                                 69   
194            1                                  2            MKDEBUG && _d('Not processing now', $queue_level, '<', $self->{queue});
195            1                                  4            return;
196                                                         }
197            5                                 11         MKDEBUG && _d('Processing rows:');
198            5                                 18         my ($row, $cur_act);
199            5                                 13         eval {
200            5                                 30            foreach my $action ( @ACTIONS ) {
201           20                                 73               my $func = "make_$action";
202           20                                 68               my $rows = $self->{$action};
203           20                                 48               MKDEBUG && _d(scalar(@$rows), 'to', $action);
204           20                                 56               $cur_act = $action;
205           20                                102               while ( @$rows ) {
206                                                                  # Each row is an arrayref like:
207                                                                  # [
208                                                                  #   { col1 => val1, colN => ... },
209                                                                  #   [ col1, colN, ... ],
210                                                                  #   dbh,  # optional
211                                                                  # ]
212            4                                 17                  $row    = shift @$rows;
213            4                                 23                  my $sql = $self->$func(@$row);
214            4    100                          81                  $sql   .= " /*maatkit $trace_msg*/" if $trace_msg;
215            4                                 23                  $self->_take_action($sql, $row->[2]);
216                                                               }
217                                                            }
218            5                                 18            $error_count = 0;
219                                                         };
220   ***      5     50     33                   90         if ( !$error_count++ && $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
      ***            50                               
221   ***      0                                  0            MKDEBUG && _d('Duplicate key violation; re-queueing and rewriting');
222   ***      0                                  0            $self->{queue}++; # Defer rows to the very end
223   ***      0                                  0            $self->{replace} = 1;
224   ***      0                                  0            $self->__queue($cur_act, @$row);
225   ***      0                                  0            redo TRY;
226                                                         }
227                                                         elsif ( $EVAL_ERROR ) {
228   ***      0                                  0            die $EVAL_ERROR;
229                                                         }
230                                                      }
231                                                   }
232                                                   
233                                                   # DELETE never needs to be fetched back.
234                                                   sub make_DELETE {
235   ***      4                    4      0     25      my ( $self, $row, $cols ) = @_;
236            4                                 13      MKDEBUG && _d('Make DELETE');
237            4                                 35      return "DELETE FROM $self->{dst_db_tbl} WHERE "
238                                                         . $self->make_where_clause($row, $cols)
239                                                         . ' LIMIT 1';
240                                                   }
241                                                   
242                                                   sub make_UPDATE {
243   ***      6                    6      0     53      my ( $self, $row, $cols ) = @_;
244            6                                 24      MKDEBUG && _d('Make UPDATE');
245   ***      6     50                          45      if ( $self->{replace} ) {
246   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
247                                                      }
248            6                                 35      my %in_where = map { $_ => 1 } @$cols;
               9                                 91   
249            6                                 65      my $where = $self->make_where_clause($row, $cols);
250            6                                 34      my @cols;
251            6    100                          54      if ( my $dbh = $self->{fetch_back} ) {
252            3                                 35         my $sql = $self->make_fetch_back_query($where);
253            3                                 11         MKDEBUG && _d('Fetching data on dbh', $dbh, 'for UPDATE:', $sql);
254            3                                 17         my $res = $dbh->selectrow_hashref($sql);
255            3                                 48         @{$row}{keys %$res} = values %$res;
               3                                 34   
256            3                                 36         @cols = $self->sort_cols($res);
257                                                      }
258                                                      else {
259            3                                 21         @cols = $self->sort_cols($row);
260                                                      }
261            7                                 60      return "UPDATE $self->{dst_db_tbl} SET "
262                                                         . join(', ', map {
263           16                                 97               $self->{Quoter}->quote($_)
264                                                               . '=' .  $self->{Quoter}->quote_val($row->{$_})
265            6                                 63            } grep { !$in_where{$_} } @cols)
266                                                         . " WHERE $where LIMIT 1";
267                                                   }
268                                                   
269                                                   sub make_INSERT {
270   ***     10                   10      0     62      my ( $self, $row, $cols ) = @_;
271           10                                 35      MKDEBUG && _d('Make INSERT');
272   ***     10     50                          73      if ( $self->{replace} ) {
273   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
274                                                      }
275           10                                 76      return $self->make_row('INSERT', $row, $cols);
276                                                   }
277                                                   
278                                                   sub make_REPLACE {
279   ***      3                    3      0     23      my ( $self, $row, $cols ) = @_;
280            3                                 13      MKDEBUG && _d('Make REPLACE');
281            3                                 22      return $self->make_row('REPLACE', $row, $cols);
282                                                   }
283                                                   
284                                                   sub make_row {
285   ***     13                   13      0     88      my ( $self, $verb, $row, $cols ) = @_;
286           13                                 51      my @cols; 
287           13    100                          91      if ( my $dbh = $self->{fetch_back} ) {
288            4                                 30         my $where = $self->make_where_clause($row, $cols);
289            4                                 31         my $sql   = $self->make_fetch_back_query($where);
290            4                                 14         MKDEBUG && _d('Fetching data on dbh', $dbh, 'for', $verb, ':', $sql);
291            4                                 16         my $res = $dbh->selectrow_hashref($sql);
292            4                                 66         @{$row}{keys %$res} = values %$res;
               4                                 39   
293            4                                 36         @cols = $self->sort_cols($res);
294                                                      }
295                                                      else {
296            9                                 50         @cols = $self->sort_cols($row);
297                                                      }
298           13                                 75      my $q = $self->{Quoter};
299           34                               1050      return "$verb INTO $self->{dst_db_tbl}("
300           34                                897         . join(', ', map { $q->quote($_) } @cols)
301                                                         . ') VALUES ('
302           13                                123         . join(', ', map { $q->quote_val($_) } @{$row}{@cols} )
              13                                558   
303                                                         . ')';
304                                                   }
305                                                   
306                                                   sub make_where_clause {
307   ***     14                   14      0     99      my ( $self, $row, $cols ) = @_;
308           21                                115      my @clauses = map {
309           14                                 73         my $val = $row->{$_};
310   ***     21     50                         131         my $sep = defined $val ? '=' : ' IS ';
311           21                                179         $self->{Quoter}->quote($_) . $sep . $self->{Quoter}->quote_val($val);
312                                                      } @$cols;
313           14                                128      return join(' AND ', @clauses);
314                                                   }
315                                                   
316                                                   sub get_changes {
317   ***      1                    1      0      4      my ( $self ) = @_;
318            1                                  2      return %{$self->{changes}};
               1                                 13   
319                                                   }
320                                                   
321                                                   sub sort_cols {
322   ***     19                   19      0    150      my ( $self, $row ) = @_;
323           19                                 72      my @cols;
324           19    100                         118      if ( $self->{tbl_struct} ) { 
325           11                                 77         my $pos = $self->{tbl_struct}->{col_posn};
326           11                                 39         my @not_in_tbl;
327           20                                114         @cols = sort {
328                                                               $pos->{$a} <=> $pos->{$b}
329                                                            }
330                                                            grep {
331           11    100                          86               if ( !defined $pos->{$_} ) {
              34                                224   
332            3                                 18                  push @not_in_tbl, $_;
333            3                                  8                  0;
334                                                               }
335                                                               else {
336           31                                126                  1;
337                                                               }
338                                                            }
339                                                            keys %$row;
340           11    100                         149         push @cols, @not_in_tbl if @not_in_tbl;
341                                                      }
342                                                      else {
343            8                                 91         @cols = sort keys %$row;
344                                                      }
345           19                                185      return @cols;
346                                                   }
347                                                   
348                                                   sub make_fetch_back_query {
349   ***     10                   10      0     82      my ( $self, $where ) = @_;
350   ***     10     50                          73      die "I need a where argument" unless $where;
351           10                                 45      my $cols       = '*';
352           10                                 58      my $tbl_struct = $self->{tbl_struct};
353           10    100                          73      if ( $tbl_struct ) {
354           11                                 53         $cols = join(', ',
355                                                            map {
356            8                                 58               my $col = $_;
357           11    100    100                  219               if (    $self->{hex_blob}
358                                                                    && $tbl_struct->{type_for}->{$col} =~ m/blob|text|binary/ ) {
359            4                                 34                  $col = "IF(`$col`='', '', CONCAT('0x', HEX(`$col`))) AS `$col`";
360                                                               }
361                                                               else {
362            7                                 41                  $col = "`$col`";
363                                                               }
364           11                                 70               $col;
365            8                                 42            } @{ $tbl_struct->{cols} }
366                                                         );
367                                                   
368            8    100                          59         if ( !$cols ) {
369                                                            # This shouldn't happen in the real world.
370            3                                  9            MKDEBUG && _d('Failed to make explicit columns list from tbl struct');
371            3                                 16            $cols = '*';
372                                                         }
373                                                      }
374           10                                143      return "SELECT $cols FROM $self->{src_db_tbl} WHERE $where LIMIT 1";
375                                                   }
376                                                   
377                                                   sub _d {
378   ***      0                    0                    my ($package, undef, $line) = caller 0;
379   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
380   ***      0                                              map { defined $_ ? $_ : 'undef' }
381                                                           @_;
382   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
383                                                   }
384                                                   
385                                                   1;
386                                                   
387                                                   # ###########################################################################
388                                                   # End ChangeHandler package
389                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
47           100      1     63   unless defined $args{$arg}
91    ***     50      0      1   unless $src
92    ***     50      0      1   if (lc $src eq 'left') { }
      ***     50      1      0   elsif (lc $src eq 'right') { }
104   ***     50      0      1   if $dbh
151          100      1     13   unless $action
154   ***     50      0     13   $$self{'replace'} && $action ne 'DELETE' ? :
156          100      4      9   if ($$self{'queue'}) { }
164   ***     50      0      9   if ($EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      9   elsif ($EVAL_ERROR) { }
180   ***     50      0      4   if ($$self{'replace'})
181   ***      0      0      0   $action eq 'DELETE' ? :
193          100      1      5   if ($queue_level and $queue_level < $$self{'queue'})
214          100      1      3   if $trace_msg
220   ***     50      0      5   if (not $error_count++ and $EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      5   elsif ($EVAL_ERROR) { }
245   ***     50      0      6   if ($$self{'replace'})
251          100      3      3   if (my $dbh = $$self{'fetch_back'}) { }
272   ***     50      0     10   if ($$self{'replace'})
287          100      4      9   if (my $dbh = $$self{'fetch_back'}) { }
310   ***     50     21      0   defined $val ? :
324          100     11      8   if ($$self{'tbl_struct'}) { }
331          100      3     31   if (not defined $$pos{$_}) { }
340          100      3      8   if @not_in_tbl
350   ***     50      0     10   unless $where
353          100      8      2   if ($tbl_struct)
357          100      4      7   if ($$self{'hex_blob'} and $$tbl_struct{'type_for'}{$col} =~ /blob|text|binary/) { }
368          100      3      5   if (not $cols)
379   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
154   ***     33     13      0      0   $$self{'replace'} && $action ne 'DELETE'
193          100      1      4      1   $queue_level and $queue_level < $$self{'queue'}
220   ***     33      0      5      0   not $error_count++ and $EVAL_ERROR =~ /$DUPE_KEY/
357          100      3      4      4   $$self{'hex_blob'} and $$tbl_struct{'type_for'}{$col} =~ /blob|text|binary/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
29    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine            Count Pod Location                                            
--------------------- ----- --- ----------------------------------------------------
BEGIN                     1     /home/daniel/dev/maatkit/common/ChangeHandler.pm:22 
BEGIN                     1     /home/daniel/dev/maatkit/common/ChangeHandler.pm:23 
BEGIN                     1     /home/daniel/dev/maatkit/common/ChangeHandler.pm:24 
BEGIN                     1     /home/daniel/dev/maatkit/common/ChangeHandler.pm:29 
__queue                   4     /home/daniel/dev/maatkit/common/ChangeHandler.pm:178
_take_action             13     /home/daniel/dev/maatkit/common/ChangeHandler.pm:127
change                   14   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:146
dst                       1   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:116
fetch_back                3   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:77 
get_changes               1   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:317
make_DELETE               4   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:235
make_INSERT              10   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:270
make_REPLACE              3   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:279
make_UPDATE               6   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:243
make_fetch_back_query    10   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:349
make_row                 13   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:285
make_where_clause        14   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:307
new                      10   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:44 
process_rows              6   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:190
set_src                   1   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:90 
sort_cols                19   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:322
src                       1   0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:110

Uncovered Subroutines
---------------------

Subroutine            Count Pod Location                                            
--------------------- ----- --- ----------------------------------------------------
_d                        0     /home/daniel/dev/maatkit/common/ChangeHandler.pm:378


ChangeHandler.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  5   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  4   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                 10   
12             1                    1            11   use Test::More tests => 32;
               1                                  4   
               1                                  9   
13                                                    
14             1                    1            12   use ChangeHandler;
               1                                  3   
               1                                 11   
15             1                    1            10   use Quoter;
               1                                  4   
               1                                 14   
16             1                    1            12   use DSNParser;
               1                                  4   
               1                                 12   
17             1                    1            14   use Sandbox;
               1                                  3   
               1                                 13   
18             1                    1            14   use MaatkitTest;
               1                                  5   
               1                                 39   
19                                                    
20             1                                 11   my $dp  = new DSNParser(opts => $dsn_opts);
21             1                                247   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
22             1                                 55   my $dbh = $sb->get_dbh_for('master');
23                                                    
24                                                    throws_ok(
25             1                    1            25      sub { new ChangeHandler() },
26             1                                406      qr/I need a Quoter/,
27                                                       'Needs a Quoter',
28                                                    );
29                                                    
30             1                                 15   my @rows;
31             1                                  3   my @dbhs;
32             1                                 11   my $q  = new Quoter();
33                                                    my $ch = new ChangeHandler(
34                                                       Quoter    => $q,
35                                                       right_db  => 'test',  # dst
36                                                       right_tbl => 'foo',
37                                                       left_db   => 'test',  # src
38                                                       left_tbl  => 'test1',
39             1                    5            32      actions   => [ sub { push @rows, $_[0]; push @dbhs, $_[1]; } ],
               5                                 18   
               5                                 21   
40                                                       replace   => 0,
41                                                       queue     => 0,
42                                                    );
43                                                    
44             1                                 10   $ch->change('INSERT', { a => 1, b => 2 }, [qw(a)] );
45                                                    
46             1                                 11   is_deeply(\@rows,
47                                                       ["INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2')",],
48                                                       'First row',
49                                                    );
50                                                    
51             1                                 13   $ch->change(undef, { a => 1, b => 2 }, [qw(a)] );
52                                                    
53             1                                  7   is_deeply(
54                                                       \@rows,
55                                                       ["INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2')",],
56                                                       'Skips undef action'
57                                                    );
58                                                    
59                                                    
60             1                                 11   is_deeply(\@rows,
61                                                       ["INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2')",],
62                                                       'First row',
63                                                    );
64                                                    
65             1                                  7   $ch->{queue} = 1;
66                                                    
67             1                                  8   $ch->change('DELETE', { a => 1, b => 2 }, [qw(a)] );
68                                                    
69             1                                  6   is_deeply(\@rows,
70                                                       ["INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2')",],
71                                                       'Second row not there yet',
72                                                    );
73                                                    
74             1                                 13   $ch->process_rows(1);
75                                                    
76             1                                  7   is_deeply(\@rows,
77                                                       [
78                                                       "INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2')",
79                                                       "DELETE FROM `test`.`foo` WHERE `a`='1' LIMIT 1",
80                                                       ],
81                                                       'Second row there',
82                                                    );
83             1                                  9   $ch->{queue} = 2;
84                                                    
85             1                                  8   $ch->change('UPDATE', { a => 1, b => 2 }, [qw(a)] );
86             1                                  4   $ch->process_rows(1);
87                                                    
88             1                                  6   is_deeply(\@rows,
89                                                       [
90                                                       "INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2')",
91                                                       "DELETE FROM `test`.`foo` WHERE `a`='1' LIMIT 1",
92                                                       ],
93                                                       'Third row not there',
94                                                    );
95                                                    
96             1                                  8   $ch->process_rows();
97                                                    
98             1                                  8   is_deeply(\@rows,
99                                                       [
100                                                      "INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2')",
101                                                      "DELETE FROM `test`.`foo` WHERE `a`='1' LIMIT 1",
102                                                      "UPDATE `test`.`foo` SET `b`='2' WHERE `a`='1' LIMIT 1",
103                                                      ],
104                                                      'All rows',
105                                                   );
106                                                   
107            1                                 10   is_deeply(
108                                                      { $ch->get_changes() },
109                                                      { REPLACE => 0, DELETE => 1, INSERT => 1, UPDATE => 1 },
110                                                      'Changes were recorded',
111                                                   );
112                                                   
113                                                   
114                                                   # #############################################################################
115                                                   # Test that the optional dbh is passed through to our actions.
116                                                   # #############################################################################
117            1                                  9   @rows = ();
118            1                                  3   @dbhs = ();
119            1                                  4   $ch->{queue} = 0;
120                                                   # 42 is a placeholder for the dbh arg.
121            1                                  9   $ch->change('INSERT', { a => 1, b => 2 }, [qw(a)], 42);
122                                                   
123            1                                  7   is_deeply(
124                                                      \@dbhs,
125                                                      [42],
126                                                      'dbh passed through change()'
127                                                   );
128                                                   
129            1                                  7   $ch->{queue} = 1;
130                                                   
131            1                                  4   @rows = ();
132            1                                  3   @dbhs = ();
133            1                                 30   $ch->change('INSERT', { a => 1, b => 2 }, [qw(a)], 42);
134                                                   
135            1                                  6   is_deeply(
136                                                      \@dbhs,
137                                                      [],
138                                                      'No dbh yet'
139                                                   );
140                                                   
141            1                                  9   $ch->process_rows(1);
142                                                   
143            1                                  6   is_deeply(
144                                                      \@dbhs,
145                                                      [42],
146                                                      'dbh passed through process_rows()'
147                                                   );
148                                                   
149                                                   
150                                                   # #############################################################################
151                                                   # Test switching direction (swap src/dst).
152                                                   # #############################################################################
153                                                   $ch = new ChangeHandler(
154                                                      Quoter    => $q,
155                                                      left_db   => 'test',
156                                                      left_tbl  => 'left_foo',
157                                                      right_db  => 'test',
158                                                      right_tbl => 'right_foo',
159            1                    2            18      actions   => [ sub { push @rows, $_[0]; push @dbhs, $_[1]; } ],
               2                                  7   
               2                                 10   
160                                                      replace   => 0,
161                                                      queue     => 0,
162                                                   );
163                                                   
164            1                                 14   @rows = ();
165            1                                  4   @dbhs = ();
166                                                   
167                                                   # Default is left=source.
168            1                                  6   $ch->set_src('right');
169            1                                 10   is(
170                                                      $ch->src,
171                                                      '`test`.`right_foo`',
172                                                      'Changed src',
173                                                   );
174            1                                  7   is(
175                                                      $ch->dst,
176                                                      '`test`.`left_foo`',
177                                                      'Changed dst'
178                                                   );
179                                                   
180            1                                 10   $ch->change('INSERT', { a => 1, b => 2 }, [qw(a)] );
181                                                   
182            1                                  9   is_deeply(
183                                                      \@rows,
184                                                      ["INSERT INTO `test`.`left_foo`(`a`, `b`) VALUES ('1', '2')",],
185                                                      'INSERT new dst',
186                                                   );
187                                                   
188            1                                 14   $ch->change('DELETE', { a => 1, b => 2 }, [qw(a)] );
189            1                                  7   $ch->process_rows(1);
190            1                                  7   is_deeply(\@rows,
191                                                      [
192                                                      "INSERT INTO `test`.`left_foo`(`a`, `b`) VALUES ('1', '2')",
193                                                      "DELETE FROM `test`.`left_foo` WHERE `a`='1' LIMIT 1",
194                                                      ],
195                                                      'DELETE new dst',
196                                                   );
197                                                   
198                                                   
199                                                   # #############################################################################
200                                                   # Test fetch_back().
201                                                   # #############################################################################
202   ***      1     50                           6   SKIP: {
203            1                                  7      skip 'Cannot connect to sandbox master', 1 unless $dbh;
204                                                   
205            1                                394      $dbh->do('CREATE DATABASE IF NOT EXISTS test');
206                                                   
207                                                      $ch = new ChangeHandler(
208                                                         Quoter    => $q,
209                                                         right_db  => 'test',  # dst
210                                                         right_tbl => 'foo',
211                                                         left_db   => 'test',  # src
212                                                         left_tbl  => 'test1',
213            1                    3           184         actions   => [ sub { push @rows, $_[0]; push @dbhs, $_[1]; } ],
               3                                 21   
               3                                 26   
214                                                         replace   => 0,
215                                                         queue     => 0,
216                                                      );
217                                                   
218            1                                 16      @rows = ();
219            1                                  4      $ch->{queue} = 0;
220            1                                  5      $ch->fetch_back($dbh);
221            1                             1148406      `/tmp/12345/use < $trunk/common/t/samples/before-TableSyncChunk.sql`;
222                                                      # This should cause it to fetch the row from test.test1 where a=1
223            1                                121      $ch->change('UPDATE', { a => 1, __foo => 'bar' }, [qw(a)] );
224            1                                 18      $ch->change('DELETE', { a => 1, __foo => 'bar' }, [qw(a)] );
225            1                                 15      $ch->change('INSERT', { a => 1, __foo => 'bar' }, [qw(a)] );
226            1                                 31      is_deeply(
227                                                         \@rows,
228                                                         [
229                                                            "UPDATE `test`.`foo` SET `b`='en' WHERE `a`='1' LIMIT 1",
230                                                            "DELETE FROM `test`.`foo` WHERE `a`='1' LIMIT 1",
231                                                            "INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', 'en')",
232                                                         ],
233                                                         'Fetch-back',
234                                                      );
235                                                   }
236                                                   
237                                                   # #############################################################################
238                                                   # Issue 371: Make mk-table-sync preserve column order in SQL
239                                                   # #############################################################################
240            1                                 27   my $row = {
241                                                      id  => 1,
242                                                      foo => 'foo',
243                                                      bar => 'bar',
244                                                   };
245            1                                 10   my $tbl_struct = {
246                                                      col_posn => { id=>0, foo=>1, bar=>2 },
247                                                   };
248                                                   $ch = new ChangeHandler(
249                                                      Quoter     => $q,
250                                                      right_db   => 'test',       # dst
251                                                      right_tbl  => 'issue_371',
252                                                      left_db    => 'test',       # src
253                                                      left_tbl   => 'issue_371',
254   ***      1                    0            37      actions    => [ sub { push @rows, @_ } ],
      ***      0                                  0   
255                                                      replace    => 0,
256                                                      queue      => 0,
257                                                      tbl_struct => $tbl_struct,
258                                                   );
259                                                   
260            1                                 29   @rows = ();
261            1                                  9   @dbhs = ();
262                                                   
263            1                                 13   is(
264                                                      $ch->make_INSERT($row, [qw(id foo bar)]),
265                                                      "INSERT INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES ('1', 'foo', 'bar')",
266                                                      'make_INSERT() preserves column order'
267                                                   );
268                                                   
269            1                                 21   is(
270                                                      $ch->make_REPLACE($row, [qw(id foo bar)]),
271                                                      "REPLACE INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES ('1', 'foo', 'bar')",
272                                                      'make_REPLACE() preserves column order'
273                                                   );
274                                                   
275            1                                 16   is(
276                                                      $ch->make_UPDATE($row, [qw(id foo)]),
277                                                      "UPDATE `test`.`issue_371` SET `bar`='bar' WHERE `id`='1' AND `foo`='foo' LIMIT 1",
278                                                      'make_UPDATE() preserves column order'
279                                                   );
280                                                   
281            1                                 16   is(
282                                                      $ch->make_DELETE($row, [qw(id foo bar)]),
283                                                      "DELETE FROM `test`.`issue_371` WHERE `id`='1' AND `foo`='foo' AND `bar`='bar' LIMIT 1",
284                                                      'make_DELETE() preserves column order'
285                                                   );
286                                                   
287                                                   # Test what happens if the row has a column that not in the tbl struct.
288            1                                 14   $row->{other_col} = 'zzz';
289                                                   
290            1                                 17   is(
291                                                      $ch->make_INSERT($row, [qw(id foo bar)]),
292                                                      "INSERT INTO `test`.`issue_371`(`id`, `foo`, `bar`, `other_col`) VALUES ('1', 'foo', 'bar', 'zzz')",
293                                                      'make_INSERT() preserves column order, with col not in tbl'
294                                                   );
295                                                   
296            1                                 17   is(
297                                                      $ch->make_REPLACE($row, [qw(id foo bar)]),
298                                                      "REPLACE INTO `test`.`issue_371`(`id`, `foo`, `bar`, `other_col`) VALUES ('1', 'foo', 'bar', 'zzz')",
299                                                      'make_REPLACE() preserves column order, with col not in tbl'
300                                                   );
301                                                   
302            1                                 24   is(
303                                                      $ch->make_UPDATE($row, [qw(id foo)]),
304                                                      "UPDATE `test`.`issue_371` SET `bar`='bar', `other_col`='zzz' WHERE `id`='1' AND `foo`='foo' LIMIT 1",
305                                                      'make_UPDATE() preserves column order, with col not in tbl'
306                                                   );
307                                                   
308            1                                 10   delete $row->{other_col};
309                                                   
310   ***      1     50                           9   SKIP: {
311            1                                  5      skip 'Cannot connect to sandbox master', 3 unless $dbh;
312                                                   
313            1                              49782      $dbh->do('DROP TABLE IF EXISTS test.issue_371');
314            1                             102524      $dbh->do('CREATE TABLE test.issue_371 (id INT, foo varchar(16), bar char)');
315            1                                523      $dbh->do('INSERT INTO test.issue_371 VALUES (1,"foo","a"),(2,"bar","b")');
316                                                   
317            1                                 24      $ch->fetch_back($dbh);
318                                                   
319            1                                 16      is(
320                                                         $ch->make_INSERT($row, [qw(id foo)]),
321                                                         "INSERT INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES ('1', 'foo', 'a')",
322                                                         'make_INSERT() preserves column order, with fetch-back'
323                                                      );
324                                                   
325            1                                 18      is(
326                                                         $ch->make_REPLACE($row, [qw(id foo)]),
327                                                         "REPLACE INTO `test`.`issue_371`(`id`, `foo`, `bar`) VALUES ('1', 'foo', 'a')",
328                                                         'make_REPLACE() preserves column order, with fetch-back'
329                                                      );
330                                                   
331            1                                 19      is(
332                                                         $ch->make_UPDATE($row, [qw(id foo)]),
333                                                         "UPDATE `test`.`issue_371` SET `bar`='a' WHERE `id`='1' AND `foo`='foo' LIMIT 1",
334                                                         'make_UPDATE() preserves column order, with fetch-back'
335                                                      );
336                                                   };
337                                                   
338                                                   # #############################################################################
339                                                   # Issue 641: Make mk-table-sync use hex for binary/blob data
340                                                   # #############################################################################
341            1                                 28   $tbl_struct = {
342                                                      cols     => [qw(a x b)],
343                                                      type_for => {a=>'int', x=>'blob', b=>'varchar'},
344                                                   };
345                                                   $ch = new ChangeHandler(
346                                                      Quoter     => $q,
347                                                      left_db    => 'test',
348                                                      left_tbl   => 'lt',
349                                                      right_db   => 'test',
350                                                      right_tbl  => 'rt',
351   ***      1                    0            27      actions    => [ sub {} ],
      ***      0                                  0   
352                                                      replace    => 0,
353                                                      queue      => 0,
354                                                      tbl_struct => $tbl_struct,
355                                                   );
356                                                   
357            1                                 25   is(
358                                                      $ch->make_fetch_back_query('1=1'),
359                                                      "SELECT `a`, IF(`x`='', '', CONCAT('0x', HEX(`x`))) AS `x`, `b` FROM `test`.`lt` WHERE 1=1 LIMIT 1",
360                                                      "Wraps BLOB column in CONCAT('0x', HEX(col)) AS col"
361                                                   );
362                                                   
363                                                   $ch = new ChangeHandler(
364                                                      Quoter     => $q,
365                                                      left_db    => 'test',
366                                                      left_tbl   => 'lt',
367                                                      right_db   => 'test',
368                                                      right_tbl  => 'rt',
369   ***      1                    0            32      actions    => [ sub {} ],
      ***      0                                  0   
370                                                      replace    => 0,
371                                                      queue      => 0,
372                                                      hex_blob   => 0,
373                                                      tbl_struct => $tbl_struct,
374                                                   );
375                                                   
376            1                                 21   is(
377                                                      $ch->make_fetch_back_query('1=1'),
378                                                      "SELECT `a`, `x`, `b` FROM `test`.`lt` WHERE 1=1 LIMIT 1",
379                                                      "Disable blob hexing"
380                                                   );
381                                                   
382                                                   # #############################################################################
383                                                   # Issue 1052: mk-table-sync inserts "0x" instead of "" for empty blob and text
384                                                   # column values
385                                                   # #############################################################################
386            1                                 19   $tbl_struct = {
387                                                      cols     => [qw(t)],
388                                                      type_for => {t=>'text'},
389                                                   };
390                                                   $ch = new ChangeHandler(
391                                                      Quoter     => $q,
392                                                      left_db    => 'test',
393                                                      left_tbl   => 't',
394                                                      right_db   => 'test',
395                                                      right_tbl  => 't',
396   ***      1                    0            27      actions    => [ sub {} ],
      ***      0                                  0   
397                                                      replace    => 0,
398                                                      queue      => 0,
399                                                      tbl_struct => $tbl_struct,
400                                                   );
401                                                   
402            1                                 23   is(
403                                                      $ch->make_fetch_back_query('1=1'),
404                                                      "SELECT IF(`t`='', '', CONCAT('0x', HEX(`t`))) AS `t` FROM `test`.`t` WHERE 1=1 LIMIT 1",
405                                                      "Don't prepend 0x to blank blob/text column value (issue 1052)"
406                                                   );
407                                                   
408                                                   # #############################################################################
409                                                   
410   ***      1     50                           9   SKIP: {
411            1                                  6      skip 'Cannot connect to sandbox master', 1 unless $dbh;
412            1                                 25      $sb->load_file('master', "common/t/samples/issue_641.sql");
413                                                   
414            1                             587948      @rows = ();
415            1                                 68      $tbl_struct = {
416                                                         cols     => [qw(id b)],
417                                                         col_posn => {id=>0, b=>1},
418                                                         type_for => {id=>'int', b=>'blob'},
419                                                      };
420                                                      $ch = new ChangeHandler(
421                                                         Quoter     => $q,
422                                                         left_db    => 'issue_641',
423                                                         left_tbl   => 'lt',
424                                                         right_db   => 'issue_641',
425                                                         right_tbl  => 'rt',
426            1                    2            70         actions   => [ sub { push @rows, $_[0]; } ],
               2                                 25   
427                                                         replace    => 0,
428                                                         queue      => 0,
429                                                         tbl_struct => $tbl_struct,
430                                                      );
431            1                                 40      $ch->fetch_back($dbh);
432                                                   
433            1                                 20      $ch->change('UPDATE', {id=>1}, [qw(id)] );
434            1                                 18      $ch->change('INSERT', {id=>1}, [qw(id)] );
435                                                   
436            1                                 30      is_deeply(
437                                                         \@rows,
438                                                         [
439                                                            "UPDATE `issue_641`.`rt` SET `b`=0x089504E470D0A1A0A0000000D4948445200000079000000750802000000E55AD965000000097048597300000EC300000EC301C76FA8640000200049444154789C4CBB7794246779FFBBF78F7B7EBE466177677772CE3D9D667AA67BA62776CE39545557CE3974EE9EB049AB9556392210414258083 WHERE `id`='1' LIMIT 1",
440                                                            "INSERT INTO `issue_641`.`rt`(`id`, `b`) VALUES ('1', 0x089504E470D0A1A0A0000000D4948445200000079000000750802000000E55AD965000000097048597300000EC300000EC301C76FA8640000200049444154789C4CBB7794246779FFBBF78F7B7EBE466177677772CE3D9D667AA67BA62776CE39545557CE3974EE9EB049AB9556392210414258083)",
441                                                         ],
442                                                         "UPDATE and INSERT binary data as hex"
443                                                      );
444                                                   }
445                                                   
446                                                   # #############################################################################
447                                                   # Issue 387: More useful comments in mk-table-sync statements
448                                                   # #############################################################################
449            1                                 15   @rows = ();
450                                                   $ch = new ChangeHandler(
451                                                      Quoter    => $q,
452                                                      right_db  => 'test',  # dst
453                                                      right_tbl => 'foo',
454                                                      left_db   => 'test',  # src
455                                                      left_tbl  => 'test1',
456            1                    1            37      actions   => [ sub { push @rows, $_[0]; push @dbhs, $_[1]; } ],
               1                                  6   
               1                                  9   
457                                                      replace   => 0,
458                                                      queue     => 1,
459                                                   );
460                                                   
461            1                                 25   $ch->change('INSERT', { a => 1, b => 2 }, [qw(a)] );
462            1                                 14   $ch->process_rows(1, "trace");
463                                                   
464            1                                 12   is_deeply(
465                                                      \@rows,
466                                                      ["INSERT INTO `test`.`foo`(`a`, `b`) VALUES ('1', '2') /*maatkit trace*/",],
467                                                      "process_rows() appends trace msg to SQL statements"
468                                                   );
469                                                   
470                                                   # #############################################################################
471                                                   # Done.
472                                                   # #############################################################################
473   ***      1     50                          39   $sb->wipe_clean($dbh) if $dbh;
474            1                                  6   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
202   ***     50      0      1   unless $dbh
310   ***     50      0      1   unless $dbh
410   ***     50      0      1   unless $dbh
473   ***     50      1      0   if $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location           
---------- ----- -------------------
BEGIN          1 ChangeHandler.t:10 
BEGIN          1 ChangeHandler.t:11 
BEGIN          1 ChangeHandler.t:12 
BEGIN          1 ChangeHandler.t:14 
BEGIN          1 ChangeHandler.t:15 
BEGIN          1 ChangeHandler.t:16 
BEGIN          1 ChangeHandler.t:17 
BEGIN          1 ChangeHandler.t:18 
BEGIN          1 ChangeHandler.t:4  
BEGIN          1 ChangeHandler.t:9  
__ANON__       2 ChangeHandler.t:159
__ANON__       3 ChangeHandler.t:213
__ANON__       1 ChangeHandler.t:25 
__ANON__       5 ChangeHandler.t:39 
__ANON__       2 ChangeHandler.t:426
__ANON__       1 ChangeHandler.t:456

Uncovered Subroutines
---------------------

Subroutine Count Location           
---------- ----- -------------------
__ANON__       0 ChangeHandler.t:254
__ANON__       0 ChangeHandler.t:351
__ANON__       0 ChangeHandler.t:369
__ANON__       0 ChangeHandler.t:396


