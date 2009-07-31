---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/LogSplitter.pm   85.6   63.9   63.6   89.5    n/a  100.0   79.2
Total                          85.6   63.9   63.6   89.5    n/a  100.0   79.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          LogSplitter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:59 2009
Finish:       Fri Jul 31 18:52:13 2009

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
19                                                    # LogSplitter package $Revision: 4223 $
20                                                    # ###########################################################################
21                                                    package LogSplitter;
22                                                    
23             1                    1             9   use strict;
               1                                  2   
               1                                  7   
24             1                    1           106   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26                                                    
27             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  9   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32             1                    1             6   use constant MKDEBUG           => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
33             1                    1             6   use constant MAX_OPEN_FILES    => 1000;
               1                                  2   
               1                                  4   
34             1                    1             6   use constant CLOSE_N_LRU_FILES => 100;
               1                                  2   
               1                                  4   
35                                                    
36                                                    sub new {
37             5                    5          7337      my ( $class, %args ) = @_;
38             5                                 49      foreach my $arg ( qw(attribute base_dir SlowLogParser session_files) ) {
39    ***     20     50                         109         die "I need a $arg argument" unless $args{$arg};
40                                                       }
41                                                    
42                                                       # TODO: this is probably problematic on Windows
43    ***      5     50                          58      $args{base_dir} .= '/' if substr($args{base_dir}, -1, 1) ne '/';
44                                                    
45             5                                174      my $self = {
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
71             5                                 19      MKDEBUG && _d('new LogSplitter final args:', Dumper($self));
72             5                                 59      return bless $self, $class;
73                                                    }
74                                                    
75                                                    sub split {
76             5                    5          8266      my ( $self, @logs ) = @_;
77             5                                 25      my $oktorun = 1; # True as long as we haven't created too many
78                                                                        # session files or too many dirs and files
79                                                    
80    ***      5     50                          34      if ( @logs == 0 ) {
81    ***      0                                  0         MKDEBUG && _d('Implicitly reading STDIN because no logs were given');
82    ***      0                                  0         push @logs, '-';
83                                                       }
84                                                    
85                                                       # This sub is called by SlowLogParser::parse_event().
86                                                       # It saves each session to its own file.
87             5                                 13      my @callbacks;
88                                                       push @callbacks, sub {
89          6015                 6015         20074         my ( $event ) = @_; 
90          6015                              22418         my ($session, $session_id) = $self->_get_session_ds($event);
91          6015    100                       27483         return unless $session;
92                                                    
93          4018    100                       15153         if ( !defined $session->{fh} ) {
                    100                               
94          4013                              11592            $self->{n_sessions_saved}++;
95          4013                               8444            MKDEBUG && _d('New session:', $session_id, ',',
96                                                                $self->{n_sessions_saved}, 'of', $self->{max_sessions});
97                                                    
98          4013                              13541            my $session_file = $self->_get_next_session_file();
99    ***   4013     50                       14444            if ( !$session_file ) {
100   ***      0                                  0               $oktorun = 0;
101   ***      0                                  0               MKDEBUG && _d('Not oktorun because no _get_next_session_file');
102   ***      0                                  0               return;
103                                                            }
104                                                   
105                                                            # Close Last Recently Used session fhs if opening if this new
106                                                            # session fh will cause us to have too many open files.
107         4013    100                       16251            $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
108                                                   
109                                                            # Open a fh for this session file.
110   ***   4013     50                      188872            open my $fh, '>', $session_file
111                                                               or die "Cannot open session file $session_file: $OS_ERROR";
112         4013                              16355            $session->{fh} = $fh;
113         4013                              11985            $self->{n_open_fhs}++;
114                                                   
115                                                            # Save fh and session file in case we need to open/close it later.
116         4013                              12423            $session->{active}       = 1;
117         4013                              14652            $session->{session_file} = $session_file;
118                                                   
119         4013                               9879            push @{$self->{session_fhs}}, { fh => $fh, session_id => $session_id };
            4013                              22778   
120                                                   
121         4013                               9720            MKDEBUG && _d('Created', $session_file, 'for session',
122                                                               $self->{attribute}, '=', $session_id);
123                                                   
124                                                            # This special comment lets mk-log-player know when a session begins.
125         4013                              37782            print $fh "-- START SESSION $session_id\n\n";
126                                                         }
127                                                         elsif ( !$session->{active} ) {
128                                                            # Reopen the existing but inactive session. This happens when
129                                                            # a new session (above) had to close LRU session fhs.
130                                                   
131                                                            # Again, close Last Recently Used session fhs if reopening if this
132                                                            # session's fh will cause us to have too many open files.
133   ***      2     50                          14            $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
134                                                   
135                                                             # Reopen this session's fh.
136   ***      2     50                          56             open $session->{fh}, '>>', $session->{session_file}
137                                                                or die "Cannot reopen session file "
138                                                                  . "$session->{session_file}: $OS_ERROR";
139                                                   
140                                                             # Mark this session as active again.
141            2                                  9             $session->{active} = 1;
142            2                                  6             $self->{n_open_fhs}++;
143                                                   
144            2                                  6             MKDEBUG && _d('Reopend', $session->{session_file}, 'for session',
145                                                               $self->{attribute}, '=', $session_id);
146                                                         }
147                                                         else {
148            3                                  7            MKDEBUG && _d('Event belongs to active session', $session_id);
149                                                         }
150                                                   
151         4018                              13813         my $session_fh = $session->{fh};
152                                                   
153                                                         # Print USE db if 1) we haven't done so yet or 2) the db has changed.
154   ***   4018            66                33016         my $db = $event->{db} || $event->{Schema};
155         4018    100    100                43538         if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
      ***                   66                        
156         4014                              15758            print $session_fh "use $db\n\n";
157         4014                              14598            $session->{db} = $db;
158                                                         }
159                                                   
160         4018                              17097         print $session_fh flatten($event->{arg}), "\n\n";
161         4018                              12721         $self->{n_events_saved}++;
162                                                   
163         4018                              25524         return $event;
164            5                               2228      };
165                                                   
166                                                      # Split all the log files.
167            5                                 27      my $lp = $self->{SlowLogParser};
168                                                      LOG:
169            5                                 33      foreach my $log ( @logs ) {
170   ***      5     50                          25         next unless defined $log;
171   ***      5     50     33                   97         if ( !-f $log && $log ne '-' ) {
172   ***      0                                  0            warn "Skipping $log because it is not a file";
173   ***      0                                  0            next LOG;
174                                                         }
175            5                                 14         my $fh;
176   ***      5     50                          27         if ( $log eq '-' ) {
177   ***      0                                  0            $fh = *STDIN;
178                                                         }
179                                                         else {
180   ***      5     50                         452            if ( !open $fh, "<", $log ) {
181   ***      0                                  0               warn "Cannot open $log: $OS_ERROR\n";
182   ***      0                                  0               next LOG;
183                                                            }
184                                                         }
185   ***      5     50                          40         if ( $fh ) {
186            5                                 15            MKDEBUG && _d('Splitting', $log);
187            5                                 21            while ( $oktorun ) {
188         6020                              26084               my $events = $lp->parse_event($fh, undef, @callbacks);
189         6020                              20904               $self->{n_events_total} += $events;
190   ***   6020     50                       21303               last LOG unless $oktorun;
191         6020    100                       29485               if ( !$events ) {
192            5                                 15                  MKDEBUG && _d('No more events in', $log);
193            5                                 56                  close $fh;
194            5                                 16                  next LOG;
195                                                               }
196                                                            }
197                                                         }
198                                                      }
199                                                   
200                                                      # Close session filehandles.
201            5                                 72      while ( my $fh = pop @{ $self->{session_fhs} } ) {
            4018                              20962   
202         4013                              74720         close $fh->{fh};
203                                                      }
204            5                                 22      $self->{n_open_fhs}  = 0;
205                                                   
206            5    100                          46      $self->_merge_session_files() if $self->{merge_sessions};
207   ***      5     50                          29      $self->print_split_summary() unless $self->{quiet};
208                                                   
209            5                                268      return;
210                                                   }
211                                                   
212                                                   # Returns shortcut to session data store and id for the given event.
213                                                   # The returned session will be undef if no more sessions are allowed.
214                                                   sub _get_session_ds {
215         6015                 6015         19313      my ( $self, $event ) = @_;
216                                                   
217         6015                              20452      my $attrib = $self->{attribute};
218         6015    100                       24523      if ( !$event->{ $attrib } ) {
219            6                                 12         MKDEBUG && _d('No attribute', $attrib, 'in event:', Dumper($event));
220            6                                 22         return;
221                                                      }
222                                                   
223                                                      # This could indicate a problem in SlowLogParser not parsing
224                                                      # a log event correctly thereby leaving $event->{arg} undefined.
225                                                      # Or, it could simply be an event like:
226                                                      #   use db;
227                                                      #   SET NAMES utf8;
228   ***   6009     50                       23031      return unless $event->{arg};
229                                                   
230                                                      # Don't print admin commands like quit or ping because these
231                                                      # cannot be played.
232   ***   6009     50     50                31307      return if ($event->{cmd} || '') eq 'Admin';
233                                                   
234         6009                              13180      my $session;
235         6009                              17775      my $session_id = $event->{ $attrib };
236                                                   
237                                                      # The following is necessary to prevent Perl from auto-vivifying
238                                                      # a lot of empty hashes for new sessions that are ignored due to
239                                                      # already having max_sessions.
240         6009    100                       29713      if ( $self->{n_sessions_saved} < $self->{max_sessions} ) {
      ***            50                               
241                                                         # Will auto-vivify if necessary.
242         4018           100                39754         $session = $self->{sessions}->{ $session_id } ||= {};
243                                                      }
244                                                      elsif ( exists $self->{sessions}->{ $session_id } ) {
245                                                         # Use only existing sessions.
246   ***      0                                  0         $session = $self->{sessions}->{ $session_id };
247                                                      }
248                                                      else {
249         1991                               6306         $self->{n_sessions_skipped} += 1;
250         1991                               4549         MKDEBUG && _d('Skipping new session', $session_id,
251                                                            'because max_sessions is reached');
252                                                      }
253                                                   
254         6009                              28369      return $session, $session_id;
255                                                   }
256                                                   
257                                                   sub _close_lru_session {
258           22                   22            85      my ( $self ) = @_;
259           22                                 82      my $session_fhs = $self->{session_fhs};
260           22                                 92      my $lru_n       = $self->{n_sessions_saved} - MAX_OPEN_FILES - 1;
261           22                                 79      my $close_to_n  = $lru_n + CLOSE_N_LRU_FILES - 1;
262                                                   
263           22                                 52      MKDEBUG && _d('Closing session fhs', $lru_n, '..', $close_to_n,
264                                                         '(',$self->{n_sessions}, 'sessions', $self->{n_open_fhs}, 'open fhs)');
265                                                   
266           22                                370      foreach my $session ( @$session_fhs[ $lru_n..$close_to_n ] ) {
267         2200                              37169         close $session->{fh};
268         2200                               6876         $self->{n_open_fhs}--;
269         2200                              12527         $self->{sessions}->{ $session->{session_id} }->{active} = 0;
270                                                      }
271                                                   
272           22                                154      return;
273                                                   }
274                                                   
275                                                   # Returns an empty string on failure, or the next session file name on success.
276                                                   # This will fail if we have opened maxdirs and maxfiles.
277                                                   sub _get_next_session_file {
278         4013                 4013         13000      my ( $self, $n ) = @_;
279   ***   4013     50                       19006      return if $self->{n_dirs_total} >= $self->{max_dirs};
280                                                   
281                                                      # n_files_this_dir will only be < 0 for the first dir and file
282                                                      # because n_file is set to -1 in new(). This is a hack
283                                                      # to cause the first dir and file to be created automatically.
284   ***   4013    100     66                35212      if ( ($self->{n_files_this_dir} >= $self->{max_files_per_dir})
285                                                           || $self->{n_files_this_dir} < 0 ) {
286            4                                 12         $self->{n_dirs_total}++;
287            4                                 13         $self->{n_files_this_dir} = 0;
288            4                                 24         my $new_dir = "$self->{base_dir}$self->{n_dirs_total}";
289   ***      4     50                          63         if ( !-d $new_dir ) {
290            4                              13347            my $retval = system("mkdir $new_dir");
291   ***      4     50                          61            if ( ($retval >> 8) != 0 ) {
292   ***      0                                  0               die "Cannot create new directory $new_dir: $OS_ERROR";
293                                                            }
294            4                                 14            MKDEBUG && _d('Created new base_dir', $new_dir);
295            4                                 37            push @{$self->{created_dirs}}, $new_dir;
               4                                 93   
296                                                         }
297                                                         elsif ( MKDEBUG ) {
298                                                            _d($new_dir, 'already exists');
299                                                         }
300                                                      }
301                                                      else {
302         4009                               9161         MKDEBUG && _d('No dir created; n_files_this_dir:',
303                                                            $self->{n_files_this_dir}, 'n_files_total:',
304                                                            $self->{n_files_total});
305                                                      }
306                                                   
307         4013                              11472      $self->{n_files_total}++;
308         4013                              11310      $self->{n_files_this_dir}++;
309         4013                              14385      my $dir_n        = $self->{n_dirs_total} . '/';
310   ***   4013            33                32981      my $session_n    = sprintf '%d', $n || $self->{n_sessions_saved};
311         4013                              20958      my $session_file = $self->{base_dir}
312                                                                       . $dir_n
313                                                                       . $self->{base_file_name}."-$session_n.txt";
314         4013                               9178      MKDEBUG && _d('Next session file', $session_file);
315         4013                              15276      return $session_file;
316                                                   }
317                                                   
318                                                   # Flattens multiple new-line and spaces to single new-lines and spaces
319                                                   # and remove /* comment */ blocks.
320                                                   sub flatten {
321         4018                 4018         14644      my ( $query ) = @_;
322   ***   4018     50                       14466      return unless $query;
323         4018                              11987      $query =~ s!/\*.*?\*/! !g;
324         4018                              14550      $query =~ s/^\s+//;
325         4018                              13981      $query =~ s/\s{2,}/ /g;
326         4018                              15742      return $query;
327                                                   }
328                                                   
329                                                   sub _merge_session_files {
330            2                    2            10      my ( $self ) = @_;
331                                                   
332   ***      2     50                          11      print "Merging session files...\n" unless $self->{quiet};
333                                                   
334            2                                  6      my @multi_session_files;
335            2                                 18      for my $i ( 1..$self->{session_files} ) {
336           13                                 76         push @multi_session_files, $self->{base_dir} ."sessions-$i.txt";
337                                                      }
338                                                   
339         2000                               9175      my @single_session_files = map {
340            2                               1052         $_->{session_file};
341            2                                  7      } values %{$self->{sessions}};
342                                                   
343            2                                478      my $i = make_rr_iter(0, $#multi_session_files);  # round-robin iterator
344            2                                 10      foreach my $single_session_file ( @single_session_files ) {
345         2000                              40957         my $multi_session_file = $multi_session_files[ $i->() ];
346         2000                              22584         my $cmd = "cat $single_session_file >> $multi_session_file";
347         2000                               7306         eval { `$cmd`; };
            2000                             9830147   
348   ***   2000     50                       50515         if ( $EVAL_ERROR ) {
349   ***      0                                  0            warn "Failed to `$cmd`: $OS_ERROR";
350                                                         }
351                                                      }
352                                                   
353            2                                 23      foreach my $created_dir ( @{$self->{created_dirs}} ) {
               2                                 18   
354            1                                 27         my $cmd = "rm -rf $created_dir";
355            1                                 12         eval { `$cmd`; };
               1                              40472   
356   ***      1     50                          52         if ( $EVAL_ERROR ) {
357   ***      0                                  0            warn "Failed to `$cmd`: $OS_ERROR";
358                                                         }
359                                                      }
360                                                   
361            2                               1023      return;
362                                                   }
363                                                   
364                                                   sub make_rr_iter {
365            2                    2            14      my ( $start, $end ) = @_;
366            2                                  7      my $current = $start;
367                                                      return sub {
368         2000    100          2000         25256         $current = $start if $current > $end ;
369         2000                               7073         $current++;  # For next iteration.
370         2000                              31472         return $current - 1;
371            2                                 24      };
372                                                   }
373                                                   
374                                                   sub print_split_summary {
375   ***      0                    0                    my ( $self ) = @_;
376   ***      0                                         print "Split summary:\n";
377   ***      0                                         my $fmt = "%-20s %-10s\n";
378   ***      0                                         printf $fmt, 'Total sessions',
379                                                         $self->{n_sessions_saved} + $self->{n_sessions_skipped};
380   ***      0                                         printf $fmt, 'Sessions saved',
381                                                         $self->{n_sessions_saved};
382   ***      0                                         printf $fmt, 'Total events', $self->{n_events_total};
383   ***      0                                         printf $fmt, 'Events saved', $self->{n_events_saved};
384   ***      0                                         return;
385                                                   }
386                                                   
387                                                   sub _d {
388   ***      0                    0                    my ($package, undef, $line) = caller 0;
389   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
390   ***      0                                              map { defined $_ ? $_ : 'undef' }
391                                                           @_;
392   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
393                                                   }
394                                                   
395                                                   1;
396                                                   
397                                                   # ###########################################################################
398                                                   # End LogSplitter package
399                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***     50      0     20   unless $args{$arg}
43    ***     50      5      0   if substr($args{'base_dir'}, -1, 1) ne '/'
80    ***     50      0      5   if (@logs == 0)
91           100   1997   4018   unless $session
93           100   4013      5   if (not defined $$session{'fh'}) { }
             100      2      3   elsif (not $$session{'active'}) { }
99    ***     50      0   4013   if (not $session_file)
107          100     22   3991   if $$self{'n_open_fhs'} >= 1000
110   ***     50      0   4013   unless open my $fh, '>', $session_file
133   ***     50      0      2   if $$self{'n_open_fhs'} >= 1000
136   ***     50      0      2   unless open $$session{'fh'}, '>>', $$session{'session_file'}
155          100   4014      4   if ($db and !defined($$session{'db'}) || $$session{'db'} ne $db)
170   ***     50      0      5   unless defined $log
171   ***     50      0      5   if (not -f $log and $log ne '-')
176   ***     50      0      5   if ($log eq '-') { }
180   ***     50      0      5   if (not open $fh, '<', $log)
185   ***     50      5      0   if ($fh)
190   ***     50      0   6020   unless $oktorun
191          100      5   6015   if (not $events)
206          100      2      3   if $$self{'merge_sessions'}
207   ***     50      0      5   unless $$self{'quiet'}
218          100      6   6009   if (not $$event{$attrib})
228   ***     50      0   6009   unless $$event{'arg'}
232   ***     50      0   6009   if ($$event{'cmd'} || '') eq 'Admin'
240          100   4018   1991   if ($$self{'n_sessions_saved'} < $$self{'max_sessions'}) { }
      ***     50      0   1991   elsif (exists $$self{'sessions'}{$session_id}) { }
279   ***     50      0   4013   if $$self{'n_dirs_total'} >= $$self{'max_dirs'}
284          100      4   4009   if ($$self{'n_files_this_dir'} >= $$self{'max_files_per_dir'} or $$self{'n_files_this_dir'} < 0) { }
289   ***     50      4      0   !-d($new_dir) ? :
291   ***     50      0      4   if ($retval >> 8 != 0)
322   ***     50      0   4018   unless $query
332   ***     50      0      2   unless $$self{'quiet'}
348   ***     50      0   2000   if ($EVAL_ERROR)
356   ***     50      0      1   if ($EVAL_ERROR)
368          100    199   1801   if $current > $end
389   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
155   ***     66      0      4   4014   $db and !defined($$session{'db'}) || $$session{'db'} ne $db
171   ***     33      5      0      0   not -f $log and $log ne '-'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
232   ***     50   6009      0   $$event{'cmd'} || ''
242          100      5   4013   $$self{'sessions'}{$session_id} ||= {}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
154   ***     66      2   4016      0   $$event{'db'} || $$event{'Schema'}
155          100   4013      1      4   !defined($$session{'db'}) || $$session{'db'} ne $db
284   ***     66      0      4   4009   $$self{'n_files_this_dir'} >= $$self{'max_files_per_dir'} or $$self{'n_files_this_dir'} < 0
310   ***     33      0   4013      0   $n || $$self{'n_sessions_saved'}


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
__ANON__                2000 /home/daniel/dev/maatkit/common/LogSplitter.pm:368
__ANON__                6015 /home/daniel/dev/maatkit/common/LogSplitter.pm:89 
_close_lru_session        22 /home/daniel/dev/maatkit/common/LogSplitter.pm:258
_get_next_session_file  4013 /home/daniel/dev/maatkit/common/LogSplitter.pm:278
_get_session_ds         6015 /home/daniel/dev/maatkit/common/LogSplitter.pm:215
_merge_session_files       2 /home/daniel/dev/maatkit/common/LogSplitter.pm:330
flatten                 4018 /home/daniel/dev/maatkit/common/LogSplitter.pm:321
make_rr_iter               2 /home/daniel/dev/maatkit/common/LogSplitter.pm:365
new                        5 /home/daniel/dev/maatkit/common/LogSplitter.pm:37 
split                      5 /home/daniel/dev/maatkit/common/LogSplitter.pm:76 

Uncovered Subroutines
---------------------

Subroutine             Count Location                                          
---------------------- ----- --------------------------------------------------
_d                         0 /home/daniel/dev/maatkit/common/LogSplitter.pm:388
print_split_summary        0 /home/daniel/dev/maatkit/common/LogSplitter.pm:375


