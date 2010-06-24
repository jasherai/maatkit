---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/MasterSlave.pm   82.1   55.4   49.1   91.7    n/a    7.3   71.0
MasterSlave.t                  98.3   50.0   30.0   91.7    n/a   92.7   90.5
Total                          87.2   54.8   47.6   91.7    n/a  100.0   75.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:34:18 2010
Finish:       Thu Jun 24 19:34:18 2010

Run:          MasterSlave.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:34:19 2010
Finish:       Thu Jun 24 19:34:56 2010

/home/daniel/dev/maatkit/common/MasterSlave.pm

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
18                                                    # MasterSlave package $Revision: 6452 $
19                                                    # ###########################################################################
20             1                    1             5   use strict;
               1                                  2   
               1                                  7   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
22                                                    
23                                                    package MasterSlave;
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1             7   use List::Util qw(min max);
               1                                  2   
               1                                 11   
27             1                    1             9   use Data::Dumper;
               1                                  2   
               1                                  8   
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    $Data::Dumper::Indent    = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 15   
32                                                    
33                                                    sub new {
34             1                    1             9      my ( $class, %args ) = @_;
35             1                                  5      my $self = { %args };
36             1                                 12      return bless $self, $class;
37                                                    }
38                                                    
39                                                    # Descends to slaves by examining SHOW SLAVE HOSTS.  Arguments is a hashref:
40                                                    #
41                                                    # * dbh           (Optional) a DBH.
42                                                    # * dsn           The DSN to connect to; if no DBH, will connect using this.
43                                                    # * dsn_parser    A DSNParser object.
44                                                    # * recurse       How many levels to recurse. 0 = none, undef = infinite.
45                                                    # * callback      Code to execute after finding a new slave.
46                                                    # * skip_callback Optional: execute with slaves that will be skipped.
47                                                    # * method        Optional: whether to prefer HOSTS over PROCESSLIST
48                                                    # * parent        Optional: the DSN from which this call descended.
49                                                    #
50                                                    # The callback gets the slave's DSN, dbh, parent, and the recursion level as args.
51                                                    # The recursion is tail recursion.
52                                                    sub recurse_to_slaves {
53             4                    4            33      my ( $self, $args, $level ) = @_;
54             4           100                   29      $level ||= 0;
55             4                                 24      my $dp   = $args->{dsn_parser};
56             4                                 25      my $dsn  = $args->{dsn};
57                                                    
58             4                                 16      my $dbh;
59             4                                 18      eval {
60    ***      4            66                   58         $dbh = $args->{dbh} || $dp->get_dbh(
61                                                             $dp->get_cxn_params($dsn), { AutoCommit => 1 });
62             4                               1643         MKDEBUG && _d('Connected to', $dp->as_string($dsn));
63                                                       };
64    ***      4     50                          27      if ( $EVAL_ERROR ) {
65    ***      0      0                           0         print STDERR "Cannot connect to ", $dp->as_string($dsn), "\n"
66                                                             or die "Cannot print: $OS_ERROR";
67    ***      0                                  0         return;
68                                                       }
69                                                    
70                                                       # SHOW SLAVE HOSTS sometimes has obsolete information.  Verify that this
71                                                       # server has the ID its master thought, and that we have not seen it before
72                                                       # in any case.
73             4                                 20      my $sql  = 'SELECT @@SERVER_ID';
74             4                                 14      MKDEBUG && _d($sql);
75             4                                 21      my ($id) = $dbh->selectrow_array($sql);
76             4                                837      MKDEBUG && _d('Working on server ID', $id);
77             4                                 33      my $master_thinks_i_am = $dsn->{server_id};
78    ***      4     50     66                  165      if ( !defined $id
      ***                   33                        
      ***                   33                        
79                                                           || ( defined $master_thinks_i_am && $master_thinks_i_am != $id )
80                                                           || $args->{server_ids_seen}->{$id}++
81                                                       ) {
82    ***      0                                  0         MKDEBUG && _d('Server ID seen, or not what master said');
83    ***      0      0                           0         if ( $args->{skip_callback} ) {
84    ***      0                                  0            $args->{skip_callback}->($dsn, $dbh, $level, $args->{parent});
85                                                          }
86    ***      0                                  0         return;
87                                                       }
88                                                    
89                                                       # Call the callback!
90             4                                 48      $args->{callback}->($dsn, $dbh, $level, $args->{parent});
91                                                    
92    ***      4    100     66                  164      if ( !defined $args->{recurse} || $level < $args->{recurse} ) {
93                                                    
94                                                          # Find the slave hosts.  Eliminate hosts that aren't slaves of me (as
95                                                          # revealed by server_id and master_id).
96    ***      3     50                          70         my @slaves =
97             3                                 47            grep { !$_->{master_id} || $_->{master_id} == $id } # Only my slaves.
98                                                             $self->find_slave_hosts($dp, $dbh, $dsn, $args->{method});
99                                                    
100            3                                 38         foreach my $slave ( @slaves ) {
101            3                                 10            MKDEBUG && _d('Recursing from',
102                                                               $dp->as_string($dsn), 'to', $dp->as_string($slave));
103            3                                100            $self->recurse_to_slaves(
104                                                               { %$args, dsn => $slave, dbh => undef, parent => $dsn }, $level + 1 );
105                                                         }
106                                                      }
107                                                   }
108                                                   
109                                                   # Finds slave hosts by trying different methods.  The default preferred method
110                                                   # is trying SHOW PROCESSLIST (processlist) and guessing which ones are slaves,
111                                                   # and if that doesn't reveal anything, then try SHOW SLAVE STATUS (hosts).
112                                                   # One exception is if the port is non-standard (3306), indicating that the port
113                                                   # from SHOW SLAVE HOSTS may be important.  Then only the hosts methods is used.
114                                                   #
115                                                   # Returns a list of DSN hashes.  Optional extra keys in the DSN hash are
116                                                   # master_id and server_id.  Also, the 'source' key is either 'processlist' or
117                                                   # 'hosts'.
118                                                   #
119                                                   # If a method is given, it becomes the preferred (first tried) method.
120                                                   # Searching stops as soon as a method finds slaves.
121                                                   sub find_slave_hosts {
122            3                    3            30      my ( $self, $dsn_parser, $dbh, $dsn, $method ) = @_;
123                                                   
124            3                                 23      my @methods = qw(processlist hosts);
125   ***      3     50                          18      if ( $method ) {
126                                                         # Remove all but the given method.
127   ***      0                                  0         @methods = grep { $_ ne $method } @methods;
      ***      0                                  0   
128                                                         # Add given method to the head of the list.
129   ***      0                                  0         unshift @methods, $method;
130                                                      }
131                                                      else {
132   ***      3     50     50                   40         if ( ($dsn->{P} || 3306) != 3306 ) {
133            3                                 10            MKDEBUG && _d('Port number is non-standard; using only hosts method');
134            3                                 22            @methods = qw(hosts);
135                                                         }
136                                                      }
137            3                                 11      MKDEBUG && _d('Looking for slaves on', $dsn_parser->as_string($dsn),
138                                                         'using methods', @methods);
139                                                   
140            3                                 10      my @slaves;
141                                                      METHOD:
142            3                                 24      foreach my $method ( @methods ) {
143            3                                 20         my $find_slaves = "_find_slaves_by_$method";
144            3                                 11         MKDEBUG && _d('Finding slaves with', $find_slaves);
145            3                                 36         @slaves = $self->$find_slaves($dsn_parser, $dbh, $dsn);
146            3    100                          28         last METHOD if @slaves;
147                                                      }
148                                                   
149            3                                 10      MKDEBUG && _d('Found', scalar(@slaves), 'slaves');
150            3                                 22      return @slaves;
151                                                   }
152                                                   
153                                                   sub _find_slaves_by_processlist {
154   ***      0                    0             0      my ( $self, $dsn_parser, $dbh, $dsn ) = @_;
155                                                   
156   ***      0                                  0      my @slaves = map  {
157   ***      0                                  0         my $slave        = $dsn_parser->parse("h=$_", $dsn);
158   ***      0                                  0         $slave->{source} = 'processlist';
159   ***      0                                  0         $slave;
160                                                      }
161   ***      0                                  0      grep { $_ }
162                                                      map  {
163   ***      0                                  0         my ( $host ) = $_->{host} =~ m/^([^:]+):/;
164   ***      0      0                           0         if ( $host eq 'localhost' ) {
165   ***      0                                  0            $host = '127.0.0.1'; # Replication never uses sockets.
166                                                         }
167   ***      0                                  0         $host;
168                                                      } $self->get_connected_slaves($dbh);
169                                                   
170   ***      0                                  0      return @slaves;
171                                                   }
172                                                   
173                                                   # SHOW SLAVE HOSTS is significantly less reliable.
174                                                   # Machines tend to share the host list around with every machine in the
175                                                   # replication hierarchy, but they don't update each other when machines
176                                                   # disconnect or change to use a different master or something.  So there is
177                                                   # lots of cruft in SHOW SLAVE HOSTS.
178                                                   sub _find_slaves_by_hosts {
179            3                    3            24      my ( $self, $dsn_parser, $dbh, $dsn ) = @_;
180                                                   
181            3                                 13      my @slaves;
182            3                                 13      my $sql = 'SHOW SLAVE HOSTS';
183            3                                 11      MKDEBUG && _d($dbh, $sql);
184            3                                 12      @slaves = @{$dbh->selectall_arrayref($sql, { Slice => {} })};
               3                                107   
185                                                   
186                                                      # Convert SHOW SLAVE HOSTS into DSN hashes.
187            3    100                          53      if ( @slaves ) {
188            2                                  7         MKDEBUG && _d('Found some SHOW SLAVE HOSTS info');
189            3                                 12         @slaves = map {
190            2                                 13            my %hash;
191            3                                 34            @hash{ map { lc $_ } keys %$_ } = values %$_;
              15                                115   
192   ***      3     50                          54            my $spec = "h=$hash{host},P=$hash{port}"
      ***            50                               
193                                                               . ( $hash{user} ? ",u=$hash{user}" : '')
194                                                               . ( $hash{password} ? ",p=$hash{password}" : '');
195            3                                 27            my $dsn           = $dsn_parser->parse($spec, $dsn);
196            3                               1490            $dsn->{server_id} = $hash{server_id};
197            3                                 19            $dsn->{master_id} = $hash{master_id};
198            3                                 16            $dsn->{source}    = 'hosts';
199            3                                 31            $dsn;
200                                                         } @slaves;
201                                                      }
202                                                   
203            3                                 24      return @slaves;
204                                                   }
205                                                   
206                                                   # Returns PROCESSLIST entries of connected slaves, normalized to lowercase
207                                                   # column names.
208                                                   sub get_connected_slaves {
209            3                    3            23      my ( $self, $dbh ) = @_;
210                                                   
211                                                      # Check for the PROCESS privilege.  SHOW GRANTS operates differently
212                                                      # before 4.1.2: it requires "FROM ..." and it's not until 4.0.6 that
213                                                      # CURRENT_USER() is available.  So for versions <4.1.2 we get current
214                                                      # user with USER(), quote it, and then add it to statement.
215            3                                 15      my $show = "SHOW GRANTS FOR ";
216            3                                 14      my $user = 'CURRENT_USER()';
217            3                                 24      my $vp   = $self->{VersionParser};
218   ***      3     50     33                   61      if ( $vp && !$vp->version_ge($dbh, '4.1.2') ) {
219   ***      0                                  0         $user = $dbh->selectrow_arrayref('SELECT USER()')->[0];
220   ***      0                                  0         $user =~ s/([^@]+)@(.+)/'$1'\@'$2'/;
221                                                      }
222            3                                 21      my $sql = $show . $user;
223            3                                 11      MKDEBUG && _d($dbh, $sql);
224                                                   
225            3                                 10      my $proc;
226            3                                 14      eval {
227            3                               1172         $proc = grep {
228            3                                 12            m/ALL PRIVILEGES.*?\*\.\*|PROCESS/
229            3                                 13         } @{$dbh->selectcol_arrayref($sql)};
230                                                      };
231   ***      3     50                          25      if ( $EVAL_ERROR ) {
232                                                   
233   ***      0      0                           0         if ( $EVAL_ERROR =~ m/no such grant defined for user/ ) {
234                                                            # Try again without a host.
235   ***      0                                  0            MKDEBUG && _d('Retrying SHOW GRANTS without host; error:',
236                                                               $EVAL_ERROR);
237   ***      0                                  0            ($user) = split('@', $user);
238   ***      0                                  0            $sql    = $show . $user;
239   ***      0                                  0            MKDEBUG && _d($sql);
240   ***      0                                  0            eval {
241   ***      0                                  0               $proc = grep {
242   ***      0                                  0                  m/ALL PRIVILEGES.*?\*\.\*|PROCESS/
243   ***      0                                  0               } @{$dbh->selectcol_arrayref($sql)};
244                                                            };
245                                                         }
246                                                   
247                                                         # The 2nd try above might have cleared $EVAL_ERROR.
248                                                         # If not, die now.
249   ***      0      0                           0         die "Failed to $sql: $EVAL_ERROR" if $EVAL_ERROR;
250                                                      }
251   ***      3     50                          21      if ( !$proc ) {
252   ***      0                                  0         die "You do not have the PROCESS privilege";
253                                                      }
254                                                   
255            3                                 14      $sql = 'SHOW PROCESSLIST';
256            3                                 10      MKDEBUG && _d($dbh, $sql);
257                                                      # It's probably a slave if it's doing a binlog dump.
258           11                                 99      grep { $_->{command} =~ m/Binlog Dump/i }
              11                                 63   
259                                                      map  { # Lowercase the column names
260            3                                 27         my %hash;
261           11                                115         @hash{ map { lc $_ } keys %$_ } = values %$_;
              88                                649   
262           11                                101         \%hash;
263                                                      }
264            3                                 13      @{$dbh->selectall_arrayref($sql, { Slice => {} })};
265                                                   }
266                                                   
267                                                   # Verifies that $master is really the master of $slave.  This is not an exact
268                                                   # science, but there is a decent chance of catching some obvious cases when it
269                                                   # is not the master.  If not the master, it dies; otherwise returns true.
270                                                   sub is_master_of {
271            3                    3            25      my ( $self, $master, $slave ) = @_;
272   ***      3     50                          33      my $master_status = $self->get_master_status($master)
273                                                         or die "The server specified as a master is not a master";
274   ***      3     50                          23      my $slave_status  = $self->get_slave_status($slave)
275                                                         or die "The server specified as a slave is not a slave";
276            3    100                          31      my @connected     = $self->get_connected_slaves($master)
277                                                         or die "The server specified as a master has no connected slaves";
278            2                                  8      my (undef, $port) = $master->selectrow_array('SHOW VARIABLES LIKE "port"');
279                                                   
280            2    100                        1616      if ( $port != $slave_status->{master_port} ) {
281            1                                  4         die "The slave is connected to $slave_status->{master_port} "
282                                                            . "but the master's port is $port";
283                                                      }
284                                                   
285   ***      1     50                           7      if ( !grep { $slave_status->{master_user} eq $_->{user} } @connected ) {
               1                                 15   
286   ***      0                                  0         die "I don't see any slave I/O thread connected with user "
287                                                            . $slave_status->{master_user};
288                                                      }
289                                                   
290   ***      1     50     50                   14      if ( ($slave_status->{slave_io_state} || '')
291                                                         eq 'Waiting for master to send event' )
292                                                      {
293                                                         # The slave thinks its I/O thread is caught up to the master.  Let's
294                                                         # compare and make sure the master and slave are reasonably close to each
295                                                         # other.  Note that this is one of the few places where I check the I/O
296                                                         # thread positions instead of the SQL thread positions!
297                                                         # Master_Log_File/Read_Master_Log_Pos is the I/O thread's position on the
298                                                         # master.
299            1                                 32         my ( $master_log_name, $master_log_num )
300                                                            = $master_status->{file} =~ m/^(.*?)\.0*([1-9][0-9]*)$/;
301            1                                 15         my ( $slave_log_name, $slave_log_num )
302                                                            = $slave_status->{master_log_file} =~ m/^(.*?)\.0*([1-9][0-9]*)$/;
303   ***      1     50     33                   31         if ( $master_log_name ne $slave_log_name
304                                                            || abs($master_log_num - $slave_log_num) > 1 )
305                                                         {
306   ***      0                                  0            die "The slave thinks it is reading from "
307                                                               . "$slave_status->{master_log_file},  but the "
308                                                               . "master is writing to $master_status->{file}";
309                                                         }
310                                                      }
311            1                                 42      return 1;
312                                                   }
313                                                   
314                                                   # Figures out how to connect to the master, by examining SHOW SLAVE STATUS.  But
315                                                   # does NOT use the value from Master_User for the username, because typically we
316                                                   # want to perform operations as the username that was specified (usually to the
317                                                   # program's --user option, or in a DSN), rather than as the replication user,
318                                                   # which is often restricted.
319                                                   sub get_master_dsn {
320            8                    8            72      my ( $self, $dbh, $dsn, $dsn_parser ) = @_;
321   ***      8     50                          66      my $master = $self->get_slave_status($dbh) or return undef;
322            8                                 85      my $spec   = "h=$master->{master_host},P=$master->{master_port}";
323            8                                 96      return       $dsn_parser->parse($spec, $dsn);
324                                                   }
325                                                   
326                                                   # Gets SHOW SLAVE STATUS, with column names all lowercased, as a hashref.
327                                                   sub get_slave_status {
328           49                   49           388      my ( $self, $dbh ) = @_;
329   ***     49     50                         806      if ( !$self->{not_a_slave}->{$dbh} ) {
330   ***     49            66                  532         my $sth = $self->{sths}->{$dbh}->{SLAVE_STATUS}
331                                                               ||= $dbh->prepare('SHOW SLAVE STATUS');
332           49                                284         MKDEBUG && _d($dbh, 'SHOW SLAVE STATUS');
333           49                             866836         $sth->execute();
334           49                                338         my ($ss) = @{$sth->fetchall_arrayref({})};
              49                                610   
335                                                   
336   ***     49    100     66                 1483         if ( $ss && %$ss ) {
337           47                                832            $ss = { map { lc($_) => $ss->{$_} } keys %$ss }; # lowercase the keys
            1786                              13627   
338           47                               1605            return $ss;
339                                                         }
340                                                   
341            2                                  9         MKDEBUG && _d('This server returns nothing for SHOW SLAVE STATUS');
342            2                                150         $self->{not_a_slave}->{$dbh}++;
343                                                      }
344                                                   }
345                                                   
346                                                   # Gets SHOW MASTER STATUS, with column names all lowercased, as a hashref.
347                                                   sub get_master_status {
348           19                   19           139      my ( $self, $dbh ) = @_;
349   ***     19     50                         333      if ( !$self->{not_a_master}->{$dbh} ) {
350   ***     19            66                  180         my $sth = $self->{sths}->{$dbh}->{MASTER_STATUS}
351                                                               ||= $dbh->prepare('SHOW MASTER STATUS');
352           19                                171         MKDEBUG && _d($dbh, 'SHOW MASTER STATUS');
353           19                               4026         $sth->execute();
354           19                                105         my ($ms) = @{$sth->fetchall_arrayref({})};
              19                                224   
355                                                   
356   ***     19     50     33                  555         if ( $ms && %$ms ) {
357           19                                176            $ms = { map { lc($_) => $ms->{$_} } keys %$ms }; # lowercase the keys
              76                                739   
358   ***     19     50     33                  402            if ( $ms->{file} && $ms->{position} ) {
359           19                                207               return $ms;
360                                                            }
361                                                         }
362                                                   
363   ***      0                                  0         MKDEBUG && _d('This server returns nothing for SHOW MASTER STATUS');
364   ***      0                                  0         $self->{not_a_master}->{$dbh}++;
365                                                      }
366                                                   }
367                                                   
368                                                   # Waits for a slave to catch up to the master, with MASTER_POS_WAIT().  Returns
369                                                   # the return value of MASTER_POS_WAIT().  $ms is the optional result of calling
370                                                   # get_master_status().
371                                                   sub wait_for_master {
372            3                    3            47      my ( $self, $master, $slave, $time, $timeoutok, $ms ) = @_;
373            3                                 13      my $result;
374   ***      3     50                          25      $time = 60 unless defined $time;
375            3                                 10      MKDEBUG && _d('Waiting', $time, 'seconds for slave to catch up to master;',
376                                                         'timeout ok:', ($timeoutok ? 'yes' : 'no'));
377            3           100                   35      $ms ||= $self->get_master_status($master);
378   ***      3     50                          24      if ( $ms ) {
379            3                                 44         my $query = "SELECT MASTER_POS_WAIT('$ms->{file}', $ms->{position}, $time)";
380            3                                 12         MKDEBUG && _d($slave, $query);
381            3                                 13         ($result) = $slave->selectrow_array($query);
382   ***      3     50                      428428         my $stat = defined $result ? $result : 'NULL';
383            3                                 13         MKDEBUG && _d('Result of waiting:', $stat);
384   ***      3     50     33                   97         if ( $stat eq 'NULL' || $stat < 0 && !$timeoutok ) {
      ***                   33                        
385   ***      0                                  0            die "MASTER_POS_WAIT returned $stat";
386                                                         }
387                                                      }
388                                                      else {
389   ***      0                                  0         MKDEBUG && _d('Not waiting: this server is not a master');
390                                                      }
391            3                                 40      return $result;
392                                                   }
393                                                   
394                                                   # Executes STOP SLAVE.
395                                                   sub stop_slave {
396           27                   27           196      my ( $self, $dbh ) = @_;
397   ***     27            66                  316      my $sth = $self->{sths}->{$dbh}->{STOP_SLAVE}
398                                                            ||= $dbh->prepare('STOP SLAVE');
399           27                                177      MKDEBUG && _d($dbh, $sth->{Statement});
400           27                             517986      $sth->execute();
401                                                   }
402                                                   
403                                                   # Executes START SLAVE, optionally with UNTIL.
404                                                   sub start_slave {
405           25                   25           210      my ( $self, $dbh, $pos ) = @_;
406           25    100                         167      if ( $pos ) {
407                                                         # Just like with CHANGE MASTER TO, you can't quote the position.
408            1                                 15         my $sql = "START SLAVE UNTIL MASTER_LOG_FILE='$pos->{file}', "
409                                                                 . "MASTER_LOG_POS=$pos->{position}";
410            1                                  4         MKDEBUG && _d($dbh, $sql);
411            1                               1190         $dbh->do($sql);
412                                                      }
413                                                      else {
414   ***     24            66                  303         my $sth = $self->{sths}->{$dbh}->{START_SLAVE}
415                                                               ||= $dbh->prepare('START SLAVE');
416           24                                121         MKDEBUG && _d($dbh, $sth->{Statement});
417           24                              19295         $sth->execute();
418                                                      }
419                                                   }
420                                                   
421                                                   # Waits for the slave to catch up to its master, using START SLAVE UNTIL.  When
422                                                   # complete, the slave is caught up to the master, and the slave process is
423                                                   # stopped on both servers.
424                                                   sub catchup_to_master {
425            3                    3            30      my ( $self, $slave, $master, $time ) = @_;
426            3                                 22      $self->stop_slave($master);
427            3                                 27      $self->stop_slave($slave);
428            3                                 35      my $slave_status  = $self->get_slave_status($slave);
429            3                                 38      my $slave_pos     = $self->repl_posn($slave_status);
430            3                                 22      my $master_status = $self->get_master_status($master);
431            3                                 23      my $master_pos    = $self->repl_posn($master_status);
432            3                                 11      MKDEBUG && _d('Master position:', $self->pos_to_string($master_pos),
433                                                         'Slave position:', $self->pos_to_string($slave_pos));
434            3    100                          30      if ( $self->pos_cmp($slave_pos, $master_pos) < 0 ) {
435            1                                  4         MKDEBUG && _d('Waiting for slave to catch up to master');
436            1                                  8         $self->start_slave($slave, $master_pos);
437                                                         # The slave may catch up instantly and stop, in which case MASTER_POS_WAIT
438                                                         # will return NULL.  We must catch this; if it returns NULL, then we check
439                                                         # that its position is as desired.
440            1                                 16         eval {
441            1                                 12            $self->wait_for_master($master, $slave, $time, 0, $master_status);
442                                                         };
443   ***      1     50                          47         if ( $EVAL_ERROR ) {
444   ***      0                                  0            MKDEBUG && _d($EVAL_ERROR);
445   ***      0      0                           0            if ( $EVAL_ERROR =~ m/MASTER_POS_WAIT returned NULL/ ) {
446   ***      0                                  0               $slave_status = $self->get_slave_status($slave);
447   ***      0      0                           0               if ( !$self->slave_is_running($slave_status) ) {
448   ***      0                                  0                  MKDEBUG && _d('Master position:',
449                                                                     $self->pos_to_string($master_pos),
450                                                                     'Slave position:', $self->pos_to_string($slave_pos));
451   ***      0                                  0                  $slave_pos = $self->repl_posn($slave_status);
452   ***      0      0                           0                  if ( $self->pos_cmp($slave_pos, $master_pos) != 0 ) {
453   ***      0                                  0                     die "$EVAL_ERROR but slave has not caught up to master";
454                                                                  }
455   ***      0                                  0                  MKDEBUG && _d('Slave is caught up to master and stopped');
456                                                               }
457                                                               else {
458   ***      0                                  0                  die "$EVAL_ERROR but slave was still running";
459                                                               }
460                                                            }
461                                                            else {
462   ***      0                                  0               die $EVAL_ERROR;
463                                                            }
464                                                         }
465                                                      }
466                                                   }
467                                                   
468                                                   # Makes one server catch up to the other in replication.  When complete, both
469                                                   # servers are stopped and at the same position.
470                                                   sub catchup_to_same_pos {
471            2                    2            19      my ( $self, $s1_dbh, $s2_dbh ) = @_;
472            2                                 16      $self->stop_slave($s1_dbh);
473            2                                 19      $self->stop_slave($s2_dbh);
474            2                                 22      my $s1_status = $self->get_slave_status($s1_dbh);
475            2                                 15      my $s2_status = $self->get_slave_status($s2_dbh);
476            2                                 18      my $s1_pos    = $self->repl_posn($s1_status);
477            2                                 15      my $s2_pos    = $self->repl_posn($s2_status);
478   ***      2     50                          14      if ( $self->pos_cmp($s1_pos, $s2_pos) < 0 ) {
      ***            50                               
479   ***      0                                  0         $self->start_slave($s1_dbh, $s2_pos);
480                                                      }
481                                                      elsif ( $self->pos_cmp($s2_pos, $s1_pos) < 0 ) {
482   ***      0                                  0         $self->start_slave($s2_dbh, $s1_pos);
483                                                      }
484                                                   
485                                                      # Re-fetch the replication statuses and positions.
486            2                                 17      $s1_status = $self->get_slave_status($s1_dbh);
487            2                                 30      $s2_status = $self->get_slave_status($s2_dbh);
488            2                                 29      $s1_pos    = $self->repl_posn($s1_status);
489            2                                 18      $s2_pos    = $self->repl_posn($s2_status);
490                                                   
491                                                      # Verify that they are both stopped and are at the same position.
492   ***      2     50     33                   16      if ( $self->slave_is_running($s1_status)
      ***                   33                        
493                                                        || $self->slave_is_running($s2_status)
494                                                        || $self->pos_cmp($s1_pos, $s2_pos) != 0)
495                                                      {
496   ***      0                                  0         die "The servers aren't both stopped at the same position";
497                                                      }
498                                                   
499                                                   }
500                                                   
501                                                   # Uses CHANGE MASTER TO to change a slave's master.
502                                                   sub change_master_to {
503            3                    3            25      my ( $self, $dbh, $master_dsn, $master_pos ) = @_;
504            3                                 22      $self->stop_slave($dbh);
505                                                      # Don't prepare a $sth because CHANGE MASTER TO doesn't like quotes around
506                                                      # port numbers, etc.  It's possible to specify the bind type, but it's easier
507                                                      # to just not use a prepared statement.
508            3                                 15      MKDEBUG && _d(Dumper($master_dsn), Dumper($master_pos));
509            3                                 63      my $sql = "CHANGE MASTER TO MASTER_HOST='$master_dsn->{h}', "
510                                                         . "MASTER_PORT= $master_dsn->{P}, MASTER_LOG_FILE='$master_pos->{file}', "
511                                                         . "MASTER_LOG_POS=$master_pos->{position}";
512            3                                 18      MKDEBUG && _d($dbh, $sql);
513            3                             413153      $dbh->do($sql);
514                                                   }
515                                                   
516                                                   # Moves a slave to be a slave of its grandmaster: a sibling of its master.
517                                                   sub make_sibling_of_master {
518            1                    1            13      my ( $self, $slave_dbh, $slave_dsn, $dsn_parser, $timeout) = @_;
519                                                   
520                                                      # Connect to the master and the grand-master, and verify that the master is
521                                                      # also a slave.  Also verify that the grand-master isn't the slave!
522                                                      # (master-master replication).
523   ***      1     50                          14      my $master_dsn  = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
524                                                         or die "This server is not a slave";
525            1                                591      my $master_dbh  = $dsn_parser->get_dbh(
526                                                         $dsn_parser->get_cxn_params($master_dsn), { AutoCommit => 1 });
527   ***      1     50                         486      my $gmaster_dsn
528                                                         = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
529                                                         or die "This server's master is not a slave";
530            1                                539      my $gmaster_dbh = $dsn_parser->get_dbh(
531                                                         $dsn_parser->get_cxn_params($gmaster_dsn), { AutoCommit => 1 });
532   ***      1     50                         468      if ( $self->short_host($slave_dsn) eq $self->short_host($gmaster_dsn) ) {
533   ***      0                                  0         die "The slave's master's master is the slave: master-master replication";
534                                                      }
535                                                   
536                                                      # Stop the master, and make the slave catch up to it.
537            1                                  8      $self->stop_slave($master_dbh);
538            1                                 13      $self->catchup_to_master($slave_dbh, $master_dbh, $timeout);
539            1                                 10      $self->stop_slave($slave_dbh);
540                                                   
541                                                      # Get the replication statuses and positions.
542            1                                 10      my $master_status = $self->get_master_status($master_dbh);
543            1                                  8      my $mslave_status = $self->get_slave_status($master_dbh);
544            1                                  8      my $slave_status  = $self->get_slave_status($slave_dbh);
545            1                                  8      my $master_pos    = $self->repl_posn($master_status);
546            1                                  7      my $slave_pos     = $self->repl_posn($slave_status);
547                                                   
548                                                      # Verify that they are both stopped and are at the same position.
549   ***      1     50     33                   13      if ( !$self->slave_is_running($mslave_status)
      ***                   33                        
550                                                        && !$self->slave_is_running($slave_status)
551                                                        && $self->pos_cmp($master_pos, $slave_pos) == 0)
552                                                      {
553            1                                  8         $self->change_master_to($slave_dbh, $gmaster_dsn,
554                                                            $self->repl_posn($mslave_status)); # Note it's not $master_pos!
555                                                      }
556                                                      else {
557   ***      0                                  0         die "The servers aren't both stopped at the same position";
558                                                      }
559                                                   
560                                                      # Verify that they have the same master and are at the same position.
561            1                                 27      $mslave_status = $self->get_slave_status($master_dbh);
562            1                                 21      $slave_status  = $self->get_slave_status($slave_dbh);
563            1                                 20      my $mslave_pos = $self->repl_posn($mslave_status);
564            1                                  8      $slave_pos     = $self->repl_posn($slave_status);
565   ***      1     50     33                    9      if ( $self->short_host($mslave_status) ne $self->short_host($slave_status)
566                                                        || $self->pos_cmp($mslave_pos, $slave_pos) != 0)
567                                                      {
568   ***      0                                  0         die "The servers don't have the same master/position after the change";
569                                                      }
570                                                   }
571                                                   
572                                                   # Moves a slave to be a slave of its sibling.
573                                                   # 1. Connect to the sibling and verify that it has the same master.
574                                                   # 2. Stop the slave processes on the server and its sibling.
575                                                   # 3. If one of the servers is behind the other, make it catch up.
576                                                   # 4. Point the slave to its sibling.
577                                                   sub make_slave_of_sibling {
578            2                    2            21      my ( $self, $slave_dbh, $slave_dsn, $sib_dbh, $sib_dsn,
579                                                           $dsn_parser, $timeout) = @_;
580                                                   
581                                                      # Verify that the sibling is a different server.
582            2    100                          17      if ( $self->short_host($slave_dsn) eq $self->short_host($sib_dsn) ) {
583            1                                  4         die "You are trying to make the slave a slave of itself";
584                                                      }
585                                                   
586                                                      # Verify that the sibling has the same master, and that it is a master.
587   ***      1     50                          10      my $master_dsn1 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
588                                                         or die "This server is not a slave";
589            1                                531      my $master_dbh1 = $dsn_parser->get_dbh(
590                                                         $dsn_parser->get_cxn_params($master_dsn1), { AutoCommit => 1 });
591   ***      1     50                         506      my $master_dsn2 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
592                                                         or die "The sibling is not a slave";
593   ***      1     50                         517      if ( $self->short_host($master_dsn1) ne $self->short_host($master_dsn2) ) {
594   ***      0                                  0         die "This server isn't a sibling of the slave";
595                                                      }
596   ***      1     50                           8      my $sib_master_stat = $self->get_master_status($sib_dbh)
597                                                         or die "Binary logging is not enabled on the sibling";
598   ***      1     50                           9      die "The log_slave_updates option is not enabled on the sibling"
599                                                         unless $self->has_slave_updates($sib_dbh);
600                                                   
601                                                      # Stop the slave and its sibling, then if one is behind the other, make it
602                                                      # catch up.
603            1                                 15      $self->catchup_to_same_pos($slave_dbh, $sib_dbh);
604                                                   
605                                                      # Actually change the slave's master to its sibling.
606            1                                 12      $sib_master_stat = $self->get_master_status($sib_dbh);
607            1                                 11      $self->change_master_to($slave_dbh, $sib_dsn,
608                                                            $self->repl_posn($sib_master_stat));
609                                                   
610                                                      # Verify that the slave's master is the sibling and that it is at the same
611                                                      # position.
612            1                                 26      my $slave_status = $self->get_slave_status($slave_dbh);
613            1                                 11      my $slave_pos    = $self->repl_posn($slave_status);
614            1                                  9      $sib_master_stat = $self->get_master_status($sib_dbh);
615   ***      1     50     33                   11      if ( $self->short_host($slave_status) ne $self->short_host($sib_dsn)
616                                                        || $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0)
617                                                      {
618   ***      0                                  0         die "After changing the slave's master, it isn't a slave of the sibling, "
619                                                            . "or it has a different replication position than the sibling";
620                                                      }
621                                                   }
622                                                   
623                                                   # Moves a slave to be a slave of its uncle.
624                                                   #  1. Connect to the slave's master and its uncle, and verify that both have the
625                                                   #     same master.  (Their common master is the slave's grandparent).
626                                                   #  2. Stop the slave processes on the master and uncle.
627                                                   #  3. If one of them is behind the other, make it catch up.
628                                                   #  4. Point the slave to its uncle.
629                                                   sub make_slave_of_uncle {
630            1                    1            13      my ( $self, $slave_dbh, $slave_dsn, $unc_dbh, $unc_dsn,
631                                                           $dsn_parser, $timeout) = @_;
632                                                   
633                                                      # Verify that the uncle is a different server.
634   ***      1     50                          10      if ( $self->short_host($slave_dsn) eq $self->short_host($unc_dsn) ) {
635   ***      0                                  0         die "You are trying to make the slave a slave of itself";
636                                                      }
637                                                   
638                                                      # Verify that the uncle has the same master.
639   ***      1     50                          10      my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
640                                                         or die "This server is not a slave";
641            1                                557      my $master_dbh = $dsn_parser->get_dbh(
642                                                         $dsn_parser->get_cxn_params($master_dsn), { AutoCommit => 1 });
643   ***      1     50                         519      my $gmaster_dsn
644                                                         = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
645                                                         or die "The master is not a slave";
646   ***      1     50                         573      my $unc_master_dsn
647                                                         = $self->get_master_dsn($unc_dbh, $unc_dsn, $dsn_parser)
648                                                         or die "The uncle is not a slave";
649   ***      1     50                         595      if ($self->short_host($gmaster_dsn) ne $self->short_host($unc_master_dsn)) {
650   ***      0                                  0         die "The uncle isn't really the slave's uncle";
651                                                      }
652                                                   
653                                                      # Verify that the uncle is a master.
654   ***      1     50                           8      my $unc_master_stat = $self->get_master_status($unc_dbh)
655                                                         or die "Binary logging is not enabled on the uncle";
656   ***      1     50                          10      die "The log_slave_updates option is not enabled on the uncle"
657                                                         unless $self->has_slave_updates($unc_dbh);
658                                                   
659                                                      # Stop the master and uncle, then if one is behind the other, make it
660                                                      # catch up.  Then make the slave catch up to its master.
661            1                                 10      $self->catchup_to_same_pos($master_dbh, $unc_dbh);
662            1                                 12      $self->catchup_to_master($slave_dbh, $master_dbh, $timeout);
663                                                   
664                                                      # Verify that the slave is caught up to its master.
665            1                                  9      my $slave_status  = $self->get_slave_status($slave_dbh);
666            1                                  8      my $master_status = $self->get_master_status($master_dbh);
667   ***      1     50                           8      if ( $self->pos_cmp(
668                                                            $self->repl_posn($slave_status),
669                                                            $self->repl_posn($master_status)) != 0 )
670                                                      {
671   ***      0                                  0         die "The slave is not caught up to its master";
672                                                      }
673                                                   
674                                                      # Point the slave to its uncle.
675            1                                 11      $unc_master_stat = $self->get_master_status($unc_dbh);
676            1                                 10      $self->change_master_to($slave_dbh, $unc_dsn,
677                                                         $self->repl_posn($unc_master_stat));
678                                                   
679                                                   
680                                                      # Verify that the slave's master is the uncle and that it is at the same
681                                                      # position.
682            1                                 26      $slave_status    = $self->get_slave_status($slave_dbh);
683            1                                 21      my $slave_pos    = $self->repl_posn($slave_status);
684   ***      1     50     33                   10      if ( $self->short_host($slave_status) ne $self->short_host($unc_dsn)
685                                                        || $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0)
686                                                      {
687   ***      0                                  0         die "After changing the slave's master, it isn't a slave of the uncle, "
688                                                            . "or it has a different replication position than the uncle";
689                                                      }
690                                                   }
691                                                   
692                                                   # Makes a server forget that it is a slave.  Returns the slave status.
693                                                   sub detach_slave {
694            1                    1            11      my ( $self, $dbh ) = @_;
695                                                      # Verify that it is a slave.
696            1                                  9      $self->stop_slave($dbh);
697   ***      1     50                         292      my $stat = $self->get_slave_status($dbh)
698                                                         or die "This server is not a slave";
699            1                             188784      $dbh->do('CHANGE MASTER TO MASTER_HOST=""');
700            1                             168197      $dbh->do('RESET SLAVE'); # Wipes out master.info, etc etc
701            1                                 39      return $stat;
702                                                   }
703                                                   
704                                                   # Returns true if the slave is running.
705                                                   sub slave_is_running {
706            6                    6            40      my ( $self, $slave_status ) = @_;
707   ***      6            50                  137      return ($slave_status->{slave_sql_running} || 'No') eq 'Yes';
708                                                   }
709                                                   
710                                                   # Returns true if the server's log_slave_updates option is enabled.
711                                                   sub has_slave_updates {
712            2                    2            15      my ( $self, $dbh ) = @_;
713            2                                 11      my $sql = q{SHOW VARIABLES LIKE 'log_slave_updates'};
714            2                                  8      MKDEBUG && _d($dbh, $sql);
715            2                                  8      my ($name, $value) = $dbh->selectrow_array($sql);
716   ***      2            33                 1869      return $value && $value =~ m/^(1|ON)$/;
717                                                   }
718                                                   
719                                                   # Extracts the replication position out of either SHOW MASTER STATUS or SHOW
720                                                   # SLAVE STATUS, and returns it as a hashref { file, position }
721                                                   sub repl_posn {
722           29                   29           188      my ( $self, $status ) = @_;
723   ***     29    100     66                  367      if ( exists $status->{file} && exists $status->{position} ) {
724                                                         # It's the output of SHOW MASTER STATUS
725                                                         return {
726           10                                131            file     => $status->{file},
727                                                            position => $status->{position},
728                                                         };
729                                                      }
730                                                      else {
731                                                         return {
732           19                                247            file     => $status->{relay_master_log_file},
733                                                            position => $status->{exec_master_log_pos},
734                                                         };
735                                                      }
736                                                   }
737                                                   
738                                                   # Gets the slave's lag.  TODO: permit using a heartbeat table.
739                                                   sub get_slave_lag {
740   ***      0                    0             0      my ( $self, $dbh ) = @_;
741   ***      0                                  0      my $stat = $self->get_slave_status($dbh);
742   ***      0                                  0      return $stat->{seconds_behind_master};
743                                                   }
744                                                   
745                                                   # Compares two replication positions and returns -1, 0, or 1 just as the cmp
746                                                   # operator does.
747                                                   sub pos_cmp {
748           14                   14            94      my ( $self, $a, $b ) = @_;
749           14                                111      return $self->pos_to_string($a) cmp $self->pos_to_string($b);
750                                                   }
751                                                   
752                                                   # Simplifies a hostname as much as possible.  For purposes of replication, a
753                                                   # hostname is really just the combination of hostname and port, since
754                                                   # replication always uses TCP connections (it does not work via sockets).  If
755                                                   # the port is the default 3306, it is omitted.  As a convenience, this sub
756                                                   # accepts either SHOW SLAVE STATUS or a DSN.
757                                                   sub short_host {
758           18                   18           122      my ( $self, $dsn ) = @_;
759           18                                 84      my ($host, $port);
760           18    100                         137      if ( $dsn->{master_host} ) {
761            4                                 32         $host = $dsn->{master_host};
762            4                                 25         $port = $dsn->{master_port};
763                                                      }
764                                                      else {
765           14                                 82         $host = $dsn->{h};
766           14                                 79         $port = $dsn->{P};
767                                                      }
768   ***     18     50     50                  375      return ($host || '[default]') . ( ($port || 3306) == 3306 ? '' : ":$port" );
      ***                   50                        
769                                                   }
770                                                      
771                                                   # Arguments:
772                                                   #   * query   hashref: a processlist item
773                                                   #   * type    scalar: all, binlog_dump, slave_io or slave_sql
774                                                   # Returns true if the query is the given type of replication thread.
775                                                   sub is_replication_thread {
776           13                   13           103      my ( $self, $query, $type ) = @_; 
777   ***     13     50                          83      return unless $query;
778                                                   
779           13           100                   80      $type ||= 'all';
780   ***     13     50                         176      die "Invalid type: $type"
781                                                         unless $type =~ m/binlog_dump|slave_io|slave_sql|all/i;
782                                                   
783           13                                974      my $match = 0;
784           13    100                         131      if ( $type =~ m/binlog_dump|all/i ) {
785   ***      5    100     33                   72         $match = 1
      ***                   50                        
786                                                            if ($query->{Command} || $query->{command} || '') eq "Binlog Dump";
787                                                      }
788           13    100                          86      if ( !$match ) {
789                                                         # On a slave, there are two threads.  Both have user="system user".
790   ***     12    100     33                  143         if ( ($query->{User} || $query->{user} || '') eq "system user" ) {
      ***                   50                        
791   ***      6            33                   83            my $state = $query->{State} || $query->{state} || '';
      ***                   50                        
792                                                            # These patterns are abbreviated because if the first few words
793                                                            # match chances are very high it's the full slave thd state.
794            6    100                          66            if ( $type =~ m/slave_io|all/i ) {
795            4                                 43               ($match) = $state =~ m/
796                                                                  ^(Waiting\sfor\smaster\supdate
797                                                                   |Connecting\sto\smaster
798                                                                   |Waiting\sto\sreconnect\safter\sa\sfailed
799                                                                   |Reconnecting\safter\sa\sfailed\sbinlog
800                                                                   |Waiting\sfor\smaster\sto\ssend\sevent
801                                                                   |Queueing\smaster\sevent\sto\sthe\srelay
802                                                                   |Waiting\sto\sreconnect\safter\sa\sfailed
803                                                                   |Reconnecting\safter\sa\sfailed\smaster
804                                                                   |Waiting\sfor\sthe\sslave\sSQL\sthread)/xi;
805                                                            }
806            6    100    100                  122            if ( !$match && $type =~ m/slave_sql|all/i ) {
807            3                                 38               ($match) = $state =~ m/
808                                                                  ^(Waiting\sfor\sthe\snext\sevent
809                                                                   |Reading\sevent\sfrom\sthe\srelay\slog
810                                                                   |Has\sread\sall\srelay\slog;\swaiting
811                                                                   |Making\stemp\sfile)/xi; 
812                                                            }
813                                                         }
814                                                         else {
815            6                                 23            MKDEBUG && _d('Not system user');
816                                                         }
817                                                      }
818           13                                 46      MKDEBUG && _d($type, 'replication thread:', ($match ? 'yes' : 'no'),
819                                                         '; match:', $match);
820           13                                142      return $match;
821                                                   }
822                                                   
823                                                   # Arguments:
824                                                   #   dbh    dbh to check, either a master or slave
825                                                   # Returns a hashref of any replication filters.  If none are set,
826                                                   # an empty hashref is returned.
827                                                   sub get_replication_filters {
828            3                    3            49      my ( $self, %args ) = @_;
829            3                                 26      my @required_args = qw(dbh);
830            3                                 25      foreach my $arg ( @required_args ) {
831   ***      3     50                          33         die "I need a $arg argument" unless $args{$arg};
832                                                      }
833            3                                 21      my ($dbh) = @args{@required_args};
834                                                   
835            3                                 15      my %filters = ();
836                                                   
837            3                                 37      my $status = $self->get_master_status($dbh);
838   ***      3     50                          29      if ( $status ) {
839   ***      1     50                          17         map { $filters{$_} = $status->{$_} }
               6                                110   
840            3                                 17         grep { defined $status->{$_} && $status->{$_} ne '' }
841                                                         qw(
842                                                            binlog_do_db
843                                                            binlog_ignore_db
844                                                         );
845                                                      }
846                                                   
847            3                                 28      $status = $self->get_slave_status($dbh);
848            3    100                          36      if ( $status ) {
849   ***      1     50                          19         map { $filters{$_} = $status->{$_} }
              12                                183   
850            2                                 15         grep { defined $status->{$_} && $status->{$_} ne '' }
851                                                         qw(
852                                                            replicate_do_db
853                                                            replicate_ignore_db
854                                                            replicate_do_table
855                                                            replicate_ignore_table 
856                                                            replicate_wild_do_table
857                                                            replicate_wild_ignore_table
858                                                         );
859                                                   
860            2                                 15         my $sql = "SHOW VARIABLES LIKE 'slave_skip_errors'";
861            2                                  5         MKDEBUG && _d($dbh, $sql);
862            2                                  8         my $row = $dbh->selectrow_arrayref($sql);
863                                                         # "OFF" in 5.0, "" in 5.1
864   ***      2     50     33                 1952         $filters{slave_skip_errors} = $row->[1] if $row->[1] && $row->[1] ne 'OFF';
865                                                      }
866                                                   
867            3                                 92      return \%filters; 
868                                                   }
869                                                   
870                                                   # Stringifies a position in a way that's string-comparable.
871                                                   sub pos_to_string {
872           28                   28           159      my ( $self, $pos ) = @_;
873           28                                123      my $fmt  = '%s/%020d';
874           28                                150      return sprintf($fmt, @{$pos}{qw(file position)});
              28                               1323   
875                                                   }
876                                                   
877                                                   sub _d {
878   ***      0                    0                    my ($package, undef, $line) = caller 0;
879   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
880   ***      0                                              map { defined $_ ? $_ : 'undef' }
881                                                           @_;
882   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
883                                                   }
884                                                   
885                                                   1;
886                                                   
887                                                   # ###########################################################################
888                                                   # End MasterSlave package
889                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
64    ***     50      0      4   if ($EVAL_ERROR)
65    ***      0      0      0   unless print STDERR 'Cannot connect to ', $dp->as_string($dsn), "\n"
78    ***     50      0      4   if (not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id or $$args{'server_ids_seen'}{$id}++)
83    ***      0      0      0   if ($$args{'skip_callback'})
92           100      3      1   if (not defined $$args{'recurse'} or $level < $$args{'recurse'})
96    ***     50      3      0   unless not $$_{'master_id'}
125   ***     50      0      3   if ($method) { }
132   ***     50      3      0   if (($$dsn{'P'} || 3306) != 3306)
146          100      2      1   if @slaves
164   ***      0      0      0   if ($host eq 'localhost')
187          100      2      1   if (@slaves)
192   ***     50      0      3   $hash{'user'} ? :
      ***     50      0      3   $hash{'password'} ? :
218   ***     50      0      3   if ($vp and not $vp->version_ge($dbh, '4.1.2'))
231   ***     50      0      3   if ($EVAL_ERROR)
233   ***      0      0      0   if ($EVAL_ERROR =~ /no such grant defined for user/)
249   ***      0      0      0   if $EVAL_ERROR
251   ***     50      0      3   if (not $proc)
272   ***     50      0      3   unless my $master_status = $self->get_master_status($master)
274   ***     50      0      3   unless my $slave_status = $self->get_slave_status($slave)
276          100      1      2   unless my(@connected) = $self->get_connected_slaves($master)
280          100      1      1   if ($port != $$slave_status{'master_port'})
285   ***     50      0      1   if (not grep {$$slave_status{'master_user'} eq $$_{'user'};} @connected)
290   ***     50      1      0   if (($$slave_status{'slave_io_state'} || '') eq 'Waiting for master to send event')
303   ***     50      0      1   if ($master_log_name ne $slave_log_name or abs $master_log_num - $slave_log_num > 1)
321   ***     50      0      8   unless my $master = $self->get_slave_status($dbh)
329   ***     50     49      0   if (not $$self{'not_a_slave'}{$dbh})
336          100     47      2   if ($ss and %$ss)
349   ***     50     19      0   if (not $$self{'not_a_master'}{$dbh})
356   ***     50     19      0   if ($ms and %$ms)
358   ***     50     19      0   if ($$ms{'file'} and $$ms{'position'})
374   ***     50      0      3   unless defined $time
378   ***     50      3      0   if ($ms) { }
382   ***     50      3      0   defined $result ? :
384   ***     50      0      3   if ($stat eq 'NULL' or $stat < 0 and not $timeoutok)
406          100      1     24   if ($pos) { }
434          100      1      2   if ($self->pos_cmp($slave_pos, $master_pos) < 0)
443   ***     50      0      1   if ($EVAL_ERROR)
445   ***      0      0      0   if ($EVAL_ERROR =~ /MASTER_POS_WAIT returned NULL/) { }
447   ***      0      0      0   if (not $self->slave_is_running($slave_status)) { }
452   ***      0      0      0   if ($self->pos_cmp($slave_pos, $master_pos) != 0)
478   ***     50      0      2   if ($self->pos_cmp($s1_pos, $s2_pos) < 0) { }
      ***     50      0      2   elsif ($self->pos_cmp($s2_pos, $s1_pos) < 0) { }
492   ***     50      0      2   if ($self->slave_is_running($s1_status) or $self->slave_is_running($s2_status) or $self->pos_cmp($s1_pos, $s2_pos) != 0)
523   ***     50      0      1   unless my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
527   ***     50      0      1   unless my $gmaster_dsn = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
532   ***     50      0      1   if ($self->short_host($slave_dsn) eq $self->short_host($gmaster_dsn))
549   ***     50      1      0   if (not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status) and $self->pos_cmp($master_pos, $slave_pos) == 0) { }
565   ***     50      0      1   if ($self->short_host($mslave_status) ne $self->short_host($slave_status) or $self->pos_cmp($mslave_pos, $slave_pos) != 0)
582          100      1      1   if ($self->short_host($slave_dsn) eq $self->short_host($sib_dsn))
587   ***     50      0      1   unless my $master_dsn1 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
591   ***     50      0      1   unless my $master_dsn2 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
593   ***     50      0      1   if ($self->short_host($master_dsn1) ne $self->short_host($master_dsn2))
596   ***     50      0      1   unless my $sib_master_stat = $self->get_master_status($sib_dbh)
598   ***     50      0      1   unless $self->has_slave_updates($sib_dbh)
615   ***     50      0      1   if ($self->short_host($slave_status) ne $self->short_host($sib_dsn) or $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0)
634   ***     50      0      1   if ($self->short_host($slave_dsn) eq $self->short_host($unc_dsn))
639   ***     50      0      1   unless my $master_dsn = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
643   ***     50      0      1   unless my $gmaster_dsn = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
646   ***     50      0      1   unless my $unc_master_dsn = $self->get_master_dsn($unc_dbh, $unc_dsn, $dsn_parser)
649   ***     50      0      1   if ($self->short_host($gmaster_dsn) ne $self->short_host($unc_master_dsn))
654   ***     50      0      1   unless my $unc_master_stat = $self->get_master_status($unc_dbh)
656   ***     50      0      1   unless $self->has_slave_updates($unc_dbh)
667   ***     50      0      1   if ($self->pos_cmp($self->repl_posn($slave_status), $self->repl_posn($master_status)) != 0)
684   ***     50      0      1   if ($self->short_host($slave_status) ne $self->short_host($unc_dsn) or $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0)
697   ***     50      0      1   unless my $stat = $self->get_slave_status($dbh)
723          100     10     19   if (exists $$status{'file'} and exists $$status{'position'}) { }
760          100      4     14   if ($$dsn{'master_host'}) { }
768   ***     50      0     18   ($port || 3306) == 3306 ? :
777   ***     50      0     13   unless $query
780   ***     50      0     13   unless $type =~ /binlog_dump|slave_io|slave_sql|all/i
784          100      5      8   if ($type =~ /binlog_dump|all/i)
785          100      1      4   if ($$query{'Command'} || $$query{'command'} || '') eq 'Binlog Dump'
788          100     12      1   if (not $match)
790          100      6      6   if (($$query{'User'} || $$query{'user'} || '') eq 'system user') { }
794          100      4      2   if ($type =~ /slave_io|all/i)
806          100      3      3   if (not $match and $type =~ /slave_sql|all/i)
831   ***     50      0      3   unless $args{$arg}
838   ***     50      3      0   if ($status)
839   ***     50      6      0   if defined $$status{$_}
848          100      2      1   if ($status)
849   ***     50     12      0   if defined $$status{$_}
864   ***     50      0      2   if $$row[1] and $$row[1] ne 'OFF'
879   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
78    ***     66      1      3      0   defined $master_thinks_i_am and $master_thinks_i_am != $id
218   ***     33      0      3      0   $vp and not $vp->version_ge($dbh, '4.1.2')
336   ***     66      2      0     47   $ss and %$ss
356   ***     33      0      0     19   $ms and %$ms
358   ***     33      0      0     19   $$ms{'file'} and $$ms{'position'}
384   ***     33      3      0      0   $stat < 0 and not $timeoutok
549   ***     33      0      0      1   not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status)
      ***     33      0      0      1   not $self->slave_is_running($mslave_status) and not $self->slave_is_running($slave_status) and $self->pos_cmp($master_pos, $slave_pos) == 0
716   ***     33      0      0      2   $value && $value =~ /^(1|ON)$/
723   ***     66     19      0     10   exists $$status{'file'} and exists $$status{'position'}
806          100      2      1      3   not $match and $type =~ /slave_sql|all/i
864   ***     33      2      0      0   $$row[1] and $$row[1] ne 'OFF'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
54           100      3      1   $level ||= 0
132   ***     50      3      0   $$dsn{'P'} || 3306
290   ***     50      1      0   $$slave_status{'slave_io_state'} || ''
377          100      1      2   $ms ||= $self->get_master_status($master)
707   ***     50      6      0   $$slave_status{'slave_sql_running'} || 'No'
768   ***     50     18      0   $host || '[default]'
      ***     50     18      0   $port || 3306
779          100      9      4   $type ||= 'all'
785   ***     50      5      0   $$query{'Command'} || $$query{'command'} || ''
790   ***     50     12      0   $$query{'User'} || $$query{'user'} || ''
791   ***     50      6      0   $$query{'State'} || $$query{'state'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
60    ***     66      1      3      0   $$args{'dbh'} || $dp->get_dbh($dp->get_cxn_params($dsn), {'AutoCommit', 1})
78    ***     33      0      0      4   not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id
      ***     33      0      0      4   not defined $id or defined $master_thinks_i_am and $master_thinks_i_am != $id or $$args{'server_ids_seen'}{$id}++
92    ***     66      0      3      1   not defined $$args{'recurse'} or $level < $$args{'recurse'}
303   ***     33      0      0      1   $master_log_name ne $slave_log_name or abs $master_log_num - $slave_log_num > 1
330   ***     66     41      8      0   $$self{'sths'}{$dbh}{'SLAVE_STATUS'} ||= $dbh->prepare('SHOW SLAVE STATUS')
350   ***     66     10      9      0   $$self{'sths'}{$dbh}{'MASTER_STATUS'} ||= $dbh->prepare('SHOW MASTER STATUS')
384   ***     33      0      0      3   $stat eq 'NULL' or $stat < 0 and not $timeoutok
397   ***     66     21      6      0   $$self{'sths'}{$dbh}{'STOP_SLAVE'} ||= $dbh->prepare('STOP SLAVE')
414   ***     66     21      3      0   $$self{'sths'}{$dbh}{'START_SLAVE'} ||= $dbh->prepare('START SLAVE')
492   ***     33      0      0      2   $self->slave_is_running($s1_status) or $self->slave_is_running($s2_status)
      ***     33      0      0      2   $self->slave_is_running($s1_status) or $self->slave_is_running($s2_status) or $self->pos_cmp($s1_pos, $s2_pos) != 0
565   ***     33      0      0      1   $self->short_host($mslave_status) ne $self->short_host($slave_status) or $self->pos_cmp($mslave_pos, $slave_pos) != 0
615   ***     33      0      0      1   $self->short_host($slave_status) ne $self->short_host($sib_dsn) or $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0
684   ***     33      0      0      1   $self->short_host($slave_status) ne $self->short_host($unc_dsn) or $self->pos_cmp($self->repl_posn($unc_master_stat), $slave_pos) != 0
785   ***     33      5      0      0   $$query{'Command'} || $$query{'command'}
790   ***     33     12      0      0   $$query{'User'} || $$query{'user'}
791   ***     33      6      0      0   $$query{'State'} || $$query{'state'}


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
_find_slaves_by_hosts           3 /home/daniel/dev/maatkit/common/MasterSlave.pm:179
catchup_to_master               3 /home/daniel/dev/maatkit/common/MasterSlave.pm:425
catchup_to_same_pos             2 /home/daniel/dev/maatkit/common/MasterSlave.pm:471
change_master_to                3 /home/daniel/dev/maatkit/common/MasterSlave.pm:503
detach_slave                    1 /home/daniel/dev/maatkit/common/MasterSlave.pm:694
find_slave_hosts                3 /home/daniel/dev/maatkit/common/MasterSlave.pm:122
get_connected_slaves            3 /home/daniel/dev/maatkit/common/MasterSlave.pm:209
get_master_dsn                  8 /home/daniel/dev/maatkit/common/MasterSlave.pm:320
get_master_status              19 /home/daniel/dev/maatkit/common/MasterSlave.pm:348
get_replication_filters         3 /home/daniel/dev/maatkit/common/MasterSlave.pm:828
get_slave_status               49 /home/daniel/dev/maatkit/common/MasterSlave.pm:328
has_slave_updates               2 /home/daniel/dev/maatkit/common/MasterSlave.pm:712
is_master_of                    3 /home/daniel/dev/maatkit/common/MasterSlave.pm:271
is_replication_thread          13 /home/daniel/dev/maatkit/common/MasterSlave.pm:776
make_sibling_of_master          1 /home/daniel/dev/maatkit/common/MasterSlave.pm:518
make_slave_of_sibling           2 /home/daniel/dev/maatkit/common/MasterSlave.pm:578
make_slave_of_uncle             1 /home/daniel/dev/maatkit/common/MasterSlave.pm:630
new                             1 /home/daniel/dev/maatkit/common/MasterSlave.pm:34 
pos_cmp                        14 /home/daniel/dev/maatkit/common/MasterSlave.pm:748
pos_to_string                  28 /home/daniel/dev/maatkit/common/MasterSlave.pm:872
recurse_to_slaves               4 /home/daniel/dev/maatkit/common/MasterSlave.pm:53 
repl_posn                      29 /home/daniel/dev/maatkit/common/MasterSlave.pm:722
short_host                     18 /home/daniel/dev/maatkit/common/MasterSlave.pm:758
slave_is_running                6 /home/daniel/dev/maatkit/common/MasterSlave.pm:706
start_slave                    25 /home/daniel/dev/maatkit/common/MasterSlave.pm:405
stop_slave                     27 /home/daniel/dev/maatkit/common/MasterSlave.pm:396
wait_for_master                 3 /home/daniel/dev/maatkit/common/MasterSlave.pm:372

Uncovered Subroutines
---------------------

Subroutine                  Count Location                                          
--------------------------- ----- --------------------------------------------------
_d                              0 /home/daniel/dev/maatkit/common/MasterSlave.pm:878
_find_slaves_by_processlist     0 /home/daniel/dev/maatkit/common/MasterSlave.pm:154
get_slave_lag                   0 /home/daniel/dev/maatkit/common/MasterSlave.pm:740


MasterSlave.t

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
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            11   use Test::More tests => 47;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use MasterSlave;
               1                                  3   
               1                                 15   
15             1                    1            13   use DSNParser;
               1                                  3   
               1                                 12   
16             1                    1            14   use VersionParser;
               1                                  4   
               1                                  9   
17             1                    1            10   use Sandbox;
               1                                  2   
               1                                 22   
18             1                    1            10   use MaatkitTest;
               1                                  6   
               1                                 48   
19                                                    
20             1                                 12   my $vp = new VersionParser();
21             1                                 30   my $ms = new MasterSlave(VersionParser => $vp);
22             1                                  9   my $dp = new DSNParser(opts=>$dsn_opts);
23             1                                246   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
24                                                    
25                                                    # slave_dbh is used near the end but for the most part we
26                                                    # use special sandboxes on ports 2900-2903.
27             1                                 55   my $master_dbh = $sb->get_dbh_for('master');
28             1                                389   my $slave_dbh  = $sb->get_dbh_for('slave1');
29                                                    
30                                                    # Create slave2 as slave of slave1.
31                                                    #diag(`/tmp/12347/stop 2> /dev/null`);
32                                                    #diag(`rm -rf /tmp/12347 2> /dev/null`);
33                                                    #diag(`$trunk/sandbox/make_sandbox 12347`);
34                                                    #diag(`/tmp/12347/use -e "change master to master_host='127.0.0.1', master_log_file='mysql-bin.000001', master_log_pos=0, master_user='msandbox', master_password='msandbox', master_port=12346"`);
35                                                    #diag(`/tmp/12347/use -e "start slave"`);
36             1                                305   my $slave_2_dbh = $sb->get_dbh_for('slave2');
37                                                    #   or BAIL_OUT('Cannot connect to sandbox slave2');
38                                                    
39                                                    # Make slave2 slave of master.
40                                                    #diag(`$trunk/mk-slave-move/mk-slave-move --sibling-of-master h=127.1,P=12347`);
41                                                    
42                                                    #SKIP: {
43                                                    #   skip 'idea for future improvement', 3;
44                                                    #
45                                                    ## Make sure we're messed up nicely.
46                                                    #my $rows = $master_dbh->selectall_arrayref('SHOW SLAVE HOSTS', {Slice => {}});
47                                                    #is_deeply(
48                                                    #   $rows,
49                                                    #   [
50                                                    #      {
51                                                    #         Server_id => '12346',
52                                                    #         Host      => '127.0.0.1',
53                                                    #         Port      => '12346',
54                                                    #         Rpl_recovery_rank => '0',
55                                                    #         Master_id => '12345',
56                                                    #      },
57                                                    #   ],
58                                                    #   'show slave hosts on master is precisely inaccurate'
59                                                    #);
60                                                    #
61                                                    #$rows = $slave_dbh->selectall_arrayref('SHOW SLAVE HOSTS', {Slice => {}});
62                                                    #is_deeply(
63                                                    #   $rows,
64                                                    #   [
65                                                    #      {
66                                                    #         Server_id => '12347',     # This is what's messed up because
67                                                    #         Host      => '127.0.0.1', # slave2 (12347) was made a slave
68                                                    #         Port      => '12347',     # of the master (12345), yet here
69                                                    #         Rpl_recovery_rank => '0', # it still shows as a slave of
70                                                    #         Master_id => '12346', # <-- slave1 (12346)
71                                                    #      },
72                                                    #      {
73                                                    #         Server_id => '12346',
74                                                    #         Host      => '127.0.0.1',
75                                                    #         Port      => '12346',
76                                                    #         Rpl_recovery_rank => '0',
77                                                    #         Master_id => '12345',
78                                                    #      },
79                                                    #   ],
80                                                    #   'show slave hosts on slave1 is precisely inaccurate'
81                                                    #);
82                                                    #
83                                                    #$rows = $slave_2_dbh->selectall_arrayref('SHOW SLAVE HOSTS', {Slice => {}});
84                                                    #is_deeply(
85                                                    #   $rows,
86                                                    #   [
87                                                    #      {
88                                                    #         Server_id => '12347',     
89                                                    #         Host      => '127.0.0.1', 
90                                                    #         Port      => '12347',     # Even slave2 itself is confused about
91                                                    #         Rpl_recovery_rank => '0', # which sever it is really a slave to:
92                                                    #         Master_id => '12346', # <-- slave1 (123456) wrong again
93                                                    #      },
94                                                    #      {
95                                                    #         Server_id => '12346',
96                                                    #         Host      => '127.0.0.1',
97                                                    #         Port      => '12346',
98                                                    #         Rpl_recovery_rank => '0',
99                                                    #         Master_id => '12345',
100                                                   #      },
101                                                   #   ],
102                                                   #   'show slave hosts on slave2 is precisely inaccurate'
103                                                   #);
104                                                   
105                                                   # The real picture is:
106                                                   #    12345
107                                                   #    +- 12346
108                                                   #    +- 12347
109                                                   # And here's what MySQL would have us wrongly see:
110                                                   #   12345
111                                                   #   +- 12346
112                                                   #      +- 12347
113                                                   #is_deeply(
114                                                   #   $ms->new_recurse_to_salves(),
115                                                   #   [
116                                                   #      '127.0.0.1:12345',
117                                                   #      [
118                                                   #         '127.0.0.1:12346',
119                                                   #         '127.0.0.1:12357',
120                                                   #      ],
121                                                   #   ],
122                                                   #   '_new_rts()'
123                                                   #);
124                                                   
125                                                   # Stop and remove slave2.
126                                                   #diag(`/tmp/12347/stop`);
127                                                   #diag(`rm -rf /tmp/12347`);
128                                                   #};
129                                                   
130                                                   # #############################################################################
131                                                   # First we need to setup a special replication sandbox environment apart from
132                                                   # the usual persistent sandbox servers on ports 12345 and 12346.
133                                                   # The tests in this script require a master with 3 slaves in a setup like:
134                                                   #    127.0.0.1:master
135                                                   #    +- 127.0.0.1:slave0
136                                                   #    |  +- 127.0.0.1:slave1
137                                                   #    +- 127.0.0.1:slave2
138                                                   # The servers will have the ports (which won't conflict with the persistent
139                                                   # sandbox servers) as seen in the %port_for hash below.
140                                                   # #############################################################################
141            1                                 20   my %port_for = (
142                                                      master => 2900,
143                                                      slave0 => 2901,
144                                                      slave1 => 2902,
145                                                      slave2 => 2903,
146                                                   );
147            1                             2151966   diag(`$trunk/sandbox/start-sandbox master 2900 >/dev/null`);
148            1                             2352199   diag(`$trunk/sandbox/start-sandbox slave 2903 2900 >/dev/null`);
149            1                             2458508   diag(`$trunk/sandbox/start-sandbox slave 2901 2900 >/dev/null`);
150            1                             2435512   diag(`$trunk/sandbox/start-sandbox slave 2902 2901 >/dev/null`);
151                                                   
152                                                   # I discovered something weird while updating this test. Above, you see that
153                                                   # slave2 is started first, then the others. Before, slave2 was started last,
154                                                   # but this caused the tests to fail because SHOW SLAVE HOSTS on the master
155                                                   # returned:
156                                                   # +-----------+-----------+------+-------------------+-----------+
157                                                   # | Server_id | Host      | Port | Rpl_recovery_rank | Master_id |
158                                                   # +-----------+-----------+------+-------------------+-----------+
159                                                   # |      2903 | 127.0.0.1 | 2903 |                 0 |      2900 | 
160                                                   # |      2901 | 127.0.0.1 | 2901 |                 0 |      2900 | 
161                                                   # +-----------+-----------+------+-------------------+-----------+
162                                                   # This caused recurse_to_slaves() to report 2903, 2901, 2902.
163                                                   # Since the tests are senstive to the order of @slaves, they failed
164                                                   # because $slaves->[1] was no longer slave1 but slave0. Starting slave2
165                                                   # last fixes/works around this.
166                                                   
167                                                   # #############################################################################
168                                                   # Now the test.
169                                                   # #############################################################################
170            1                                 15   my $dbh;
171            1                                 11   my @slaves;
172            1                                  4   my @sldsns;
173                                                   
174            1                                 43   my $dsn = $dp->parse("h=127.0.0.1,P=$port_for{master},u=msandbox,p=msandbox");
175            1                                622   $dbh    = $dp->get_dbh($dp->get_cxn_params($dsn), { AutoCommit => 1 });
176                                                   
177                                                   my $callback = sub {
178            4                    4            37      my ( $dsn, $dbh, $level, $parent ) = @_;
179            4    100                          29      return unless $level;
180   ***      3            50                   43      ok($dsn, "Connected to one slave "
181                                                         . ($dp->as_string($dsn) || '<none>')
182                                                         . " from $dsn->{source}");
183            3                                 33      push @slaves, $dbh;
184            3                                 22      push @sldsns, $dsn;
185            1                                584   };
186                                                   
187                                                   my $skip_callback = sub {
188   ***      0                    0             0      my ( $dsn, $dbh, $level ) = @_;
189   ***      0      0                           0      return unless $level;
190   ***      0             0                    0      ok($dsn, "Skipped one slave "
191                                                         . ($dp->as_string($dsn) || '<none>')
192                                                         . " from $dsn->{source}");
193            1                                 17   };
194                                                   
195            1                                 54   $ms->recurse_to_slaves(
196                                                      {  dsn_parser    => $dp,
197                                                         dbh           => $dbh,
198                                                         dsn           => $dsn,
199                                                         recurse       => 2,
200                                                         callback      => $callback,
201                                                         skip_callback => $skip_callback,
202                                                      });
203                                                   
204            1                                 32   is_deeply(
205                                                      $ms->get_master_dsn( $slaves[0], undef, $dp ),
206                                                      {  h => '127.0.0.1',
207                                                         u => undef,
208                                                         P => $port_for{master},
209                                                         S => undef,
210                                                         F => undef,
211                                                         p => undef,
212                                                         D => undef,
213                                                         A => undef,
214                                                         t => undef,
215                                                      },
216                                                      'Got master DSN',
217                                                   );
218                                                   
219                                                   # The picture:
220                                                   # 127.0.0.1:master
221                                                   # +- 127.0.0.1:slave0
222                                                   # |  +- 127.0.0.1:slave1
223                                                   # +- 127.0.0.1:slave2
224            1                                 34   is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{master}, 'slave 1 port');
225            1                                 28   is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{slave0}, 'slave 2 port');
226            1                                 28   is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');
227                                                   
228            1                                 35   ok($ms->is_master_of($slaves[0], $slaves[1]), 'slave 1 is slave of slave 0');
229            1                                  6   eval {
230            1                                 13      $ms->is_master_of($slaves[0], $slaves[2]);
231                                                   };
232            1                                 49   like($EVAL_ERROR, qr/but the master's port/, 'slave 2 is not slave of slave 0');
233            1                                  9   eval {
234            1                                 14      $ms->is_master_of($slaves[2], $slaves[1]);
235                                                   };
236            1                                 36   like($EVAL_ERROR, qr/has no connected slaves/, 'slave 1 is not slave of slave 2');
237                                                   
238            1                                 13   map { $ms->stop_slave($_) } @slaves;
               3                                 44   
239            1                                 10   map { $ms->start_slave($_) } @slaves;
               3                                 36   
240                                                   
241            1                                  8   my $res;
242            1                                 19   $res = $ms->wait_for_master($dbh, $slaves[0], 1, 0);
243   ***      1            33                   28   ok(defined $res && $res >= 0, 'Wait was successful');
244                                                   
245            1                                 11   $ms->stop_slave($slaves[0]);
246            1                                380   $dbh->do('drop database if exists test'); # Any stmt will do
247            1                             1024721   diag(`(sleep 1; echo "start slave" | /tmp/$port_for{slave0}/use)&`);
248            1                                 13   eval {
249            1                                 44      $res = $ms->wait_for_master($dbh, $slaves[0], 1, 0);
250                                                   };
251            1                                 33   ok($res, 'Waited for some events');
252                                                   
253                                                   # Clear any START SLAVE UNTIL conditions.
254            1                                  7   map { $ms->stop_slave($_) } @slaves;
               3                                 33   
255            1                                 10   map { $ms->start_slave($_) } @slaves;
               3                                 46   
256            1                             1000260   sleep 1;
257                                                   
258            1                                 26   $ms->stop_slave($slaves[0]);
259            1                                294   $dbh->do('drop database if exists test'); # Any stmt will do
260            1                                 16   eval {
261            1                                 25      $res = $ms->catchup_to_master($slaves[0], $dbh, 10);
262                                                   };
263   ***      1     50                          11   diag $EVAL_ERROR if $EVAL_ERROR;
264            1                                 13   ok(!$EVAL_ERROR, 'No eval error catching up');
265            1                                 10   my $master_stat = $ms->get_master_status($dbh);
266            1                                 12   my $slave_stat = $ms->get_slave_status($slaves[0]);
267            1                                 12   is_deeply(
268                                                      $ms->repl_posn($master_stat),
269                                                      $ms->repl_posn($slave_stat),
270                                                      'Caught up');
271                                                   
272            1                                 14   eval {
273            1                                  7      map { $ms->start_slave($_) } @slaves;
               3                                 27   
274            1                                 32      $ms->make_sibling_of_master($slaves[1], $sldsns[1], $dp, 100);
275                                                   };
276   ***      1     50                          16   diag $EVAL_ERROR if $EVAL_ERROR;
277            1                                 12   ok(!$EVAL_ERROR, 'Made slave sibling of master');
278                                                   
279                                                   # Clear any START SLAVE UNTIL conditions.
280            1                                  7   map { $ms->stop_slave($_) } @slaves;
               3                                 27   
281            1                                  9   map { $ms->start_slave($_) } @slaves;
               3                                 31   
282                                                   
283                                                   # The picture now:
284                                                   # 127.0.0.1:master
285                                                   # +- 127.0.0.1:slave0
286                                                   # +- 127.0.0.1:slave1
287                                                   # +- 127.0.0.1:slave2
288            1                                 20   is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{master}, 'slave 1 port');
289            1                                 21   is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
290            1                                 26   is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');
291                                                   
292            1                                 18   eval {
293            1                                  6      map { $ms->start_slave($_) } @slaves;
               3                                 28   
294            1                                 25      $ms->make_slave_of_sibling(
295                                                         $slaves[0], $sldsns[0],
296                                                         $slaves[0], $sldsns[0], $dp, 100);
297                                                   };
298            1                                 30   like($EVAL_ERROR, qr/slave of itself/, 'Cannot make slave slave of itself');
299                                                   
300            1                                 13   eval {
301            1                                  5      map { $ms->start_slave($_) } @slaves;
               3                                 26   
302            1                                 16      $ms->make_slave_of_sibling(
303                                                         $slaves[0], $sldsns[0],
304                                                         $slaves[1], $sldsns[1], $dp, 100);
305                                                   };
306   ***      1     50                          15   diag $EVAL_ERROR if $EVAL_ERROR;
307            1                                 11   ok(!$EVAL_ERROR, 'Made slave of sibling');
308                                                   
309                                                   # The picture now:
310                                                   # 127.0.0.1:master
311                                                   # +- 127.0.0.1:slave1
312                                                   # |  +- 127.0.0.1:slave0
313                                                   # +- 127.0.0.1:slave2
314            1                                 18   is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{slave1}, 'slave 1 port');
315            1                                 26   is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
316            1                                 23   is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');
317                                                   
318            1                                 19   eval {
319            1                                  7      map { $ms->start_slave($_) } @slaves;
               3                                 34   
320            1                                 35      $ms->make_slave_of_uncle(
321                                                         $slaves[0], $sldsns[0],
322                                                         $slaves[2], $sldsns[2], $dp, 100);
323                                                   };
324   ***      1     50                          10   diag $EVAL_ERROR if $EVAL_ERROR;
325            1                                 11   ok(!$EVAL_ERROR, 'Made slave of uncle');
326                                                   
327                                                   # The picture now:
328                                                   # 127.0.0.1:master
329                                                   # +- 127.0.0.1:slave1
330                                                   # +- 127.0.0.1:slave2
331                                                   #    +- 127.0.0.1:slave0
332            1                                 13   is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{slave2}, 'slave 1 port');
333            1                                 22   is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
334            1                                 26   is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');
335                                                   
336            1                                 16   eval {
337            1                                  6      map { $ms->start_slave($_) } @slaves;
               3                                 38   
338            1                                 31      $ms->detach_slave($slaves[0]);
339                                                   };
340   ***      1     50                          15   diag $EVAL_ERROR if $EVAL_ERROR;
341            1                                 14   ok(!$EVAL_ERROR, 'Detached slave');
342                                                   
343                                                   # The picture now:
344                                                   # 127.0.0.1:master
345                                                   # +- 127.0.0.1:slave1
346                                                   # +- 127.0.0.1:slave2
347            1                                 14   is($ms->get_slave_status($slaves[0]), 0, 'slave 1 detached');
348            1                                 14   is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
349            1                                 23   is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');
350                                                   
351                                                   # #############################################################################
352                                                   # Test is_replication_thread()
353                                                   # #############################################################################
354            1                                 38   my $query = {
355                                                      Id      => '302',
356                                                      User    => 'msandbox',
357                                                      Host    => 'localhost',
358                                                      db      => 'NULL',
359                                                      Command => 'Query',
360                                                      Time    => '0',
361                                                      State   => 'NULL',
362                                                      Info    => 'show processlist',
363                                                   };
364                                                   
365            1                                 15   ok(
366                                                      !$ms->is_replication_thread($query),
367                                                      "Non-rpl thd is not repl thd"
368                                                   );
369                                                   
370            1                                 11   ok(
371                                                      !$ms->is_replication_thread($query, 'binlog_dump'),
372                                                      "Non-rpl thd is not binlog dump thd"
373                                                   );
374                                                   
375            1                                 12   ok(
376                                                      !$ms->is_replication_thread($query, 'slave_io'),
377                                                      "Non-rpl thd is not slave io thd"
378                                                   );
379                                                   
380            1                                 11   ok(
381                                                      !$ms->is_replication_thread($query, 'slave_sql'),
382                                                      "Non-rpl thd is not slave sql thd"
383                                                   );
384                                                   
385            1                                 28   $query = {
386                                                      Id      => '7',
387                                                      User    => 'msandbox',
388                                                      Host    => 'localhost:53246',
389                                                      db      => 'NULL',
390                                                      Command => 'Binlog Dump',
391                                                      Time    => '1174',
392                                                      State   => 'Sending binlog event to slave',
393                                                      Info    => 'NULL',
394                                                   },
395                                                   
396                                                   ok(
397                                                      $ms->is_replication_thread($query),
398                                                      'Binlog Dump is a repl thd'
399                                                   );
400                                                   
401            1                                 16   ok(
402                                                      !$ms->is_replication_thread($query, 'slave_io'),
403                                                      'Binlog Dump is not a slave io thd'
404                                                   );
405                                                   
406            1                                 10   ok(
407                                                      !$ms->is_replication_thread($query, 'slave_sql'),
408                                                      'Binlog Dump is not a slave sql thd'
409                                                   );
410                                                   
411            1                                 21   $query = {
412                                                      Id      => '7',
413                                                      User    => 'system user',
414                                                      Host    => '',
415                                                      db      => 'NULL',
416                                                      Command => 'Connect',
417                                                      Time    => '1174',
418                                                      State   => 'Waiting for master to send event',
419                                                      Info    => 'NULL',
420                                                   },
421                                                   
422                                                   ok(
423                                                      $ms->is_replication_thread($query),
424                                                      'Slave io thd is a repl thd'
425                                                   );
426                                                   
427            1                                 13   ok(
428                                                      $ms->is_replication_thread($query, 'slave_io'),
429                                                      'Slave io thd is a slave io thd'
430                                                   );
431                                                   
432            1                                 14   ok(
433                                                      !$ms->is_replication_thread($query, 'slave_sql'),
434                                                      'Slave io thd is not a slave sql thd',
435                                                   );
436                                                   
437            1                                 28   $query = {
438                                                      Id      => '7',
439                                                      User    => 'system user',
440                                                      Host    => '',
441                                                      db      => 'NULL',
442                                                      Command => 'Connect',
443                                                      Time    => '1174',
444                                                      State   => 'Has read all relay log; waiting for the slave I/O thread to update it',
445                                                      Info    => 'NULL',
446                                                   },
447                                                   
448                                                   ok(
449                                                      $ms->is_replication_thread($query),
450                                                      'Slave sql thd is a repl thd'
451                                                   );
452                                                   
453            1                                 17   ok(
454                                                      !$ms->is_replication_thread($query, 'slave_io'),
455                                                      'Slave sql thd is not a slave io thd'
456                                                   );
457                                                   
458            1                                 10   ok(
459                                                      $ms->is_replication_thread($query, 'slave_sql'),
460                                                      'Slave sql thd is a slave sql thd',
461                                                   );
462                                                   
463                                                   # #############################################################################
464                                                   # get_replication_filters()
465                                                   # #############################################################################
466   ***      1     50                           9   SKIP: {
467            1                                  7      skip "Cannot connect to sandbox master", 3 unless $master_dbh;
468   ***      1     50                           7      skip "Cannot connect to sandbox slave", 3 unless $slave_dbh;
469                                                   
470            1                                 15      is_deeply(
471                                                         $ms->get_replication_filters(dbh=>$slave_dbh),
472                                                         {
473                                                         },
474                                                         "No replication filters"
475                                                      );
476                                                   
477            1                                288      $master_dbh->disconnect();
478            1                                 55      $slave_dbh->disconnect();
479                                                   
480            1                             2030404      diag(`/tmp/12346/stop >/dev/null`);
481            1                             4031649      diag(`/tmp/12345/stop >/dev/null`);
482            1                               6546      diag(`cp /tmp/12346/my.sandbox.cnf /tmp/12346/orig.cnf`);
483            1                               6559      diag(`cp /tmp/12345/my.sandbox.cnf /tmp/12345/orig.cnf`);
484            1                               8509      diag(`echo "replicate-ignore-db=foo" >> /tmp/12346/my.sandbox.cnf`);
485            1                               8156      diag(`echo "binlog-ignore-db=bar" >> /tmp/12345/my.sandbox.cnf`);
486            1                             1039294      diag(`/tmp/12345/start >/dev/null`);
487            1                             1031408      diag(`/tmp/12346/start >/dev/null`);
488                                                      
489            1                                 39      $master_dbh = $sb->get_dbh_for('master');
490            1                                775      $slave_dbh  = $sb->get_dbh_for('slave1');
491                                                   
492            1                                685      is_deeply(
493                                                         $ms->get_replication_filters(dbh=>$master_dbh),
494                                                         {
495                                                            binlog_ignore_db => 'bar',
496                                                         },
497                                                         "Master replication filter"
498                                                      );
499                                                   
500            1                                 30      is_deeply(
501                                                         $ms->get_replication_filters(dbh=>$slave_dbh),
502                                                         {
503                                                            replicate_ignore_db => 'foo',
504                                                         },
505                                                         "Slave replication filter"
506                                                      );
507                                                      
508            1                             1030323      diag(`/tmp/12346/stop >/dev/null`);
509            1                             3031164      diag(`/tmp/12345/stop >/dev/null`);
510            1                               6473      diag(`mv /tmp/12346/orig.cnf /tmp/12346/my.sandbox.cnf`);
511            1                               6642      diag(`mv /tmp/12345/orig.cnf /tmp/12345/my.sandbox.cnf`);
512            1                             1038704      diag(`/tmp/12345/start >/dev/null`);
513            1                             1039398      diag(`/tmp/12346/start >/dev/null`);
514                                                   }
515                                                   
516                                                   # #############################################################################
517                                                   # Done.
518                                                   # #############################################################################
519            1                             8193177   diag(`$trunk/sandbox/stop-sandbox remove 2903 2902 2901 2900 >/dev/null`);
520            1                                 10   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
179          100      1      3   unless $level
189   ***      0      0      0   unless $level
263   ***     50      0      1   if $EVAL_ERROR
276   ***     50      0      1   if $EVAL_ERROR
306   ***     50      0      1   if $EVAL_ERROR
324   ***     50      0      1   if $EVAL_ERROR
340   ***     50      0      1   if $EVAL_ERROR
466   ***     50      0      1   unless $master_dbh
468   ***     50      0      1   unless $slave_dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
243   ***     33      0      0      1   defined $res && $res >= 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
180   ***     50      3      0   $dp->as_string($dsn) || '<none>'
190   ***      0      0      0   $dp->as_string($dsn) || '<none>'


Covered Subroutines
-------------------

Subroutine Count Location         
---------- ----- -----------------
BEGIN          1 MasterSlave.t:10 
BEGIN          1 MasterSlave.t:11 
BEGIN          1 MasterSlave.t:12 
BEGIN          1 MasterSlave.t:14 
BEGIN          1 MasterSlave.t:15 
BEGIN          1 MasterSlave.t:16 
BEGIN          1 MasterSlave.t:17 
BEGIN          1 MasterSlave.t:18 
BEGIN          1 MasterSlave.t:4  
BEGIN          1 MasterSlave.t:9  
__ANON__       4 MasterSlave.t:178

Uncovered Subroutines
---------------------

Subroutine Count Location         
---------- ----- -----------------
__ANON__       0 MasterSlave.t:188


