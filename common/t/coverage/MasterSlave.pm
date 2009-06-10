---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/MasterSlave.pm   85.9   56.2   48.9   93.8    n/a  100.0   73.6
Total                          85.9   56.2   48.9   93.8    n/a  100.0   73.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MasterSlave.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:00 2009
Finish:       Wed Jun 10 17:20:23 2009

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
18                                                    # MasterSlave package $Revision: 3186 $
19                                                    # ###########################################################################
20             1                    1            16   use strict;
               1                                  4   
               1                                 10   
21             1                    1            10   use warnings FATAL => 'all';
               1                                119   
               1                                 10   
22                                                    
23                                                    package MasterSlave;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
26             1                    1            11   use List::Util qw(min max);
               1                                  2   
               1                                 15   
27             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  8   
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    $Data::Dumper::Indent    = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 12   
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
51             4                    4           141      my ( $self, $args, $level ) = @_;
52             4           100                   35      $level ||= 0;
53             4                                 23      my $dp   = $args->{dsn_parser};
54             4                                 38      my $dsn  = $args->{dsn};
55                                                    
56             4                                 14      my $dbh;
57             4                                 31      eval {
58    ***      4            66                   53         $dbh = $args->{dbh} || $dp->get_dbh(
59                                                             $dp->get_cxn_params($dsn), { AutoCommit => 1 });
60             4                                 25         MKDEBUG && _d('Connected to', $dp->as_string($dsn));
61                                                       };
62    ***      4     50                          27      if ( $EVAL_ERROR ) {
63    ***      0      0                           0         print STDERR "Cannot connect to ", $dp->as_string($dsn), "\n"
64                                                             or die "Cannot print: $OS_ERROR";
65    ***      0                                  0         return;
66                                                       }
67                                                    
68                                                       # SHOW SLAVE HOSTS sometimes has obsolete information.  Verify that this
69                                                       # server has the ID its master thought, and that we have not seen it before
70                                                       # in any case.
71             4                                 22      my $sql  = 'SELECT @@SERVER_ID';
72             4                                 19      MKDEBUG && _d($sql);
73             4                                 16      my ($id) = $dbh->selectrow_array($sql);
74             4                               5854      MKDEBUG && _d('Working on server ID', $id);
75             4                                 36      my $master_thinks_i_am = $dsn->{server_id};
76    ***      4     50     66                 1319      if ( !defined $id
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
88             4                                 53      $args->{callback}->($dsn, $dbh, $level, $args->{parent});
89                                                    
90    ***      4    100     66                  250      if ( !defined $args->{recurse} || $level < $args->{recurse} ) {
91                                                    
92                                                          # Find the slave hosts.  Eliminate hosts that aren't slaves of me (as
93                                                          # revealed by server_id and master_id).
94    ***      3     50                          67         my @slaves =
95             3                                 50            grep { !$_->{master_id} || $_->{master_id} == $id } # Only my slaves.
96                                                             $self->find_slave_hosts($dp, $dbh, $dsn, $args->{method});
97                                                    
98             3                                 37         foreach my $slave ( @slaves ) {
99             3                                 11            MKDEBUG && _d('Recursing from',
100                                                               $dp->as_string($dsn), 'to', $dp->as_string($slave));
101            3                                 90            $self->recurse_to_slaves(
102                                                               { %$args, dsn => $slave, dbh => undef, parent => $dsn }, $level + 1 );
103                                                         }
104                                                      }
105                                                   }
106                                                   
107                                                   # Finds slave hosts by trying SHOW PROCESSLIST and guessing which ones are
108                                                   # slaves, and if that doesn't reveal anything, looks at SHOW SLAVE STATUS.
109                                                   # Returns a list of DSN hashes.  Optional extra keys in the DSN hash are
110                                                   # master_id and server_id.  Also, the 'source' key is either 'processlist' or
111                                                   # 'hosts'.  If $method is given, uses that method instead of defaults.  The
112                                                   # default is to use 'processlist' unless the port is non-standard (indicating
113                                                   # that the port # from SHOW SLAVE HOSTS may be important).
114                                                   sub find_slave_hosts {
115            3                    3            32      my ( $self, $dsn_parser, $dbh, $dsn, $method ) = @_;
116   ***      3            50                   26      $method ||= '';
117            3                                 12      MKDEBUG && _d('Looking for slaves on', $dsn_parser->as_string($dsn));
118                                                   
119            3                                 12      my @slaves;
120                                                   
121   ***      3     50     50                  100      if ( (!$method && ($dsn->{P}||3306) == 3306) || $method eq 'processlist' ) {
      ***                   33                        
      ***                   33                        
122   ***      0                                  0         @slaves =
123                                                            map  {
124   ***      0                                  0               my $slave        = $dsn_parser->parse("h=$_", $dsn);
125   ***      0                                  0               $slave->{source} = 'processlist';
126   ***      0                                  0               $slave;
127                                                            }
128   ***      0                                  0            grep { $_ }
129                                                            map  {
130   ***      0                                  0               my ( $host ) = $_->{host} =~ m/^([^:]+):/;
131   ***      0      0                           0               if ( $host eq 'localhost' ) {
132   ***      0                                  0                  $host = '127.0.0.1'; # Replication never uses sockets.
133                                                               }
134   ***      0                                  0               $host;
135                                                            } $self->get_connected_slaves($dbh);
136                                                      }
137                                                   
138                                                      # Fall back to SHOW SLAVE HOSTS, which is significantly less reliable.
139                                                      # Machines tend to share the host list around with every machine in the
140                                                      # replication hierarchy, but they don't update each other when machines
141                                                      # disconnect or change to use a different master or something.  So there is
142                                                      # lots of cruft in SHOW SLAVE HOSTS.
143   ***      3     50                          22      if ( !@slaves ) {
144            3                                 15         my $sql = 'SHOW SLAVE HOSTS';
145            3                                 11         MKDEBUG && _d($dbh, $sql);
146            3                                 12         @slaves = @{$dbh->selectall_arrayref($sql, { Slice => {} })};
               3                                 88   
147                                                   
148                                                         # Convert SHOW SLAVE HOSTS into DSN hashes.
149            3    100                          52         if ( @slaves ) {
150            2                                  9            MKDEBUG && _d('Found some SHOW SLAVE HOSTS info');
151            3                                 13            @slaves = map {
152            2                                 11               my %hash;
153            3                                 40               @hash{ map { lc $_ } keys %$_ } = values %$_;
              15                                103   
154   ***      3     50                          54               my $spec = "h=$hash{host},P=$hash{port}"
      ***            50                               
155                                                                  . ( $hash{user} ? ",u=$hash{user}" : '')
156                                                                  . ( $hash{password} ? ",p=$hash{password}" : '');
157            3                                 26               my $dsn           = $dsn_parser->parse($spec, $dsn);
158            3                                 26               $dsn->{server_id} = $hash{server_id};
159            3                                 20               $dsn->{master_id} = $hash{master_id};
160            3                                 18               $dsn->{source}    = 'hosts';
161            3                                 29               $dsn;
162                                                            } @slaves;
163                                                         }
164                                                      }
165                                                   
166            3                                 13      MKDEBUG && _d('Found', scalar(@slaves), 'slaves');
167            3                                 22      return @slaves;
168                                                   }
169                                                   
170                                                   # Returns PROCESSLIST entries of connected slaves, normalized to lowercase
171                                                   # column names.
172                                                   sub get_connected_slaves {
173            3                    3            22      my ( $self, $dbh ) = @_;
174                                                   
175                                                      # Check for the PROCESS privilege.
176            3                                 92      my $proc =
177            3                                 11         grep { m/ALL PRIVILEGES.*?\*\.\*|PROCESS/ }
178            3                                 13         @{$dbh->selectcol_arrayref('SHOW GRANTS')};
179   ***      3     50                          24      if ( !$proc ) {
180   ***      0                                  0         die "You do not have the PROCESS privilege";
181                                                      }
182                                                   
183            3                                 15      my $sql = 'SHOW PROCESSLIST';
184            3                                 14      MKDEBUG && _d($dbh, $sql);
185                                                      # It's probably a slave if it's doing a binlog dump.
186           11                                111      grep { $_->{command} =~ m/Binlog Dump/i }
              11                                 62   
187                                                      map  { # Lowercase the column names
188            3                                 30         my %hash;
189           11                                112         @hash{ map { lc $_ } keys %$_ } = values %$_;
              88                                529   
190           11                                 95         \%hash;
191                                                      }
192            3                                 14      @{$dbh->selectall_arrayref($sql, { Slice => {} })};
193                                                   }
194                                                   
195                                                   # Verifies that $master is really the master of $slave.  This is not an exact
196                                                   # science, but there is a decent chance of catching some obvious cases when it
197                                                   # is not the master.  If not the master, it dies; otherwise returns true.
198                                                   sub is_master_of {
199            3                    3            50      my ( $self, $master, $slave ) = @_;
200   ***      3     50                          27      my $master_status = $self->get_master_status($master)
201                                                         or die "The server specified as a master is not a master";
202   ***      3     50                          23      my $slave_status  = $self->get_slave_status($slave)
203                                                         or die "The server specified as a slave is not a slave";
204            3    100                          35      my @connected     = $self->get_connected_slaves($master)
205                                                         or die "The server specified as a master has no connected slaves";
206            2                                  8      my (undef, $port) = $master->selectrow_array('SHOW VARIABLES LIKE "port"');
207                                                   
208            2    100                         877      if ( $port != $slave_status->{master_port} ) {
209            1                                  5         die "The slave is connected to $slave_status->{master_port} "
210                                                            . "but the master's port is $port";
211                                                      }
212                                                   
213   ***      1     50                           6      if ( !grep { $slave_status->{master_user} eq $_->{user} } @connected ) {
               1                                 15   
214   ***      0                                  0         die "I don't see any slave I/O thread connected with user "
215                                                            . $slave_status->{master_user};
216                                                      }
217                                                   
218   ***      1     50     50                   14      if ( ($slave_status->{slave_io_state} || '')
219                                                         eq 'Waiting for master to send event' )
220                                                      {
221                                                         # The slave thinks its I/O thread is caught up to the master.  Let's
222                                                         # compare and make sure the master and slave are reasonably close to each
223                                                         # other.  Note that this is one of the few places where I check the I/O
224                                                         # thread positions instead of the SQL thread positions!
225                                                         # Master_Log_File/Read_Master_Log_Pos is the I/O thread's position on the
226                                                         # master.
227            1                                 27         my ( $master_log_name, $master_log_num )
228                                                            = $master_status->{file} =~ m/^(.*?)\.0*([1-9][0-9]*)$/;
229            1                                 15         my ( $slave_log_name, $slave_log_num )
230                                                            = $slave_status->{master_log_file} =~ m/^(.*?)\.0*([1-9][0-9]*)$/;
231   ***      1     50     33                   30         if ( $master_log_name ne $slave_log_name
232                                                            || abs($master_log_num - $slave_log_num) > 1 )
233                                                         {
234   ***      0                                  0            die "The slave thinks it is reading from "
235                                                               . "$slave_status->{master_log_file},  but the "
236                                                               . "master is writing to $master_status->{file}";
237                                                         }
238                                                      }
239            1                                 32      return 1;
240                                                   }
241                                                   
242                                                   # Figures out how to connect to the master, by examining SHOW SLAVE STATUS.  But
243                                                   # does NOT use the value from Master_User for the username, because typically we
244                                                   # want to perform operations as the username that was specified (usually to the
245                                                   # program's --user option, or in a DSN), rather than as the replication user,
246                                                   # which is often restricted.
247                                                   sub get_master_dsn {
248            8                    8           104      my ( $self, $dbh, $dsn, $dsn_parser ) = @_;
249   ***      8     50                          70      my $master = $self->get_slave_status($dbh) or return undef;
250            8                                 98      my $spec   = "h=$master->{master_host},P=$master->{master_port}";
251            8                                107      return       $dsn_parser->parse($spec, $dsn);
252                                                   }
253                                                   
254                                                   # Gets SHOW SLAVE STATUS, with column names all lowercased, as a hashref.
255                                                   sub get_slave_status {
256           47                   47           431      my ( $self, $dbh ) = @_;
257   ***     47     50                         781      if ( !$self->{not_a_slave}->{$dbh} ) {
258   ***     47            66                  527         my $sth = $self->{sths}->{$dbh}->{SLAVE_STATUS}
259                                                               ||= $dbh->prepare('SHOW SLAVE STATUS');
260           47                                223         MKDEBUG && _d($dbh, 'SHOW SLAVE STATUS');
261           47                             759343         $sth->execute();
262           47                                300         my ($ss) = @{$sth->fetchall_arrayref({})};
              47                                536   
263                                                   
264   ***     47    100     66                 1435         if ( $ss && %$ss ) {
265           46                                726            $ss = { map { lc($_) => $ss->{$_} } keys %$ss }; # lowercase the keys
            1518                              11464   
266           46                               1454            return $ss;
267                                                         }
268                                                   
269            1                                  5         MKDEBUG && _d('This server returns nothing for SHOW SLAVE STATUS');
270            1                                102         $self->{not_a_slave}->{$dbh}++;
271                                                      }
272                                                   }
273                                                   
274                                                   # Gets SHOW MASTER STATUS, with column names all lowercased, as a hashref.
275                                                   sub get_master_status {
276           16                   16           130      my ( $self, $dbh ) = @_;
277   ***     16     50                         260      if ( !$self->{not_a_master}->{$dbh} ) {
278   ***     16            66                  148         my $sth = $self->{sths}->{$dbh}->{MASTER_STATUS}
279                                                               ||= $dbh->prepare('SHOW MASTER STATUS');
280           16                                122         MKDEBUG && _d($dbh, 'SHOW MASTER STATUS');
281           16                               3504         $sth->execute();
282           16                                 89         my ($ms) = @{$sth->fetchall_arrayref({})};
              16                                172   
283                                                   
284   ***     16     50     33                  465         if ( $ms && %$ms ) {
285           16                                148            $ms = { map { lc($_) => $ms->{$_} } keys %$ms }; # lowercase the keys
              64                                562   
286   ***     16     50     33                  340            if ( $ms->{file} && $ms->{position} ) {
287           16                                134               return $ms;
288                                                            }
289                                                         }
290                                                   
291   ***      0                                  0         MKDEBUG && _d('This server returns nothing for SHOW MASTER STATUS');
292   ***      0                                  0         $self->{not_a_master}->{$dbh}++;
293                                                      }
294                                                   }
295                                                   
296                                                   # Waits for a slave to catch up to the master, with MASTER_POS_WAIT().  Returns
297                                                   # the return value of MASTER_POS_WAIT().  $ms is the optional result of calling
298                                                   # get_master_status().
299                                                   sub wait_for_master {
300            3                    3        1022534      my ( $self, $master, $slave, $time, $timeoutok, $ms ) = @_;
301            3                                 18      my $result;
302            3                                 14      MKDEBUG && _d('Waiting for slave to catch up to master');
303            3           100                   42      $ms ||= $self->get_master_status($master);
304   ***      3     50                          23      if ( $ms ) {
305            3                                 50         my $query = "SELECT MASTER_POS_WAIT('$ms->{file}', $ms->{position}, $time)";
306            3                                 12         MKDEBUG && _d($slave, $query);
307            3                                 12         ($result) = $slave->selectrow_array($query);
308            3    100                      387072         my $stat = defined $result ? $result : 'NULL';
309   ***      3    100     33                   72         if ( $stat eq 'NULL' || $stat < 0 && !$timeoutok ) {
      ***                   66                        
310            1                                  5            die "MASTER_POS_WAIT returned $stat";
311                                                         }
312            2                                 11         MKDEBUG && _d('Result of waiting:', $stat);
313                                                      }
314                                                      else {
315   ***      0                                  0         MKDEBUG && _d('Not waiting: this server is not a master');
316                                                      }
317            2                                 32      return $result;
318                                                   }
319                                                   
320                                                   # Executes STOP SLAVE.
321                                                   sub stop_slave {
322           21                   21           226      my ( $self, $dbh ) = @_;
323   ***     21            66                  233      my $sth = $self->{sths}->{$dbh}->{STOP_SLAVE}
324                                                            ||= $dbh->prepare('STOP SLAVE');
325           21                                128      MKDEBUG && _d($dbh, $sth->{Statement});
326           21                             805065      $sth->execute();
327                                                   }
328                                                   
329                                                   # Executes START SLAVE, optionally with UNTIL.
330                                                   sub start_slave {
331           19                   19           387      my ( $self, $dbh, $pos ) = @_;
332           19    100                         145      if ( $pos ) {
333                                                         # Just like with CHANGE MASTER TO, you can't quote the position.
334            1                                 13         my $sql = "START SLAVE UNTIL MASTER_LOG_FILE='$pos->{file}', "
335                                                                 . "MASTER_LOG_POS=$pos->{position}";
336            1                                 13         MKDEBUG && _d($dbh, $sql);
337            1                                434         $dbh->do($sql);
338                                                      }
339                                                      else {
340   ***     18            66                 2344         my $sth = $self->{sths}->{$dbh}->{START_SLAVE}
341                                                               ||= $dbh->prepare('START SLAVE');
342           18                                 96         MKDEBUG && _d($dbh, $sth->{Statement});
343           18                             339729         $sth->execute();
344                                                      }
345                                                   }
346                                                   
347                                                   # Waits for the slave to catch up to its master, using START SLAVE UNTIL.  When
348                                                   # complete, the slave is caught up to the master, and the slave process is
349                                                   # stopped on both servers.
350                                                   sub catchup_to_master {
351            3                    3           410      my ( $self, $slave, $master, $time ) = @_;
352            3                                 27      $self->stop_slave($master);
353            3                                 26      $self->stop_slave($slave);
354            3                                 34      my $slave_status  = $self->get_slave_status($slave);
355            3                                 39      my $slave_pos     = $self->repl_posn($slave_status);
356            3                                 22      my $master_status = $self->get_master_status($master);
357            3                                 42      my $master_pos    = $self->repl_posn($master_status);
358            3                                 12      MKDEBUG && _d('Master position:', $self->pos_to_string($master_pos),
359                                                         'Slave position:', $self->pos_to_string($slave_pos));
360            3    100                          26      if ( $self->pos_cmp($slave_pos, $master_pos) < 0 ) {
361            1                                  5         MKDEBUG && _d('Waiting for slave to catch up to master');
362            1                                 11         $self->start_slave($slave, $master_pos);
363                                                         # The slave may catch up instantly and stop, in which case MASTER_POS_WAIT
364                                                         # will return NULL.  We must catch this; if it returns NULL, then we check
365                                                         # that its position is as desired.
366            1                                  8         eval {
367            1                                 10            $self->wait_for_master($master, $slave, $time, 0, $master_status);
368                                                         };
369   ***      1     50                          18         if ( $EVAL_ERROR ) {
370            1                                  4            MKDEBUG && _d($EVAL_ERROR);
371   ***      1     50                          19            if ( $EVAL_ERROR =~ m/MASTER_POS_WAIT returned NULL/ ) {
372            1                                 12               $slave_status = $self->get_slave_status($slave);
373   ***      1     50                          23               if ( !$self->slave_is_running($slave_status) ) {
374            1                                  8                  $slave_pos = $self->repl_posn($slave_status);
375   ***      1     50                           8                  if ( $self->pos_cmp($slave_pos, $master_pos) != 0 ) {
376            1                                  5                     die "$EVAL_ERROR but slave has not caught up to master";
377                                                                  }
378   ***      0                                  0                  MKDEBUG && _d('Slave is caught up to master and stopped');
379                                                               }
380                                                               else {
381   ***      0                                  0                  die "$EVAL_ERROR but slave was still running";
382                                                               }
383                                                            }
384                                                            else {
385   ***      0                                  0               die $EVAL_ERROR;
386                                                            }
387                                                         }
388                                                      }
389                                                   }
390                                                   
391                                                   # Makes one server catch up to the other in replication.  When complete, both
392                                                   # servers are stopped and at the same position.
393                                                   sub catchup_to_same_pos {
394            2                    2            15      my ( $self, $s1_dbh, $s2_dbh ) = @_;
395            2                                 17      $self->stop_slave($s1_dbh);
396            2                                 21      $self->stop_slave($s2_dbh);
397            2                                 31      my $s1_status = $self->get_slave_status($s1_dbh);
398            2                                 21      my $s2_status = $self->get_slave_status($s2_dbh);
399            2                                 17      my $s1_pos    = $self->repl_posn($s1_status);
400            2                                 14      my $s2_pos    = $self->repl_posn($s2_status);
401   ***      2     50                          16      if ( $self->pos_cmp($s1_pos, $s2_pos) < 0 ) {
      ***            50                               
402   ***      0                                  0         $self->start_slave($s1_dbh, $s2_pos);
403                                                      }
404                                                      elsif ( $self->pos_cmp($s2_pos, $s1_pos) < 0 ) {
405   ***      0                                  0         $self->start_slave($s2_dbh, $s1_pos);
406                                                      }
407                                                   
408                                                      # Re-fetch the replication statuses and positions.
409            2                                 18      $s1_status = $self->get_slave_status($s1_dbh);
410            2                                 29      $s2_status = $self->get_slave_status($s2_dbh);
411            2                                 28      $s1_pos    = $self->repl_posn($s1_status);
412            2                                 16      $s2_pos    = $self->repl_posn($s2_status);
413                                                   
414                                                      # Verify that they are both stopped and are at the same position.
415   ***      2     50     33                   17      if ( $self->slave_is_running($s1_status)
      ***                   33                        
416                                                        || $self->slave_is_running($s2_status)
417                                                        || $self->pos_cmp($s1_pos, $s2_pos) != 0)
418                                                      {
419   ***      0                                  0         die "The servers aren't both stopped at the same position";
420                                                      }
421                                                   
422                                                   }
423                                                   
424                                                   # Uses CHANGE MASTER TO to change a slave's master.
425                                                   sub change_master_to {
426            3                    3            24      my ( $self, $dbh, $master_dsn, $master_pos ) = @_;
427            3                                 24      $self->stop_slave($dbh);
428                                                      # Don't prepare a $sth because CHANGE MASTER TO doesn't like quotes around
429                                                      # port numbers, etc.  It's possible to specify the bind type, but it's easier
430                                                      # to just not use a prepared statement.
431            3                                 16      MKDEBUG && _d(Dumper($master_dsn), Dumper($master_pos));
432            3                                 60      my $sql = "CHANGE MASTER TO MASTER_HOST='$master_dsn->{h}', "
433                                                         . "MASTER_PORT= $master_dsn->{P}, MASTER_LOG_FILE='$master_pos->{file}', "
434                                                         . "MASTER_LOG_POS=$master_pos->{position}";
435            3                                 10      MKDEBUG && _d($dbh, $sql);
436            3                             452555      $dbh->do($sql);
437                                                   }
438                                                   
439                                                   # Moves a slave to be a slave of its grandmaster: a sibling of its master.
440                                                   sub make_sibling_of_master {
441            1                    1            45      my ( $self, $slave_dbh, $slave_dsn, $dsn_parser, $timeout) = @_;
442                                                   
443                                                      # Connect to the master and the grand-master, and verify that the master is
444                                                      # also a slave.  Also verify that the grand-master isn't the slave!
445                                                      # (master-master replication).
446   ***      1     50                          13      my $master_dsn  = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
447                                                         or die "This server is not a slave";
448            1                                 19      my $master_dbh  = $dsn_parser->get_dbh(
449                                                         $dsn_parser->get_cxn_params($master_dsn), { AutoCommit => 1 });
450   ***      1     50                          15      my $gmaster_dsn
451                                                         = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
452                                                         or die "This server's master is not a slave";
453            1                                 12      my $gmaster_dbh = $dsn_parser->get_dbh(
454                                                         $dsn_parser->get_cxn_params($gmaster_dsn), { AutoCommit => 1 });
455   ***      1     50                          19      if ( $self->short_host($slave_dsn) eq $self->short_host($gmaster_dsn) ) {
456   ***      0                                  0         die "The slave's master's master is the slave: master-master replication";
457                                                      }
458                                                   
459                                                      # Stop the master, and make the slave catch up to it.
460            1                                  9      $self->stop_slave($master_dbh);
461            1                                 12      $self->catchup_to_master($slave_dbh, $master_dbh, $timeout);
462            1                                 11      $self->stop_slave($slave_dbh);
463                                                   
464                                                      # Get the replication statuses and positions.
465            1                                 11      my $master_status = $self->get_master_status($master_dbh);
466            1                                  8      my $mslave_status = $self->get_slave_status($master_dbh);
467            1                                  9      my $slave_status  = $self->get_slave_status($slave_dbh);
468            1                                 10      my $master_pos    = $self->repl_posn($master_status);
469            1                                  7      my $slave_pos     = $self->repl_posn($slave_status);
470                                                   
471                                                      # Verify that they are both stopped and are at the same position.
472   ***      1     50     33                    8      if ( !$self->slave_is_running($mslave_status)
      ***                   33                        
473                                                        && !$self->slave_is_running($slave_status)
474                                                        && $self->pos_cmp($master_pos, $slave_pos) == 0)
475                                                      {
476            1                                  8         $self->change_master_to($slave_dbh, $gmaster_dsn,
477                                                            $self->repl_posn($mslave_status)); # Note it's not $master_pos!
478                                                      }
479                                                      else {
480   ***      0                                  0         die "The servers aren't both stopped at the same position";
481                                                      }
482                                                   
483                                                      # Verify that they have the same master and are at the same position.
484            1                                 26      $mslave_status = $self->get_slave_status($master_dbh);
485            1                                 20      $slave_status  = $self->get_slave_status($slave_dbh);
486            1                                 21      my $mslave_pos = $self->repl_posn($mslave_status);
487            1                                  8      $slave_pos     = $self->repl_posn($slave_status);
488   ***      1     50     33                   10      if ( $self->short_host($mslave_status) ne $self->short_host($slave_status)
489                                                        || $self->pos_cmp($mslave_pos, $slave_pos) != 0)
490                                                      {
491   ***      0                                  0         die "The servers don't have the same master/position after the change";
492                                                      }
493                                                   }
494                                                   
495                                                   # Moves a slave to be a slave of its sibling.
496                                                   # 1. Connect to the sibling and verify that it has the same master.
497                                                   # 2. Stop the slave processes on the server and its sibling.
498                                                   # 3. If one of the servers is behind the other, make it catch up.
499                                                   # 4. Point the slave to its sibling.
500                                                   sub make_slave_of_sibling {
501            2                    2            90      my ( $self, $slave_dbh, $slave_dsn, $sib_dbh, $sib_dsn,
502                                                           $dsn_parser, $timeout) = @_;
503                                                   
504                                                      # Verify that the sibling is a different server.
505            2    100                          20      if ( $self->short_host($slave_dsn) eq $self->short_host($sib_dsn) ) {
506            1                                  4         die "You are trying to make the slave a slave of itself";
507                                                      }
508                                                   
509                                                      # Verify that the sibling has the same master, and that it is a master.
510   ***      1     50                          12      my $master_dsn1 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
511                                                         or die "This server is not a slave";
512            1                                 10      my $master_dbh1 = $dsn_parser->get_dbh(
513                                                         $dsn_parser->get_cxn_params($master_dsn1), { AutoCommit => 1 });
514   ***      1     50                          14      my $master_dsn2 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
515                                                         or die "The sibling is not a slave";
516   ***      1     50                           9      if ( $self->short_host($master_dsn1) ne $self->short_host($master_dsn2) ) {
517   ***      0                                  0         die "This server isn't a sibling of the slave";
518                                                      }
519   ***      1     50                           8      my $sib_master_stat = $self->get_master_status($sib_dbh)
520                                                         or die "Binary logging is not enabled on the sibling";
521   ***      1     50                           8      die "The log_slave_updates option is not enabled on the sibling"
522                                                         unless $self->has_slave_updates($sib_dbh);
523                                                   
524                                                      # Stop the slave and its sibling, then if one is behind the other, make it
525                                                      # catch up.
526            1                                 15      $self->catchup_to_same_pos($slave_dbh, $sib_dbh);
527                                                   
528                                                      # Actually change the slave's master to its sibling.
529            1                                 12      $sib_master_stat = $self->get_master_status($sib_dbh);
530            1                                 11      $self->change_master_to($slave_dbh, $sib_dsn,
531                                                            $self->repl_posn($sib_master_stat));
532                                                   
533                                                      # Verify that the slave's master is the sibling and that it is at the same
534                                                      # position.
535            1                                 27      my $slave_status = $self->get_slave_status($slave_dbh);
536            1                                 10      my $slave_pos    = $self->repl_posn($slave_status);
537            1                                  9      $sib_master_stat = $self->get_master_status($sib_dbh);
538   ***      1     50     33                   10      if ( $self->short_host($slave_status) ne $self->short_host($sib_dsn)
539                                                        || $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0)
540                                                      {
541   ***      0                                  0         die "After changing the slave's master, it isn't a slave of the sibling, "
542                                                            . "or it has a different replication position than the sibling";
543                                                      }
544                                                   }
545                                                   
546                                                   # Moves a slave to be a slave of its uncle.
547                                                   #  1. Connect to the slave's master and its uncle, and verify that both have the
548                                                   #     same master.  (Their common master is the slave's grandparent).
549                                                   #  2. Stop the slave processes on the master and uncle.
550                                                   #  3. If one of them is behind the other, make it catch up.
551                                                   #  4. Point the slave to its uncle.
552                                                   sub make_slave_of_uncle {
553            1                    1            51      my ( $self, $slave_dbh, $slave_dsn, $unc_dbh, $unc_dsn,
554                                                           $dsn_parser, $timeout) = @_;
555                                                   
556                                                      # Verify that the uncle is a different server.
557   ***      1     50                          10      if ( $self->short_host($slave_dsn) eq $self->short_host($unc_dsn) ) {
558   ***      0                                  0         die "You are trying to make the slave a slave of itself";
559                                                      }
560                                                   
561                                                      # Verify that the uncle has the same master.
562   ***      1     50                          11      my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
563                                                         or die "This server is not a slave";
564            1                                 11      my $master_dbh = $dsn_parser->get_dbh(
565                                                         $dsn_parser->get_cxn_params($master_dsn), { AutoCommit => 1 });
566   ***      1     50                          12      my $gmaster_dsn
567                                                         = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
568                                                         or die "The master is not a slave";
569   ***      1     50                          11      my $unc_master_dsn
570                                                         = $self->get_master_dsn($unc_dbh, $unc_dsn, $dsn_parser)
571                                                         or die "The uncle is not a slave";
572   ***      1     50                           8      if ($self->short_host($gmaster_dsn) ne $self->short_host($unc_master_dsn)) {
573   ***      0                                  0         die "The uncle isn't really the slave's uncle";
574                                                      }
575                                                   
576                                                      # Verify that the uncle is a master.
577   ***      1     50                           9      my $unc_master_stat = $self->get_master_status($unc_dbh)
578                                                         or die "Binary logging is not enabled on the uncle";
579   ***      1     50                           9      die "The log_slave_updates option is not enabled on the uncle"
580                                                         unless $self->has_slave_updates($unc_dbh);
581                                                   
582                                                      # Stop the master and uncle, then if one is behind the other, make it
583                                                      # catch up.  Then make the slave catch up to its master.
584            1                                 11      $self->catchup_to_same_pos($master_dbh, $unc_dbh);
585            1                                 11      $self->catchup_to_master($slave_dbh, $master_dbh, $timeout);
586                                                   
587                                                      # Verify that the slave is caught up to its master.
588            1                                 11      my $slave_status  = $self->get_slave_status($slave_dbh);
589            1                                  8      my $master_status = $self->get_master_status($master_dbh);
590   ***      1     50                           9      if ( $self->pos_cmp(
591                                                            $self->repl_posn($slave_status),
592                                                            $self->repl_posn($master_status)) != 0 )
593                                                      {
594   ***      0                                  0         die "The slave is not caught up to its master";
595                                                      }
596                                                   
597                                                      # Point the slave to its uncle.
598            1                                 10      $unc_master_stat = $self->get_master_status($unc_dbh);
599            1                                 12      $self->change_master_to($slave_dbh, $unc_dsn,
600                                                         $self->repl_posn($unc_master_stat));
601                                                   
602                                                   
603                                                      # Verify that the slave's master is the uncle and that it is at the same
604                                                      # position.
605            1                                 28      $slave_status    = $self->get_slave_status($slave_dbh);
606            1                                 17      my $slave_pos    = $self->repl_posn($slave_status);
607   ***      1     50     33                    8      if ( $self->short_host($slave_status) ne $self->short_host($unc_dsn)
608                                                        || $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0)
609                                                      {
610   ***      0                                  0         die "After changing the slave's master, it isn't a slave of the uncle, "
611                                                            . "or it has a different replication position than the uncle";
612                                                      }
613                                                   }
614                                                   
615                                                   # Makes a server forget that it is a slave.  Returns the slave status.
616                                                   sub detach_slave {
617            1                    1            29      my ( $self, $dbh ) = @_;
618                                                      # Verify that it is a slave.
619            1                                  9      $self->stop_slave($dbh);
620   ***      1     50                          23      my $stat = $self->get_slave_status($dbh)
621                                                         or die "This server is not a slave";
622            1                             183675      $dbh->do('CHANGE MASTER TO MASTER_HOST=""');
623            1                             134622      $dbh->do('RESET SLAVE'); # Wipes out master.info, etc etc
624            1                                 40      return $stat;
625                                                   }
626                                                   
627                                                   # Returns true if the slave is running.
628                                                   sub slave_is_running {
629            7                    7            45      my ( $self, $slave_status ) = @_;
630   ***      7            50                  165      return ($slave_status->{slave_sql_running} || 'No') eq 'Yes';
631                                                   }
632                                                   
633                                                   # Returns true if the server's log_slave_updates option is enabled.
634                                                   sub has_slave_updates {
635            2                    2            14      my ( $self, $dbh ) = @_;
636            2                                 11      my $sql = q{SHOW VARIABLES LIKE 'log_slave_updates'};
637            2                                  6      MKDEBUG && _d($dbh, $sql);
638            2                                  7      my ($name, $value) = $dbh->selectrow_array($sql);
639   ***      2            33                 1044      return $value && $value =~ m/^(1|ON)$/;
640                                                   }
641                                                   
642                                                   # Extracts the replication position out of either SHOW MASTER STATUS or SHOW
643                                                   # SLAVE STATUS, and returns it as a hashref { file, position }
644                                                   sub repl_posn {
645           30                   30           201      my ( $self, $status ) = @_;
646   ***     30    100     66                  382      if ( exists $status->{file} && exists $status->{position} ) {
647                                                         # It's the output of SHOW MASTER STATUS
648                                                         return {
649           10                                136            file     => $status->{file},
650                                                            position => $status->{position},
651                                                         };
652                                                      }
653                                                      else {
654                                                         return {
655           20                                273            file     => $status->{relay_master_log_file},
656                                                            position => $status->{exec_master_log_pos},
657                                                         };
658                                                      }
659                                                   }
660                                                   
661                                                   # Gets the slave's lag.  TODO: permit using a heartbeat table.
662                                                   sub get_slave_lag {
663   ***      0                    0             0      my ( $self, $dbh ) = @_;
664   ***      0                                  0      my $stat = $self->get_slave_status($dbh);
665   ***      0                                  0      return $stat->{seconds_behind_master};
666                                                   }
667                                                   
668                                                   # Compares two replication positions and returns -1, 0, or 1 just as the cmp
669                                                   # operator does.
670                                                   sub pos_cmp {
671           15                   15           105      my ( $self, $a, $b ) = @_;
672           15                                110      return $self->pos_to_string($a) cmp $self->pos_to_string($b);
673                                                   }
674                                                   
675                                                   # Simplifies a hostname as much as possible.  For purposes of replication, a
676                                                   # hostname is really just the combination of hostname and port, since
677                                                   # replication always uses TCP connections (it does not work via sockets).  If
678                                                   # the port is the default 3306, it is omitted.  As a convenience, this sub
679                                                   # accepts either SHOW SLAVE STATUS or a DSN.
680                                                   sub short_host {
681           18                   18           119      my ( $self, $dsn ) = @_;
682           18                                 88      my ($host, $port);
683           18    100                         149      if ( $dsn->{master_host} ) {
684            4                                 24         $host = $dsn->{master_host};
685            4                                 25         $port = $dsn->{master_port};
686                                                      }
687                                                      else {
688           14                                 80         $host = $dsn->{h};
689           14                                 78         $port = $dsn->{P};
690                                                      }
691   ***     18     50     50                  424      return ($host || '[default]') . ( ($port || 3306) == 3306 ? '' : ":$port" );
      ***                   50                        
692                                                   }
693                                                   
694                                                   # Stringifies a position in a way that's string-comparable.
695                                                   sub pos_to_string {
696           30                   30           166      my ( $self, $pos ) = @_;
697           30                                131      my $fmt  = '%s/%020d';
698           30                                156      return sprintf($fmt, @{$pos}{qw(file position)});
              30                               1268   
699                                                   }
700                                                   
701                                                   sub _d {
702   ***      0                    0                    my ($package, undef, $line) = caller 0;
703   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
704   ***      0                                              map { defined $_ ? $_ : 'undef' }
705                                                           @_;
706   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
707                                                   }
708                                                   
709                                                   1;
710                                                   
711                                                   # ###########################################################################
712                                                   # End MasterSlave package
713                                                   # ###########################################################################


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
121   ***     50      0      3   if (not $method and ($$dsn{'P'} || 3306) == 3306 or $method eq 'processlist')
131   ***      0      0      0   if ($host eq 'localhost')
143   ***     50      3      0   if (not @slaves)
149          100      2      1   if (@slaves)
154   ***     50      0      3   $hash{'user'} ? :
      ***     50      0      3   $hash{'password'} ? :
179   ***     50      0      3   if (not $proc)
200   ***     50      0      3   unless my $master_status = $self->get_master_status($master)
202   ***     50      0      3   unless my $slave_status = $self->get_slave_status($slave)
204          100      1      2   unless my(@connected) = $self->get_connected_slaves($master)
208          100      1      1   if ($port != $$slave_status{'master_port'})
213   ***     50      0      1   if (not grep {$$slave_status{'master_user'} eq $$_{'user'};} @connected)
218   ***     50      1      0   if (($$slave_status{'slave_io_state'} || '') eq 'Waiting for master to send event')
231   ***     50      0      1   if ($master_log_name ne $slave_log_name or abs $master_log_num - $slave_log_num > 1)
249   ***     50      0      8   unless my $master = $self->get_slave_status($dbh)
257   ***     50     47      0   if (not $$self{'not_a_slave'}{$dbh})
264          100     46      1   if ($ss and %$ss)
277   ***     50     16      0   if (not $$self{'not_a_master'}{$dbh})
284   ***     50     16      0   if ($ms and %$ms)
286   ***     50     16      0   if ($$ms{'file'} and $$ms{'position'})
304   ***     50      3      0   if ($ms) { }
308          100      2      1   defined $result ? :
309          100      1      2   if ($stat eq 'NULL' or $stat < 0 and not $timeoutok)
332          100      1     18   if ($pos) { }
360          100      1      2   if ($self->pos_cmp($slave_pos, $master_pos) < 0)
369   ***     50      1      0   if ($EVAL_ERROR)
371   ***     50      1      0   if ($EVAL_ERROR =~ /MASTER_POS_WAIT returned NULL/) { }
373   ***     50      1      0   if (not $self->slave_is_running($slave_status)) { }
375   ***     50      1      0   if ($self->pos_cmp($slave_pos, $master_pos) != 0)
401   ***     50      0      2   if ($self->pos_cmp($s1_pos, $s2_pos) < 0) { }
      ***     50      0      2   elsif ($self->pos_cmp($s2_pos, $s1_pos) < 0) { }
415   ***     50      0      2   if ($self->slave_is_running($s1_status) or $self->slave_is_running($s2_status) or $self->pos_cmp($s1_pos, $s2_pos) != 0)
446   ***     50      0      1   unless my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
450   ***     50      0      1   unless my $gmaster_dsn = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
455   ***     50      0      1   if ($self->short_host($slave_dsn) eq $self->short_host($gmaster_dsn))
472   ***     50      1      0   if (not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status) and $self->pos_cmp($master_pos, $slave_pos) == 0) { }
488   ***     50      0      1   if ($self->short_host($mslave_status) ne $self->short_host($slave_status) or $self->pos_cmp($mslave_pos, $slave_pos) != 0)
505          100      1      1   if ($self->short_host($slave_dsn) eq $self->short_host($sib_dsn))
510   ***     50      0      1   unless my $master_dsn1 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
514   ***     50      0      1   unless my $master_dsn2 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
516   ***     50      0      1   if ($self->short_host($master_dsn1) ne $self->short_host($master_dsn2))
519   ***     50      0      1   unless my $sib_master_stat = $self->get_master_status($sib_dbh)
521   ***     50      0      1   unless $self->has_slave_updates($sib_dbh)
538   ***     50      0      1   if ($self->short_host($slave_status) ne $self->short_host($sib_dsn) or $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0)
557   ***     50      0      1   if ($self->short_host($slave_dsn) eq $self->short_host($unc_dsn))
562   ***     50      0      1   unless my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
566   ***     50      0      1   unless my $gmaster_dsn = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
569   ***     50      0      1   unless my $unc_master_dsn = $self->get_master_dsn($unc_dbh, $unc_dsn, $dsn_parser)
572   ***     50      0      1   if ($self->short_host($gmaster_dsn) ne $self->short_host($unc_master_dsn))
577   ***     50      0      1   unless my $unc_master_stat = $self->get_master_status($unc_dbh)
579   ***     50      0      1   unless $self->has_slave_updates($unc_dbh)
590   ***     50      0      1   if ($self->pos_cmp($self->repl_posn($slave_status), $self->repl_posn($master_status)) != 0)
607   ***     50      0      1   if ($self->short_host($slave_status) ne $self->short_host($unc_dsn) or $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0)
620   ***     50      0      1   unless my $stat = $self->get_slave_status($dbh)
646          100     10     20   if (exists $$status{'file'} and exists $$status{'position'}) { }
683          100      4     14   if ($$dsn{'master_host'}) { }
691   ***     50      0     18   ($port || 3306) == 3306 ? :
703   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
76    ***     66      1      3      0   defined $master_thinks_i_am and $master_thinks_i_am != $id
121   ***     33      0      3      0   not $method and ($$dsn{'P'} || 3306) == 3306
264   ***     66      1      0     46   $ss and %$ss
284   ***     33      0      0     16   $ms and %$ms
286   ***     33      0      0     16   $$ms{'file'} and $$ms{'position'}
309   ***     33      2      0      0   $stat < 0 and not $timeoutok
472   ***     33      0      0      1   not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status)
      ***     33      0      0      1   not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status) and $self->pos_cmp($master_pos, $slave_pos) == 0
639   ***     33      0      0      2   $value && $value =~ /^(1|ON)$/
646   ***     66     20      0     10   exists $$status{'file'} and exists $$status{'position'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
52           100      3      1   $level ||= 0
116   ***     50      0      3   $method ||= ''
121   ***     50      3      0   $$dsn{'P'} || 3306
218   ***     50      1      0   $$slave_status{'slave_io_state'} || ''
303          100      1      2   $ms ||= $self->get_master_status($master)
630   ***     50      7      0   $$slave_status{'slave_sql_running'} || 'No'
691   ***     50     18      0   $host || '[default]'
      ***     50     18      0   $port || 3306

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
58    ***     66      1      3      0   $$args{'dbh'} || $dp->get_dbh($dp->get_cxn_params($dsn), {'AutoCommit', 1})
76    ***     33      0      0      4   not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id
      ***     33      0      0      4   not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id or $$args{'server_ids_seen'}{$id}++
90    ***     66      0      3      1   not defined $$args{'recurse'} or $level < $$args{'recurse'}
121   ***     33      0      0      3   not $method and ($$dsn{'P'} || 3306) == 3306 or $method eq 'processlist'
231   ***     33      0      0      1   $master_log_name ne $slave_log_name or abs $master_log_num - $slave_log_num > 1
258   ***     66     42      5      0   $$self{'sths'}{$dbh}{'SLAVE_STATUS'} ||= $dbh->prepare('SHOW SLAVE STATUS')
278   ***     66     10      6      0   $$self{'sths'}{$dbh}{'MASTER_STATUS'} ||= $dbh->prepare('SHOW MASTER STATUS')
309   ***     66      1      0      2   $stat eq 'NULL' or $stat < 0 and not $timeoutok
323   ***     66     15      6      0   $$self{'sths'}{$dbh}{'STOP_SLAVE'} ||= $dbh->prepare('STOP SLAVE')
340   ***     66     15      3      0   $$self{'sths'}{$dbh}{'START_SLAVE'} ||= $dbh->prepare('START SLAVE')
415   ***     33      0      0      2   $self->slave_is_running($s1_status) or $self->slave_is_running($s2_status)
      ***     33      0      0      2   $self->slave_is_running($s1_status) or $self->slave_is_running($s2_status) or $self->pos_cmp($s1_pos, $s2_pos) != 0
488   ***     33      0      0      1   $self->short_host($mslave_status) ne $self->short_host($slave_status) or $self->pos_cmp($mslave_pos, $slave_pos) != 0
538   ***     33      0      0      1   $self->short_host($slave_status) ne $self->short_host($sib_dsn) or $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0
607   ***     33      0      0      1   $self->short_host($slave_status) ne $self->short_host($unc_dsn) or $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0


Covered Subroutines
-------------------

Subroutine             Count Location                                          
---------------------- ----- --------------------------------------------------
BEGIN                      1 /home/daniel/dev/maatkit/common/MasterSlave.pm:20 
BEGIN                      1 /home/daniel/dev/maatkit/common/MasterSlave.pm:21 
BEGIN                      1 /home/daniel/dev/maatkit/common/MasterSlave.pm:25 
BEGIN                      1 /home/daniel/dev/maatkit/common/MasterSlave.pm:26 
BEGIN                      1 /home/daniel/dev/maatkit/common/MasterSlave.pm:27 
BEGIN                      1 /home/daniel/dev/maatkit/common/MasterSlave.pm:31 
catchup_to_master          3 /home/daniel/dev/maatkit/common/MasterSlave.pm:351
catchup_to_same_pos        2 /home/daniel/dev/maatkit/common/MasterSlave.pm:394
change_master_to           3 /home/daniel/dev/maatkit/common/MasterSlave.pm:426
detach_slave               1 /home/daniel/dev/maatkit/common/MasterSlave.pm:617
find_slave_hosts           3 /home/daniel/dev/maatkit/common/MasterSlave.pm:115
get_connected_slaves       3 /home/daniel/dev/maatkit/common/MasterSlave.pm:173
get_master_dsn             8 /home/daniel/dev/maatkit/common/MasterSlave.pm:248
get_master_status         16 /home/daniel/dev/maatkit/common/MasterSlave.pm:276
get_slave_status          47 /home/daniel/dev/maatkit/common/MasterSlave.pm:256
has_slave_updates          2 /home/daniel/dev/maatkit/common/MasterSlave.pm:635
is_master_of               3 /home/daniel/dev/maatkit/common/MasterSlave.pm:199
make_sibling_of_master     1 /home/daniel/dev/maatkit/common/MasterSlave.pm:441
make_slave_of_sibling      2 /home/daniel/dev/maatkit/common/MasterSlave.pm:501
make_slave_of_uncle        1 /home/daniel/dev/maatkit/common/MasterSlave.pm:553
new                        1 /home/daniel/dev/maatkit/common/MasterSlave.pm:34 
pos_cmp                   15 /home/daniel/dev/maatkit/common/MasterSlave.pm:671
pos_to_string             30 /home/daniel/dev/maatkit/common/MasterSlave.pm:696
recurse_to_slaves          4 /home/daniel/dev/maatkit/common/MasterSlave.pm:51 
repl_posn                 30 /home/daniel/dev/maatkit/common/MasterSlave.pm:645
short_host                18 /home/daniel/dev/maatkit/common/MasterSlave.pm:681
slave_is_running           7 /home/daniel/dev/maatkit/common/MasterSlave.pm:629
start_slave               19 /home/daniel/dev/maatkit/common/MasterSlave.pm:331
stop_slave                21 /home/daniel/dev/maatkit/common/MasterSlave.pm:322
wait_for_master            3 /home/daniel/dev/maatkit/common/MasterSlave.pm:300

Uncovered Subroutines
---------------------

Subroutine             Count Location                                          
---------------------- ----- --------------------------------------------------
_d                         0 /home/daniel/dev/maatkit/common/MasterSlave.pm:702
get_slave_lag              0 /home/daniel/dev/maatkit/common/MasterSlave.pm:663


