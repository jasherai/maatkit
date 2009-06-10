---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/LogSplitter.pm   92.2   67.5   70.2   93.8    n/a  100.0   83.7
Total                          92.2   67.5   70.2   93.8    n/a  100.0   83.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          LogSplitter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:55 2009
Finish:       Wed Jun 10 17:19:58 2009

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
19                                                    # LogSplitter package $Revision: 3643 $
20                                                    # ###########################################################################
21                                                    package LogSplitter;
22                                                    
23             1                    1            15   use strict;
               1                                  5   
               1                                 12   
24             1                    1           155   use warnings FATAL => 'all';
               1                                  3   
               1                                  9   
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27             1                    1             7   use constant MKDEBUG           => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
28             1                    1             5   use constant MAX_OPEN_FILES    => 1000;
               1                                  3   
               1                                  4   
29             1                    1             6   use constant CLOSE_N_LRU_FILES => 100;
               1                                  2   
               1                                  5   
30                                                    
31                                                    sub new {
32             6                    6         22238      my ( $class, %args ) = @_;
33             6                                 69      foreach my $arg ( qw(attribute saveto_dir lp) ) {
34    ***     18     50                         124         die "I need a $arg argument" unless $args{$arg};
35                                                       }
36                                                    
37                                                       # TODO: this is probably problematic on Windows
38    ***      6     50                          73      $args{saveto_dir} .= '/' if substr($args{saveto_dir}, -1, 1) ne '/';
39                                                    
40             6                                177      my $self = {
41                                                          %args,
42                                                          n_dirs          => 0,  # number of dirs created
43                                                          n_files         => -1, # number of session files in current dir
44                                                          n_sessions      => 0,  # number of sessions saved
45                                                          n_session_files => 0,  # number of session files created
46                                                          session_fhs     => [], # filehandles for each session
47                                                          n_open_fhs      => 0,  # number of open session filehandles
48                                                          sessions        => {}, # sessions data store
49                                                          n_events_total  => 0,  # number of total queries in log
50                                                          n_events_saved  => 0,  # number of queries split and saved from log
51                                                       };
52                                                       # These are "required options."
53                                                       # They cannot be undef, so we must check that here.
54    ***      6            50                   48      $self->{maxfiles}          ||= 100;
55    ***      6            50                   38      $self->{maxdirs}           ||= 100;
56    ***      6            50                   51      $self->{maxsessions}       ||= 100000;
57             6           100                   36      $self->{maxsessionfiles}   ||= 0;
58             6           100                   34      $self->{verbose}           ||= 0;
59    ***      6            50                   44      $self->{session_file_name} ||= 'mysql_log_session_';
60                                                    
61             6                                 75      return bless $self, $class;
62                                                    }
63                                                    
64                                                    sub split_logs {
65             7                    7         46902      my ( $self, $logs ) = @_;
66             7                                 36      my $oktorun = 1; # true as long as we haven't created too many
67                                                                        # session files or too many dirs and files
68                                                    
69                                                       # TODO: not pretty
70             7                                 46      @{$self}{qw(n_dirs n_files n_sessions n_session_files n_events_total n_events_saved)} = qw(0 -1 0 0 0 0);
               7                                102   
71                                                    
72             7                                 49      $self->{sessions} = {};
73                                                    
74    ***      7     50     33                  111      if ( !defined $logs || scalar @$logs == 0 ) {
75    ***      0                                  0         MKDEBUG && _d('Implicitly reading STDIN because no logs were given');
76    ***      0                                  0         push @$logs, '-';
77                                                       }
78                                                    
79                                                       # This sub is called by LogParser::parse_event (below).
80                                                       # It saves each event to its proper session file.
81             7                               1965      my @callbacks;
82             7    100                          48      if ( $self->{maxsessionfiles} ) {
83                                                          push @callbacks, sub {
84             9                    9            49            my ( $event ) = @_;
85             9                                 44            $self->{n_events_total}++;
86             9                                 58            my ( $session, $sesion_id ) = $self->_get_session_ds($event);
87    ***      9     50                          57            return unless defined $session;
88             9    100                          71            $self->{n_sessions}++ if !$session->{already_seen}++;
89    ***      9            66                   98            my $db = $event->{db} || $event->{Schema};
90             9    100    100                  155            if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
      ***                   66                        
91             7                                 26               push @{$session->{queries}}, "USE `$db`";
               7                                 62   
92             7                                 35               $session->{db} = $db;
93                                                             }
94             9                                 30            push @{$session->{queries}}, flatten($event->{arg});
               9                                 74   
95             9                                 43            $self->{n_events_saved}++;
96             9                                 70            return;
97             2                                 54         };
98                                                       }
99                                                       else {
100                                                         push @callbacks, sub {
101         4017                 4017         13595            my ( $event ) = @_; 
102         4017                              13243            $self->{n_events_total}++;
103         4017                              15083            my ($session, $session_id) = $self->_get_session_ds($event);
104         4017    100                       20908            return unless defined $session;
105                                                   
106         2020    100                        8989            if ( !defined $session->{fh} ) {
                    100                               
107         2014                               5945               $self->{n_sessions}++;
108         2014                               4289               MKDEBUG && _d('New session:', $session_id, ',',
109                                                                  $self->{n_sessions}, 'of', $self->{maxsessions});
110                                                   
111         2014                               7059               my $session_file = $self->_next_session_file();
112   ***   2014     50                        7467               if ( !$session_file ) {
113   ***      0                                  0                  $oktorun = 0;
114   ***      0                                  0                  MKDEBUG && _d('No longer oktorun because no _next_session_file');
115   ***      0                                  0                  return;
116                                                               }
117                                                   
118                                                               # Close Last Recently Used session fhs if opening if this new
119                                                               # session fh will cause us to have too many open files.
120         2014    100                        8599               $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
121                                                   
122                                                               # Open a fh for the log split file.
123   ***   2014     50                      186691               open my $fh, '>', $session_file
124                                                                  or die "Cannot open log split file $session_file: $OS_ERROR";
125         2014                              17454               print $fh "-- ONE SESSION\n";
126         2014                               8327               $session->{fh} = $fh;
127         2014                               6088               $self->{n_open_fhs}++;
128                                                   
129                                                               # Save fh and log split file info for this session.
130         2014                               7383               $session->{active}       = 1;
131         2014                               7677               $session->{session_file} = $session_file;
132         2014                               5250               push @{ $self->{session_fhs} },
            2014                              12412   
133                                                                  { fh => $fh, session_id => $session_id };
134                                                   
135         2014                               6294               MKDEBUG && _d('Created', $session_file, 'for session',
136                                                                  $self->{attribute}, '=', $session_id);
137                                                            }
138                                                            elsif ( !$session->{active} ) {
139                                                               # Reopen the existing but inactive session. This happens when
140                                                               # a new session (above) had to close LRU session fhs.
141                                                   
142                                                               # Again, close Last Recently Used session fhs if reopening if this
143                                                               # session's fh will cause us to have too many open files.
144   ***      1     50                          11               $self->_close_lru_session() if $self->{n_open_fhs} >= MAX_OPEN_FILES;
145                                                   
146                                                                # Reopen this session's fh.
147   ***      1     50                          33                open $session->{fh}, '>>', $session->{session_file}
148                                                                   or die "Cannot reopen log split file "
149                                                                     . "$session->{session_file}: $OS_ERROR";
150            1                                  5                $self->{n_open_fhs}++;
151                                                   
152                                                                # Mark this session as active again;
153            1                                  4                $session->{active} = 1;
154                                                   
155            1                                  3                MKDEBUG && _d('Reopend', $session->{session_file}, 'for session',
156                                                                  $self->{attribute}, '=', $session_id);
157                                                            }
158                                                            else {
159            5                                 13               MKDEBUG && _d('Event belongs to active session', $session_id);
160                                                            }
161                                                   
162         2020                               6649            my $session_fh = $session->{fh};
163                                                   
164                                                            # Print USE db if 1) we haven't done so yet or 2) the db has changed.
165   ***   2020            66                17345            my $db = $event->{db} || $event->{Schema};
166         2020    100    100                19958            if ( $db && ( !defined $session->{db} || $session->{db} ne $db ) ) {
      ***                   66                        
167         2017                               8347               print $session_fh "USE `$db`\n\n";
168         2017                               7642               $session->{db} = $db;
169                                                            }
170                                                   
171         2020                               9946            print $session_fh flatten($event->{arg}), "\n\n";
172         2020                               7816            $self->{n_events_saved}++;
173                                                   
174         2020                              11310            return;
175            5                                172         };
176                                                      }
177                                                   
178                                                      # Split all the log files.
179                                                      LOG:
180            7                                 64      foreach my $log ( @$logs ) {
181   ***      7     50                          34         next unless defined $log;
182   ***      7     50     33                  163         if ( !-f $log && $log ne '-' ) {
183   ***      0                                  0            warn "Skipping $log because it is not a file";
184   ***      0                                  0            next LOG;
185                                                         }
186            7                                 22         my $fh;
187   ***      7     50                          38         if ( $log eq '-' ) {
188   ***      0                                  0            $fh = *STDIN;
189                                                         }
190                                                         else {
191   ***      7     50                         407            open $fh, "<", $log or warn "Cannot open $log: $OS_ERROR\n";
192                                                         }
193   ***      7     50                          53         if ( $fh ) {
194   ***      7            66                  141            1 while ($oktorun && $self->{lp}->parse_event($fh, undef, @callbacks));
195            7                                 77            close $fh;
196   ***      7     50                          22            last LOG if !$oktorun;
197                                                         }
198                                                      }
199                                                   
200            7                                116      my $sessions_per_file;
201            7    100                          47      if ( $self->{maxsessionfiles} ) {   
202                                                         # Open all the needed session files.
203            2                                 17         for my $i ( 1..$self->{maxsessionfiles} ) {
204            3                                 33            my $session_file = $self->_next_session_file($i);
205   ***      3     50                          58            last if !$session_file;
206   ***      3     50                         324            open my $fh, '>', $session_file
207                                                               or die "Cannot open session file $session_file: $OS_ERROR";
208            3                                 22            $self->{n_session_files}++;
209            3                                 63            print $fh "-- MULTIPLE SESSIONS\n";
210            3                                 27            push @{ $self->{session_fhs} },
               3                                 95   
211                                                               { fh => $fh, session_file => $session_file };
212                                                         }
213                                                   
214            2                                 35         $sessions_per_file = int($self->{n_sessions} / $self->{maxsessionfiles});
215            2                                  7         MKDEBUG && _d($self->{n_sessions}, 'session,',
216                                                            $sessions_per_file, 'per file');
217                                                   
218                                                         # Save sessions to the files.
219            2                                 11         my $i      = 0;
220            2                                 11         my $file_n = 0;
221            2                                 16         my $fh     = $self->{session_fhs}->[0]->{fh};
222            2                                 10         while ( my ($session_id, $session) = each %{$self->{sessions}} ) {
               6                                 79   
223            4                                 57            $session->{session_file}
224                                                               = $self->{session_fhs}->[$file_n]->{session_file}; 
225            4                                 18            print $fh join("\n\n", @{$session->{queries}});
               4                                 52   
226            4                                 18            print $fh "\n"; # because join() doesn't do this
227            4                                 20            print $fh "-- END SESSION\n\n";
228   ***      4     50                          27            if ( ++$i >= $sessions_per_file ) {
229            4                                 16               $i = 0;
230            4    100                          36               $file_n++ if $file_n < $self->{n_session_files} - 1;
231            4                                 37               $fh = $self->{session_fhs}->[$file_n]->{fh};
232                                                            }
233                                                         }
234                                                      }
235                                                   
236                                                      # Close session filehandles.
237            7                                 30      while ( my $fh = pop @{ $self->{session_fhs} } ) {
            2024                              11437   
238         2017                              15985         close $fh->{fh};
239                                                      }
240            7                                 31      $self->{n_open_fhs}  = 0;
241                                                   
242                                                      # Report what session files were created.
243            7    100                          41      if ( $self->{verbose} ) {
244            1                                  5         my $fmt = "%-22s %15s %15s\n";
245            1                                 38         printf($fmt, 'SPLIT SUMMARY', 'COUNT', 'MAX ALLOWED');
246            1                                 10         printf($fmt, 'Parsed sessions', $self->{n_sessions},$self->{maxsessions});
247            1                                 11         printf($fmt, 'Directories created', $self->{n_dirs}, $self->{maxdirs});
248            1                                  9         printf($fmt, 'Session files created', $self->{n_session_files},
249                                                            $self->{maxfiles});
250   ***      1     50                          15         printf($fmt, 'Sessions per file', $sessions_per_file,
251                                                            $self->{maxsessionfiles}) if $self->{maxsessionfiles};
252            1                                  7         printf($fmt, 'Events read', $self->{n_events_total}, '');
253            1                                 10         printf($fmt, 'Events saved', $self->{n_events_saved}, '');
254                                                   
255            1                                  6         print "\n";
256            1                                  4         $fmt = "%-16s %-60s\n";
257            1                                 10         printf($fmt, $self->{attribute}, 'SAVED IN SESSION FILE');
258            1                                  6         foreach my $session_id ( sort keys %{ $self->{sessions} } ) {
               1                                 34   
259            3                                 17            my $session = $self->{sessions}->{ $session_id };
260            3                                 35            printf($fmt, $session_id, $session->{session_file}); 
261                                                         }
262                                                      }
263                                                   
264            7                                293      return;
265                                                   }
266                                                   
267                                                   # Returns shortcut to session data store and id for the given event.
268                                                   # The returned session will be undef if no more sessions are allowed.
269                                                   sub _get_session_ds {
270         4026                 4026         13713      my ( $self, $event ) = @_;
271                                                   
272         4026                              13701      my $attrib = $self->{attribute};
273         4026    100                       17350      if ( !exists $event->{ $attrib } ) {
274            6                                 13         if ( MKDEBUG ) {
275            1                    1             7            use Data::Dumper;
               1                                  2   
               1                                 11   
276                                                            _d('No attribute', $attrib, 'in event:', Dumper($event));
277                                                         }
278            6                                 20         return;
279                                                      }
280                                                   
281                                                      # This could indicate a problem in LogParser not parsing
282                                                      # a log event correctly thereby leaving $event->{arg} undefined.
283                                                      # Or, it could simply be an event like:
284                                                      # USE db;
285                                                      # SET NAMES utf8;
286   ***   4020     50                       16979      return if !defined $event->{arg};
287                                                   
288                                                      # Don't print admin commands like quit or ping because these
289                                                      # cannot be played.
290   ***   4020     50                       16450      return if $event->{cmd} eq 'Admin';
291                                                   
292         4020                               9102      my $session;
293         4020                              13003      my $session_id = $event->{ $attrib };
294                                                   
295                                                      # The following is necessary to prevent Perl from auto-vivifying
296                                                      # a lot of empty hashes for new sessions that are ignored due to
297                                                      # already having maxsessions.
298         4020    100                       21980      if ( $self->{n_sessions} < $self->{maxsessions} ) {
      ***            50                               
299                                                         # Will auto-vivify if necessary.
300         2029           100                23863         $session = $self->{sessions}->{ $session_id } ||= {};
301                                                      }
302                                                      elsif ( exists $self->{sessions}->{ $session_id } ) {
303                                                         # Use only existing sessions.
304   ***      0                                  0         $session = $self->{sessions}->{ $session_id };
305                                                      }
306                                                      else {
307         1991                               4588         MKDEBUG && _d('Skipping new session', $session_id,
308                                                            'because maxsessions is reached');
309                                                      }
310                                                   
311         4020                              21136      return ($session, $session_id);
312                                                   }
313                                                   
314                                                   sub _close_lru_session {
315           11                   11            53      my ( $self ) = @_;
316           11                                 43      my $session_fhs = $self->{session_fhs};
317           11                                 69      my $lru_n       = $self->{n_sessions} - MAX_OPEN_FILES - 1;
318           11                                 65      my $close_to_n  = $lru_n + CLOSE_N_LRU_FILES - 1;
319                                                   
320           11                                 24      MKDEBUG && _d('Closing session fhs', $lru_n, '..', $close_to_n,
321                                                         '(',$self->{n_sessions}, 'sessions', $self->{n_open_fhs}, 'open fhs)');
322                                                   
323           11                                223      foreach my $session ( @$session_fhs[ $lru_n..$close_to_n ] ) {
324         1100                              10632         close $session->{fh};
325         1100                               3209         $self->{n_open_fhs}--;
326         1100                               6785         $self->{sessions}->{ $session->{session_id} }->{active} = 0;
327                                                      }
328                                                   
329           11                                 69      return;
330                                                   }
331                                                   
332                                                   # Returns an empty string on failure, or the next session file name on success.
333                                                   # This will fail if we have opened maxdirs and maxfiles.
334                                                   sub _next_session_file {
335         2017                 2017          7799      my ( $self, $n ) = @_;
336   ***   2017     50                        9846      return '' if $self->{n_dirs} >= $self->{maxdirs};
337                                                   
338                                                      # n_files will only be < 0 for the first dir and file
339                                                      # because n_file is set to -1 in new(). This is a hack
340                                                      # to cause the first dir and file to be created automatically.
341         2017    100    100                19137      if ( $self->{n_files} >= $self->{maxfiles} || $self->{n_files} < 0) {
342           25                                 83         $self->{n_dirs}++;
343           25                                 91         $self->{n_files} = 0;
344           25                                165         my $new_dir = "$self->{saveto_dir}$self->{n_dirs}";
345           25    100                         483         if ( !-d $new_dir ) {
346           24                             133103            my $retval = system("mkdir $new_dir");
347   ***     24     50                         362            if ( ($retval >> 8) != 0 ) {
348   ***      0                                  0               die "Cannot create new directory $new_dir: $OS_ERROR";
349                                                            }
350           24                                167            MKDEBUG && _d('Created new saveto_dir', $new_dir);
351                                                         }
352                                                         elsif ( MKDEBUG ) {
353                                                            _d('saveto_dir', $new_dir, 'already exists');
354                                                         }
355                                                      }
356                                                   
357         2017                               6130      $self->{n_files}++;
358         2017                               7496      my $dir_n        = $self->{n_dirs} . '/';
359   ***   2017            66                17547      my $session_n    = sprintf '%04d', $n || $self->{n_sessions};
360         2017                              10070      my $session_file = $self->{saveto_dir}
361                                                                       . $dir_n
362                                                                       . $self->{session_file_name} . $session_n;
363         2017                               4261      MKDEBUG && _d('Next session file', $session_file);
364         2017                               8266      return $session_file;
365                                                   }
366                                                   
367                                                   # Flattens multiple new-line and spaces to single new-lines and spaces.
368                                                   sub flatten {
369         2029                 2029          7683      my ( $query ) = @_;
370   ***   2029     50                        7846      return unless $query;
371         2029                               9280      $query =~ s/\s{2,}/ /g;
372         2029                               8077      return $query;
373                                                   }
374                                                   
375                                                   sub _d {
376   ***      0                    0                    my ($package, undef, $line) = caller 0;
377   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
378   ***      0                                              map { defined $_ ? $_ : 'undef' }
379                                                           @_;
380   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
381                                                   }
382                                                   
383                                                   1;
384                                                   
385                                                   # ###########################################################################
386                                                   # End LogSplitter package
387                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
34    ***     50      0     18   unless $args{$arg}
38    ***     50      0      6   if substr($args{'saveto_dir'}, -1, 1) ne '/'
74    ***     50      0      7   if (not defined $logs or scalar @$logs == 0)
82           100      2      5   if ($$self{'maxsessionfiles'}) { }
87    ***     50      0      9   unless defined $session
88           100      4      5   if not $$session{'already_seen'}++
90           100      7      2   if ($db and !defined($$session{'db'}) || $$session{'db'} ne $db)
104          100   1997   2020   unless defined $session
106          100   2014      6   if (not defined $$session{'fh'}) { }
             100      1      5   elsif (not $$session{'active'}) { }
112   ***     50      0   2014   if (not $session_file)
120          100     11   2003   if $$self{'n_open_fhs'} >= 1000
123   ***     50      0   2014   unless open my $fh, '>', $session_file
144   ***     50      0      1   if $$self{'n_open_fhs'} >= 1000
147   ***     50      0      1   unless open $$session{'fh'}, '>>', $$session{'session_file'}
166          100   2017      3   if ($db and !defined($$session{'db'}) || $$session{'db'} ne $db)
181   ***     50      0      7   unless defined $log
182   ***     50      0      7   if (not -f $log and $log ne '-')
187   ***     50      0      7   if ($log eq '-') { }
191   ***     50      0      7   unless open $fh, '<', $log
193   ***     50      7      0   if ($fh)
196   ***     50      0      7   if not $oktorun
201          100      2      5   if ($$self{'maxsessionfiles'})
205   ***     50      0      3   if not $session_file
206   ***     50      0      3   unless open my $fh, '>', $session_file
228   ***     50      4      0   if (++$i >= $sessions_per_file)
230          100      1      3   if $file_n < $$self{'n_session_files'} - 1
243          100      1      6   if ($$self{'verbose'})
250   ***     50      1      0   if $$self{'maxsessionfiles'}
273          100      6   4020   if (not exists $$event{$attrib})
286   ***     50      0   4020   if not defined $$event{'arg'}
290   ***     50      0   4020   if $$event{'cmd'} eq 'Admin'
298          100   2029   1991   if ($$self{'n_sessions'} < $$self{'maxsessions'}) { }
      ***     50      0   1991   elsif (exists $$self{'sessions'}{$session_id}) { }
336   ***     50      0   2017   if $$self{'n_dirs'} >= $$self{'maxdirs'}
341          100     25   1992   if ($$self{'n_files'} >= $$self{'maxfiles'} or $$self{'n_files'} < 0)
345          100     24      1   !-d($new_dir) ? :
347   ***     50      0     24   if ($retval >> 8 != 0)
370   ***     50      0   2029   unless $query
377   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
90    ***     66      0      2      7   $db and !defined($$session{'db'}) || $$session{'db'} ne $db
166   ***     66      0      3   2017   $db and !defined($$session{'db'}) || $$session{'db'} ne $db
182   ***     33      7      0      0   not -f $log and $log ne '-'
194   ***     66      0      7   4026   $oktorun and $$self{'lp'}->parse_event($fh, undef, @callbacks)

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
54    ***     50      0      6   $$self{'maxfiles'} ||= 100
55    ***     50      0      6   $$self{'maxdirs'} ||= 100
56    ***     50      0      6   $$self{'maxsessions'} ||= 100000
57           100      2      4   $$self{'maxsessionfiles'} ||= 0
58           100      1      5   $$self{'verbose'} ||= 0
59    ***     50      0      6   $$self{'session_file_name'} ||= 'mysql_log_session_'
300          100     11   2018   $$self{'sessions'}{$session_id} ||= {}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
74    ***     33      0      0      7   not defined $logs or scalar @$logs == 0
89    ***     66      3      6      0   $$event{'db'} || $$event{'Schema'}
90           100      4      3      2   !defined($$session{'db'}) || $$session{'db'} ne $db
165   ***     66      3   2017      0   $$event{'db'} || $$event{'Schema'}
166          100   2014      3      3   !defined($$session{'db'}) || $$session{'db'} ne $db
341          100     19      6   1992   $$self{'n_files'} >= $$self{'maxfiles'} or $$self{'n_files'} < 0
359   ***     66      3   2014      0   $n || $$self{'n_sessions'}


Covered Subroutines
-------------------

Subroutine         Count Location                                          
------------------ ----- --------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/LogSplitter.pm:23 
BEGIN                  1 /home/daniel/dev/maatkit/common/LogSplitter.pm:24 
BEGIN                  1 /home/daniel/dev/maatkit/common/LogSplitter.pm:25 
BEGIN                  1 /home/daniel/dev/maatkit/common/LogSplitter.pm:27 
BEGIN                  1 /home/daniel/dev/maatkit/common/LogSplitter.pm:275
BEGIN                  1 /home/daniel/dev/maatkit/common/LogSplitter.pm:28 
BEGIN                  1 /home/daniel/dev/maatkit/common/LogSplitter.pm:29 
__ANON__            4017 /home/daniel/dev/maatkit/common/LogSplitter.pm:101
__ANON__               9 /home/daniel/dev/maatkit/common/LogSplitter.pm:84 
_close_lru_session    11 /home/daniel/dev/maatkit/common/LogSplitter.pm:315
_get_session_ds     4026 /home/daniel/dev/maatkit/common/LogSplitter.pm:270
_next_session_file  2017 /home/daniel/dev/maatkit/common/LogSplitter.pm:335
flatten             2029 /home/daniel/dev/maatkit/common/LogSplitter.pm:369
new                    6 /home/daniel/dev/maatkit/common/LogSplitter.pm:32 
split_logs             7 /home/daniel/dev/maatkit/common/LogSplitter.pm:65 

Uncovered Subroutines
---------------------

Subroutine         Count Location                                          
------------------ ----- --------------------------------------------------
_d                     0 /home/daniel/dev/maatkit/common/LogSplitter.pm:376


