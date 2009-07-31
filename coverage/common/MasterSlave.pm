---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/MasterSlave.pm   85.0   56.9   50.0   91.2    n/a  100.0   74.0
Total                          85.0   56.9   50.0   91.2    n/a  100.0   74.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MasterSlave.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:52:16 2009
Finish:       Fri Jul 31 18:52:41 2009

/home/daniel/dev/maatkit/common/MasterSlave.pm

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
18                                                    # MasterSlave package $Revision: 4182 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  2   
               1                                  7   
21             1                    1           107   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
22                                                    
23                                                    package MasterSlave;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1             7   use List::Util qw(min max);
               1                                  2   
               1                                 10   
27             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  8   
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    $Data::Dumper::Indent    = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
32                                                    
33                                                    sub new {
34             1                    1            24      bless {}, shift;
35                                                    }
36                                                    
37                                                    # Descends to slaves by examining SHOW SLAVE HOSTS.  Arguments is a hashref:
38                                                    #
39                                                    # * dbh           (Optional) a DBH.
40                                                    # * dsn           The DSN to connect to; if no DBH, will connect using this.
41                                                    # * dsn_parser    A DSNParser object.
42                                                    # * recurse       How many levels to recurse. 0 = none, undef = infinite.
43                                                    # * callback      Code to execute after finding a new slave.
44                                                    # * skip_callback Optional: execute with slaves that will be skipped.
45                                                    # * method        Optional: whether to prefer HOSTS over PROCESSLIST
46                                                    # * parent        Optional: the DSN from which this call descended.
47                                                    #
48                                                    # The callback gets the slave's DSN, dbh, parent, and the recursion level as args.
49                                                    # The recursion is tail recursion.
50                                                    sub recurse_to_slaves {
51             4                    4            77      my ( $self, $args, $level ) = @_;
52             4           100                   19      $level ||= 0;
53             4                                 17      my $dp   = $args->{dsn_parser};
54             4                                 16      my $dsn  = $args->{dsn};
55                                                    
56             4                                 10      my $dbh;
57             4                                 14      eval {
58    ***      4            66                   32         $dbh = $args->{dbh} || $dp->get_dbh(
59                                                             $dp->get_cxn_params($dsn), { AutoCommit => 1 });
60             4                                 15         MKDEBUG && _d('Connected to', $dp->as_string($dsn));
61                                                       };
62    ***      4     50                          19      if ( $EVAL_ERROR ) {
63    ***      0      0                           0         print STDERR "Cannot connect to ", $dp->as_string($dsn), "\n"
64                                                             or die "Cannot print: $OS_ERROR";
65    ***      0                                  0         return;
66                                                       }
67                                                    
68                                                       # SHOW SLAVE HOSTS sometimes has obsolete information.  Verify that this
69                                                       # server has the ID its master thought, and that we have not seen it before
70                                                       # in any case.
71             4                                 12      my $sql  = 'SELECT @@SERVER_ID';
72             4                                 10      MKDEBUG && _d($sql);
73             4                                 12      my ($id) = $dbh->selectrow_array($sql);
74             4                                611      MKDEBUG && _d('Working on server ID', $id);
75             4                                 20      my $master_thinks_i_am = $dsn->{server_id};
76    ***      4     50     66                   95      if ( !defined $id
      ***                   33                        
      ***                   33                        
77                                                           || ( defined $master_thinks_i_am && $master_thinks_i_am != $id )
78                                                           || $args->{server_ids_seen}->{$id}++
79                                                       ) {
80    ***      0                                  0         MKDEBUG && _d('Server ID seen, or not what master said');
81    ***      0      0                           0         if ( $args->{skip_callback} ) {
82    ***      0                                  0            $args->{skip_callback}->($dsn, $dbh, $level, $args->{parent});
83                                                          }
84    ***      0                                  0         return;
85                                                       }
86                                                    
87                                                       # Call the callback!
88             4                                 29      $args->{callback}->($dsn, $dbh, $level, $args->{parent});
89                                                    
90    ***      4    100     66                  145      if ( !defined $args->{recurse} || $level < $args->{recurse} ) {
91                                                    
92                                                          # Find the slave hosts.  Eliminate hosts that aren't slaves of me (as
93                                                          # revealed by server_id and master_id).
94    ***      3     50                          65         my @slaves =
95             3                                 33            grep { !$_->{master_id} || $_->{master_id} == $id } # Only my slaves.
96                                                             $self->find_slave_hosts($dp, $dbh, $dsn, $args->{method});
97                                                    
98             3                                 20         foreach my $slave ( @slaves ) {
99             3                                  7            MKDEBUG && _d('Recursing from',
100                                                               $dp->as_string($dsn), 'to', $dp->as_string($slave));
101            3                                 61            $self->recurse_to_slaves(
102                                                               { %$args, dsn => $slave, dbh => undef, parent => $dsn }, $level + 1 );
103                                                         }
104                                                      }
105                                                   }
106                                                   
107                                                   # Finds slave hosts by trying different methods.  The default preferred method
108                                                   # is trying SHOW PROCESSLIST (processlist) and guessing which ones are slaves,
109                                                   # and if that doesn't reveal anything, then try SHOW SLAVE STATUS (hosts).
110                                                   # One exception is if the port is non-standard (3306), indicating that the port
111                                                   # from SHOW SLAVE HOSTS may be important.  Then only the hosts methods is used.
112                                                   #
113                                                   # Returns a list of DSN hashes.  Optional extra keys in the DSN hash are
114                                                   # master_id and server_id.  Also, the 'source' key is either 'processlist' or
115                                                   # 'hosts'.
116                                                   #
117                                                   # If a method is given, it becomes the preferred (first tried) method.
118                                                   # Searching stops as soon as a method finds slaves.
119                                                   sub find_slave_hosts {
120            3                    3            18      my ( $self, $dsn_parser, $dbh, $dsn, $method ) = @_;
121                                                   
122            3                                 14      my @methods = qw(processlist hosts);
123   ***      3     50                          12      if ( $method ) {
124                                                         # Remove all but the given method.
125   ***      0                                  0         @methods = grep { $_ ne $method } @methods;
      ***      0                                  0   
126                                                         # Add given method to the head of the list.
127   ***      0                                  0         unshift @methods, $method;
128                                                      }
129                                                      else {
130   ***      3     50     50                   22         if ( ($dsn->{P} || 3306) != 3306 ) {
131            3                                  6            MKDEBUG && _d('Port number is non-standard; using only hosts method');
132            3                                 12            @methods = qw(hosts);
133                                                         }
134                                                      }
135            3                                  7      MKDEBUG && _d('Looking for slaves on', $dsn_parser->as_string($dsn),
136                                                         'using methods', @methods);
137                                                   
138            3                                  8      my @slaves;
139                                                      METHOD:
140            3                                 16      foreach my $method ( @methods ) {
141            3                                 10         my $find_slaves = "_find_slaves_by_$method";
142            3                                  6         MKDEBUG && _d('Finding slaves with', $find_slaves);
143            3                                 20         @slaves = $self->$find_slaves($dsn_parser, $dbh, $dsn);
144            3    100                          21         last METHOD if @slaves;
145                                                      }
146                                                   
147            3                                  7      MKDEBUG && _d('Found', scalar(@slaves), 'slaves');
148            3                                 12      return @slaves;
149                                                   }
150                                                   
151                                                   sub _find_slaves_by_processlist {
152   ***      0                    0             0      my ( $self, $dsn_parser, $dbh, $dsn ) = @_;
153                                                   
154   ***      0                                  0      my @slaves = map  {
155   ***      0                                  0         my $slave        = $dsn_parser->parse("h=$_", $dsn);
156   ***      0                                  0         $slave->{source} = 'processlist';
157   ***      0                                  0         $slave;
158                                                      }
159   ***      0                                  0      grep { $_ }
160                                                      map  {
161   ***      0                                  0         my ( $host ) = $_->{host} =~ m/^([^:]+):/;
162   ***      0      0                           0         if ( $host eq 'localhost' ) {
163   ***      0                                  0            $host = '127.0.0.1'; # Replication never uses sockets.
164                                                         }
165   ***      0                                  0         $host;
166                                                      } $self->get_connected_slaves($dbh);
167                                                   
168   ***      0                                  0      return @slaves;
169                                                   }
170                                                   
171                                                   # SHOW SLAVE HOSTS is significantly less reliable.
172                                                   # Machines tend to share the host list around with every machine in the
173                                                   # replication hierarchy, but they don't update each other when machines
174                                                   # disconnect or change to use a different master or something.  So there is
175                                                   # lots of cruft in SHOW SLAVE HOSTS.
176                                                   sub _find_slaves_by_hosts {
177            3                    3            13      my ( $self, $dsn_parser, $dbh, $dsn ) = @_;
178                                                   
179            3                                  8      my @slaves;
180            3                                  9      my $sql = 'SHOW SLAVE HOSTS';
181            3                                  7      MKDEBUG && _d($dbh, $sql);
182            3                                  9      @slaves = @{$dbh->selectall_arrayref($sql, { Slice => {} })};
               3                                 77   
183                                                   
184                                                      # Convert SHOW SLAVE HOSTS into DSN hashes.
185            3    100                          27      if ( @slaves ) {
186            2                                  5         MKDEBUG && _d('Found some SHOW SLAVE HOSTS info');
187            3                                  8         @slaves = map {
188            2                                  7            my %hash;
189            3                                 19            @hash{ map { lc $_ } keys %$_ } = values %$_;
              15                                 60   
190   ***      3     50                          39            my $spec = "h=$hash{host},P=$hash{port}"
      ***            50                               
191                                                               . ( $hash{user} ? ",u=$hash{user}" : '')
192                                                               . ( $hash{password} ? ",p=$hash{password}" : '');
193            3                                 15            my $dsn           = $dsn_parser->parse($spec, $dsn);
194            3                                 13            $dsn->{server_id} = $hash{server_id};
195            3                                 12            $dsn->{master_id} = $hash{master_id};
196            3                                 10            $dsn->{source}    = 'hosts';
197            3                                 17            $dsn;
198                                                         } @slaves;
199                                                      }
200                                                   
201            3                                 13      return @slaves;
202                                                   }
203                                                   
204                                                   # Returns PROCESSLIST entries of connected slaves, normalized to lowercase
205                                                   # column names.
206                                                   sub get_connected_slaves {
207            3                    3            13      my ( $self, $dbh ) = @_;
208                                                   
209                                                      # Check for the PROCESS privilege.
210            3                                 50      my $proc =
211            3                                  7         grep { m/ALL PRIVILEGES.*?\*\.\*|PROCESS/ }
212            3                                  9         @{$dbh->selectcol_arrayref('SHOW GRANTS')};
213   ***      3     50                          15      if ( !$proc ) {
214   ***      0                                  0         die "You do not have the PROCESS privilege";
215                                                      }
216                                                   
217            3                                 10      my $sql = 'SHOW PROCESSLIST';
218            3                                  6      MKDEBUG && _d($dbh, $sql);
219                                                      # It's probably a slave if it's doing a binlog dump.
220           11                                 53      grep { $_->{command} =~ m/Binlog Dump/i }
              11                                 37   
221                                                      map  { # Lowercase the column names
222            3                                 19         my %hash;
223           11                                 59         @hash{ map { lc $_ } keys %$_ } = values %$_;
              88                                311   
224           11                                 52         \%hash;
225                                                      }
226            3                                  7      @{$dbh->selectall_arrayref($sql, { Slice => {} })};
227                                                   }
228                                                   
229                                                   # Verifies that $master is really the master of $slave.  This is not an exact
230                                                   # science, but there is a decent chance of catching some obvious cases when it
231                                                   # is not the master.  If not the master, it dies; otherwise returns true.
232                                                   sub is_master_of {
233            3                    3            26      my ( $self, $master, $slave ) = @_;
234   ***      3     50                          18      my $master_status = $self->get_master_status($master)
235                                                         or die "The server specified as a master is not a master";
236   ***      3     50                          15      my $slave_status  = $self->get_slave_status($slave)
237                                                         or die "The server specified as a slave is not a slave";
238            3    100                          18      my @connected     = $self->get_connected_slaves($master)
239                                                         or die "The server specified as a master has no connected slaves";
240            2                                  4      my (undef, $port) = $master->selectrow_array('SHOW VARIABLES LIKE "port"');
241                                                   
242            2    100                         506      if ( $port != $slave_status->{master_port} ) {
243            1                                  3         die "The slave is connected to $slave_status->{master_port} "
244                                                            . "but the master's port is $port";
245                                                      }
246                                                   
247   ***      1     50                           4      if ( !grep { $slave_status->{master_user} eq $_->{user} } @connected ) {
               1                                  8   
248   ***      0                                  0         die "I don't see any slave I/O thread connected with user "
249                                                            . $slave_status->{master_user};
250                                                      }
251                                                   
252   ***      1     50     50                    8      if ( ($slave_status->{slave_io_state} || '')
253                                                         eq 'Waiting for master to send event' )
254                                                      {
255                                                         # The slave thinks its I/O thread is caught up to the master.  Let's
256                                                         # compare and make sure the master and slave are reasonably close to each
257                                                         # other.  Note that this is one of the few places where I check the I/O
258                                                         # thread positions instead of the SQL thread positions!
259                                                         # Master_Log_File/Read_Master_Log_Pos is the I/O thread's position on the
260                                                         # master.
261            1                                 17         my ( $master_log_name, $master_log_num )
262                                                            = $master_status->{file} =~ m/^(.*?)\.0*([1-9][0-9]*)$/;
263            1                                 10         my ( $slave_log_name, $slave_log_num )
264                                                            = $slave_status->{master_log_file} =~ m/^(.*?)\.0*([1-9][0-9]*)$/;
265   ***      1     50     33                   18         if ( $master_log_name ne $slave_log_name
266                                                            || abs($master_log_num - $slave_log_num) > 1 )
267                                                         {
268   ***      0                                  0            die "The slave thinks it is reading from "
269                                                               . "$slave_status->{master_log_file},  but the "
270                                                               . "master is writing to $master_status->{file}";
271                                                         }
272                                                      }
273            1                                 18      return 1;
274                                                   }
275                                                   
276                                                   # Figures out how to connect to the master, by examining SHOW SLAVE STATUS.  But
277                                                   # does NOT use the value from Master_User for the username, because typically we
278                                                   # want to perform operations as the username that was specified (usually to the
279                                                   # program's --user option, or in a DSN), rather than as the replication user,
280                                                   # which is often restricted.
281                                                   sub get_master_dsn {
282            8                    8            62      my ( $self, $dbh, $dsn, $dsn_parser ) = @_;
283   ***      8     50                          44      my $master = $self->get_slave_status($dbh) or return undef;
284            8                                 48      my $spec   = "h=$master->{master_host},P=$master->{master_port}";
285            8                                 60      return       $dsn_parser->parse($spec, $dsn);
286                                                   }
287                                                   
288                                                   # Gets SHOW SLAVE STATUS, with column names all lowercased, as a hashref.
289                                                   sub get_slave_status {
290           47                   47           249      my ( $self, $dbh ) = @_;
291   ***     47     50                         431      if ( !$self->{not_a_slave}->{$dbh} ) {
292   ***     47            66                  313         my $sth = $self->{sths}->{$dbh}->{SLAVE_STATUS}
293                                                               ||= $dbh->prepare('SHOW SLAVE STATUS');
294           47                                173         MKDEBUG && _d($dbh, 'SHOW SLAVE STATUS');
295           47                             689869         $sth->execute();
296           47                                183         my ($ss) = @{$sth->fetchall_arrayref({})};
              47                                311   
297                                                   
298   ***     47    100     66                  746         if ( $ss && %$ss ) {
299           46                                398            $ss = { map { lc($_) => $ss->{$_} } keys %$ss }; # lowercase the keys
            1518                               6569   
300           46                                748            return $ss;
301                                                         }
302                                                   
303            1                                  4         MKDEBUG && _d('This server returns nothing for SHOW SLAVE STATUS');
304            1                                 57         $self->{not_a_slave}->{$dbh}++;
305                                                      }
306                                                   }
307                                                   
308                                                   # Gets SHOW MASTER STATUS, with column names all lowercased, as a hashref.
309                                                   sub get_master_status {
310           16                   16            78      my ( $self, $dbh ) = @_;
311   ***     16     50                         151      if ( !$self->{not_a_master}->{$dbh} ) {
312   ***     16            66                   94         my $sth = $self->{sths}->{$dbh}->{MASTER_STATUS}
313                                                               ||= $dbh->prepare('SHOW MASTER STATUS');
314           16                                 74         MKDEBUG && _d($dbh, 'SHOW MASTER STATUS');
315           16                               2710         $sth->execute();
316           16                                 55         my ($ms) = @{$sth->fetchall_arrayref({})};
              16                                102   
317                                                   
318   ***     16     50     33                  254         if ( $ms && %$ms ) {
319           16                                 87            $ms = { map { lc($_) => $ms->{$_} } keys %$ms }; # lowercase the keys
              64                                317   
320   ***     16     50     33                  191            if ( $ms->{file} && $ms->{position} ) {
321           16                                 78               return $ms;
322                                                            }
323                                                         }
324                                                   
325   ***      0                                  0         MKDEBUG && _d('This server returns nothing for SHOW MASTER STATUS');
326   ***      0                                  0         $self->{not_a_master}->{$dbh}++;
327                                                      }
328                                                   }
329                                                   
330                                                   # Waits for a slave to catch up to the master, with MASTER_POS_WAIT().  Returns
331                                                   # the return value of MASTER_POS_WAIT().  $ms is the optional result of calling
332                                                   # get_master_status().
333                                                   sub wait_for_master {
334            3                    3        1013810      my ( $self, $master, $slave, $time, $timeoutok, $ms ) = @_;
335            3                                 12      my $result;
336            3                                 13      MKDEBUG && _d('Waiting for slave to catch up to master');
337            3           100                   30      $ms ||= $self->get_master_status($master);
338   ***      3     50                          15      if ( $ms ) {
339            3                                 26         my $query = "SELECT MASTER_POS_WAIT('$ms->{file}', $ms->{position}, $time)";
340            3                                 12         MKDEBUG && _d($slave, $query);
341            3                                  9         ($result) = $slave->selectrow_array($query);
342            3    100                      387441         my $stat = defined $result ? $result : 'NULL';
343   ***      3    100     33                   47         if ( $stat eq 'NULL' || $stat < 0 && !$timeoutok ) {
      ***                   66                        
344            1                                  4            die "MASTER_POS_WAIT returned $stat";
345                                                         }
346            2                                  7         MKDEBUG && _d('Result of waiting:', $stat);
347                                                      }
348                                                      else {
349   ***      0                                  0         MKDEBUG && _d('Not waiting: this server is not a master');
350                                                      }
351            2                                 18      return $result;
352                                                   }
353                                                   
354                                                   # Executes STOP SLAVE.
355                                                   sub stop_slave {
356           21                   21           131      my ( $self, $dbh ) = @_;
357   ***     21            66                  135      my $sth = $self->{sths}->{$dbh}->{STOP_SLAVE}
358                                                            ||= $dbh->prepare('STOP SLAVE');
359           21                                 82      MKDEBUG && _d($dbh, $sth->{Statement});
360           21                             941494      $sth->execute();
361                                                   }
362                                                   
363                                                   # Executes START SLAVE, optionally with UNTIL.
364                                                   sub start_slave {
365           19                   19           233      my ( $self, $dbh, $pos ) = @_;
366           19    100                          87      if ( $pos ) {
367                                                         # Just like with CHANGE MASTER TO, you can't quote the position.
368            1                                  9         my $sql = "START SLAVE UNTIL MASTER_LOG_FILE='$pos->{file}', "
369                                                                 . "MASTER_LOG_POS=$pos->{position}";
370            1                                  2         MKDEBUG && _d($dbh, $sql);
371            1                                257         $dbh->do($sql);
372                                                      }
373                                                      else {
374   ***     18            66                  147         my $sth = $self->{sths}->{$dbh}->{START_SLAVE}
375                                                               ||= $dbh->prepare('START SLAVE');
376           18                                 58         MKDEBUG && _d($dbh, $sth->{Statement});
377           18                             291261         $sth->execute();
378                                                      }
379                                                   }
380                                                   
381                                                   # Waits for the slave to catch up to its master, using START SLAVE UNTIL.  When
382                                                   # complete, the slave is caught up to the master, and the slave process is
383                                                   # stopped on both servers.
384                                                   sub catchup_to_master {
385            3                    3           222      my ( $self, $slave, $master, $time ) = @_;
386            3                                 17      $self->stop_slave($master);
387            3                                 16      $self->stop_slave($slave);
388            3                                 25      my $slave_status  = $self->get_slave_status($slave);
389            3                                 20      my $slave_pos     = $self->repl_posn($slave_status);
390            3                                 17      my $master_status = $self->get_master_status($master);
391            3                                 14      my $master_pos    = $self->repl_posn($master_status);
392            3                                  8      MKDEBUG && _d('Master position:', $self->pos_to_string($master_pos),
393                                                         'Slave position:', $self->pos_to_string($slave_pos));
394            3    100                          16      if ( $self->pos_cmp($slave_pos, $master_pos) < 0 ) {
395            1                                  3         MKDEBUG && _d('Waiting for slave to catch up to master');
396            1                                  7         $self->start_slave($slave, $master_pos);
397                                                         # The slave may catch up instantly and stop, in which case MASTER_POS_WAIT
398                                                         # will return NULL.  We must catch this; if it returns NULL, then we check
399                                                         # that its position is as desired.
400            1                                  5         eval {
401            1                                  7            $self->wait_for_master($master, $slave, $time, 0, $master_status);
402                                                         };
403   ***      1     50                          12         if ( $EVAL_ERROR ) {
404            1                                  5            MKDEBUG && _d($EVAL_ERROR);
405   ***      1     50                           7            if ( $EVAL_ERROR =~ m/MASTER_POS_WAIT returned NULL/ ) {
406            1                                  8               $slave_status = $self->get_slave_status($slave);
407   ***      1     50                          13               if ( !$self->slave_is_running($slave_status) ) {
408            1                                  6                  $slave_pos = $self->repl_posn($slave_status);
409   ***      1     50                           5                  if ( $self->pos_cmp($slave_pos, $master_pos) != 0 ) {
410            1                                  3                     die "$EVAL_ERROR but slave has not caught up to master";
411                                                                  }
412   ***      0                                  0                  MKDEBUG && _d('Slave is caught up to master and stopped');
413                                                               }
414                                                               else {
415   ***      0                                  0                  die "$EVAL_ERROR but slave was still running";
416                                                               }
417                                                            }
418                                                            else {
419   ***      0                                  0               die $EVAL_ERROR;
420                                                            }
421                                                         }
422                                                      }
423                                                   }
424                                                   
425                                                   # Makes one server catch up to the other in replication.  When complete, both
426                                                   # servers are stopped and at the same position.
427                                                   sub catchup_to_same_pos {
428            2                    2            10      my ( $self, $s1_dbh, $s2_dbh ) = @_;
429            2                                 12      $self->stop_slave($s1_dbh);
430            2                                 11      $self->stop_slave($s2_dbh);
431            2                                 18      my $s1_status = $self->get_slave_status($s1_dbh);
432            2                                 11      my $s2_status = $self->get_slave_status($s2_dbh);
433            2                                 11      my $s1_pos    = $self->repl_posn($s1_status);
434            2                                  9      my $s2_pos    = $self->repl_posn($s2_status);
435   ***      2     50                          11      if ( $self->pos_cmp($s1_pos, $s2_pos) < 0 ) {
      ***            50                               
436   ***      0                                  0         $self->start_slave($s1_dbh, $s2_pos);
437                                                      }
438                                                      elsif ( $self->pos_cmp($s2_pos, $s1_pos) < 0 ) {
439   ***      0                                  0         $self->start_slave($s2_dbh, $s1_pos);
440                                                      }
441                                                   
442                                                      # Re-fetch the replication statuses and positions.
443            2                                 10      $s1_status = $self->get_slave_status($s1_dbh);
444            2                                 16      $s2_status = $self->get_slave_status($s2_dbh);
445            2                                 16      $s1_pos    = $self->repl_posn($s1_status);
446            2                                  8      $s2_pos    = $self->repl_posn($s2_status);
447                                                   
448                                                      # Verify that they are both stopped and are at the same position.
449   ***      2     50     33                   10      if ( $self->slave_is_running($s1_status)
      ***                   33                        
450                                                        || $self->slave_is_running($s2_status)
451                                                        || $self->pos_cmp($s1_pos, $s2_pos) != 0)
452                                                      {
453   ***      0                                  0         die "The servers aren't both stopped at the same position";
454                                                      }
455                                                   
456                                                   }
457                                                   
458                                                   # Uses CHANGE MASTER TO to change a slave's master.
459                                                   sub change_master_to {
460            3                    3            16      my ( $self, $dbh, $master_dsn, $master_pos ) = @_;
461            3                                 13      $self->stop_slave($dbh);
462                                                      # Don't prepare a $sth because CHANGE MASTER TO doesn't like quotes around
463                                                      # port numbers, etc.  It's possible to specify the bind type, but it's easier
464                                                      # to just not use a prepared statement.
465            3                                 11      MKDEBUG && _d(Dumper($master_dsn), Dumper($master_pos));
466            3                                 34      my $sql = "CHANGE MASTER TO MASTER_HOST='$master_dsn->{h}', "
467                                                         . "MASTER_PORT= $master_dsn->{P}, MASTER_LOG_FILE='$master_pos->{file}', "
468                                                         . "MASTER_LOG_POS=$master_pos->{position}";
469            3                                  8      MKDEBUG && _d($dbh, $sql);
470            3                             430704      $dbh->do($sql);
471                                                   }
472                                                   
473                                                   # Moves a slave to be a slave of its grandmaster: a sibling of its master.
474                                                   sub make_sibling_of_master {
475            1                    1            25      my ( $self, $slave_dbh, $slave_dsn, $dsn_parser, $timeout) = @_;
476                                                   
477                                                      # Connect to the master and the grand-master, and verify that the master is
478                                                      # also a slave.  Also verify that the grand-master isn't the slave!
479                                                      # (master-master replication).
480   ***      1     50                          10      my $master_dsn  = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
481                                                         or die "This server is not a slave";
482            1                                 10      my $master_dbh  = $dsn_parser->get_dbh(
483                                                         $dsn_parser->get_cxn_params($master_dsn), { AutoCommit => 1 });
484   ***      1     50                           7      my $gmaster_dsn
485                                                         = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
486                                                         or die "This server's master is not a slave";
487            1                                  7      my $gmaster_dbh = $dsn_parser->get_dbh(
488                                                         $dsn_parser->get_cxn_params($gmaster_dsn), { AutoCommit => 1 });
489   ***      1     50                           7      if ( $self->short_host($slave_dsn) eq $self->short_host($gmaster_dsn) ) {
490   ***      0                                  0         die "The slave's master's master is the slave: master-master replication";
491                                                      }
492                                                   
493                                                      # Stop the master, and make the slave catch up to it.
494            1                                  6      $self->stop_slave($master_dbh);
495            1                                  7      $self->catchup_to_master($slave_dbh, $master_dbh, $timeout);
496            1                                 25      $self->stop_slave($slave_dbh);
497                                                   
498                                                      # Get the replication statuses and positions.
499            1                                  6      my $master_status = $self->get_master_status($master_dbh);
500            1                                  5      my $mslave_status = $self->get_slave_status($master_dbh);
501            1                                  5      my $slave_status  = $self->get_slave_status($slave_dbh);
502            1                                  5      my $master_pos    = $self->repl_posn($master_status);
503            1                                  3      my $slave_pos     = $self->repl_posn($slave_status);
504                                                   
505                                                      # Verify that they are both stopped and are at the same position.
506   ***      1     50     33                    5      if ( !$self->slave_is_running($mslave_status)
      ***                   33                        
507                                                        && !$self->slave_is_running($slave_status)
508                                                        && $self->pos_cmp($master_pos, $slave_pos) == 0)
509                                                      {
510            1                                  5         $self->change_master_to($slave_dbh, $gmaster_dsn,
511                                                            $self->repl_posn($mslave_status)); # Note it's not $master_pos!
512                                                      }
513                                                      else {
514   ***      0                                  0         die "The servers aren't both stopped at the same position";
515                                                      }
516                                                   
517                                                      # Verify that they have the same master and are at the same position.
518            1                                 20      $mslave_status = $self->get_slave_status($master_dbh);
519            1                                 11      $slave_status  = $self->get_slave_status($slave_dbh);
520            1                                 12      my $mslave_pos = $self->repl_posn($mslave_status);
521            1                                  5      $slave_pos     = $self->repl_posn($slave_status);
522   ***      1     50     33                    6      if ( $self->short_host($mslave_status) ne $self->short_host($slave_status)
523                                                        || $self->pos_cmp($mslave_pos, $slave_pos) != 0)
524                                                      {
525   ***      0                                  0         die "The servers don't have the same master/position after the change";
526                                                      }
527                                                   }
528                                                   
529                                                   # Moves a slave to be a slave of its sibling.
530                                                   # 1. Connect to the sibling and verify that it has the same master.
531                                                   # 2. Stop the slave processes on the server and its sibling.
532                                                   # 3. If one of the servers is behind the other, make it catch up.
533                                                   # 4. Point the slave to its sibling.
534                                                   sub make_slave_of_sibling {
535            2                    2            54      my ( $self, $slave_dbh, $slave_dsn, $sib_dbh, $sib_dsn,
536                                                           $dsn_parser, $timeout) = @_;
537                                                   
538                                                      # Verify that the sibling is a different server.
539            2    100                          16      if ( $self->short_host($slave_dsn) eq $self->short_host($sib_dsn) ) {
540            1                                  4         die "You are trying to make the slave a slave of itself";
541                                                      }
542                                                   
543                                                      # Verify that the sibling has the same master, and that it is a master.
544   ***      1     50                           7      my $master_dsn1 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
545                                                         or die "This server is not a slave";
546            1                                  6      my $master_dbh1 = $dsn_parser->get_dbh(
547                                                         $dsn_parser->get_cxn_params($master_dsn1), { AutoCommit => 1 });
548   ***      1     50                           8      my $master_dsn2 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
549                                                         or die "The sibling is not a slave";
550   ***      1     50                           6      if ( $self->short_host($master_dsn1) ne $self->short_host($master_dsn2) ) {
551   ***      0                                  0         die "This server isn't a sibling of the slave";
552                                                      }
553   ***      1     50                           5      my $sib_master_stat = $self->get_master_status($sib_dbh)
554                                                         or die "Binary logging is not enabled on the sibling";
555   ***      1     50                           5      die "The log_slave_updates option is not enabled on the sibling"
556                                                         unless $self->has_slave_updates($sib_dbh);
557                                                   
558                                                      # Stop the slave and its sibling, then if one is behind the other, make it
559                                                      # catch up.
560            1                                  8      $self->catchup_to_same_pos($slave_dbh, $sib_dbh);
561                                                   
562                                                      # Actually change the slave's master to its sibling.
563            1                                  8      $sib_master_stat = $self->get_master_status($sib_dbh);
564            1                                  6      $self->change_master_to($slave_dbh, $sib_dsn,
565                                                            $self->repl_posn($sib_master_stat));
566                                                   
567                                                      # Verify that the slave's master is the sibling and that it is at the same
568                                                      # position.
569            1                                 20      my $slave_status = $self->get_slave_status($slave_dbh);
570            1                                  7      my $slave_pos    = $self->repl_posn($slave_status);
571            1                                  6      $sib_master_stat = $self->get_master_status($sib_dbh);
572   ***      1     50     33                    7      if ( $self->short_host($slave_status) ne $self->short_host($sib_dsn)
573                                                        || $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0)
574                                                      {
575   ***      0                                  0         die "After changing the slave's master, it isn't a slave of the sibling, "
576                                                            . "or it has a different replication position than the sibling";
577                                                      }
578                                                   }
579                                                   
580                                                   # Moves a slave to be a slave of its uncle.
581                                                   #  1. Connect to the slave's master and its uncle, and verify that both have the
582                                                   #     same master.  (Their common master is the slave's grandparent).
583                                                   #  2. Stop the slave processes on the master and uncle.
584                                                   #  3. If one of them is behind the other, make it catch up.
585                                                   #  4. Point the slave to its uncle.
586                                                   sub make_slave_of_uncle {
587            1                    1            30      my ( $self, $slave_dbh, $slave_dsn, $unc_dbh, $unc_dsn,
588                                                           $dsn_parser, $timeout) = @_;
589                                                   
590                                                      # Verify that the uncle is a different server.
591   ***      1     50                           7      if ( $self->short_host($slave_dsn) eq $self->short_host($unc_dsn) ) {
592   ***      0                                  0         die "You are trying to make the slave a slave of itself";
593                                                      }
594                                                   
595                                                      # Verify that the uncle has the same master.
596   ***      1     50                           6      my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
597                                                         or die "This server is not a slave";
598            1                                  7      my $master_dbh = $dsn_parser->get_dbh(
599                                                         $dsn_parser->get_cxn_params($master_dsn), { AutoCommit => 1 });
600   ***      1     50                           8      my $gmaster_dsn
601                                                         = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
602                                                         or die "The master is not a slave";
603   ***      1     50                           5      my $unc_master_dsn
604                                                         = $self->get_master_dsn($unc_dbh, $unc_dsn, $dsn_parser)
605                                                         or die "The uncle is not a slave";
606   ***      1     50                           5      if ($self->short_host($gmaster_dsn) ne $self->short_host($unc_master_dsn)) {
607   ***      0                                  0         die "The uncle isn't really the slave's uncle";
608                                                      }
609                                                   
610                                                      # Verify that the uncle is a master.
611   ***      1     50                           4      my $unc_master_stat = $self->get_master_status($unc_dbh)
612                                                         or die "Binary logging is not enabled on the uncle";
613   ***      1     50                           6      die "The log_slave_updates option is not enabled on the uncle"
614                                                         unless $self->has_slave_updates($unc_dbh);
615                                                   
616                                                      # Stop the master and uncle, then if one is behind the other, make it
617                                                      # catch up.  Then make the slave catch up to its master.
618            1                                  6      $self->catchup_to_same_pos($master_dbh, $unc_dbh);
619            1                                  8      $self->catchup_to_master($slave_dbh, $master_dbh, $timeout);
620                                                   
621                                                      # Verify that the slave is caught up to its master.
622            1                                  6      my $slave_status  = $self->get_slave_status($slave_dbh);
623            1                                  5      my $master_status = $self->get_master_status($master_dbh);
624   ***      1     50                           5      if ( $self->pos_cmp(
625                                                            $self->repl_posn($slave_status),
626                                                            $self->repl_posn($master_status)) != 0 )
627                                                      {
628   ***      0                                  0         die "The slave is not caught up to its master";
629                                                      }
630                                                   
631                                                      # Point the slave to its uncle.
632            1                                  5      $unc_master_stat = $self->get_master_status($unc_dbh);
633            1                                  6      $self->change_master_to($slave_dbh, $unc_dsn,
634                                                         $self->repl_posn($unc_master_stat));
635                                                   
636                                                   
637                                                      # Verify that the slave's master is the uncle and that it is at the same
638                                                      # position.
639            1                                 21      $slave_status    = $self->get_slave_status($slave_dbh);
640            1                                 11      my $slave_pos    = $self->repl_posn($slave_status);
641   ***      1     50     33                    5      if ( $self->short_host($slave_status) ne $self->short_host($unc_dsn)
642                                                        || $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0)
643                                                      {
644   ***      0                                  0         die "After changing the slave's master, it isn't a slave of the uncle, "
645                                                            . "or it has a different replication position than the uncle";
646                                                      }
647                                                   }
648                                                   
649                                                   # Makes a server forget that it is a slave.  Returns the slave status.
650                                                   sub detach_slave {
651            1                    1            22      my ( $self, $dbh ) = @_;
652                                                      # Verify that it is a slave.
653            1                                  8      $self->stop_slave($dbh);
654   ***      1     50                          14      my $stat = $self->get_slave_status($dbh)
655                                                         or die "This server is not a slave";
656            1                             123649      $dbh->do('CHANGE MASTER TO MASTER_HOST=""');
657            1                             134883      $dbh->do('RESET SLAVE'); # Wipes out master.info, etc etc
658            1                                 29      return $stat;
659                                                   }
660                                                   
661                                                   # Returns true if the slave is running.
662                                                   sub slave_is_running {
663            7                    7            28      my ( $self, $slave_status ) = @_;
664   ***      7            50                   85      return ($slave_status->{slave_sql_running} || 'No') eq 'Yes';
665                                                   }
666                                                   
667                                                   # Returns true if the server's log_slave_updates option is enabled.
668                                                   sub has_slave_updates {
669            2                    2            10      my ( $self, $dbh ) = @_;
670            2                                  7      my $sql = q{SHOW VARIABLES LIKE 'log_slave_updates'};
671            2                                  4      MKDEBUG && _d($dbh, $sql);
672            2                                  4      my ($name, $value) = $dbh->selectrow_array($sql);
673   ***      2            33                  606      return $value && $value =~ m/^(1|ON)$/;
674                                                   }
675                                                   
676                                                   # Extracts the replication position out of either SHOW MASTER STATUS or SHOW
677                                                   # SLAVE STATUS, and returns it as a hashref { file, position }
678                                                   sub repl_posn {
679           30                   30           127      my ( $self, $status ) = @_;
680   ***     30    100     66                  211      if ( exists $status->{file} && exists $status->{position} ) {
681                                                         # It's the output of SHOW MASTER STATUS
682                                                         return {
683           10                                 72            file     => $status->{file},
684                                                            position => $status->{position},
685                                                         };
686                                                      }
687                                                      else {
688                                                         return {
689           20                                149            file     => $status->{relay_master_log_file},
690                                                            position => $status->{exec_master_log_pos},
691                                                         };
692                                                      }
693                                                   }
694                                                   
695                                                   # Gets the slave's lag.  TODO: permit using a heartbeat table.
696                                                   sub get_slave_lag {
697   ***      0                    0             0      my ( $self, $dbh ) = @_;
698   ***      0                                  0      my $stat = $self->get_slave_status($dbh);
699   ***      0                                  0      return $stat->{seconds_behind_master};
700                                                   }
701                                                   
702                                                   # Compares two replication positions and returns -1, 0, or 1 just as the cmp
703                                                   # operator does.
704                                                   sub pos_cmp {
705           15                   15            69      my ( $self, $a, $b ) = @_;
706           15                                 73      return $self->pos_to_string($a) cmp $self->pos_to_string($b);
707                                                   }
708                                                   
709                                                   # Simplifies a hostname as much as possible.  For purposes of replication, a
710                                                   # hostname is really just the combination of hostname and port, since
711                                                   # replication always uses TCP connections (it does not work via sockets).  If
712                                                   # the port is the default 3306, it is omitted.  As a convenience, this sub
713                                                   # accepts either SHOW SLAVE STATUS or a DSN.
714                                                   sub short_host {
715           18                   18            72      my ( $self, $dsn ) = @_;
716           18                                 56      my ($host, $port);
717           18    100                          83      if ( $dsn->{master_host} ) {
718            4                                 14         $host = $dsn->{master_host};
719            4                                 15         $port = $dsn->{master_port};
720                                                      }
721                                                      else {
722           14                                 48         $host = $dsn->{h};
723           14                                 50         $port = $dsn->{P};
724                                                      }
725   ***     18     50     50                  221      return ($host || '[default]') . ( ($port || 3306) == 3306 ? '' : ":$port" );
      ***                   50                        
726                                                   }
727                                                   
728                                                   # Stringifies a position in a way that's string-comparable.
729                                                   sub pos_to_string {
730           30                   30           108      my ( $self, $pos ) = @_;
731           30                                 81      my $fmt  = '%s/%020d';
732           30                                 96      return sprintf($fmt, @{$pos}{qw(file position)});
              30                                561   
733                                                   }
734                                                   
735                                                   sub _d {
736   ***      0                    0                    my ($package, undef, $line) = caller 0;
737   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
738   ***      0                                              map { defined $_ ? $_ : 'undef' }
739                                                           @_;
740   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
741                                                   }
742                                                   
743                                                   1;
744                                                   
745                                                   # ###########################################################################
746                                                   # End MasterSlave package
747                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
62    ***     50      0      4   if ($EVAL_ERROR)
63    ***      0      0      0   unless print STDERR 'Cannot connect to ', $dp->as_string($dsn), "\n"
76    ***     50      0      4   if (not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id or $$args{'server_ids_seen'}{$id}++)
81    ***      0      0      0   if ($$args{'skip_callback'})
90           100      3      1   if (not defined $$args{'recurse'} or $level < $$args{'recurse'})
94    ***     50      3      0   unless not $$_{'master_id'}
123   ***     50      0      3   if ($method) { }
130   ***     50      3      0   if (($$dsn{'P'} || 3306) != 3306)
144          100      2      1   if @slaves
162   ***      0      0      0   if ($host eq 'localhost')
185          100      2      1   if (@slaves)
190   ***     50      0      3   $hash{'user'} ? :
      ***     50      0      3   $hash{'password'} ? :
213   ***     50      0      3   if (not $proc)
234   ***     50      0      3   unless my $master_status = $self->get_master_status($master)
236   ***     50      0      3   unless my $slave_status = $self->get_slave_status($slave)
238          100      1      2   unless my(@connected) = $self->get_connected_slaves($master)
242          100      1      1   if ($port != $$slave_status{'master_port'})
247   ***     50      0      1   if (not grep {$$slave_status{'master_user'} eq $$_{'user'};} @connected)
252   ***     50      1      0   if (($$slave_status{'slave_io_state'} || '') eq 'Waiting for master to send event')
265   ***     50      0      1   if ($master_log_name ne $slave_log_name or abs $master_log_num - $slave_log_num > 1)
283   ***     50      0      8   unless my $master = $self->get_slave_status($dbh)
291   ***     50     47      0   if (not $$self{'not_a_slave'}{$dbh})
298          100     46      1   if ($ss and %$ss)
311   ***     50     16      0   if (not $$self{'not_a_master'}{$dbh})
318   ***     50     16      0   if ($ms and %$ms)
320   ***     50     16      0   if ($$ms{'file'} and $$ms{'position'})
338   ***     50      3      0   if ($ms) { }
342          100      2      1   defined $result ? :
343          100      1      2   if ($stat eq 'NULL' or $stat < 0 and not $timeoutok)
366          100      1     18   if ($pos) { }
394          100      1      2   if ($self->pos_cmp($slave_pos, $master_pos) < 0)
403   ***     50      1      0   if ($EVAL_ERROR)
405   ***     50      1      0   if ($EVAL_ERROR =~ /MASTER_POS_WAIT returned NULL/) { }
407   ***     50      1      0   if (not $self->slave_is_running($slave_status)) { }
409   ***     50      1      0   if ($self->pos_cmp($slave_pos, $master_pos) != 0)
435   ***     50      0      2   if ($self->pos_cmp($s1_pos, $s2_pos) < 0) { }
      ***     50      0      2   elsif ($self->pos_cmp($s2_pos, $s1_pos) < 0) { }
449   ***     50      0      2   if ($self->slave_is_running($s1_status) or $self->slave_is_running($s2_status) or $self->pos_cmp($s1_pos, $s2_pos) != 0)
480   ***     50      0      1   unless my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
484   ***     50      0      1   unless my $gmaster_dsn = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
489   ***     50      0      1   if ($self->short_host($slave_dsn) eq $self->short_host($gmaster_dsn))
506   ***     50      1      0   if (not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status) and $self->pos_cmp($master_pos, $slave_pos) == 0) { }
522   ***     50      0      1   if ($self->short_host($mslave_status) ne $self->short_host($slave_status) or $self->pos_cmp($mslave_pos, $slave_pos) != 0)
539          100      1      1   if ($self->short_host($slave_dsn) eq $self->short_host($sib_dsn))
544   ***     50      0      1   unless my $master_dsn1 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
548   ***     50      0      1   unless my $master_dsn2 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
550   ***     50      0      1   if ($self->short_host($master_dsn1) ne $self->short_host($master_dsn2))
553   ***     50      0      1   unless my $sib_master_stat = $self->get_master_status($sib_dbh)
555   ***     50      0      1   unless $self->has_slave_updates($sib_dbh)
572   ***     50      0      1   if ($self->short_host($slave_status) ne $self->short_host($sib_dsn) or $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0)
591   ***     50      0      1   if ($self->short_host($slave_dsn) eq $self->short_host($unc_dsn))
596   ***     50      0      1   unless my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
600   ***     50      0      1   unless my $gmaster_dsn = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
603   ***     50      0      1   unless my $unc_master_dsn = $self->get_master_dsn($unc_dbh, $unc_dsn, $dsn_parser)
606   ***     50      0      1   if ($self->short_host($gmaster_dsn) ne $self->short_host($unc_master_dsn))
611   ***     50      0      1   unless my $unc_master_stat = $self->get_master_status($unc_dbh)
613   ***     50      0      1   unless $self->has_slave_updates($unc_dbh)
624   ***     50      0      1   if ($self->pos_cmp($self->repl_posn($slave_status), $self->repl_posn($master_status)) != 0)
641   ***     50      0      1   if ($self->short_host($slave_status) ne $self->short_host($unc_dsn) or $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0)
654   ***     50      0      1   unless my $stat = $self->get_slave_status($dbh)
680          100     10     20   if (exists $$status{'file'} and exists $$status{'position'}) { }
717          100      4     14   if ($$dsn{'master_host'}) { }
725   ***     50      0     18   ($port || 3306) == 3306 ? :
737   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
76    ***     66      1      3      0   defined $master_thinks_i_am and $master_thinks_i_am != $id
298   ***     66      1      0     46   $ss and %$ss
318   ***     33      0      0     16   $ms and %$ms
320   ***     33      0      0     16   $$ms{'file'} and $$ms{'position'}
343   ***     33      2      0      0   $stat < 0 and not $timeoutok
506   ***     33      0      0      1   not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status)
      ***     33      0      0      1   not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status) and $self->pos_cmp($master_pos, $slave_pos) == 0
673   ***     33      0      0      2   $value && $value =~ /^(1|ON)$/
680   ***     66     20      0     10   exists $$status{'file'} and exists $$status{'position'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
52           100      3      1   $level ||= 0
130   ***     50      3      0   $$dsn{'P'} || 3306
252   ***     50      1      0   $$slave_status{'slave_io_state'} || ''
337          100      1      2   $ms ||= $self->get_master_status($master)
664   ***     50      7      0   $$slave_status{'slave_sql_running'} || 'No'
725   ***     50     18      0   $host || '[default]'
      ***     50     18      0   $port || 3306

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
58    ***     66      1      3      0   $$args{'dbh'} || $dp->get_dbh($dp->get_cxn_params($dsn), {'AutoCommit', 1})
76    ***     33      0      0      4   not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id
      ***     33      0      0      4   not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id or $$args{'server_ids_seen'}{$id}++
90    ***     66      0      3      1   not defined $$args{'recurse'} or $level < $$args{'recurse'}
265   ***     33      0      0      1   $master_log_name ne $slave_log_name or abs $master_log_num - $slave_log_num > 1
292   ***     66     42      5      0   $$self{'sths'}{$dbh}{'SLAVE_STATUS'} ||= $dbh->prepare('SHOW SLAVE STATUS')
312   ***     66     10      6      0   $$self{'sths'}{$dbh}{'MASTER_STATUS'} ||= $dbh->prepare('SHOW MASTER STATUS')
343   ***     66      1      0      2   $stat eq 'NULL' or $stat < 0 and not $timeoutok
357   ***     66     15      6      0   $$self{'sths'}{$dbh}{'STOP_SLAVE'} ||= $dbh->prepare('STOP SLAVE')
374   ***     66     15      3      0   $$self{'sths'}{$dbh}{'START_SLAVE'} ||= $dbh->prepare('START SLAVE')
449   ***     33      0      0      2   $self->slave_is_running($s1_status) or $self->slave_is_running($s2_status)
      ***     33      0      0      2   $self->slave_is_running($s1_status) or $self->slave_is_running($s2_status) or $self->pos_cmp($s1_pos, $s2_pos) != 0
522   ***     33      0      0      1   $self->short_host($mslave_status) ne $self->short_host($slave_status) or $self->pos_cmp($mslave_pos, $slave_pos) != 0
572   ***     33      0      0      1   $self->short_host($slave_status) ne $self->short_host($sib_dsn) or $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0
641   ***     33      0      0      1   $self->short_host($slave_status) ne $self->short_host($unc_dsn) or $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0


Covered Subroutines
-------------------

Subroutine                  Count Location                                          
--------------------------- ----- --------------------------------------------------
BEGIN                           1 /home/daniel/dev/maatkit/common/MasterSlave.pm:20 
BEGIN                           1 /home/daniel/dev/maatkit/common/MasterSlave.pm:21 
BEGIN                           1 /home/daniel/dev/maatkit/common/MasterSlave.pm:25 
BEGIN                           1 /home/daniel/dev/maatkit/common/MasterSlave.pm:26 
BEGIN                           1 /home/daniel/dev/maatkit/common/MasterSlave.pm:27 
BEGIN                           1 /home/daniel/dev/maatkit/common/MasterSlave.pm:31 
_find_slaves_by_hosts           3 /home/daniel/dev/maatkit/common/MasterSlave.pm:177
catchup_to_master               3 /home/daniel/dev/maatkit/common/MasterSlave.pm:385
catchup_to_same_pos             2 /home/daniel/dev/maatkit/common/MasterSlave.pm:428
change_master_to                3 /home/daniel/dev/maatkit/common/MasterSlave.pm:460
detach_slave                    1 /home/daniel/dev/maatkit/common/MasterSlave.pm:651
find_slave_hosts                3 /home/daniel/dev/maatkit/common/MasterSlave.pm:120
get_connected_slaves            3 /home/daniel/dev/maatkit/common/MasterSlave.pm:207
get_master_dsn                  8 /home/daniel/dev/maatkit/common/MasterSlave.pm:282
get_master_status              16 /home/daniel/dev/maatkit/common/MasterSlave.pm:310
get_slave_status               47 /home/daniel/dev/maatkit/common/MasterSlave.pm:290
has_slave_updates               2 /home/daniel/dev/maatkit/common/MasterSlave.pm:669
is_master_of                    3 /home/daniel/dev/maatkit/common/MasterSlave.pm:233
make_sibling_of_master          1 /home/daniel/dev/maatkit/common/MasterSlave.pm:475
make_slave_of_sibling           2 /home/daniel/dev/maatkit/common/MasterSlave.pm:535
make_slave_of_uncle             1 /home/daniel/dev/maatkit/common/MasterSlave.pm:587
new                             1 /home/daniel/dev/maatkit/common/MasterSlave.pm:34 
pos_cmp                        15 /home/daniel/dev/maatkit/common/MasterSlave.pm:705
pos_to_string                  30 /home/daniel/dev/maatkit/common/MasterSlave.pm:730
recurse_to_slaves               4 /home/daniel/dev/maatkit/common/MasterSlave.pm:51 
repl_posn                      30 /home/daniel/dev/maatkit/common/MasterSlave.pm:679
short_host                     18 /home/daniel/dev/maatkit/common/MasterSlave.pm:715
slave_is_running                7 /home/daniel/dev/maatkit/common/MasterSlave.pm:663
start_slave                    19 /home/daniel/dev/maatkit/common/MasterSlave.pm:365
stop_slave                     21 /home/daniel/dev/maatkit/common/MasterSlave.pm:356
wait_for_master                 3 /home/daniel/dev/maatkit/common/MasterSlave.pm:334

Uncovered Subroutines
---------------------

Subroutine                  Count Location                                          
--------------------------- ----- --------------------------------------------------
_d                              0 /home/daniel/dev/maatkit/common/MasterSlave.pm:736
_find_slaves_by_processlist     0 /home/daniel/dev/maatkit/common/MasterSlave.pm:152
get_slave_lag                   0 /home/daniel/dev/maatkit/common/MasterSlave.pm:697


