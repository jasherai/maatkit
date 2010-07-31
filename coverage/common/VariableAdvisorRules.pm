---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/VariableAdvisorRules.pm  100.0   92.5   72.7  100.0    0.0   93.5   96.9
VariableAdvisorRules.t         96.6   50.0   33.3  100.0    n/a    6.5   87.1
Total                          99.0   87.0   55.0  100.0    0.0  100.0   94.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jul  8 23:13:06 2010
Finish:       Thu Jul  8 23:13:06 2010

Run:          VariableAdvisorRules.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jul  8 23:13:08 2010
Finish:       Thu Jul  8 23:13:08 2010

/home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010 Percona Inc.
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
18                                                    # VariableAdvisorRules package $Revision: 6688 $
19                                                    # ###########################################################################
20                                                    package VariableAdvisorRules;
21             1                    1             4   use base 'AdvisorRules';
               1                                  2   
               1                                  8   
22                                                    
23             1                    1             6   use strict;
               1                                  2   
               1                                  4   
24             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
25             1                    1             6   use English qw(-no_match_vars);
               1                                  6   
               1                                  4   
26    ***      1            50      1            10   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 12   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      6      my ( $class, %args ) = @_;
30             1                                 31      my $self = $class->SUPER::new(%args);
31             1                                 44      @{$self->{rules}} = $self->get_rules();
               1                                 19   
32             1                                  9      MKDEBUG && _d(scalar @{$self->{rules}}, "rules");
33             1                                  6      return $self;
34                                                    }
35                                                    
36                                                    # Each rules is a hashref with two keys:
37                                                    #   * id       Unique PREFIX.NUMBER for the rule.
38                                                    #   * code     Coderef to check rule, returns true if the rule matches.
39                                                    sub get_rules {
40                                                       return
41                                                       {
42                                                          id   => 'auto_increment',
43                                                          code => sub {
44            52                   52          1375            my ( %args ) = @_;
45            52                                167            my $vars = $args{variables};
46    ***     52    100     66                  382            return unless defined $vars->{auto_increment_increment}
47                                                                && defined $vars->{auto_increment_offset};
48             3    100    100                   33            return    $vars->{auto_increment_increment} != 1
49                                                                    || $vars->{auto_increment_offset}    != 1 ? 1 : 0;
50                                                          },
51                                                       },
52                                                       {
53                                                          id   => 'concurrent_insert',
54                                                          code => sub {
55            52                   52           835            my ( %args ) = @_;
56            52                                341            return _var_gt($args{variables}->{concurrent_insert}, 1);
57                                                          },
58                                                       },
59                                                       {
60                                                          id   => 'connect_timeout',
61                                                          code => sub {
62            52                   52           820            my ( %args ) = @_;
63            52                                274            return _var_gt($args{variables}->{connect_timeout}, 10);
64                                                          },
65                                                       },
66                                                       {
67                                                          id   => 'debug',
68                                                          code => sub {
69            52                   52           792            my ( %args ) = @_;
70            52    100                         298            return $args{variables}->{debug} ? 1 : 0;
71                                                          },
72                                                       },
73                                                       {
74                                                          id   => 'delay_key_write',
75                                                          code => sub {
76            52                   52           768            my ( %args ) = @_;
77            52                                269            return _var_seq($args{variables}->{delay_key_write}, "ON");
78                                                          },
79                                                       },
80                                                       {
81                                                          id   => 'flush',
82                                                          code => sub {
83            52                   52           921            my ( %args ) = @_;
84            52                                263            return _var_seq($args{variables}->{flush}, "ON");
85                                                          },
86                                                       },
87                                                       {
88                                                          id   => 'flush_time',
89                                                          code => sub {
90            52                   52           784            my ( %args ) = @_;
91            52                                283            return _var_gt($args{variables}->{flush_time}, 0);
92                                                          },
93                                                       },
94                                                       {
95                                                          id   => 'have_bdb',
96                                                          code => sub {
97            52                   52           795            my ( %args ) = @_;
98            52                                263            return _var_seq($args{variables}->{have_bdb}, 'YES');
99                                                          },
100                                                      },
101                                                      {
102                                                         id   => 'init_connect',
103                                                         code => sub {
104           52                   52           811            my ( %args ) = @_;
105           52    100                         289            return $args{variables}->{init_connect} ? 1 : 0;
106                                                         },
107                                                      },
108                                                      {
109                                                         id   => 'init_file',
110                                                         code => sub {
111           52                   52           795            my ( %args ) = @_;
112           52    100                         275            return $args{variables}->{init_file} ? 1 : 0;
113                                                         },
114                                                      },
115                                                      {
116                                                         id   => 'init_slave',
117                                                         code => sub {
118           52                   52           764            my ( %args ) = @_;
119           52    100                         274            return $args{variables}->{init_slave} ? 1 : 0;
120                                                         },
121                                                      },
122                                                      {
123                                                         id   => 'innodb_additional_mem_pool_size',
124                                                         code => sub {
125           52                   52           747            my ( %args ) = @_;
126           52                                277            return _var_gt($args{variables}->{innodb_additional_mem_pool_size},
127                                                               20 * 1_048_576);  # 20M
128                                                         },
129                                                      },
130                                                      {
131                                                         id   => 'innodb_buffer_pool_size',
132                                                         code => sub {
133           52                   52           803            my ( %args ) = @_;
134           52                                285            return _var_eq($args{variables}->{innodb_buffer_pool_size},
135                                                               10 * 1_048_576);  # 10M
136                                                         },
137                                                      },
138                                                      {
139                                                         id   => 'innodb_checksums',
140                                                         code => sub {
141           52                   52           796            my ( %args ) = @_;
142           52                                272            return _var_sneq($args{variables}->{innodb_checksums}, "ON");
143                                                         },
144                                                      },
145                                                      {
146                                                         id   => 'innodb_doublewrite',
147                                                         code => sub {
148           52                   52           785            my ( %args ) = @_;
149           52                                258            return _var_sneq($args{variables}->{innodb_doublewrite}, "ON");
150                                                         },
151                                                      },
152                                                      {
153                                                         id   => 'innodb_fast_shutdown',
154                                                         code => sub {
155           52                   52           783            my ( %args ) = @_;
156           52                                266            return _var_neq($args{variables}->{innodb_fast_shutdown}, 1);
157                                                         },
158                                                      },
159                                                      {
160                                                         id   => 'innodb_flush_log_at_trx_commit-1',
161                                                         code => sub {
162           52                   52           798            my ( %args ) = @_;
163           52                                266            return _var_neq($args{variables}->{innodb_flush_log_at_trx_commit}, 1);
164                                                         },
165                                                      },
166                                                      {
167                                                         id   => 'innodb_flush_log_at_trx_commit-2',
168                                                         code => sub {
169           52                   52           803            my ( %args ) = @_;
170           52                                267            return _var_eq($args{variables}->{innodb_flush_log_at_trx_commit}, 0);
171                                                         },
172                                                      },
173                                                      {
174                                                         id   => 'innodb_force_recovery',
175                                                         code => sub {
176           52                   52           785            my ( %args ) = @_;
177           52                                261            return _var_gt($args{variables}->{innodb_force_recovery}, 0);
178                                                         },
179                                                      },
180                                                      {
181                                                         id   => 'innodb_lock_wait_timeout',
182                                                         code => sub {
183           52                   52           805            my ( %args ) = @_;
184           52                                286            return _var_gt($args{variables}->{innodb_lock_wait_timeout}, 50);
185                                                         },
186                                                      },
187                                                      {
188                                                         id   => 'innodb_log_buffer_size',
189                                                         code => sub {
190           52                   52           788            my ( %args ) = @_;
191           52                                264            return _var_gt($args{variables}->{innodb_log_buffer_size},
192                                                               16 * 1_048_576);  # 16M
193                                                         },
194                                                      },
195                                                      {
196                                                         id   => 'innodb_log_file_size',
197                                                         code => sub {
198           52                   52           793            my ( %args ) = @_;
199           52                                262            return _var_eq($args{variables}->{innodb_log_file_size},
200                                                               5 * 1_048_576);  # 5M
201                                                         },
202                                                      },
203                                                      {
204                                                         id   => 'innodb_max_dirty_pages_pct',
205                                                         code => sub {
206           52                   52           795            my ( %args ) = @_;
207           52                                298            return _var_lt($args{variables}->{innodb_max_dirty_pages_pct}, 90);
208                                                         },
209                                                      },
210                                                      {
211                                                         id   => 'key_buffer_size',
212                                                         code => sub {
213           52                   52           792            my ( %args ) = @_;
214           52                                267            return _var_eq($args{variables}->{key_buffer_size},
215                                                               8 * 1_048_576);  # 8M
216                                                         },
217                                                      },
218                                                      {
219                                                         id   => 'large_pages',
220                                                         code => sub {
221           52                   52           803            my ( %args ) = @_;
222           52                                261            return _var_seq($args{variables}->{large_pages}, "ON");
223                                                         },
224                                                      },
225                                                      {
226                                                         id   => 'locked_in_memory',
227                                                         code => sub {
228           52                   52           787            my ( %args ) = @_;
229           52                                258            return _var_seq($args{variables}->{locked_in_memory}, "ON");
230                                                         },
231                                                      },
232                                                      {
233                                                         id   => 'log_warnings-1',
234                                                         code => sub {
235           52                   52           795            my ( %args ) = @_;
236           52                                257            return _var_eq($args{variables}->{log_warnings}, 0);
237                                                         },
238                                                      },
239                                                      {
240                                                         id   => 'log_warnings-2',
241                                                         code => sub {
242           52                   52           827            my ( %args ) = @_;
243           52                                263            return _var_eq($args{variables}->{log_warnings}, 1);
244                                                         },
245                                                      },
246                                                      {
247                                                         id   => 'low_priority_updates',
248                                                         code => sub {
249           52                   52           792            my ( %args ) = @_;
250           52                                271            return _var_seq($args{variables}->{low_priority_updates}, "ON");
251                                                         },
252                                                      },
253                                                      {
254                                                         id   => 'max_binlog_size',
255                                                         code => sub {
256           52                   52           817            my ( %args ) = @_;
257           52                                276            return _var_lt($args{variables}->{max_binlog_size},
258                                                               1 * 1_073_741_824);  # 1G
259                                                         },
260                                                      },
261                                                      {
262                                                         id   => 'max_connect_errors',
263                                                         code => sub {
264           52                   52           790            my ( %args ) = @_;
265           52                                280            return _var_eq($args{variables}->{max_connect_errors}, 10);
266                                                         },
267                                                      },
268                                                      {
269                                                         id   => 'max_connections',
270                                                         code => sub {
271           52                   52           801            my ( %args ) = @_;
272           52                                269            return _var_gt($args{variables}->{max_connections}, 1_000);
273                                                         },
274                                                      },
275                                                   
276                                                      {
277                                                         id   => 'myisam_repair_threads',
278                                                         code => sub {
279           52                   52           802            my ( %args ) = @_;
280           52                                260            return _var_gt($args{variables}->{myisam_repair_threads}, 1);
281                                                         },
282                                                      },
283                                                      {
284                                                         id   => 'old_passwords',
285                                                         code => sub {
286           52                   52           807            my ( %args ) = @_;
287           52                                269            return _var_seq($args{variables}->{old_passwords}, "ON");
288                                                         },
289                                                      },
290                                                      {
291                                                         id   => 'optimizer_prune_level',
292                                                         code => sub {
293           52                   52           808            my ( %args ) = @_;
294           52                                260            return _var_lt($args{variables}->{optimizer_prune_level}, 1);
295                                                         },
296                                                      },
297                                                      {
298                                                         id   => 'port',
299                                                         code => sub {
300           52                   52           793            my ( %args ) = @_;
301           52                                267            return _var_neq($args{variables}->{port}, 3306);
302                                                         },
303                                                      },
304                                                      {
305                                                         id   => 'query_cache_size-1',
306                                                         code => sub {
307           52                   52           815            my ( %args ) = @_;
308           52                                258            return _var_gt($args{variables}->{query_cache_size},
309                                                               128 * 1_048_576);  # 128M
310                                                         },
311                                                      },
312                                                      {
313                                                         id   => 'query_cache_size-2',
314                                                         code => sub {
315           52                   52           805            my ( %args ) = @_;
316           52                                268            return _var_gt($args{variables}->{query_cache_size},
317                                                               512 * 1_048_576);  # 512M
318                                                         },
319                                                      },
320                                                      {
321                                                         id   => 'read_buffer_size-1',
322                                                         code => sub {
323           52                   52           786            my ( %args ) = @_;
324           52                                260            return _var_neq($args{variables}->{read_buffer_size}, 131_072);
325                                                         },
326                                                      },
327                                                      {
328                                                         id   => 'read_buffer_size-2',
329                                                         code => sub {
330           52                   52           796            my ( %args ) = @_;
331           52                                262            return _var_gt($args{variables}->{read_buffer_size},
332                                                               8 * 1_048_576);  # 8M
333                                                         },
334                                                      },
335                                                      {
336                                                         id   => 'read_rnd_buffer_size-1',
337                                                         code => sub {
338           52                   52           807            my ( %args ) = @_;
339           52                                262            return _var_neq($args{variables}->{read_rnd_buffer_size}, 262_144);
340                                                         },
341                                                      },
342                                                      {
343                                                         id   => 'read_rnd_buffer_size-2',
344                                                         code => sub {
345           52                   52           810            my ( %args ) = @_;
346           52                                266            return _var_gt($args{variables}->{read_rnd_buffer_size},
347                                                               4 * 1_048_576);  # 4M
348                                                         },
349                                                      },
350                                                      {
351                                                         id   => 'relay_log_space_limit',
352                                                         code => sub {
353           52                   52           816            my ( %args ) = @_;
354           52                                269            return _var_gt($args{variables}->{relay_log_space_limit}, 0);
355                                                         },
356                                                      },
357                                                      
358                                                      {
359                                                         id   => 'slave_net_timeout',
360                                                         code => sub {
361           52                   52           794            my ( %args ) = @_;
362           52                                270            return _var_gt($args{variables}->{slave_net_timeout}, 60);
363                                                         },
364                                                      },
365                                                      {
366                                                         id   => 'slave_skip_errors',
367                                                         code => sub {
368           52                   52           791            my ( %args ) = @_;
369           52    100                         296            return $args{variables}->{slave_skip_errors} ? 1 : 0;
370                                                         },
371                                                      },
372                                                      {
373                                                         id   => 'sort_buffer_size-1',
374                                                         code => sub {
375           52                   52           761            my ( %args ) = @_;
376           52                                282            return _var_neq($args{variables}->{sort_buffer_size}, 2_097_144);
377                                                         },
378                                                      },
379                                                      {
380                                                         id   => 'sort_buffer_size-2',
381                                                         code => sub {
382           52                   52           794            my ( %args ) = @_;
383           52                                264            return _var_gt($args{variables}->{sort_buffer_size},
384                                                               4 * 1_048_576);  # 4M
385                                                         },
386                                                      },
387                                                      {
388                                                         id   => 'sql_notes',
389                                                         code => sub {
390           52                   52           798            my ( %args ) = @_;
391           52                                280            return _var_eq($args{variables}->{sql_notes}, 0);
392                                                         },
393                                                      },
394                                                      {
395                                                         id   => 'sync_frm',
396                                                         code => sub {
397           52                   52           793            my ( %args ) = @_;
398           52                                259            return _var_sneq($args{variables}->{sync_frm}, "ON");
399                                                         },
400                                                      },
401                                                      {
402                                                         id   => 'tx_isolation-1',
403                                                         code => sub {
404           52                   52           788            my ( %args ) = @_;
405           52                                255            return _var_sneq($args{variables}->{tx_isolation}, "REPEATABLE-READ");
406                                                         },
407                                                      },
408                                                      {
409                                                         id   => 'tx_isolation-2',
410                                                         code => sub {
411           52                   52           798            my ( %args ) = @_;
412                                                            return
413   ***     52    100     66                  261                  _var_sneq($args{variables}->{tx_isolation}, "REPEATABLE-READ")
414                                                               || _var_sneq($args{variables}->{tx_isolation}, "READ-COMMITTED")
415                                                               ? 1 : 0;
416                                                         },
417                                                      },
418   ***      3                    3      0    773   };
419                                                   
420                                                   sub _var_gt {
421          832                  832          3028      my ($var, $val) = @_;
422          832    100                        4573      return 0 unless defined $var;
423           21    100                         120      return $var > $val ? 1 : 0;
424                                                   }
425                                                   
426                                                   sub _var_lt {
427          156                  156           572      my ($var, $val) = @_;
428          156    100                         852      return 0 unless defined $var;
429   ***      3     50                          19      return $var < $val ? 1 : 0;
430                                                   }
431                                                   
432                                                   sub _var_eq {
433          426                  426          1534      my ($var, $val) = @_;
434          426    100                        2347      return 0 unless defined $var;
435           21    100                         134      return $var == $val ? 1 : 0;
436                                                   }
437                                                   
438                                                   sub _var_neq {
439          312                  312          1129      my ($var, $val) = @_;
440          312    100                        1667      return 0 unless defined $var;
441   ***     10     50                          35      return _var_eq($var, $val) ? 0 : 1;
442                                                   }
443                                                   
444                                                   sub _var_seq {
445          369                  369          1390      my ($var, $val) = @_;
446          369    100                        2041      return 0 unless defined $var;
447           12    100                          73      return $var eq $val ? 1 : 0;
448                                                   }
449                                                   
450                                                   sub _var_sneq {
451          311                  311          1176      my ($var, $val) = @_;
452          311    100                        2055      return 0 unless defined $var;
453   ***      5     50                          17      return _var_seq($var, $val) ? 0 : 1;
454                                                   }
455                                                   
456                                                   1;
457                                                   
458                                                   # ###########################################################################
459                                                   # End VariableAdvisorRules package
460                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
46           100     49      3   unless defined $$vars{'auto_increment_increment'} and defined $$vars{'auto_increment_offset'}
48           100      2      1   $$vars{'auto_increment_increment'} != 1 || $$vars{'auto_increment_offset'} != 1 ? :
70           100      1     51   $args{'variables'}{'debug'} ? :
105          100      1     51   $args{'variables'}{'init_connect'} ? :
112          100      1     51   $args{'variables'}{'init_file'} ? :
119          100      1     51   $args{'variables'}{'init_slave'} ? :
369          100      1     51   $args{'variables'}{'slave_skip_errors'} ? :
413          100      1     51   _var_sneq($args{'variables'}{'tx_isolation'}, 'REPEATABLE-READ') || _var_sneq($args{'variables'}{'tx_isolation'}, 'READ-COMMITTED') ? :
422          100    811     21   unless defined $var
423          100     17      4   $var > $val ? :
428          100    153      3   unless defined $var
429   ***     50      3      0   $var < $val ? :
434          100    405     21   unless defined $var
435          100      8     13   $var == $val ? :
440          100    302     10   unless defined $var
441   ***     50      0     10   _var_eq($var, $val) ? :
446          100    357     12   unless defined $var
447          100      7      5   $var eq $val ? :
452          100    306      5   unless defined $var
453   ***     50      0      5   _var_seq($var, $val) ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
46    ***     66     49      0      3   defined $$vars{'auto_increment_increment'} and defined $$vars{'auto_increment_offset'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
48           100      1      1      1   $$vars{'auto_increment_increment'} != 1 || $$vars{'auto_increment_offset'} != 1
413   ***     66      1      0     51   _var_sneq($args{'variables'}{'tx_isolation'}, 'REPEATABLE-READ') || _var_sneq($args{'variables'}{'tx_isolation'}, 'READ-COMMITTED')


Covered Subroutines
-------------------

Subroutine Count Pod Location                                                                
---------- ----- --- ------------------------------------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:21 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:23 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:24 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:25 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:26 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:104
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:111
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:118
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:125
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:133
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:141
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:148
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:155
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:162
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:169
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:176
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:183
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:190
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:198
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:206
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:213
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:221
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:228
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:235
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:242
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:249
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:256
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:264
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:271
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:279
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:286
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:293
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:300
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:307
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:315
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:323
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:330
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:338
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:345
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:353
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:361
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:368
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:375
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:382
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:390
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:397
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:404
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:411
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:44 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:55 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:62 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:69 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:76 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:83 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:90 
__ANON__      52     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:97 
_var_eq      426     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:433
_var_gt      832     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:421
_var_lt      156     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:427
_var_neq     312     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:439
_var_seq     369     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:445
_var_sneq    311     /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:451
get_rules      3   0 /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:418
new            1   0 /home/daniel/dev/maatkit/working-copy/common/VariableAdvisorRules.pm:29 


VariableAdvisorRules.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  3   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            10   use Test::More tests => 56;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use PodParser;
               1                                  3   
               1                                 10   
15             1                    1            12   use AdvisorRules;
               1                                  3   
               1                                  9   
16             1                    1            10   use VariableAdvisorRules;
               1                                  3   
               1                                  9   
17             1                    1            11   use Advisor;
               1                                  3   
               1                                 10   
18             1                    1            10   use MaatkitTest;
               1                                  4   
               1                                 38   
19                                                    
20             1                                 10   my $p   = new PodParser();
21             1                                 42   my $var = new VariableAdvisorRules(PodParser => $p);
22                                                    
23             1                                  9   isa_ok($var, 'VariableAdvisorRules');
24                                                    
25             1                                  9   my @rules = $var->get_rules();
26             1                                 12   ok(
27                                                       scalar @rules,
28                                                       'Returns array of rules'
29                                                    );
30                                                    
31             1                                  3   my $rules_ok = 1;
32             1                                  4   foreach my $rule ( @rules ) {
33    ***     51     50     33                  856      if (    !$rule->{id}
      ***                   33                        
34                                                            || !$rule->{code}
35                                                            || (ref $rule->{code} ne 'CODE') )
36                                                       {
37    ***      0                                  0         $rules_ok = 0;
38    ***      0                                  0         last;
39                                                       }
40                                                    }
41                                                    ok(
42             1                                  5      $rules_ok,
43                                                       'All rules are proper'
44                                                    );
45                                                    
46                                                    
47                                                    # #############################################################################
48                                                    # Test the rules.
49                                                    # #############################################################################
50             1                                219   my @cases = (
51                                                       {  name   => "auto inc 1",
52                                                          vars   => [qw(auto_increment_increment 1 auto_increment_offset 1)],
53                                                          advice => [],
54                                                       },
55                                                       {  name   => "auto inc 2",
56                                                          vars   => [qw(auto_increment_increment 2 auto_increment_offset 1)],
57                                                          advice => [qw(auto_increment)],
58                                                       },
59                                                       {  name   => "auto inc 3",
60                                                          vars   => [qw(auto_increment_increment 1 auto_increment_offset 3)],
61                                                          advice => [qw(auto_increment)],
62                                                       },
63                                                       {  name   => "concurrent insert",
64                                                          vars   => [qw(concurrent_insert 2)],
65                                                          advice => [qw(concurrent_insert)],
66                                                       },
67                                                       {  name   => "connect timeout",
68                                                          vars   => [qw(connect_timeout 11)],
69                                                          advice => [qw(connect_timeout)],
70                                                       },
71                                                       {  name   => "debug",
72                                                          vars   => [qw(debug ON)],
73                                                          advice => [qw(debug)],
74                                                       },
75                                                       {  name   => "delay_key_write",
76                                                          vars   => [qw(delay_key_write ON)],
77                                                          advice => [qw(delay_key_write)],
78                                                       },
79                                                       {  name   => "flush",
80                                                          vars   => [qw(flush ON)],
81                                                          advice => [qw(flush)],
82                                                       },
83                                                       {  name   => "flush time",
84                                                          vars   => [qw(flush_time 1)],
85                                                          advice => [qw(flush_time)],
86                                                       },
87                                                       {  name   => "have bdb",
88                                                          vars   => [qw(have_bdb YES)],
89                                                          advice => [qw(have_bdb)],
90                                                       },
91                                                       {  name   => "init connect",
92                                                          vars   => [qw(init_connect foo)],
93                                                          advice => [qw(init_connect)],
94                                                       },
95                                                       {  name   => "init_file",
96                                                          vars   => [qw(init_file bar)],
97                                                          advice => [qw(init_file)],
98                                                       },
99                                                       {  name   => "init slave",
100                                                         vars   => [qw(init_slave 12346)],
101                                                         advice => [qw(init_slave)],
102                                                      },
103                                                      {  name   => "innodb_additional_mem_pool_size",
104                                                         vars   => [qw(innodb_additional_mem_pool_size 21000000)],
105                                                         advice => [qw(innodb_additional_mem_pool_size)],
106                                                      },
107                                                      {  name   => "innodb_buffer_pool_size",
108                                                         vars   => [qw(innodb_buffer_pool_size 10485760)],
109                                                         advice => [qw(innodb_buffer_pool_size)],
110                                                      },
111                                                      {  name   => "innodb checksums",
112                                                         vars   => [qw(innodb_checksums OFF)],
113                                                         advice => [qw(innodb_checksums)],
114                                                      },
115                                                      {  name   => "innodb_doublewrite",
116                                                         vars   => [qw(innodb_doublewrite OFF)],
117                                                         advice => [qw(innodb_doublewrite)],
118                                                      },
119                                                      {  name   => "innodb_fast_shutdown",
120                                                         vars   => [qw(innodb_fast_shutdown 0)],
121                                                         advice => [qw(innodb_fast_shutdown)],
122                                                      },
123                                                      {  name   => "innodb_flush_log_at_trx_commit-1",
124                                                         vars   => [qw(innodb_flush_log_at_trx_commit 2)],
125                                                         advice => [qw(innodb_flush_log_at_trx_commit-1)],
126                                                      },
127                                                      {  name   => "innodb_flush_log_at_trx_commit-2",
128                                                         vars   => [qw(innodb_flush_log_at_trx_commit 0)],
129                                                         advice => [qw(innodb_flush_log_at_trx_commit-1 innodb_flush_log_at_trx_commit-2)],
130                                                      },
131                                                      {  name   => "innodb_force_recovery",
132                                                         vars   => [qw(innodb_force_recovery 1)],
133                                                         advice => [qw(innodb_force_recovery)],
134                                                      },
135                                                      {  name   => "innodb_lock_wait_timeout",
136                                                         vars   => [qw(innodb_lock_wait_timeout 51)],
137                                                         advice => [qw(innodb_lock_wait_timeout)],
138                                                      },
139                                                      {  name   => "innodb_log_buffer_size",
140                                                         vars   => [qw(innodb_log_buffer_size 17000000)],
141                                                         advice => [qw(innodb_log_buffer_size)],
142                                                      },
143                                                      {  name   => "innodb_log_file_size",
144                                                         vars   => [qw(innodb_log_file_size 5242880)],
145                                                         advice => [qw(innodb_log_file_size)],
146                                                      },
147                                                      {  name   => "innodb_max_dirty_pages_pct",
148                                                         vars   => [qw(innodb_max_dirty_pages_pct 89)],
149                                                         advice => [qw(innodb_max_dirty_pages_pct)],
150                                                      },
151                                                      {  name   => "key_buffer_size",
152                                                         vars   => [qw(key_buffer_size 8388608)],
153                                                         advice => [qw(key_buffer_size)],
154                                                      },
155                                                      {  name   => "large_pages",
156                                                         vars   => [qw(large_pages ON)],
157                                                         advice => [qw(large_pages)],
158                                                      },
159                                                      {  name   => "locked in memory",
160                                                         vars   => [qw(locked_in_memory ON)],
161                                                         advice => [qw(locked_in_memory)],
162                                                      },
163                                                      {  name   => "log_warnings-1",
164                                                         vars   => [qw(log_warnings 0)],
165                                                         advice => [qw(log_warnings-1)],
166                                                      },
167                                                      {  name   => "log_warnings-2",
168                                                         vars   => [qw(log_warnings 1)],
169                                                         advice => [qw(log_warnings-2)],
170                                                      },
171                                                      {  name   => "low_priority_updates",
172                                                         vars   => [qw(low_priority_updates ON)],
173                                                         advice => [qw(low_priority_updates)],
174                                                      },
175                                                      {  name   => "max_binlog_size",
176                                                         vars   => [qw(max_binlog_size 999999999)],
177                                                         advice => [qw(max_binlog_size)],
178                                                      },
179                                                      {  name   => "max_connect_errors",
180                                                         vars   => [qw(max_connect_errors 10)],
181                                                         advice => [qw(max_connect_errors)],
182                                                      },
183                                                      {  name   => "max_connections",
184                                                         vars   => [qw(max_connections 1001)],
185                                                         advice => [qw(max_connections)],
186                                                      },
187                                                      {  name   => "myisam_repair_threads",
188                                                         vars   => [qw(myisam_repair_threads 2)],
189                                                         advice => [qw(myisam_repair_threads)],
190                                                      },
191                                                      {  name   => "old passwords",
192                                                         vars   => [qw(old_passwords ON)],
193                                                         advice => [qw(old_passwords)],
194                                                      },
195                                                      {  name   => "optimizer_prune_level",
196                                                         vars   => [qw(optimizer_prune_level 0)],
197                                                         advice => [qw(optimizer_prune_level)],
198                                                      },
199                                                      {  name   => "port",
200                                                         vars   => [qw(port 12345)],
201                                                         advice => [qw(port)],
202                                                      },
203                                                      {  name   => "query_cache_size-1",
204                                                         vars   => [qw(query_cache_size 134217729)],
205                                                         advice => [qw(query_cache_size-1)],
206                                                      },
207                                                      {  name   => "query_cache_size-2",
208                                                         vars   => [qw(query_cache_size 536870913)],
209                                                         advice => [qw(query_cache_size-1 query_cache_size-2)],
210                                                      },
211                                                      {  name   => "read_buffer_size-1",
212                                                         vars   => [qw(read_buffer_size 130000)],
213                                                         advice => [qw(read_buffer_size-1)],
214                                                      },
215                                                      {  name   => "read_buffer_size-2",
216                                                         vars   => [qw(read_buffer_size 8500000)],
217                                                         advice => [qw(read_buffer_size-1 read_buffer_size-2)],
218                                                      },
219                                                      {  name   => "read_rnd_buffer_size-1",
220                                                         vars   => [qw(read_rnd_buffer_size 262000)],
221                                                         advice => [qw(read_rnd_buffer_size-1)],
222                                                      },
223                                                      {  name   => "read_rnd_buffer_size-2",
224                                                         vars   => [qw(read_rnd_buffer_size 7000000)],
225                                                         advice => [qw(read_rnd_buffer_size-1 read_rnd_buffer_size-2)],
226                                                      },
227                                                      {  name   => "relay_log_space_limit",
228                                                         vars   => [qw(relay_log_space_limit 1)],
229                                                         advice => [qw(relay_log_space_limit)],
230                                                      },
231                                                      {  name   => "slave net timeout",
232                                                         vars   => [qw(slave_net_timeout 61)],
233                                                         advice => [qw(slave_net_timeout)],
234                                                      },
235                                                      {  name   => "slave skip errors",
236                                                         vars   => [qw(slave_skip_errors 1024)],
237                                                         advice => [qw(slave_skip_errors)],
238                                                      },
239                                                      {  name   => "sort_buffer_size-1",
240                                                         vars   => [qw(sort_buffer_size 2097140)],
241                                                         advice => [qw(sort_buffer_size-1)],
242                                                      },
243                                                      {  name   => "sort_buffer_size-2",
244                                                         vars   => [qw(sort_buffer_size 5000000)],
245                                                         advice => [qw(sort_buffer_size-1 sort_buffer_size-2)],
246                                                      },
247                                                      {  name   => "sql notes",
248                                                         vars   => [qw(sql_notes 0)],
249                                                         advice => [qw(sql_notes)],
250                                                      },
251                                                      {  name   => "sync_frm",
252                                                         vars   => [qw(sync_frm OFF)],
253                                                         advice => [qw(sync_frm)],
254                                                      },
255                                                      {  name   => "tx_isolation-1",
256                                                         vars   => [qw(tx_isolation foo)],
257                                                         advice => [qw(tx_isolation-1 tx_isolation-2)],
258                                                      },
259                                                   );
260                                                   
261                                                   
262            1                                 12   my $adv = new Advisor(match_type => "bool");
263            1                                 55   $adv->load_rules($var);
264                                                   
265            1                               1311   foreach my $test ( @cases ) {
266           52                                132      my %vars  = @{$test->{vars}};
              52                                311   
267           52                                301      my ($ids) = $adv->run_rules(variables=>\%vars);
268                                                   
269           52                               1108      is_deeply(
270                                                         $ids,
271                                                         $test->{advice},
272                                                         $test->{name},
273                                                      );
274                                                   
275                                                      # To help me debug.
276   ***     52     50                         502      die if $test->{stop};
277                                                   }
278                                                   
279                                                   # #############################################################################
280                                                   # Done.
281                                                   # #############################################################################
282            1                                  4   my $output = '';
283                                                   {
284            1                                  3      local *STDERR;
               1                                  9   
285            1                    1             2      open STDERR, '>', \$output;
               1                                309   
               1                                  2   
               1                                  7   
286            1                                 20      $p->_d('Complete test coverage');
287                                                   }
288                                                   like(
289            1                                 25      $output,
290                                                      qr/Complete test coverage/,
291                                                      '_d() works'
292                                                   );
293            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}
33    ***     50      0     51   if (not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE')
276   ***     50      0     52   if $$test{'stop'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
33    ***     33      0      0     51   not $$rule{'id'} or not $$rule{'code'}
      ***     33      0      0     51   not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE'


Covered Subroutines
-------------------

Subroutine Count Location                  
---------- ----- --------------------------
BEGIN          1 VariableAdvisorRules.t:10 
BEGIN          1 VariableAdvisorRules.t:11 
BEGIN          1 VariableAdvisorRules.t:12 
BEGIN          1 VariableAdvisorRules.t:14 
BEGIN          1 VariableAdvisorRules.t:15 
BEGIN          1 VariableAdvisorRules.t:16 
BEGIN          1 VariableAdvisorRules.t:17 
BEGIN          1 VariableAdvisorRules.t:18 
BEGIN          1 VariableAdvisorRules.t:285
BEGIN          1 VariableAdvisorRules.t:4  
BEGIN          1 VariableAdvisorRules.t:9  


