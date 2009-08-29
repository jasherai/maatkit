---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/LogSplitter.pm   85.8   64.9   63.6   89.5    n/a  100.0   79.5
Total                          85.8   64.9   63.6   89.5    n/a  100.0   79.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          LogSplitter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:02:06 2009
Finish:       Sat Aug 29 15:02:29 2009

/home/daniel/dev/maatkit/common/LogSplitter.pm

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
19                                                    # LogSplitter package $Revision: 4580 $
20                                                    # ###########################################################################
21                                                    package LogSplitter;
22                                                    
23             1                    1             8   use strict;
               1                                  3   
               1                                  6   
24             1                    1           110   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                 10   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32             1                    1             6   use constant MKDEBUG           => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
33             1                    1             6   use constant MAX_OPEN_FILES    => 1000;
               1                                  2   
               1                                  5   
34             1                    1             5   use constant CLOSE_N_LRU_FILES => 100;
               1                                  2   
               1                                  5   
35                                                    
36                                                    sub new {
37             7                    7          7686      my ( $class, %args ) = @_;
38             7                                 56      foreach my $arg ( qw(attribute base_dir parser session_files) ) {
39    ***     28     50                         156         die "I need a $arg argument" unless $args{$arg};
40                                                       }
41                                                    
42                                                       # TODO: this is probably problematic on Windows
43    ***      7     50                          87      $args{base_dir} .= '/' if substr($args{base_dir}, -1, 1) ne '/';
44                                                    
45             7                                287      my $self = {
46                                                          # %args will override these default args if given explicitly.
47                                                          base_file_name    => 'session',
48                                                          max_dirs          => 1_000,
49                                                          max_files_per_dir => 5_000,
50                                                          max_sessions      => 5_000_000,  # max_dirs * max_files_per_dir
51                                                          merge_sessions    => 1,
52                                                          session_files     => 64,
53                                                          quiet             => 0,
54                                                          verbose           => 0,
55                                                          # Override default args above.
56                                                          %args,
57                                                          # These args cannot be overridden.
58                                                          n_dirs_total       => 0,  # total number of dirs created
59                                                          n_files_total      => 0,  # total number of session files created
60                                                          n_files_this_dir   => -1, # number of session files in current dir
61                                                          session_fhs        => [], # filehandles for each session
62                                                          n_open_fhs         => 0,  # current number of open session filehandles
63                                                          n_events_total     => 0,  # total number of events in log
64                                                          n_events_saved     => 0,  # total number of events saved
65                                                          n_sessions_skipped => 0,  # total number of sessions skipped
66                                                          n_sessions_saved   => 0,  # number of sessions saved
67                                                          sessions           => {}, # sessions data store
68                                                          created_dirs       => [],
69                                                       };
70                                                    
71             7                                 24      MKDEBUG && _d('new LogSplitter final args:', Dumper($self));
72             7                                 80      return bless $self, $class;
73                                                    }
74                                                    
75                                                    sub split {
76             7                    7         11990      my ( $self, @logs ) = @_;
77             7                                 50      my $oktorun = 1; # True as long as we haven't created too many
78                                                                        # session files or too many dirs and files
79                                                    
80    ***      7     50                          43      if ( @logs == 0 ) {
81    ***      0                                  0         MKDEBUG && _d('Implicitly reading STDIN because no logs were given');
82    ***      0                                  0         push @logs, '-';
83                                                       }
84                                                    
85                                                       # This sub is called by parser::parse_event().
86                                                       # It saves each session to its own file.
87             7                                 22      my @callbacks;
88                                                       push @callbacks, sub {
89          6018                 6018         19888         my ( $event ) = @_; 
90          6018                              22955         my ($session, $session_id) = $self->_get_session_ds($event);
91          6018    100                       28001         return unless $session;
92                                                    
93          4021    100                       15233         if ( !defined $session->{fh} ) {
                    100                               
94          4014                              11682            $self->{n_sessions_saved}++;
95          4014                               8191            MKDEBUG && _d('New session:', $session_id, ',',
96                                                                $self->{n_sessions_saved}, 'of', $self->{max_sessions});
97                                                    
98          4014                              13537            my $session_file = $self->_get_next_session_file();
99    ***   4014     50                       14239            if ( !$session_file ) {
100   ***      0                                  0               $oktorun = 0;
101   ***      0                                  0               MKDEBUG && _d('Not oktorun because no _get_next_session_file');
102   ***      0                                  0               return;
103                                                            }
104                                                   
105                                                            # Close Last Recently Used session fhs if opening if this new
106                                                            # session fh will cause us to have too many open files.
107         4014    100                       16401            $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
108                                                   
109                                                            # Open a fh for this session file.
110   ***   4014     50                      222772            open my $fh, '>', $session_file
111                                                               or die "Cannot open session file $session_file: $OS_ERROR";
112         4014                              16045            $session->{fh} = $fh;
113         4014                              11782            $self->{n_open_fhs}++;
114                                                   
115                                                            # Save fh and session file in case we need to open/close it later.
116         4014                              13029            $session->{active}       = 1;
117         4014                              14898            $session->{session_file} = $session_file;
118                                                   
119         4014                              10206            push @{$self->{session_fhs}}, { fh => $fh, session_id => $session_id };
            4014                              23557   
120                                                   
121         4014                               9596            MKDEBUG && _d('Created', $session_file, 'for session',
122                                                               $self->{attribute}, '=', $session_id);
123                                                   
124                                                            # This special comment lets mk-log-player know when a session begins.
125         4014                              37883            print $fh "-- START SESSION $session_id\n\n";
126                                                         }
127                                                         elsif ( !$session->{active} ) {
128                                                            # Reopen the existing but inactive session. This happens when
129                                                            # a new session (above) had to close LRU session fhs.
130                                                   
131                                                            # Again, close Last Recently Used session fhs if reopening if this
132                                                            # session's fh will cause us to have too many open files.
133   ***      2     50                          11            $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
134                                                   
135                                                             # Reopen this session's fh.
136   ***      2     50                          53             open $session->{fh}, '>>', $session->{session_file}
137                                                                or die "Cannot reopen session file "
138                                                                  . "$session->{session_file}: $OS_ERROR";
139                                                   
140                                                             # Mark this session as active again.
141            2                                 10             $session->{active} = 1;
142            2                                  6             $self->{n_open_fhs}++;
143                                                   
144            2                                  6             MKDEBUG && _d('Reopend', $session->{session_file}, 'for session',
145                                                               $self->{attribute}, '=', $session_id);
146                                                         }
147                                                         else {
148            5                                 12            MKDEBUG && _d('Event belongs to active session', $session_id);
149                                                         }
150                                                   
151         4021                              13583         my $session_fh = $session->{fh};
152                                                   
153                                                         # Print USE db if 1) we haven't done so yet or 2) the db has changed.
154   ***   4021            66                33281         my $db = $event->{db} || $event->{Schema};
155         4021    100    100                36818         if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
      ***                   66                        
156         4017                              15294            print $session_fh "use $db\n\n";
157         4017                              14575            $session->{db} = $db;
158                                                         }
159                                                   
160         4021                              17857         print $session_fh flatten($event->{arg}), "\n\n";
161         4021                              12718         $self->{n_events_saved}++;
162                                                   
163         4021                              25565         return $event;
164            7                               2521      };
165                                                   
166            7    100                          56      unshift @callbacks, @{$self->{callbacks}} if $self->{callbacks};
               1                                  6   
167                                                   
168                                                      # Split all the log files.
169            7                                 31      my $lp = $self->{parser};
170                                                      LOG:
171            7                                 43      foreach my $log ( @logs ) {
172   ***      7     50                          29         next unless defined $log;
173   ***      7     50     33                  138         if ( !-f $log && $log ne '-' ) {
174   ***      0                                  0            warn "Skipping $log because it is not a file";
175   ***      0                                  0            next LOG;
176                                                         }
177            7                                 19         my $fh;
178   ***      7     50                          37         if ( $log eq '-' ) {
179   ***      0                                  0            $fh = *STDIN;
180                                                         }
181                                                         else {
182   ***      7     50                         364            if ( !open $fh, "<", $log ) {
183   ***      0                                  0               warn "Cannot open $log: $OS_ERROR\n";
184   ***      0                                  0               next LOG;
185                                                            }
186                                                         }
187   ***      7     50                          51         if ( $fh ) {
188            7                                 16            MKDEBUG && _d('Splitting', $log);
189            7                                 35            while ( $oktorun ) {
190         6031                              25976               my $events = $lp->parse_event($fh, undef, @callbacks);
191         6031                              21258               $self->{n_events_total} += $events;
192   ***   6031     50                       20039               last LOG unless $oktorun;
193         6031    100                       29353               if ( !$events ) {
194            7                                 24                  MKDEBUG && _d('No more events in', $log);
195            7                                 75                  close $fh;
196            7                                 23                  next LOG;
197                                                               }
198                                                            }
199                                                         }
200                                                      }
201                                                   
202                                                      # Close session filehandles.
203            7                                 91      while ( my $fh = pop @{ $self->{session_fhs} } ) {
            4021                              20900   
204         4014                              45875         close $fh->{fh};
205                                                      }
206            7                                 30      $self->{n_open_fhs}  = 0;
207                                                   
208            7    100                          60      $self->_merge_session_files() if $self->{merge_sessions};
209   ***      7     50                          43      $self->print_split_summary() unless $self->{quiet};
210                                                   
211            7                                378      return;
212                                                   }
213                                                   
214                                                   # Returns shortcut to session data store and id for the given event.
215                                                   # The returned session will be undef if no more sessions are allowed.
216                                                   sub _get_session_ds {
217         6018                 6018         20097      my ( $self, $event ) = @_;
218                                                   
219         6018                              20621      my $attrib = $self->{attribute};
220         6018    100                       24473      if ( !$event->{ $attrib } ) {
221            6                                 13         MKDEBUG && _d('No attribute', $attrib, 'in event:', Dumper($event));
222            6                                 23         return;
223                                                      }
224                                                   
225                                                      # This could indicate a problem in parser not parsing
226                                                      # a log event correctly thereby leaving $event->{arg} undefined.
227                                                      # Or, it could simply be an event like:
228                                                      #   use db;
229                                                      #   SET NAMES utf8;
230   ***   6012     50                       22422      return unless $event->{arg};
231                                                   
232                                                      # Don't print admin commands like quit or ping because these
233                                                      # cannot be played.
234   ***   6012     50     50                31029      return if ($event->{cmd} || '') eq 'Admin';
235                                                   
236         6012                              13244      my $session;
237         6012                              17879      my $session_id = $event->{ $attrib };
238                                                   
239                                                      # The following is necessary to prevent Perl from auto-vivifying
240                                                      # a lot of empty hashes for new sessions that are ignored due to
241                                                      # already having max_sessions.
242         6012    100                       29849      if ( $self->{n_sessions_saved} < $self->{max_sessions} ) {
      ***            50                               
243                                                         # Will auto-vivify if necessary.
244         4021           100                39948         $session = $self->{sessions}->{ $session_id } ||= {};
245                                                      }
246                                                      elsif ( exists $self->{sessions}->{ $session_id } ) {
247                                                         # Use only existing sessions.
248   ***      0                                  0         $session = $self->{sessions}->{ $session_id };
249                                                      }
250                                                      else {
251         1991                               6338         $self->{n_sessions_skipped} += 1;
252         1991                               4616         MKDEBUG && _d('Skipping new session', $session_id,
253                                                            'because max_sessions is reached');
254                                                      }
255                                                   
256         6012                              28787      return $session, $session_id;
257                                                   }
258                                                   
259                                                   sub _close_lru_session {
260           22                   22            90      my ( $self ) = @_;
261           22                                 85      my $session_fhs = $self->{session_fhs};
262           22                                102      my $lru_n       = $self->{n_sessions_saved} - MAX_OPEN_FILES - 1;
263           22                                 76      my $close_to_n  = $lru_n + CLOSE_N_LRU_FILES - 1;
264                                                   
265           22                                 52      MKDEBUG && _d('Closing session fhs', $lru_n, '..', $close_to_n,
266                                                         '(',$self->{n_sessions}, 'sessions', $self->{n_open_fhs}, 'open fhs)');
267                                                   
268           22                               1305      foreach my $session ( @$session_fhs[ $lru_n..$close_to_n ] ) {
269         2200                              38044         close $session->{fh};
270         2200                               6984         $self->{n_open_fhs}--;
271         2200                              12621         $self->{sessions}->{ $session->{session_id} }->{active} = 0;
272                                                      }
273                                                   
274           22                                169      return;
275                                                   }
276                                                   
277                                                   # Returns an empty string on failure, or the next session file name on success.
278                                                   # This will fail if we have opened maxdirs and maxfiles.
279                                                   sub _get_next_session_file {
280         4014                 4014         13275      my ( $self, $n ) = @_;
281   ***   4014     50                       19931      return if $self->{n_dirs_total} >= $self->{max_dirs};
282                                                   
283                                                      # n_files_this_dir will only be < 0 for the first dir and file
284                                                      # because n_file is set to -1 in new(). This is a hack
285                                                      # to cause the first dir and file to be created automatically.
286   ***   4014    100     66                35318      if ( ($self->{n_files_this_dir} >= $self->{max_files_per_dir})
287                                                           || $self->{n_files_this_dir} < 0 ) {
288            5                                 21         $self->{n_dirs_total}++;
289            5                                 19         $self->{n_files_this_dir} = 0;
290            5                                 29         my $new_dir = "$self->{base_dir}$self->{n_dirs_total}";
291   ***      5     50                          79         if ( !-d $new_dir ) {
292            5                              43767            my $retval = system("mkdir $new_dir");
293   ***      5     50                          82            if ( ($retval >> 8) != 0 ) {
294   ***      0                                  0               die "Cannot create new directory $new_dir: $OS_ERROR";
295                                                            }
296            5                                 16            MKDEBUG && _d('Created new base_dir', $new_dir);
297            5                                 48            push @{$self->{created_dirs}}, $new_dir;
               5                                136   
298                                                         }
299                                                         elsif ( MKDEBUG ) {
300                                                            _d($new_dir, 'already exists');
301                                                         }
302                                                      }
303                                                      else {
304         4009                               9133         MKDEBUG && _d('No dir created; n_files_this_dir:',
305                                                            $self->{n_files_this_dir}, 'n_files_total:',
306                                                            $self->{n_files_total});
307                                                      }
308                                                   
309         4014                              11368      $self->{n_files_total}++;
310         4014                              11404      $self->{n_files_this_dir}++;
311         4014                              14266      my $dir_n        = $self->{n_dirs_total} . '/';
312   ***   4014            33                33600      my $session_n    = sprintf '%d', $n || $self->{n_sessions_saved};
313         4014                              20789      my $session_file = $self->{base_dir}
314                                                                       . $dir_n
315                                                                       . $self->{base_file_name}."-$session_n.txt";
316         4014                               8664      MKDEBUG && _d('Next session file', $session_file);
317         4014                              15014      return $session_file;
318                                                   }
319                                                   
320                                                   # Flattens multiple new-line and spaces to single new-lines and spaces
321                                                   # and remove /* comment */ blocks.
322                                                   sub flatten {
323         4021                 4021         16265      my ( $query ) = @_;
324   ***   4021     50                       14872      return unless $query;
325         4021                              12177      $query =~ s!/\*.*?\*/! !g;
326         4021                              14424      $query =~ s/^\s+//;
327         4021                              13423      $query =~ s/\s{2,}/ /g;
328         4021                              15386      return $query;
329                                                   }
330                                                   
331                                                   sub _merge_session_files {
332            4                    4            17      my ( $self ) = @_;
333                                                   
334   ***      4     50                          25      print "Merging session files...\n" unless $self->{quiet};
335                                                   
336            4                                 12      my @multi_session_files;
337            4                                 32      for my $i ( 1..$self->{session_files} ) {
338           17                                104         push @multi_session_files, $self->{base_dir} ."sessions-$i.txt";
339                                                      }
340                                                   
341         2001                               9287      my @single_session_files = map {
342            4                               1165         $_->{session_file};
343            4                                 13      } values %{$self->{sessions}};
344                                                   
345            4                                561      my $i = make_rr_iter(0, $#multi_session_files);  # round-robin iterator
346            4                                 20      foreach my $single_session_file ( @single_session_files ) {
347         2001                              40868         my $multi_session_file = $multi_session_files[ $i->() ];
348         2001                              22702         my $cmd = "cat $single_session_file >> $multi_session_file";
349         2001                               6925         eval { `$cmd`; };
            2001                             18807416   
350   ***   2001     50                       60048         if ( $EVAL_ERROR ) {
351   ***      0                                  0            warn "Failed to `$cmd`: $OS_ERROR";
352                                                         }
353                                                      }
354                                                   
355            4                                 35      foreach my $created_dir ( @{$self->{created_dirs}} ) {
               4                                 39   
356            2                                 42         my $cmd = "rm -rf $created_dir";
357            2                                 18         eval { `$cmd`; };
               2                              48104   
358   ***      2     50                          98         if ( $EVAL_ERROR ) {
359   ***      0                                  0            warn "Failed to `$cmd`: $OS_ERROR";
360                                                         }
361                                                      }
362                                                   
363            4                               1067      return;
364                                                   }
365                                                   
366                                                   sub make_rr_iter {
367            4                    4            31      my ( $start, $end ) = @_;
368            4                                 14      my $current = $start;
369                                                      return sub {
370         2001    100          2001         25504         $current = $start if $current > $end ;
371         2001                               7017         $current++;  # For next iteration.
372         2001                              34502         return $current - 1;
373            4                                 56      };
374                                                   }
375                                                   
376                                                   sub print_split_summary {
377   ***      0                    0                    my ( $self ) = @_;
378   ***      0                                         print "Split summary:\n";
379   ***      0                                         my $fmt = "%-20s %-10s\n";
380   ***      0                                         printf $fmt, 'Total sessions',
381                                                         $self->{n_sessions_saved} + $self->{n_sessions_skipped};
382   ***      0                                         printf $fmt, 'Sessions saved',
383                                                         $self->{n_sessions_saved};
384   ***      0                                         printf $fmt, 'Total events', $self->{n_events_total};
385   ***      0                                         printf $fmt, 'Events saved', $self->{n_events_saved};
386   ***      0                                         return;
387                                                   }
388                                                   
389                                                   sub _d {
390   ***      0                    0                    my ($package, undef, $line) = caller 0;
391   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
392   ***      0                                              map { defined $_ ? $_ : 'undef' }
393                                                           @_;
394   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
395                                                   }
396                                                   
397                                                   1;
398                                                   
399                                                   # ###########################################################################
400                                                   # End LogSplitter package
401                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***     50      0     28   unless $args{$arg}
43    ***     50      7      0   if substr($args{'base_dir'}, -1, 1) ne '/'
80    ***     50      0      7   if (@logs == 0)
91           100   1997   4021   unless $session
93           100   4014      7   if (not defined $$session{'fh'}) { }
             100      2      5   elsif (not $$session{'active'}) { }
99    ***     50      0   4014   if (not $session_file)
107          100     22   3992   if $$self{'n_open_fhs'} >= 1000
110   ***     50      0   4014   unless open my $fh, '>', $session_file
133   ***     50      0      2   if $$self{'n_open_fhs'} >= 1000
136   ***     50      0      2   unless open $$session{'fh'}, '>>', $$session{'session_file'}
155          100   4017      4   if ($db and !defined($$session{'db'}) || $$session{'db'} ne $db)
166          100      1      6   if $$self{'callbacks'}
172   ***     50      0      7   unless defined $log
173   ***     50      0      7   if (not -f $log and $log ne '-')
178   ***     50      0      7   if ($log eq '-') { }
182   ***     50      0      7   if (not open $fh, '<', $log)
187   ***     50      7      0   if ($fh)
192   ***     50      0   6031   unless $oktorun
193          100      7   6024   if (not $events)
208          100      4      3   if $$self{'merge_sessions'}
209   ***     50      0      7   unless $$self{'quiet'}
220          100      6   6012   if (not $$event{$attrib})
230   ***     50      0   6012   unless $$event{'arg'}
234   ***     50      0   6012   if ($$event{'cmd'} || '') eq 'Admin'
242          100   4021   1991   if ($$self{'n_sessions_saved'} < $$self{'max_sessions'}) { }
      ***     50      0   1991   elsif (exists $$self{'sessions'}{$session_id}) { }
281   ***     50      0   4014   if $$self{'n_dirs_total'} >= $$self{'max_dirs'}
286          100      5   4009   if ($$self{'n_files_this_dir'} >= $$self{'max_files_per_dir'} or $$self{'n_files_this_dir'} < 0) { }
291   ***     50      5      0   !-d($new_dir) ? :
293   ***     50      0      5   if ($retval >> 8 != 0)
324   ***     50      0   4021   unless $query
334   ***     50      0      4   unless $$self{'quiet'}
350   ***     50      0   2001   if ($EVAL_ERROR)
358   ***     50      0      2   if ($EVAL_ERROR)
370          100    199   1802   if $current > $end
391   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
155   ***     66      0      4   4017   $db and !defined($$session{'db'}) || $$session{'db'} ne $db
173   ***     33      7      0      0   not -f $log and $log ne '-'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
234   ***     50   6012      0   $$event{'cmd'} || ''
244          100      7   4014   $$self{'sessions'}{$session_id} ||= {}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
154   ***     66      3   4018      0   $$event{'db'} || $$event{'Schema'}
155          100   4014      3      4   !defined($$session{'db'}) || $$session{'db'} ne $db
286   ***     66      0      5   4009   $$self{'n_files_this_dir'} >= $$self{'max_files_per_dir'} or $$self{'n_files_this_dir'} < 0
312   ***     33      0   4014      0   $n || $$self{'n_sessions_saved'}


Covered Subroutines
-------------------

Subroutine             Count Location                                          
---------------------- ----- --------------------------------------------------
BEGIN                      1 /home/daniel/dev/maatkit/common/LogSplitter.pm:23 
BEGIN                      1 /home/daniel/dev/maatkit/common/LogSplitter.pm:24 
BEGIN                      1 /home/daniel/dev/maatkit/common/LogSplitter.pm:25 
BEGIN                      1 /home/daniel/dev/maatkit/common/LogSplitter.pm:27 
BEGIN                      1 /home/daniel/dev/maatkit/common/LogSplitter.pm:32 
BEGIN                      1 /home/daniel/dev/maatkit/common/LogSplitter.pm:33 
BEGIN                      1 /home/daniel/dev/maatkit/common/LogSplitter.pm:34 
__ANON__                2001 /home/daniel/dev/maatkit/common/LogSplitter.pm:370
__ANON__                6018 /home/daniel/dev/maatkit/common/LogSplitter.pm:89 
_close_lru_session        22 /home/daniel/dev/maatkit/common/LogSplitter.pm:260
_get_next_session_file  4014 /home/daniel/dev/maatkit/common/LogSplitter.pm:280
_get_session_ds         6018 /home/daniel/dev/maatkit/common/LogSplitter.pm:217
_merge_session_files       4 /home/daniel/dev/maatkit/common/LogSplitter.pm:332
flatten                 4021 /home/daniel/dev/maatkit/common/LogSplitter.pm:323
make_rr_iter               4 /home/daniel/dev/maatkit/common/LogSplitter.pm:367
new                        7 /home/daniel/dev/maatkit/common/LogSplitter.pm:37 
split                      7 /home/daniel/dev/maatkit/common/LogSplitter.pm:76 

Uncovered Subroutines
---------------------

Subroutine             Count Location                                          
---------------------- ----- --------------------------------------------------
_d                         0 /home/daniel/dev/maatkit/common/LogSplitter.pm:390
print_split_summary        0 /home/daniel/dev/maatkit/common/LogSplitter.pm:377


