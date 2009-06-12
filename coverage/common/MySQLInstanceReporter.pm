---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../MySQLInstanceReporter.pm    9.7    0.0    0.0   46.2    n/a  100.0   10.5
Total                           9.7    0.0    0.0   46.2    n/a  100.0   10.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLInstanceReporter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:35 2009
Finish:       Wed Jun 10 17:20:35 2009

/home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Percona Inc.
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
17                                                    
18                                                    # ###########################################################################
19                                                    # MySQLInstanceReporter package $Revision: 3469 $
20                                                    # ###########################################################################
21                                                    package MySQLInstanceReporter;
22                                                    
23             1                    1             9   use strict;
               1                                  4   
               1                                153   
24             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 20   
26                                                    
27                                                    Transformers->import( qw(micro_t shorten secs_to_time) );
28                                                    
29             1                    1             7   use constant MKDEBUG     => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
30             1                    1             6   use constant LINE_LENGTH => 74;
               1                                  6   
               1                                  5   
31                                                    
32                                                    sub new {
33             1                    1             8      my ( $class, %args ) = @_;
34             1                                  4      my $self = {};
35             1                                 33      return bless $self, $class;
36                                                    }
37                                                    
38                                                    sub report {
39    ***      0                    0                    my ( $self, %args ) = @_;
40    ***      0                                         foreach my $arg ( qw(mi n ps schema ma o proclist) ) {
41    ***      0      0                                     die "I need a $arg argument" unless $args{$arg};
42                                                       }
43    ***      0                                         my $mi       = $args{mi};
44    ***      0                                         my $n        = $args{n};
45    ***      0                                         my $ps       = $args{ps};
46    ***      0                                         my $schema   = $args{schema};
47    ***      0                                         my $ma       = $args{ma};
48    ***      0                                         my $o        = $args{o};
49    ***      0                                         my $proclist = $args{proclist};
50                                                    
51                                                    format MYSQL_INSTANCE_1 =
52                                                    
53                                                    ____________________________________________________________ MySQL Instance @>>
54                                                    $n
55                                                       Version:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Architecture: @<-bit
56                                                    $mi->{online_sys_vars}->{version}, $mi->{regsize}
57                                                       Uptime:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
58                                                    secs_to_time($mi->{status_vals}->{Uptime})
59                                                       ps vals:  user @<<<<<<< cpu% @<<<<< rss @<<<<<< vsz @<<<<<< syslog: @<<
60                                                    $ps->{user}, $ps->{pcpu}, shorten($ps->{rss} * 1024), shorten($ps->{vsz} * 1024), $ps->{syslog}
61                                                       Bin:      @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
62                                                    $mi->{mysqld_binary}
63                                                       Data dir: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
64                                                    $mi->{online_sys_vars}->{datadir}
65                                                       PID file: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
66                                                    $mi->{online_sys_vars}->{pid_file}
67                                                       Socket:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
68                                                    $mi->{online_sys_vars}->{'socket'}
69                                                       Port:     @<<<<<<
70                                                    $mi->{online_sys_vars}->{port}
71                                                       Log locations:
72                                                          Error:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
73                                                    $mi->{conf_sys_vars}->{log_error} || ''
74                                                          Relay:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
75                                                    $mi->{conf_sys_vars}->{relay_log} || ''
76                                                          Slow:   @<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
77                                                    micro_t($mi->{online_sys_vars}->{long_query_time}), $mi->{conf_sys_vars}->{log_slow_queries} || 'OFF'
78                                                       Config file location: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
79                                                    $mi->{cmd_line_ops}->{defaults_file}
80                                                    .
81                                                    
82    ***      0                                         $FORMAT_NAME = 'MYSQL_INSTANCE_1';
83    ***      0                                         write;
84                                                    
85    ***      0      0                                  if ( $schema->{counts}->{TOTAL}->{dbs} == 0 ) {
86                                                          # This can happen of the user doesn't have privs to see any dbs,
87                                                          # or in the rare case that there really aren't any dbs.
88    ***      0                                            print "This MySQL instance has no databases.\n"
89                                                       }
90                                                       else {
91                                                    format MYSQL_INSTANCE_2 =
92                                                       SCHEMA ________________________________________________________________
93                                                          #DATABASES   #TABLES   #ROWS     #INDEXES   SIZE DATA   SIZE INDEXES
94                                                          @<<<<<<      @<<<<<<   @<<<<<<   @<<<<<<    @<<<<<<     @<<<<<<
95                                                    $schema->{counts}->{TOTAL}->{dbs}, $schema->{counts}->{TOTAL}->{tables}, shorten($schema->{counts}->{TOTAL}->{rows}, d=>1000), $schema->{counts}->{TOTAL}->{indexes} || 'NA', shorten($schema->{counts}->{TOTAL}->{data_size}), shorten($schema->{counts}->{TOTAL}->{index_size})
96                                                    
97                                                          Key buffer size        : @<<<<<<
98                                                    shorten($mi->{online_sys_vars}->{key_buffer_size})
99                                                          InnoDB buffer pool size: @<<<<<<
100                                                   exists $mi->{online_sys_vars}->{innodb_buffer_pool_size} ? shorten($mi->{online_sys_vars}->{innodb_buffer_pool_size}) : ''
101                                                   
102                                                   .
103                                                   
104   ***      0                                            $FORMAT_NAME = 'MYSQL_INSTANCE_2';
105   ***      0                                            write;
106                                                   
107   ***      0                                            $self->_print_dbs_size_summary($schema, $o);
108   ***      0                                            $self->_print_tables_size_summary($schema, $o);
109   ***      0                                            $self->_print_engines_summary($schema, $o);
110   ***      0                                            $self->_print_stored_code_summary($schema, $o);
111                                                      }
112                                                   
113   ***      0                                         print "\n   PROBLEMS ______________________________________________________________\n";
114                                                   
115   ***      0                                         my $duplicates = $mi->duplicate_sys_vars();
116   ***      0      0                                  if ( scalar @{ $duplicates } ) {
      ***      0                                      
117   ***      0                                            print "\tDuplicate system variables in config file:\n";
118   ***      0                                            print "\tVARIABLE\n";
119   ***      0                                            foreach my $var ( @{ $duplicates } ) {
      ***      0                                      
120   ***      0                                               print "\t$var\n";
121                                                         }
122   ***      0                                            print "\n";
123                                                      }
124                                                   
125   ***      0                                         my $three_cols = "\t%-20.20s  %-24.24s  %-24.24s\n";
126                                                   
127   ***      0                                         my $overridens = $mi->overriden_sys_vars();
128   ***      0      0                                  if ( scalar keys %{ $overridens } ) {
      ***      0                                      
129   ***      0                                            print "\tOverridden system variables "
130                                                            . "(cmd line value overrides config value):\n";
131   ***      0                                            printf($three_cols, 'VARIABLE', 'CMD LINE VALUE', 'CONFIG VALUE');
132   ***      0                                            foreach my $var ( keys %{ $overridens } ) {
      ***      0                                      
133   ***      0                                               printf($three_cols,
134                                                                   $var,
135                                                                   $overridens->{$var}->[0],
136                                                                   $overridens->{$var}->[1]);
137                                                         }
138   ***      0                                            print "\n";
139                                                      }
140                                                   
141   ***      0                                         my $oos = $mi->out_of_sync_sys_vars();
142   ***      0      0                                  if ( scalar keys %{ $oos } ) {
      ***      0                                      
143   ***      0                                            print "\tOut of sync system variables "
144                                                            . "(online value differs from config value):\n";
145   ***      0                                            printf($three_cols, 'VARIABLE', 'ONLINE VALUE', 'CONFIG VALUE');
146   ***      0                                            foreach my $var ( keys %{ $oos } ) {
      ***      0                                      
147   ***      0                                               printf($three_cols,
148                                                                   $var,
149                                                                   $oos->{$var}->{online},
150                                                                   $oos->{$var}->{config});
151                                                         }
152   ***      0                                            print "\n";
153                                                      }
154                                                   
155   ***      0                                         my $failed_checks = $ma->run_checks();
156   ***      0      0                                  if ( scalar keys %{ $failed_checks } ) {
      ***      0                                      
157   ***      0                                            print "\tThings to Note:\n";
158   ***      0                                            foreach my $check_name ( keys %{ $failed_checks } ) {
      ***      0                                      
159   ***      0                                               print "\t\t- $failed_checks->{$check_name}\n";
160                                                         }
161                                                      }
162                                                   
163   ***      0                                         $self->_print_aggregated_processlist($proclist);
164                                                   
165   ***      0                                         return;
166                                                   }
167                                                   
168                                                   sub _print_dbs_size_summary {
169   ***      0                    0                    my ( $self, $schema, $o ) = @_;
170   ***      0                                         my %dbs = %{ $schema->{counts}->{dbs} }; # copy we can chop
      ***      0                                      
171   ***      0                                         my $top = $o->get('top');
172   ***      0                                         my @sorted;
173   ***      0                                         my ( $db, $size );
174   ***      0                                         print   "      Top $top largest databases:\n"
175                                                            . "         DATABASE             SIZE DATA\n";
176                                                   format DB_LINE =
177                                                            @<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<
178                                                   $db, $size
179                                                   .
180   ***      0                                         @sorted = sort { $dbs{$b}->{data_size} <=> $dbs{$a}->{data_size} } keys %dbs;
      ***      0                                      
181   ***      0                                         $FORMAT_NAME = 'DB_LINE';
182   ***      0                                         foreach $db ( @sorted ) {
183   ***      0                                            $size = shorten($dbs{$db}->{data_size});
184   ***      0                                            write;
185   ***      0                                            delete $dbs{$db};
186   ***      0      0                                     last if !--$top;
187                                                      }
188   ***      0                                         my $n_remaining = 0;
189   ***      0                                         my $r_size      = 0;
190   ***      0                                         my $r_avg       = 0;
191   ***      0                                         foreach my $db ( keys %dbs ) {
192   ***      0                                            $n_remaining++;
193   ***      0                                            $r_size += $dbs{$db}->{data_size};
194                                                      }
195   ***      0      0                                  if ($n_remaining) {
196   ***      0                                            $r_avg = shorten($r_size / $n_remaining);
197   ***      0                                            $r_size = shorten($r_size);
198   ***      0                                            $db   = "Remaining $n_remaining";
199   ***      0                                            $size = "$r_size ($r_avg average)";
200   ***      0                                            write;
201                                                      }
202   ***      0                                         return;
203                                                   }
204                                                   
205                                                   sub _print_tables_size_summary {
206   ***      0                    0                    my ( $self, $schema, $o ) = @_;
207   ***      0                                         my %dbs_tbls;
208   ***      0                                         my $dbs = $schema->{dbs};
209   ***      0                                         my $top = $o->get('top');
210   ***      0                                         my @sorted;
211   ***      0                                         my ( $db_tbl, $size_data, $size_index, $n_rows, $engine );
212   ***      0                                         print   "      Top $top largest tables:\n"
213                                                            . "         DB.TBL              SIZE DATA  SIZE INDEX  #ROWS    ENGINE\n";
214                                                   format TBL_LINE =
215                                                            @<<<<<<<<<<<<<<<<   @<<<<<<<<  @<<<<<<<<<  @<<<<<<  @<<<<<
216                                                   $db_tbl, $size_data, $size_index, $n_rows, $engine
217                                                   .
218                                                      # Build a schema-wide list of db.table => size
219   ***      0                                         foreach my $db ( keys %$dbs ) {
220   ***      0                                            foreach my $tbl ( keys %{$dbs->{$db}} ) {
      ***      0                                      
221   ***      0                                               $dbs_tbls{"$db.$tbl"} = $dbs->{$db}->{$tbl}->{data_length};
222                                                         }
223                                                      }
224   ***      0                                         @sorted = sort { $dbs_tbls{$b} <=> $dbs_tbls{$a} } keys %dbs_tbls;
      ***      0                                      
225   ***      0                                         $FORMAT_NAME = 'TBL_LINE';
226   ***      0                                         foreach $db_tbl ( @sorted ) {
227   ***      0                                            my ( $db, $tbl ) = split '\.', $db_tbl;
228   ***      0                                            $size_data  = shorten($dbs_tbls{$db_tbl});
229   ***      0                                            $size_index = shorten($dbs->{$db}->{$tbl}->{index_length});
230   ***      0                                            $n_rows     = shorten($dbs->{$db}->{$tbl}->{rows}, d=>1000);
231   ***      0                                            $engine     = $dbs->{$db}->{$tbl}->{engine};
232   ***      0                                            write;
233   ***      0                                            delete $dbs_tbls{$db_tbl};
234   ***      0      0                                     last if !--$top;
235                                                      }
236   ***      0                                         my $n_remaining = 0;
237   ***      0                                         my $r_size      = 0;
238   ***      0                                         my $r_avg       = 0;
239   ***      0                                         foreach my $db_tbl ( keys %dbs_tbls ) {
240   ***      0                                            $n_remaining++;
241   ***      0                                            $r_size += $dbs_tbls{$db_tbl};
242                                                      }
243   ***      0      0                                  if ($n_remaining) {
244   ***      0                                            $r_avg  = shorten($r_size / $n_remaining);
245   ***      0                                            $r_size = shorten($r_size);
246   ***      0                                            print "         Remaining $n_remaining        $r_size ($r_avg average)\n";
247                                                      }
248   ***      0                                         return;
249                                                   }
250                                                   
251                                                   sub _print_engines_summary {
252   ***      0                    0                    my ( $self, $schema, $o ) = @_;
253   ***      0                                         my $engines = $schema->{counts}->{engines};
254   ***      0                                         my ($engine, $n_tables, $n_indexes, $size_data, $size_indexes);
255   ***      0                                         print   "      Engines:\n"
256                                                            . "         ENGINE      SIZE DATA   SIZE INDEX   #TABLES   #INDEXES\n";
257                                                   format ENGINE_LINE =
258                                                            @<<<<<<<<<  @<<<<<<     @<<<<<<      @<<<<<<   @<<<<<<
259                                                   $engine, $size_data, $size_indexes, $n_tables, $n_indexes
260                                                   .
261   ***      0                                         $FORMAT_NAME = 'ENGINE_LINE';
262   ***      0                                         foreach $engine ( keys %{ $engines } ) {
      ***      0                                      
263   ***      0                                            $size_data    = shorten($engines->{$engine}->{data_size});
264   ***      0                                            $size_indexes = shorten($engines->{$engine}->{index_size});
265   ***      0                                            $n_tables     = $engines->{$engine}->{tables};
266   ***      0             0                              $n_indexes    = $engines->{$engine}->{indexes} || 'NA';
267   ***      0                                            write;
268                                                      }
269   ***      0                                         return;
270                                                   }
271                                                   
272                                                   sub _print_stored_code_summary {
273   ***      0                    0                    my ( $self, $schema, $o ) = @_;
274   ***      0                                         my ( $db, $type, $count );
275                                                   
276   ***      0                                         print   "      Triggers, Routines, Events:\n"
277                                                            . "         DATABASE           TYPE      COUNT\n";
278                                                   format TRE_LINE =
279                                                            @<<<<<<<<<<<<<<<<  @<<<<<<   @<<<<<<
280                                                   $db, $type, $count
281                                                   .
282                                                   
283   ***      0      0                                  if ( ref $schema->{stored_code} ) {
284   ***      0                                            my @stored_code_objs = @{$schema->{stored_code}};
      ***      0                                      
285   ***      0      0                                     if ( @stored_code_objs ) {
286   ***      0                                               $FORMAT_NAME = 'TRE_LINE';
287   ***      0                                               foreach my $code_obj ( @stored_code_objs ) {
288   ***      0                                                  ( $db, $type, $count ) = split ' ', $code_obj;
289   ***      0                                                  write;
290                                                            }
291                                                         }
292                                                         else {
293   ***      0                                               print "         No triggers, routines, or events\n";
294                                                         }
295                                                      }
296                                                      else {
297   ***      0                                            print "         $schema->{stored_code}\n";
298                                                      }
299                                                   
300   ***      0                                         return;
301                                                   }
302                                                   
303                                                   sub _print_aggregated_processlist {
304   ***      0                    0                    my ( $self, $ag_pl ) = @_;
305   ***      0                                         my ( $value, $count, $total_time); # used by format
306                                                   
307   ***      0                                         print "\n   Aggregated PROCESSLIST ________________________________________________
308                                                         FIELD      VALUE                       COUNT   TOTAL TIME (s)\n";
309                                                   
310                                                   format VALUE_LINE =
311                                                                    @<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<   @<<<<
312                                                   $value, $count, $total_time
313                                                   .
314                                                   
315   ***      0      0                                  if ( ref $ag_pl ) {
316   ***      0                                            foreach my $field ( keys %{ $ag_pl } ) {
      ***      0                                      
317   ***      0                                               printf "      %.8s\n", $field;
318   ***      0                                               $FORMAT_NAME = 'VALUE_LINE';
319   ***      0                                               foreach $value ( keys %{ $ag_pl->{$field} } ) {
      ***      0                                      
320   ***      0                                                  $count       = $ag_pl->{$field}->{$value}->{count};
321   ***      0                                                  $total_time  = $ag_pl->{$field}->{$value}->{time};
322   ***      0                                                  write;
323                                                            }
324                                                         }
325                                                      }
326                                                      else {
327   ***      0                                            print "   $ag_pl\n";
328                                                      }
329                                                   
330   ***      0                                         return;
331                                                   }
332                                                   
333                                                   sub _d {
334   ***      0                    0                    my ($package, undef, $line) = caller 0;
335   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
336   ***      0                                              map { defined $_ ? $_ : 'undef' }
337                                                           @_;
338   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
339                                                   }
340                                                   
341                                                   1;
342                                                   
343                                                   # ###########################################################################
344                                                   # End MySQLInstanceReporter package
345                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
41    ***      0      0      0   unless $args{$arg}
85    ***      0      0      0   if ($$schema{'counts'}{'TOTAL'}{'dbs'} == 0) { }
116   ***      0      0      0   if (scalar @{$duplicates;})
128   ***      0      0      0   if (scalar keys %{$overridens;})
142   ***      0      0      0   if (scalar keys %{$oos;})
156   ***      0      0      0   if (scalar keys %{$failed_checks;})
186   ***      0      0      0   if not --$top
195   ***      0      0      0   if ($n_remaining)
234   ***      0      0      0   if not --$top
243   ***      0      0      0   if ($n_remaining)
283   ***      0      0      0   if (ref $$schema{'stored_code'}) { }
285   ***      0      0      0   if (@stored_code_objs) { }
315   ***      0      0      0   if (ref $ag_pl) { }
335   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
266   ***      0      0      0   $$engines{$engine}{'indexes'} || 'NA'


Covered Subroutines
-------------------

Subroutine                    Count Location                                                    
----------------------------- ----- ------------------------------------------------------------
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:23 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:24 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:25 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:29 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:30 
new                               1 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:33 

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                                    
----------------------------- ----- ------------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:334
_print_aggregated_processlist     0 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:304
_print_dbs_size_summary           0 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:169
_print_engines_summary            0 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:252
_print_stored_code_summary        0 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:273
_print_tables_size_summary        0 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:206
report                            0 /home/daniel/dev/maatkit/common/MySQLInstanceReporter.pm:39 


