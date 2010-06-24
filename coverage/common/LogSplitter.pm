---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/LogSplitter.pm   87.1   69.3   62.5   90.9    0.0   99.1   80.1
LogSplitter.t                 100.0   50.0   33.3  100.0    n/a    0.9   97.1
Total                          90.8   68.9   59.3   93.5    0.0  100.0   83.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:46 2010
Finish:       Thu Jun 24 19:33:46 2010

Run:          LogSplitter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:48 2010
Finish:       Thu Jun 24 19:34:16 2010

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
19                                                    # LogSplitter package $Revision: 6094 $
20                                                    # ###########################################################################
21                                                    package LogSplitter;
22                                                    
23             1                    1             5   use strict;
               1                                  2   
               1                                  8   
24             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
25             1                    1             9   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
26                                                    
27             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32    ***      1            50      1             6   use constant MKDEBUG           => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
33             1                    1             5   use constant MAX_OPEN_FILES    => 1000;
               1                                  3   
               1                                  4   
34             1                    1             6   use constant CLOSE_N_LRU_FILES => 100;
               1                                  2   
               1                                  4   
35                                                    
36                                                    my $oktorun = 1;
37                                                    
38                                                    sub new {
39    ***      8                    8      0    380      my ( $class, %args ) = @_;
40             8                                 67      foreach my $arg ( qw(attribute base_dir parser session_files) ) {
41    ***     32     50                         212         die "I need a $arg argument" unless $args{$arg};
42                                                       }
43                                                    
44                                                       # TODO: this is probably problematic on Windows
45    ***      8     50                          97      $args{base_dir} .= '/' if substr($args{base_dir}, -1, 1) ne '/';
46                                                    
47             8    100                          53      if ( $args{split_random} ) {
48             1                                 18         MKDEBUG && _d('Split random');
49             1                                 16         $args{attribute} = '_sessionno';  # set round-robin 1..session_files
50                                                       }
51                                                    
52             8                                802      my $self = {
53                                                          # %args will override these default args if given explicitly.
54                                                          base_file_name    => 'session',
55                                                          max_dirs          => 1_000,
56                                                          max_files_per_dir => 5_000,
57                                                          max_sessions      => 5_000_000,  # max_dirs * max_files_per_dir
58                                                          merge_sessions    => 1,
59                                                          session_files     => 64,
60                                                          quiet             => 0,
61                                                          verbose           => 0,
62                                                          # Override default args above.
63                                                          %args,
64                                                          # These args cannot be overridden.
65                                                          n_dirs_total       => 0,  # total number of dirs created
66                                                          n_files_total      => 0,  # total number of session files created
67                                                          n_files_this_dir   => -1, # number of session files in current dir
68                                                          session_fhs        => [], # filehandles for each session
69                                                          n_open_fhs         => 0,  # current number of open session filehandles
70                                                          n_events_total     => 0,  # total number of events in log
71                                                          n_events_saved     => 0,  # total number of events saved
72                                                          n_sessions_skipped => 0,  # total number of sessions skipped
73                                                          n_sessions_saved   => 0,  # number of sessions saved
74                                                          sessions           => {}, # sessions data store
75                                                          created_dirs       => [],
76                                                       };
77                                                    
78             8                                 51      MKDEBUG && _d('new LogSplitter final args:', Dumper($self));
79             8                                105      return bless $self, $class;
80                                                    }
81                                                    
82                                                    sub split {
83    ***      8                    8      0    350      my ( $self, @logs ) = @_;
84             8                                 52      $oktorun = 1; # True as long as we haven't created too many
85                                                                     # session files or too many dirs and files
86                                                    
87             8                                 47      my $callbacks = $self->{callbacks};
88                                                    
89             8                                 24      my $next_sessionno;
90             8    100                          62      if ( $self->{split_random} ) {
91                                                          # round-robin iterator
92             1                                 25         $next_sessionno = make_rr_iter(1, $self->{session_files});
93                                                       }
94                                                    
95    ***      8     50                          46      if ( @logs == 0 ) {
96    ***      0                                  0         MKDEBUG && _d('Implicitly reading STDIN because no logs were given');
97    ***      0                                  0         push @logs, '-';
98                                                       }
99                                                    
100                                                      # Split all the log files.
101            8                                 40      my $lp = $self->{parser};
102                                                      LOG:
103            8                                 58      foreach my $log ( @logs ) {
104   ***      8     50                          44         last unless $oktorun;
105   ***      8     50                          40         next unless defined $log;
106                                                   
107   ***      8     50     33                  238         if ( !-f $log && $log ne '-' ) {
108   ***      0                                  0            warn "Skipping $log because it is not a file";
109   ***      0                                  0            next LOG;
110                                                         }
111            8                                 23         my $fh;
112   ***      8     50                          45         if ( $log eq '-' ) {
113   ***      0                                  0            $fh = *STDIN;
114                                                         }
115                                                         else {
116   ***      8     50                         567            if ( !open $fh, "<", $log ) {
117   ***      0                                  0               warn "Cannot open $log: $OS_ERROR\n";
118   ***      0                                  0               next LOG;
119                                                            }
120                                                         }
121                                                   
122            8                                 55         MKDEBUG && _d('Splitting', $log);
123            8                                 60         my $event           = {};
124            8                                 67         my $more_events     = 1;
125            8                    8           156         my $more_events_sub = sub { $more_events = $_[0]; };
               8                                184   
126                                                         EVENT:
127            8                                 51         while ( $oktorun ) {
128                                                            $event = $lp->parse_event(
129         6038                 6038        125720               next_event => sub { return <$fh>;    },
130        12068                12068        323569               tell       => sub { return tell $fh; },
131         6038                              55828               oktorun => $more_events_sub,
132                                                            );
133         6038    100                      1506585            if ( $event ) {
134         6030                              20010               $self->{n_events_total}++;
135         6030    100                       23670               if ( $self->{split_random} ) {
136            6                                 62                  $event->{_sessionno} = $next_sessionno->();
137                                                               }
138         6030    100                       19746               if ( $callbacks ) {
139            6                                 39                  foreach my $callback ( @$callbacks ) {
140            6                                 47                     $event = $callback->($event);
141   ***      6     50                         102                     last unless $event;
142                                                                  }
143                                                               }
144         6030    100                       29592               $self->_save_event($event) if $event;
145                                                            }
146         6038    100                       21724            if ( !$more_events ) {
147            8                                 21               MKDEBUG && _d('Done parsing', $log);
148            8                                 91               close $fh;
149            8                                 30               next LOG;
150                                                            }
151   ***   6030     50                       28231            last LOG unless $oktorun;
152                                                         }
153                                                      }
154                                                   
155                                                      # Close session filehandles.
156            8                                124      while ( my $fh = pop @{ $self->{session_fhs} } ) {
            4024                              20492   
157         4016                              69000         close $fh->{fh};
158                                                      }
159            8                                 39      $self->{n_open_fhs}  = 0;
160                                                   
161            8    100                         100      $self->_merge_session_files() if $self->{merge_sessions};
162   ***      8     50                          81      $self->print_split_summary() unless $self->{quiet};
163                                                   
164            8                                164      return;
165                                                   }
166                                                   
167                                                   sub _save_event {
168         6024                 6024         21297      my ( $self, $event ) = @_; 
169         6024                              22680      my ($session, $session_id) = $self->_get_session_ds($event);
170         6024    100                       23866      return unless $session;
171                                                   
172         4027    100                       15337      if ( !defined $session->{fh} ) {
                    100                               
173         4016                              11571         $self->{n_sessions_saved}++;
174         4016                               8407         MKDEBUG && _d('New session:', $session_id, ',',
175                                                            $self->{n_sessions_saved}, 'of', $self->{max_sessions});
176                                                   
177         4016                              13901         my $session_file = $self->_get_next_session_file();
178   ***   4016     50                       14830         if ( !$session_file ) {
179   ***      0                                  0            $oktorun = 0;
180   ***      0                                  0            MKDEBUG && _d('Not oktorun because no _get_next_session_file');
181   ***      0                                  0            return;
182                                                         }
183                                                   
184                                                         # Close Last Recently Used session fhs if opening if this new
185                                                         # session fh will cause us to have too many open files.
186         4016    100                       16737         $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
187                                                   
188                                                         # Open a fh for this session file.
189   ***   4016     50                      248122         open my $fh, '>', $session_file
190                                                            or die "Cannot open session file $session_file: $OS_ERROR";
191         4016                              16150         $session->{fh} = $fh;
192         4016                              11897         $self->{n_open_fhs}++;
193                                                   
194                                                         # Save fh and session file in case we need to open/close it later.
195         4016                              12376         $session->{active}       = 1;
196         4016                              14604         $session->{session_file} = $session_file;
197                                                   
198         4016                              10030         push @{$self->{session_fhs}}, { fh => $fh, session_id => $session_id };
            4016                              22509   
199                                                   
200         4016                               9657         MKDEBUG && _d('Created', $session_file, 'for session',
201                                                            $self->{attribute}, '=', $session_id);
202                                                   
203                                                         # This special comment lets mk-log-player know when a session begins.
204         4016                              37510         print $fh "-- START SESSION $session_id\n\n";
205                                                      }
206                                                      elsif ( !$session->{active} ) {
207                                                         # Reopen the existing but inactive session. This happens when
208                                                         # a new session (above) had to close LRU session fhs.
209                                                   
210                                                         # Again, close Last Recently Used session fhs if reopening if this
211                                                         # session's fh will cause us to have too many open files.
212   ***      2     50                          13         $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
213                                                   
214                                                          # Reopen this session's fh.
215   ***      2     50                          54          open $session->{fh}, '>>', $session->{session_file}
216                                                             or die "Cannot reopen session file "
217                                                               . "$session->{session_file}: $OS_ERROR";
218                                                   
219                                                          # Mark this session as active again.
220            2                                  7          $session->{active} = 1;
221            2                                  6          $self->{n_open_fhs}++;
222                                                   
223            2                                  6          MKDEBUG && _d('Reopend', $session->{session_file}, 'for session',
224                                                            $self->{attribute}, '=', $session_id);
225                                                      }
226                                                      else {
227            9                                 31         MKDEBUG && _d('Event belongs to active session', $session_id);
228                                                      }
229                                                   
230         4027                              13653      my $session_fh = $session->{fh};
231                                                   
232                                                      # Print USE db if 1) we haven't done so yet or 2) the db has changed.
233   ***   4027            66                32861      my $db = $event->{db} || $event->{Schema};
234         4027    100    100                36645      if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
      ***                   66                        
235         4022                              15300         print $session_fh "use $db\n\n";
236         4022                              14554         $session->{db} = $db;
237                                                      }
238                                                   
239         4027                              17682      print $session_fh flatten($event->{arg}), "\n\n";
240         4027                              12950      $self->{n_events_saved}++;
241                                                   
242         4027                              11782      return;
243                                                   }
244                                                   
245                                                   # Returns shortcut to session data store and id for the given event.
246                                                   # The returned session will be undef if no more sessions are allowed.
247                                                   sub _get_session_ds {
248         6024                 6024         19163      my ( $self, $event ) = @_;
249                                                   
250         6024                              21437      my $attrib = $self->{attribute};
251         6024    100                       24354      if ( !$event->{ $attrib } ) {
252            6                                 12         MKDEBUG && _d('No attribute', $attrib, 'in event:', Dumper($event));
253            6                                 23         return;
254                                                      }
255                                                   
256                                                      # This could indicate a problem in parser not parsing
257                                                      # a log event correctly thereby leaving $event->{arg} undefined.
258                                                      # Or, it could simply be an event like:
259                                                      #   use db;
260                                                      #   SET NAMES utf8;
261   ***   6018     50                       23615      return unless $event->{arg};
262                                                   
263                                                      # Don't print admin commands like quit or ping because these
264                                                      # cannot be played.
265   ***   6018     50     50                31539      return if ($event->{cmd} || '') eq 'Admin';
266                                                   
267         6018                              13413      my $session;
268         6018                              18389      my $session_id = $event->{ $attrib };
269                                                   
270                                                      # The following is necessary to prevent Perl from auto-vivifying
271                                                      # a lot of empty hashes for new sessions that are ignored due to
272                                                      # already having max_sessions.
273         6018    100                       30913      if ( $self->{n_sessions_saved} < $self->{max_sessions} ) {
      ***            50                               
274                                                         # Will auto-vivify if necessary.
275         4027           100                39570         $session = $self->{sessions}->{ $session_id } ||= {};
276                                                      }
277                                                      elsif ( exists $self->{sessions}->{ $session_id } ) {
278                                                         # Use only existing sessions.
279   ***      0                                  0         $session = $self->{sessions}->{ $session_id };
280                                                      }
281                                                      else {
282         1991                               6451         $self->{n_sessions_skipped} += 1;
283         1991                               4668         MKDEBUG && _d('Skipping new session', $session_id,
284                                                            'because max_sessions is reached');
285                                                      }
286                                                   
287         6018                              27280      return $session, $session_id;
288                                                   }
289                                                   
290                                                   sub _close_lru_session {
291           22                   22            90      my ( $self ) = @_;
292           22                                 89      my $session_fhs = $self->{session_fhs};
293           22                                103      my $lru_n       = $self->{n_sessions_saved} - MAX_OPEN_FILES - 1;
294           22                                 94      my $close_to_n  = $lru_n + CLOSE_N_LRU_FILES - 1;
295                                                   
296           22                                 56      MKDEBUG && _d('Closing session fhs', $lru_n, '..', $close_to_n,
297                                                         '(',$self->{n_sessions}, 'sessions', $self->{n_open_fhs}, 'open fhs)');
298                                                   
299           22                                340      foreach my $session ( @$session_fhs[ $lru_n..$close_to_n ] ) {
300         2200                              36602         close $session->{fh};
301         2200                               6842         $self->{n_open_fhs}--;
302         2200                              12885         $self->{sessions}->{ $session->{session_id} }->{active} = 0;
303                                                      }
304                                                   
305           22                                160      return;
306                                                   }
307                                                   
308                                                   # Returns an empty string on failure, or the next session file name on success.
309                                                   # This will fail if we have opened maxdirs and maxfiles.
310                                                   sub _get_next_session_file {
311         4016                 4016         13213      my ( $self, $n ) = @_;
312   ***   4016     50                       19544      return if $self->{n_dirs_total} >= $self->{max_dirs};
313                                                   
314                                                      # n_files_this_dir will only be < 0 for the first dir and file
315                                                      # because n_file is set to -1 in new(). This is a hack
316                                                      # to cause the first dir and file to be created automatically.
317   ***   4016    100     66                37008      if ( ($self->{n_files_this_dir} >= $self->{max_files_per_dir})
318                                                           || $self->{n_files_this_dir} < 0 ) {
319            6                                 23         $self->{n_dirs_total}++;
320            6                                 31         $self->{n_files_this_dir} = 0;
321            6                                 46         my $new_dir = "$self->{base_dir}$self->{n_dirs_total}";
322   ***      6     50                         108         if ( !-d $new_dir ) {
323            6                              26874            my $retval = system("mkdir $new_dir");
324   ***      6     50                         104            if ( ($retval >> 8) != 0 ) {
325   ***      0                                  0               die "Cannot create new directory $new_dir: $OS_ERROR";
326                                                            }
327            6                                 20            MKDEBUG && _d('Created new base_dir', $new_dir);
328            6                                 74            push @{$self->{created_dirs}}, $new_dir;
               6                                180   
329                                                         }
330                                                         elsif ( MKDEBUG ) {
331                                                            _d($new_dir, 'already exists');
332                                                         }
333                                                      }
334                                                      else {
335         4010                               9222         MKDEBUG && _d('No dir created; n_files_this_dir:',
336                                                            $self->{n_files_this_dir}, 'n_files_total:',
337                                                            $self->{n_files_total});
338                                                      }
339                                                   
340         4016                              12042      $self->{n_files_total}++;
341         4016                              11452      $self->{n_files_this_dir}++;
342         4016                              14435      my $dir_n        = $self->{n_dirs_total} . '/';
343   ***   4016            33                31995      my $session_n    = sprintf '%d', $n || $self->{n_sessions_saved};
344         4016                              21285      my $session_file = $self->{base_dir}
345                                                                       . $dir_n
346                                                                       . $self->{base_file_name}."-$session_n.txt";
347         4016                               8369      MKDEBUG && _d('Next session file', $session_file);
348         4016                              14631      return $session_file;
349                                                   }
350                                                   
351                                                   # Flattens multiple new-line and spaces to single new-lines and spaces
352                                                   # and remove /* comment */ blocks.
353                                                   sub flatten {
354   ***   4027                 4027      0  14681      my ( $query ) = @_;
355   ***   4027     50                       14810      return unless $query;
356         4027                              12549      $query =~ s!/\*.*?\*/! !g;
357         4027                              14844      $query =~ s/^\s+//;
358         4027                              13657      $query =~ s/\s{2,}/ /g;
359         4027                              15666      return $query;
360                                                   }
361                                                   
362                                                   sub _merge_session_files {
363            5                    5            29      my ( $self ) = @_;
364                                                   
365   ***      5     50                          35      print "Merging session files...\n" unless $self->{quiet};
366                                                   
367            5                                 19      my @multi_session_files;
368            5                                 57      for my $i ( 1..$self->{session_files} ) {
369           19                               1075         push @multi_session_files, $self->{base_dir} ."sessions-$i.txt";
370                                                      }
371                                                   
372         2003                               9651      my @single_session_files = map {
373            5                                316         $_->{session_file};
374            5                                 24      } values %{$self->{sessions}};
375                                                   
376            5                                703      my $i = make_rr_iter(0, $#multi_session_files);  # round-robin iterator
377            5                                 30      foreach my $single_session_file ( @single_session_files ) {
378         2003                              69961         my $multi_session_file = $multi_session_files[ $i->() ];
379         2003                              16407         my $cmd;
380         2003    100                       42715         if ( $self->{split_random} ) {
381            2                                 52            $cmd = "mv $single_session_file $multi_session_file";
382                                                         }
383                                                         else {
384         2001                              44201            $cmd = "cat $single_session_file >> $multi_session_file";
385                                                         }
386         2003                              23050         eval { `$cmd`; };
            2003                             23706612   
387   ***   2003     50                       97731         if ( $EVAL_ERROR ) {
388   ***      0                                  0            warn "Failed to `$cmd`: $OS_ERROR";
389                                                         }
390                                                      }
391                                                   
392            5                                 75      foreach my $created_dir ( @{$self->{created_dirs}} ) {
               5                                 98   
393            3                                102         my $cmd = "rm -rf $created_dir";
394            3                                 57         eval { `$cmd`; };
               3                              89911   
395   ***      3     50                         240         if ( $EVAL_ERROR ) {
396   ***      0                                  0            warn "Failed to `$cmd`: $OS_ERROR";
397                                                         }
398                                                      }
399                                                   
400            5                               1784      return;
401                                                   }
402                                                   
403                                                   sub make_rr_iter {
404   ***      6                    6      0     65      my ( $start, $end ) = @_;
405            6                                 34      my $current = $start;
406                                                      return sub {
407         2009    100          2009         57935         $current = $start if $current > $end ;
408         2009                              10667         $current++;  # For next iteration.
409         2009                              56212         return $current - 1;
410            6                                125      };
411                                                   }
412                                                   
413                                                   sub print_split_summary {
414   ***      0                    0      0             my ( $self ) = @_;
415   ***      0                                         print "Split summary:\n";
416   ***      0                                         my $fmt = "%-20s %-10s\n";
417   ***      0                                         printf $fmt, 'Total sessions',
418                                                         $self->{n_sessions_saved} + $self->{n_sessions_skipped};
419   ***      0                                         printf $fmt, 'Sessions saved',
420                                                         $self->{n_sessions_saved};
421   ***      0                                         printf $fmt, 'Total events', $self->{n_events_total};
422   ***      0                                         printf $fmt, 'Events saved', $self->{n_events_saved};
423   ***      0                                         return;
424                                                   }
425                                                   
426                                                   sub _d {
427   ***      0                    0                    my ($package, undef, $line) = caller 0;
428   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
429   ***      0                                              map { defined $_ ? $_ : 'undef' }
430                                                           @_;
431   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
432                                                   }
433                                                   
434                                                   1;
435                                                   
436                                                   # ###########################################################################
437                                                   # End LogSplitter package
438                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
41    ***     50      0     32   unless $args{$arg}
45    ***     50      8      0   if substr($args{'base_dir'}, -1, 1) ne '/'
47           100      1      7   if ($args{'split_random'})
90           100      1      7   if ($$self{'split_random'})
95    ***     50      0      8   if (@logs == 0)
104   ***     50      0      8   unless $oktorun
105   ***     50      0      8   unless defined $log
107   ***     50      0      8   if (not -f $log and $log ne '-')
112   ***     50      0      8   if ($log eq '-') { }
116   ***     50      0      8   if (not open $fh, '<', $log)
133          100   6030      8   if ($event)
135          100      6   6024   if ($$self{'split_random'})
138          100      6   6024   if ($callbacks)
141   ***     50      6      0   unless $event
144          100   6024      6   if $event
146          100      8   6030   if (not $more_events)
151   ***     50      0   6030   unless $oktorun
161          100      5      3   if $$self{'merge_sessions'}
162   ***     50      0      8   unless $$self{'quiet'}
170          100   1997   4027   unless $session
172          100   4016     11   if (not defined $$session{'fh'}) { }
             100      2      9   elsif (not $$session{'active'}) { }
178   ***     50      0   4016   if (not $session_file)
186          100     22   3994   if $$self{'n_open_fhs'} >= 1000
189   ***     50      0   4016   unless open my $fh, '>', $session_file
212   ***     50      0      2   if $$self{'n_open_fhs'} >= 1000
215   ***     50      0      2   unless open $$session{'fh'}, '>>', $$session{'session_file'}
234          100   4022      5   if ($db and !defined($$session{'db'}) || $$session{'db'} ne $db)
251          100      6   6018   if (not $$event{$attrib})
261   ***     50      0   6018   unless $$event{'arg'}
265   ***     50      0   6018   if ($$event{'cmd'} || '') eq 'Admin'
273          100   4027   1991   if ($$self{'n_sessions_saved'} < $$self{'max_sessions'}) { }
      ***     50      0   1991   elsif (exists $$self{'sessions'}{$session_id}) { }
312   ***     50      0   4016   if $$self{'n_dirs_total'} >= $$self{'max_dirs'}
317          100      6   4010   if ($$self{'n_files_this_dir'} >= $$self{'max_files_per_dir'} or $$self{'n_files_this_dir'} < 0) { }
322   ***     50      6      0   !-d($new_dir) ? :
324   ***     50      0      6   if ($retval >> 8 != 0)
355   ***     50      0   4027   unless $query
365   ***     50      0      5   unless $$self{'quiet'}
380          100      2   2001   if ($$self{'split_random'}) { }
387   ***     50      0   2003   if ($EVAL_ERROR)
395   ***     50      0      3   if ($EVAL_ERROR)
407          100    201   1808   if $current > $end
428   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
107   ***     33      8      0      0   not -f $log and $log ne '-'
234   ***     66      0      5   4022   $db and !defined($$session{'db'}) || $$session{'db'} ne $db

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
32    ***     50      0      1   $ENV{'MKDEBUG'} || 0
265   ***     50   6018      0   $$event{'cmd'} || ''
275          100     11   4016   $$self{'sessions'}{$session_id} ||= {}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
233   ***     66      5   4022      0   $$event{'db'} || $$event{'Schema'}
234          100   4016      6      5   !defined($$session{'db'}) || $$session{'db'} ne $db
317   ***     66      0      6   4010   $$self{'n_files_this_dir'} >= $$self{'max_files_per_dir'} or $$self{'n_files_this_dir'} < 0
343   ***     33      0   4016      0   $n || $$self{'n_sessions_saved'}


Covered Subroutines
-------------------

Subroutine             Count Pod Location                                          
---------------------- ----- --- --------------------------------------------------
BEGIN                      1     /home/daniel/dev/maatkit/common/LogSplitter.pm:23 
BEGIN                      1     /home/daniel/dev/maatkit/common/LogSplitter.pm:24 
BEGIN                      1     /home/daniel/dev/maatkit/common/LogSplitter.pm:25 
BEGIN                      1     /home/daniel/dev/maatkit/common/LogSplitter.pm:27 
BEGIN                      1     /home/daniel/dev/maatkit/common/LogSplitter.pm:32 
BEGIN                      1     /home/daniel/dev/maatkit/common/LogSplitter.pm:33 
BEGIN                      1     /home/daniel/dev/maatkit/common/LogSplitter.pm:34 
__ANON__                   8     /home/daniel/dev/maatkit/common/LogSplitter.pm:125
__ANON__                6038     /home/daniel/dev/maatkit/common/LogSplitter.pm:129
__ANON__               12068     /home/daniel/dev/maatkit/common/LogSplitter.pm:130
__ANON__                2009     /home/daniel/dev/maatkit/common/LogSplitter.pm:407
_close_lru_session        22     /home/daniel/dev/maatkit/common/LogSplitter.pm:291
_get_next_session_file  4016     /home/daniel/dev/maatkit/common/LogSplitter.pm:311
_get_session_ds         6024     /home/daniel/dev/maatkit/common/LogSplitter.pm:248
_merge_session_files       5     /home/daniel/dev/maatkit/common/LogSplitter.pm:363
_save_event             6024     /home/daniel/dev/maatkit/common/LogSplitter.pm:168
flatten                 4027   0 /home/daniel/dev/maatkit/common/LogSplitter.pm:354
make_rr_iter               6   0 /home/daniel/dev/maatkit/common/LogSplitter.pm:404
new                        8   0 /home/daniel/dev/maatkit/common/LogSplitter.pm:39 
split                      8   0 /home/daniel/dev/maatkit/common/LogSplitter.pm:83 

Uncovered Subroutines
---------------------

Subroutine             Count Pod Location                                          
---------------------- ----- --- --------------------------------------------------
_d                         0     /home/daniel/dev/maatkit/common/LogSplitter.pm:427
print_split_summary        0   0 /home/daniel/dev/maatkit/common/LogSplitter.pm:414


LogSplitter.t

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
               1                                  6   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            10   use Test::More tests => 22;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use LogSplitter;
               1                                  3   
               1                                 12   
15             1                    1            12   use SlowLogParser;
               1                                  2   
               1                                 11   
16             1                    1            10   use MaatkitTest;
               1                                  8   
               1                                 40   
17                                                    
18             1                                  4   my $output;
19             1                                  4   my $tmpdir = '/tmp/LogSplitter';
20             1                               7861   diag(`rm -rf $tmpdir ; mkdir $tmpdir`);
21                                                    
22             1                                 19   my $lp = new SlowLogParser();
23             1                                 65   my $ls = new LogSplitter(
24                                                       attribute     => 'foo',
25                                                       base_dir      => $tmpdir,
26                                                       parser        => $lp,
27                                                       session_files => 3,
28                                                       quiet         => 1,
29                                                    );
30                                                    
31             1                                 12   isa_ok($ls, 'LogSplitter');
32                                                    
33             1                               8133   diag(`rm -rf $tmpdir ; mkdir $tmpdir`);
34                                                    
35                                                    # This creates an implicit test to make sure that
36                                                    # split_logs() will not die if the saveto_dir already
37                                                    # exists. It should just use the existing dir.
38             1                               3568   diag(`mkdir $tmpdir/1`); 
39                                                    
40             1                                 22   $ls->split("$trunk/common/t/samples/slow006.txt");
41             1                                 11   is(
42                                                       $ls->{n_sessions_saved},
43                                                       0,
44                                                       'Parsed zero sessions for bad attribute'
45                                                    );
46                                                    
47             1                                  6   is(
48                                                       $ls->{n_events_total},
49                                                       6,
50                                                       'Parsed all events'
51                                                    );
52                                                    
53                                                    # #############################################################################
54                                                    # Test a simple split of 6 events, 3 sessions into 3 session files.
55                                                    # #############################################################################
56             1                               5694   diag(`rm -rf $tmpdir/*`);
57             1                                 29   $ls = new LogSplitter(
58                                                       attribute      => 'Thread_id',
59                                                       base_dir       => $tmpdir,
60                                                       parser         => $lp,
61                                                       session_files  => 3,
62                                                       quiet          => 1,
63                                                       merge_sessions => 0,
64                                                    );
65             1                                 23   $ls->split("$trunk/common/t/samples/slow006.txt");
66             1                                 24   ok(-f "$tmpdir/1/session-1.txt", 'Basic split session 1 file exists');
67             1                                 13   ok(-f "$tmpdir/1/session-2.txt", 'Basic split session 2 file exists');
68             1                                 11   ok(-f "$tmpdir/1/session-3.txt", 'Basic split session 3 file exists');
69                                                    
70             1                              17884   $output = `diff $tmpdir/1/session-1.txt $trunk/common/t/samples/slow006-session-1.txt`;
71             1                                 34   is(
72                                                       $output,
73                                                       '',
74                                                       'Session 1 file has correct SQL statements'
75                                                    );
76                                                    
77             1                               3300   $output = `diff $tmpdir/1/session-2.txt $trunk/common/t/samples/slow006-session-2.txt`;
78             1                                 59   is(
79                                                       $output,
80                                                       '',
81                                                       'Session 2 file has correct SQL statements'
82                                                    );
83                                                    
84             1                               3285   $output = `diff $tmpdir/1/session-3.txt $trunk/common/t/samples/slow006-session-3.txt`;
85             1                                 60   is(
86                                                       $output,
87                                                       '',
88                                                       'Session 3 file has correct SQL statements'
89                                                    );
90                                                    
91                                                    # #############################################################################
92                                                    # Test splitting more sessions than we can have open filehandles at once.
93                                                    # #############################################################################
94             1                               8564   diag(`rm -rf $tmpdir/*`);
95             1                                 27   $ls = new LogSplitter(
96                                                       attribute      => 'Thread_id',
97                                                       base_dir       => $tmpdir,
98                                                       parser         => $lp,
99                                                       session_files  => 10,
100                                                      quiet          => 1,
101                                                      merge_sessions => 0,
102                                                   );
103            1                                  7   $ls->split("$trunk/common/t/samples/slow009.txt");
104            1                              19122   chomp($output = `ls -1 $tmpdir/1/ | wc -l`);
105            1                                 39   is(
106                                                      $output,
107                                                      2000,
108                                                      'Splits 2_000 sessions'
109                                                   );
110                                                   
111            1                               3271   $output = `cat $tmpdir/1/session-2000.txt`;
112            1                                 77   like(
113                                                      $output,
114                                                      qr/SELECT 2001 FROM foo/,
115                                                      '2_000th session has correct SQL'
116                                                   );
117                                                   
118            1                               3482   $output = `cat $tmpdir/1/session-12.txt`;
119            1                                 52   like(
120                                                      $output, qr/SELECT 12 FROM foo\n\nSELECT 1234 FROM foo/,
121                                                      'Reopened and appended to previously closed session'
122                                                   );
123                                                   
124                                                   # #############################################################################
125                                                   # Test max_sessions.
126                                                   # #############################################################################
127            1                              44303   diag(`rm -rf $tmpdir/*`);
128            1                                 40   $ls = new LogSplitter(
129                                                      attribute      => 'Thread_id',
130                                                      base_dir       => $tmpdir,
131                                                      parser         => $lp,
132                                                      session_files  => 10,
133                                                      quiet          => 1,
134                                                      merge_sessions => 0,
135                                                      max_sessions   => 10,
136                                                   );
137            1                                  7   $ls->split("$trunk/common/t/samples/slow009.txt");
138            1                               7127   chomp($output = `ls -1 $tmpdir/1/ | wc -l`);
139            1                                 48   is(
140                                                      $output,
141                                                      '10',
142                                                      'max_sessions works (1/3)',
143                                                   );
144            1                                 17   is(
145                                                      $ls->{n_sessions_saved},
146                                                      '10',
147                                                      'max_sessions works (2/3)'
148                                                   );
149            1                                 13   is(
150                                                      $ls->{n_files_total},
151                                                      '10',
152                                                      'max_sessions works (3/3)'
153                                                   );
154                                                   
155                                                   # #############################################################################
156                                                   # Check that all filehandles are closed.
157                                                   # #############################################################################
158            1                                 16   is_deeply(
159                                                      $ls->{session_fhs},
160                                                      [],
161                                                      'Closes open fhs'
162                                                   );
163                                                   
164                                                   #diag(`rm -rf $tmpdir/*`);
165                                                   #$output = `cat $trunk/common/t/samples/slow006.txt | $trunk/common/t/samples/log_splitter.pl`;
166                                                   #like($output, qr/Parsed sessions\s+3/, 'Reads STDIN implicitly');
167                                                   
168                                                   #diag(`rm -rf $tmpdir/*`);
169                                                   #$output = `cat $trunk/common/t/samples/slow006.txt | $trunk/common/t/samples/log_splitter.pl -`;
170                                                   #like($output, qr/Parsed sessions\s+3/, 'Reads STDIN explicitly');
171                                                   
172                                                   #diag(`rm -rf $tmpdir/*`);
173                                                   #$output = `cat $trunk/common/t/samples/slow006.txt | $trunk/common/t/samples/log_splitter.pl blahblah`;
174                                                   #like($output, qr/Parsed sessions\s+0/, 'Does nothing if no valid logs are given');
175                                                   
176                                                   # #############################################################################
177                                                   # Test session file merging.
178                                                   # #############################################################################
179            1                               6589   diag(`rm -rf $tmpdir/*`);
180            1                                 33   $ls = new LogSplitter(
181                                                      attribute      => 'Thread_id',
182                                                      base_dir       => $tmpdir,
183                                                      parser         => $lp,
184                                                      session_files  => 10,
185                                                      quiet          => 1,
186                                                   );
187            1                                  7   $ls->split("$trunk/common/t/samples/slow009.txt");
188            1                              23329   $output = `grep 'START SESSION' $tmpdir/sessions-*.txt | cut -d' ' -f 4 | sort -n`;
189            1                                132   like(
190                                                      $output,
191                                                      qr/^1\n2\n3\n[\d\n]+2001$/,
192                                                      'Merges 2_000 sessions'
193                                                   );
194                                                   
195            1                                 84   ok(
196                                                      !-d "$tmpdir/1",
197                                                      'Removes tmp dirs after merging'
198                                                   );
199                                                   
200                                                   # #############################################################################
201                                                   # Issue 418: mk-log-player dies trying to play statements with blank lines
202                                                   # #############################################################################
203                                                   
204                                                   # LogSplitter should pre-process queries before writing them so that they
205                                                   # do not contain blank lines.
206            1                              12899   diag(`rm -rf $tmpdir/*`);
207            1                                 53   $ls = new LogSplitter(
208                                                      attribute     => 'Thread_id',
209                                                      base_dir      => $tmpdir,
210                                                      parser        => $lp,
211                                                      quiet         => 1,
212                                                      session_files => 1,
213                                                   );
214            1                                 11   $ls->split("$trunk/common/t/samples/slow020.txt");
215            1                              23443   $output = `diff $tmpdir/sessions-1.txt $trunk/common/t/samples/split_slow020.txt`;
216            1                                 87   is(
217                                                      $output,
218                                                      '',
219                                                      'Collapse multiple \n and \s (issue 418)'
220                                                   );
221                                                   
222                                                   # Make sure it works for --maxsessionfiles
223                                                   #diag(`rm -rf $tmpdir/*`);
224                                                   #$ls = new LogSplitter(
225                                                   #   attribute       => 'Thread_id',
226                                                   #   saveto_dir      => "$tmpdir/",
227                                                   #   lp              => $lp,
228                                                   #   verbose         => 0,
229                                                   #   maxsessionfiles => 1,
230                                                   #);
231                                                   #$ls->split(['common/t/samples/slow020.txt' ]);
232                                                   #$output = `diff $tmpdir/1/session-0001 $trunk/common/t/samples/split_slow020_msf.txt`;
233                                                   #is(
234                                                   #   $output,
235                                                   #   '',
236                                                   #   'Collapse multiple \n and \s with --maxsessionfiles (issue 418)'
237                                                   #);
238                                                   
239                                                   # #############################################################################
240                                                   # Issue 571: Add --filter to mk-log-player
241                                                   # #############################################################################
242                                                   my $callback = sub {
243            6                    6            42      return;
244            1                                 27   };
245            1                                 53   $ls = new LogSplitter(
246                                                      attribute     => 'Thread_id',
247                                                      base_dir      => $tmpdir,
248                                                      parser        => $lp,
249                                                      session_files => 3,
250                                                      quiet         => 1,
251                                                      callbacks     => [$callback],
252                                                   );
253            1                                  8   $ls->split("$trunk/common/t/samples/slow006.txt");
254            1                                 16   is(
255                                                      $ls->{n_sessions_saved},
256                                                      0,
257                                                      'callbacks'
258                                                   );
259                                                   
260                                                   # #############################################################################
261                                                   # Issue 798: Make mk-log-player --split work without an attribute
262                                                   # #############################################################################
263            1                              11351   diag(`rm -rf $tmpdir/*`);
264            1                                 69   $ls = new LogSplitter(
265                                                      attribute      => 'Thread_id',
266                                                      split_random   => 1,
267                                                      base_dir       => $tmpdir,
268                                                      parser         => $lp,
269                                                      session_files  => 2,
270                                                      quiet          => 1,
271                                                   
272                                                   );
273            1                                134   $ls->split("$trunk/common/t/samples/slow006.txt");
274                                                   
275            1                              12368   $output = `diff $tmpdir/sessions-1.txt $trunk/common/t/samples/LogSplitter/slow006-random-1.txt`;
276            1                                 91   is(
277                                                      $output,
278                                                      '',
279                                                      'Random file 1 file has correct SQL statements'
280                                                   );
281                                                   
282            1                               6560   $output = `diff $tmpdir/sessions-2.txt $trunk/common/t/samples/LogSplitter/slow006-random-2.txt`;
283            1                                 86   is(
284                                                      $output,
285                                                      '',
286                                                      'Random file 2 file has correct SQL statements'
287                                                   );
288                                                   
289                                                   # #############################################################################
290                                                   # Done.
291                                                   # #############################################################################
292            1                               6231   diag(`rm -rf $tmpdir`);
293            1                                 11   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location         
---------- ----- -----------------
BEGIN          1 LogSplitter.t:10 
BEGIN          1 LogSplitter.t:11 
BEGIN          1 LogSplitter.t:12 
BEGIN          1 LogSplitter.t:14 
BEGIN          1 LogSplitter.t:15 
BEGIN          1 LogSplitter.t:16 
BEGIN          1 LogSplitter.t:4  
BEGIN          1 LogSplitter.t:9  
__ANON__       6 LogSplitter.t:243


