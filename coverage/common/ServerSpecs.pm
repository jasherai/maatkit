---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/ServerSpecs.pm   80.4   51.8   62.5   94.1    n/a  100.0   71.1
Total                          80.4   51.8   62.5   94.1    n/a  100.0   71.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          ServerSpecs.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:49 2009
Finish:       Sat Aug 29 15:03:49 2009

/home/daniel/dev/maatkit/common/ServerSpecs.pm

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
17                                                    # ###########################################################################
18                                                    # ServerSpecs package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    
21                                                    # ServerSpecs - Gather info on server hardware and configuration
22                                                    package ServerSpecs;
23                                                    
24             1                    1             9   use strict;
               1                                  2   
               1                                  6   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
26                                                    
27             1                    1            10   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
28                                                    
29             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
30                                                    
31                                                    sub server_specs {
32             1                    1            13      my %server;
33                                                    
34             1                                  2      @{ $server{problems} } = ();
               1                                  6   
35                                                    
36             1                                  7      $server{os}->{name} = $OSNAME;
37                                                       # TODO: ought to go into some common library of utility funcs...
38    ***      1     50                        4032      $server{os}->{regsize} = `file /bin/ls` =~ m/64-bit/ ? '64' : '32';
39                                                    
40             1                                 23      $server{os}->{version} = _os_version();
41                                                    
42    ***      1     50                          19      if ( -f '/lib/libc.so.6' ) {
43             1                               2463         my $stuff = `/lib/libc.so.6`;
44             1                                 51         ($server{sw}->{libc}->{ver}) = $stuff =~ m/GNU C.*release version (.+), /;
45    ***      1      0                          16         $server{sw}->{libc}->{threading}
      ***            50                               
46                                                             = $stuff =~ m/Native POSIX/    ? 'NPTL'
47                                                             : $stuff =~ m/linuxthreads-\d/ ? 'Linuxthreads'
48                                                             :                                'Unknown';
49             1                                 15         ($server{sw}->{libc}->{compiled_by}) = $stuff =~ m/Compiled by (.*)/;
50             1                                  7         $server{sw}->{libc}->{GNU_LIBPTHREAD_VERSION} = do {
51             1                               1983            my $ver = `getconf GNU_LIBPTHREAD_VERSION`;
52             1                                 16            chomp $ver;
53             1                                 27            $ver;
54                                                          };
55                                                       }
56                                                    
57    ***      1     50                          48      if ( -f '/proc/cpuinfo' ) {
58             1                               2787         my $info = `cat /proc/cpuinfo`;
59             1                                 44         my $cores = scalar( map { $_ } $info =~ m/(^processor)/gm );
               2                                 15   
60             1                                 21         $server{cpu}->{cores} = $cores;
61             1                               9200         $server{cpu}->{count}
62                                                             = `grep 'physical id' /proc/cpuinfo | sort | uniq | wc -l`;
63             1                                 48         ($server{cpu}->{speed})
64                                                             = join(' ', 'MHz:', $info =~ m/cpu MHz.*: (\d+)/g);
65             1                                 18         ($server{cpu}->{cache}) = $info =~ m/cache size.*: (.+)/;
66             1                                 14         ($server{cpu}->{model}) = $info =~ m/model name.*: (.+)/;
67    ***      1     50                          28         $server{cpu}->{regsize} = $info =~ m/flags.*\blm\b/ ? '64' : '32';
68                                                       }
69                                                       else {
70                                                          # MSWin32, maybe?
71    ***      0                                  0         $server{cpu}->{count} = $ENV{NUMBER_OF_PROCESSORS};
72                                                       }
73                                                    
74                                                       # This requires root access. If it can't run (non-root), there simply
75                                                       # won't be any memory slot info reported.
76             1                                 17      @{$server{memory}->{slots}} = _memory_slots();
               1                                 20   
77                                                    
78    ***      1     50                        2356      if ( chomp(my $mem = `free -b`) ) {
79             1                                 48         my @words = $mem =~ m/(\w+)/g;
80             1                                  7         my @keys;
81             1                                  7         while ( my $key = shift @words ) {
82             7    100                          29            last if $key eq 'Mem';
83             6                                 31            push @keys, $key;
84                                                          }
85             1                                  7         foreach my $key ( @keys ) {
86             6                                 32            $server{memory}->{$key} = shorten(shift @words);
87                                                          }
88                                                       }
89                                                    
90    ***      1     50                        5818      if ( chomp(my $df = `df -hT` ) ) {
91             8                                 54         $df = "\n\t" . join("\n\t",
92             1                                 28            grep { $_ !~ m/^(varrun|varlock|udev|devshm|lrm)/ }
93                                                             split(/\n/, $df));
94             1                                 23         $server{storage}->{df} = $df;
95                                                       }
96                                                    
97                                                       # LVM
98             1                               2023      chomp(my $vgs_cmd = `which vgs`);
99    ***      1     50                          28      if ( -f $vgs_cmd ) {
100            1                               6710         chomp(my $vgs_output = `$vgs_cmd`);
101            1                                 27         $vgs_output =~ s/^\s*/\t/g;
102            1                                 17         $server{storage}->{vgs} = $vgs_output;
103                                                      }
104                                                      else {
105   ***      0                                  0         $server{storage}->{vgs} = 'No LVM2';
106                                                      }
107                                                   
108            1                                 22      get_raid_info(\%server);
109                                                   
110            1                               2728      chomp($server{os}->{swappiness} = `cat /proc/sys/vm/swappiness`);
111   ***      1     50                          24      push @{ $server{problems} },
      ***      0                                  0   
112                                                         "*** Server swappiness != 60; is currently: $server{os}->{swappiness}"
113                                                         if $server{os}->{swappiness} != 60;
114                                                   
115            1                                 24      check_proc_sys_net_ipv4_values(\%server);
116                                                   
117            1                                 23      return \%server;
118                                                   }
119                                                   
120                                                   sub get_raid_info
121                                                   {
122            1                    1             6      my ( $server ) = @_;
123                                                   
124            1                                 15      $server->{storage}->{raid} = {};
125   ***      1     50                       13295      if ( chomp(my $dmesg = `dmesg | grep '^scsi[0-9]'`) ) {
126   ***      1     50                          35         if (my ($raid) = $dmesg =~ m/: (.*MegaRaid)/mi) {
127            1                                 16            $server->{storage}->{raid}{$raid} = _get_raid_info_megarc();
128                                                         }
129   ***      1     50                          19         if (my ($raid) = $dmesg =~ m/: (aacraid)/m) {
130            1                                 12            $server->{storage}->{raid}{$raid} = _get_raid_info_arcconf();
131                                                         }
132   ***      1     50                          23         if (my ($raid) = $dmesg =~ m/: (3ware [0-9]+ Storage Controller)/m) {
133            1                                  6            $server->{storage}->{raid}{$raid} = _get_raid_info_tw_cli();
134                                                         }
135                                                      }
136                                                   }
137                                                   
138                                                   sub _get_raid_info_megarc
139                                                   {
140            1                    1             4      my $result = '';
141                                                      # TODO: MegaCli may exist on a 64-bit machine, we should choose the correct
142                                                      # one based on 64-bitness of the OS.
143            1                              11559      my $megarc = `which megarc && megarc -AllAdpInfo -aALL`;
144   ***      1     50                          24      if ( $megarc ) {
145   ***      1     50                          35         if ( $megarc =~ /No MegaRAID Found/i ) {
146   ***      0      0                           0            if ( -f '/opt/MegaRAID/MegaCli/MegaCli' ) {
      ***             0                               
147   ***      0                                  0               $megarc  = `/opt/MegaRAID/MegaCli/MegaCli -AdpAllInfo -aALL`;
148   ***      0                                  0               $megarc .= `/opt/MegaRAID/MegaCli/MegaCli -AdpBbuCmd -GetBbuStatus -aALL`;
149                                                            }
150                                                            elsif ( -f '/opt/MegaRAID/MegaCli/MegaCli64' ) {
151   ***      0                                  0               $megarc  = `/opt/MegaRAID/MegaCli/MegaCli64 -AdpAllInfo -aALL`;
152   ***      0                                  0               $megarc .= `/opt/MegaRAID/MegaCli/MegaCli64 -AdpBbuCmd -GetBbuStatus -aALL`;
153                                                            }
154                                                            else {
155   ***      0                                  0               $megarc = '';
156                                                            }
157                                                         }
158                                                         else {
159            1                               5321            $megarc .= `megarc -AdpBbuCmd -GetBbuStatus -aALL`;
160                                                         }
161                                                      }
162                                                   
163   ***      1     50                          17      if ( $megarc ) {
164   ***      1     50                          44         $result .= ($megarc =~ /^(Product Name.*\n)/m ? $1 : '');
165   ***      1     50                          24         $result .= ($megarc =~ /^(BBU.*\n)/m ? $1 : '');
166   ***      1     50                          14         $result .= ($megarc =~ /^(Battery Warning.*\n)/m ? $1 : '');
167   ***      1     50                          15         $result .= ($megarc =~ /^(Alarm.*\n)/m ? $1 : '');
168   ***      1     50                          24         $result .= ($megarc =~ /(Device Present.*?\n)\s+Supported/ms ? $1 : '');
169   ***      1     50                          24         $result .= ($megarc =~ /(Battery state.*?\n)isSOHGood/ms ? $1 : '');
170            1                                 24         $result =~ s/^/   /mg;
171                                                      }
172                                                      else {
173   ***      0                                  0         $result .= "\n*** MegaRAID present but unable to check its status";
174                                                      }
175                                                   
176            1                                 27      return $result;
177                                                   }
178                                                   
179                                                   sub _get_raid_info_arcconf
180                                                   {
181            1                    1             3      my $result = '';
182            1                                  2      my $arcconf;
183   ***      1     50                          15      if (-x '/usr/StorMan/arcconf') {
184   ***      0                                  0         $arcconf = `/usr/StorMan/arcconf GETCONFIG 1`;
185                                                      }
186                                                      else {
187            1                              18162         $arcconf = `which arcconf && arcconf GETCONFIG 1`;
188                                                      }
189   ***      1     50                          18      if ( $arcconf ) {
190   ***      1     50                          64         $result .= ($arcconf =~ /^(\s*Controller Model.*\n)/m ? $1 : '');
191   ***      1     50                          21         $result .= ($arcconf =~ /^(\s*Controller Status.*\n)/m ? $1 : '');
192   ***      1     50                          26         $result .= ($arcconf =~ /^(\s*Installed memory.*\n)/m ? $1 : '');
193   ***      1     50                          20         $result .= ($arcconf =~ /^(\s*Temperature.*\n)/m ? $1 : '');
194   ***      1     50                          24         $result .= ($arcconf =~ /^(\s*Defunct disk drive count.*\n)/m ? $1 : '');
195   ***      1     50                          60         $result .= ($arcconf =~ /^(\s*Logical devices\/Failed \(error\)\/Degraded.*\n)/m ? $1 : '');
196   ***      1     50                          57         $result .= ($arcconf =~ /^(\s*Write-cache mode.*\n)/m ? $1 : '');
197   ***      1     50                          52         $result .= ($arcconf =~ /^(\s*Write-cache setting.*\n)/m ? $1 : '');
198   ***      1     50                          36         $result .= ($arcconf =~ /^(\s*Controller Battery Information.*?\n\n)/ms ? $1 : '');
199                                                      }
200                                                      else {
201   ***      0                                  0         $result .= "\n*** aacraid present but unable to check its status";
202                                                      }
203                                                   
204            1                                 26      return $result;
205                                                   }
206                                                   
207                                                   sub _get_raid_info_tw_cli
208                                                   {
209            1                    1             4      my $result = '';
210            1                               6086      my $tw_cli = `which tw_cli && tw_cli /c0 show all`;
211   ***      1     50                          24      if ( $tw_cli ) {
212   ***      1     50                          38         $result .= ($tw_cli =~ /^\/c0\s*(Model.*\n)/m ? $1 : '');
213   ***      1     50                          16         $result .= ($tw_cli =~ /^\/c0\s*(Memory Installed.*\n)/m ? $1 : '');
214   ***      1     50                          13         $result .= ($tw_cli =~ /\n(\n.*)/ms ? $1 : '');
215            1                                 19         $result =~ s/^/   /mg;
216                                                      }
217                                                      else {
218   ***      0                                  0         $result .= "\n*** 3ware Storage Controller present but unable to check its status";
219                                                      }
220                                                   
221            1                                 33      return $result;
222                                                   }
223                                                   
224                                                   sub check_proc_sys_net_ipv4_values
225                                                   {
226            1                    1             6      my ( $server, $sysctl_conf ) = @_;
227                                                   
228            1                                 63      my %ipv4_defaults = qw(
229                                                         ip_forward                        0
230                                                         ip_default_ttl                    64
231                                                         ip_no_pmtu_disc                   0
232                                                         min_pmtu                          562
233                                                         ipfrag_secret_interval            600
234                                                         ipfrag_max_dist                   64
235                                                         somaxconn                         128
236                                                         tcp_abc                           0
237                                                         tcp_abort_on_overflow             0
238                                                         tcp_adv_win_scale                 2
239                                                         tcp_allowed_congestion_control    reno
240                                                         tcp_app_win                       31
241                                                         tcp_fin_timeout                   60
242                                                         tcp_frto_response                 0
243                                                         tcp_keepalive_time                7200
244                                                         tcp_keepalive_probes              9 
245                                                         tcp_keepalive_intvl               75
246                                                         tcp_low_latency                   0
247                                                         tcp_max_syn_backlog               1024
248                                                         tcp_moderate_rcvbuf               1
249                                                         tcp_reordering                    3
250                                                         tcp_retries1                      3
251                                                         tcp_retries2                      15
252                                                         tcp_rfc1337                       0
253                                                         tcp_rmem                          8192_87380_174760
254                                                         tcp_slow_start_after_idle         1
255                                                         tcp_stdurg                        0
256                                                         tcp_synack_retries                5
257                                                         tcp_syncookies                    0
258                                                         tcp_syn_retries                   5
259                                                         tcp_tso_win_divisor               3
260                                                         tcp_tw_recycle                    0
261                                                         tcp_tw_reuse                      0
262                                                         tcp_wmem                          4096_16384_131072
263                                                         tcp_workaround_signed_windows     0
264                                                         tcp_dma_copybreak                 4096
265                                                         ip_nonlocal_bind                  0
266                                                         ip_dynaddr                        0
267                                                         icmp_echo_ignore_all              0
268                                                         icmp_echo_ignore_broadcasts       1
269                                                         icmp_ratelimit                    100
270                                                         icmp_ratemask                     6168
271                                                         icmp_errors_use_inbound_ifaddr    0
272                                                         igmp_max_memberships              20
273                                                         icmp_ignore_bogus_error_responses 0
274                                                      );
275                                                   
276   ***      1            50                    6      $sysctl_conf ||= '/etc/sysctl.conf';
277            1                                 11      load_ipv4_defaults(\%ipv4_defaults, $sysctl_conf);
278                                                   
279            1                                  7      $server->{os}->{non_default_ipv4_vals} = '';
280   ***      1     50                        3510      if ( chomp(my $ipv4_files = `ls -1p /proc/sys/net/ipv4/`) ) {
281            1                                 41         foreach my $ipv4_file ( split "\n", $ipv4_files ) {
282           81    100                         414            next if !exists $ipv4_defaults{$ipv4_file};
283           43                             171733            chomp(my $val = `cat /proc/sys/net/ipv4/$ipv4_file`);
284           43                                755            $val =~ s/\s+/_/g;
285           43    100                         539            if ( $ipv4_defaults{$ipv4_file} ne $val ) {
286            6                                 36               push @{ $server->{problems} },
               6                                127   
287                                                                  "Not default value /proc/sys/net/ipv4/$ipv4_file\:\n" .
288                                                                  "\t\tset=$val\n\t\tdefault=$ipv4_defaults{$ipv4_file}";
289                                                            }
290                                                         }
291                                                      }
292                                                   
293            1                                 68      return;
294                                                   }
295                                                   
296                                                   # Load default values for /proc/sys/net/ipv4/ settings from sysctl.conf file
297                                                   sub load_ipv4_defaults {
298            1                    1             5      my ( $ipv4_defaults, $sysctl_conf ) = @_;
299                                                    
300            1                                  8      my %conf_ipv4_defaults = parse_sysctl_conf($sysctl_conf);
301                                                   
302                                                      # Yes we could do this with hash slices, but I want to see which
303                                                      # sysctl vars are overriden from the conf file
304            1                                 24      foreach my $var ( keys %conf_ipv4_defaults ) {
305   ***      0                                  0         if ( MKDEBUG && exists $ipv4_defaults->{$var} ) {
306                                                            _d('sysctl override', $var, ': conf=', $conf_ipv4_defaults{$var},
307                                                               'overrides default', $ipv4_defaults->{$var});
308                                                         }
309   ***      0                                  0         $ipv4_defaults->{$var} = $conf_ipv4_defaults{$var};
310                                                      }
311                                                   
312            1                                  4      return;
313                                                   }
314                                                   
315                                                   sub parse_sysctl_conf {
316            2                    2            19      my ( $sysctl_conf ) = @_;
317            2                                  6      my %sysctl;
318                                                   
319   ***      2     50                          33      if ( !-f $sysctl_conf ) {
320   ***      0                                  0         MKDEBUG && _d('sysctl file', $sysctl_conf, 'does not exist');
321   ***      0                                  0         return;
322                                                      }
323                                                   
324   ***      2     50                         139      if ( open my $SYSCTL, '<', $sysctl_conf ) {
325            2                                  7         MKDEBUG && _d('Parsing', $sysctl_conf);
326            2                                 41         while ( my $line = <$SYSCTL> ) {
327          104    100                         546            next if $line  =~ /^#/; # skip comments
328           31    100                         188            next unless $line =~ /\s*net.ipv4.(\w+)\s*=\s*(\w+)/;
329            4                                 30            my ( $var, $val ) = ( $1, $2 );
330            4                                  8            MKDEBUG && _d('sysctl:', $var, '=', $val);
331   ***      4     50    100                   78            if ( exists $sysctl{$var} && MKDEBUG ) {
332   ***      0                                  0               _d('Duplicate sysctl var:', $var,
333                                                                  '; was', $sysctl{$var}, ', is now', $val);
334                                                            }
335            4                                 82            $sysctl{$var} = $val;
336                                                         }
337                                                      }
338                                                      else {
339   ***      0                                  0         warn "Cannot read $sysctl_conf: $OS_ERROR";
340                                                      }
341                                                   
342            2                                 14      return %sysctl;
343                                                   }
344                                                   
345                                                   sub _can_run {
346            4                    4            49      my ( $cmd ) = @_;
347                                                      # Throw away all output; we're only interested in the return value.
348            4                              22822      my $retval = system("$cmd 2>/dev/null > /dev/null");
349            4                                 40      $retval = $retval >> 8;
350            4                                 12      MKDEBUG && _d('Running', $cmd, 'returned', $retval);
351            4    100                         146      return !$retval ? 1 : 0;
352                                                   }
353                                                   
354                                                   sub _os_version {
355            1                    1             4      my $version = 'unknown version';
356                                                   
357   ***      1     50                           7      if ( _can_run('cat /etc/*release') ) {
      ***             0                               
358            1                               3816         chomp(my $rel = `cat /etc/*release`);
359   ***      1     50                          43         if ( my ($desc) = $rel =~ m/DISTRIB_DESCRIPTION="(.*)"/ ) {
360            1                                  8            $version = $desc;
361                                                         }
362                                                         else {
363   ***      0                                  0            $version = $rel;
364                                                         }
365                                                      }
366                                                      elsif ( -r '/etc/debian_version' ) {
367   ***      0                                  0         chomp(my $rel = `cat /etc/debian_version`);
368   ***      0                                  0         $version = "Debian (or Debian-based) $rel";
369                                                      }
370                                                      elsif ( MKDEBUG ) {
371                                                         _d('No OS version info because no /etc/*release exists');
372                                                      }
373                                                   
374            1                                 20      return $version;
375                                                   }
376                                                   
377                                                   sub _memory_slots {
378            2                    2            22      my @memory_slots = ();
379                                                   
380   ***      2     50                          16      if ( _can_run('dmidecode') ) {
381   ***      0                                  0         my $dmi = `dmidecode`;
382   ***      0                                  0         chomp $dmi;
383   ***      0                                  0         my @mem_info = $dmi =~ m/^(Memory Device\n.*?)\n\n/gsm;
384   ***      0                                  0         my @attribs  = ( 'Size', 'Form Factor', 'Type', 'Type Detail', 'Speed' );
385   ***      0                                  0         foreach my $mem ( @mem_info ) {
386   ***      0                                  0            my %fields = map { split /: / } $mem =~ m/^\s+(\S.*:.*)$/gm;
      ***      0                                  0   
387   ***      0                                  0            push(@memory_slots, join(' ', grep { $_ } @fields{@attribs}));
      ***      0                                  0   
388                                                         }
389                                                      }
390                                                      elsif ( MKDEBUG ) {
391                                                         _d('No memory slots info because dmidecode cannot be ran');
392                                                      }
393                                                   
394            2                                 35      return @memory_slots;
395                                                   }
396                                                   
397                                                   # TODO: remove this sub and use Transformers instead, somehow, maybe.
398                                                   sub shorten
399                                                   {
400            6                    6            26      my ( $number, $kb, $d ) = @_;
401            6                                 18      my $n = 0;
402            6                                 12      my $short;
403                                                   
404   ***      6            50                   22      $kb ||= 1;
405   ***      6            50                   22      $d  ||= 2;
406                                                   
407   ***      6     50                          20      if ( $kb ) {
408            6                                 29         while ( $number > 1_023 ) { $number /= 1_024; $n++; }
              12                                 35   
              12                                 48   
409                                                      }
410                                                      else {
411   ***      0                                  0         while ($number > 999) { $number /= 1000; $n++; }
      ***      0                                  0   
      ***      0                                  0   
412                                                      }
413            6                                 77      $short = sprintf "%.${d}f%s", $number, ('','k','M','G','T')[$n];
414            6    100                          51      return $1 if $short =~ /^(.+)\.(00)$/o; # 12.00 -> 12 but not 12.00k -> 12k
415            5                                 53      return $short;
416                                                   }
417                                                   
418                                                   sub _d {
419   ***      0                    0                    my ($package, undef, $line) = caller 0;
420   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
421   ***      0                                              map { defined $_ ? $_ : 'undef' }
422                                                           @_;
423   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
424                                                   }
425                                                   
426                                                   1;
427                                                   
428                                                   # ###########################################################################
429                                                   # End ServerSpecs package
430                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
38    ***     50      1      0   `file /bin/ls` =~ /64-bit/ ? :
42    ***     50      1      0   if (-f '/lib/libc.so.6')
45    ***      0      0      0   $stuff =~ /linuxthreads-\d/ ? :
      ***     50      1      0   $stuff =~ /Native POSIX/ ? :
57    ***     50      1      0   if (-f '/proc/cpuinfo') { }
67    ***     50      1      0   $info =~ /flags.*\blm\b/ ? :
78    ***     50      1      0   if (chomp(my $mem = `free -b`))
82           100      1      6   if $key eq 'Mem'
90    ***     50      1      0   if (chomp(my $df = `df -hT`))
99    ***     50      1      0   if (-f $vgs_cmd) { }
111   ***     50      0      1   if $server{'os'}{'swappiness'} != 60
125   ***     50      1      0   if (chomp(my $dmesg = `dmesg | grep '^scsi[0-9]'`))
126   ***     50      1      0   if (my($raid) = $dmesg =~ /: (.*MegaRaid)/im)
129   ***     50      1      0   if (my($raid) = $dmesg =~ /: (aacraid)/m)
132   ***     50      1      0   if (my($raid) = $dmesg =~ /: (3ware [0-9]+ Storage Controller)/m)
144   ***     50      1      0   if ($megarc)
145   ***     50      0      1   if ($megarc =~ /No MegaRAID Found/i) { }
146   ***      0      0      0   if (-f '/opt/MegaRAID/MegaCli/MegaCli') { }
      ***      0      0      0   elsif (-f '/opt/MegaRAID/MegaCli/MegaCli64') { }
163   ***     50      1      0   if ($megarc) { }
164   ***     50      1      0   $megarc =~ /^(Product Name.*\n)/m ? :
165   ***     50      1      0   $megarc =~ /^(BBU.*\n)/m ? :
166   ***     50      1      0   $megarc =~ /^(Battery Warning.*\n)/m ? :
167   ***     50      1      0   $megarc =~ /^(Alarm.*\n)/m ? :
168   ***     50      1      0   $megarc =~ /(Device Present.*?\n)\s+Supported/ms ? :
169   ***     50      1      0   $megarc =~ /(Battery state.*?\n)isSOHGood/ms ? :
183   ***     50      0      1   if (-x '/usr/StorMan/arcconf') { }
189   ***     50      1      0   if ($arcconf) { }
190   ***     50      1      0   $arcconf =~ /^(\s*Controller Model.*\n)/m ? :
191   ***     50      1      0   $arcconf =~ /^(\s*Controller Status.*\n)/m ? :
192   ***     50      1      0   $arcconf =~ /^(\s*Installed memory.*\n)/m ? :
193   ***     50      1      0   $arcconf =~ /^(\s*Temperature.*\n)/m ? :
194   ***     50      1      0   $arcconf =~ /^(\s*Defunct disk drive count.*\n)/m ? :
195   ***     50      1      0   $arcconf =~ m[^(\s*Logical devices/Failed \(error\)/Degraded.*\n)]m ? :
196   ***     50      1      0   $arcconf =~ /^(\s*Write-cache mode.*\n)/m ? :
197   ***     50      1      0   $arcconf =~ /^(\s*Write-cache setting.*\n)/m ? :
198   ***     50      1      0   $arcconf =~ /^(\s*Controller Battery Information.*?\n\n)/ms ? :
211   ***     50      1      0   if ($tw_cli) { }
212   ***     50      1      0   $tw_cli =~ m[^/c0\s*(Model.*\n)]m ? :
213   ***     50      1      0   $tw_cli =~ m[^/c0\s*(Memory Installed.*\n)]m ? :
214   ***     50      1      0   $tw_cli =~ /\n(\n.*)/ms ? :
280   ***     50      1      0   if (chomp(my $ipv4_files = `ls -1p /proc/sys/net/ipv4/`))
282          100     38     43   if not exists $ipv4_defaults{$ipv4_file}
285          100      6     37   if ($ipv4_defaults{$ipv4_file} ne $val)
319   ***     50      0      2   if (not -f $sysctl_conf)
324   ***     50      2      0   if (open my $SYSCTL, '<', $sysctl_conf) { }
327          100     73     31   if $line =~ /^#/
328          100     27      4   unless $line =~ /\s*net.ipv4.(\w+)\s*=\s*(\w+)/
331   ***     50      0      4   if (exists $sysctl{$var} and undef)
351          100      1      3   !$retval ? :
357   ***     50      1      0   if (_can_run('cat /etc/*release')) { }
      ***      0      0      0   elsif (-r '/etc/debian_version') { }
359   ***     50      1      0   if (my($desc) = $rel =~ /DISTRIB_DESCRIPTION="(.*)"/) { }
380   ***     50      0      2   _can_run('dmidecode') ? :
407   ***     50      6      0   if ($kb) { }
414          100      1      5   if $short =~ /^(.+)\.(00)$/o
420   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
331          100      3      1   exists $sysctl{$var} and undef

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
276   ***     50      0      1   $sysctl_conf ||= '/etc/sysctl.conf'
404   ***     50      0      6   $kb ||= 1
405   ***     50      0      6   $d ||= 2


Covered Subroutines
-------------------

Subroutine                     Count Location                                          
------------------------------ ----- --------------------------------------------------
BEGIN                              1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:24 
BEGIN                              1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:25 
BEGIN                              1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:27 
BEGIN                              1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:29 
_can_run                           4 /home/daniel/dev/maatkit/common/ServerSpecs.pm:346
_get_raid_info_arcconf             1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:181
_get_raid_info_megarc              1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:140
_get_raid_info_tw_cli              1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:209
_memory_slots                      2 /home/daniel/dev/maatkit/common/ServerSpecs.pm:378
_os_version                        1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:355
check_proc_sys_net_ipv4_values     1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:226
get_raid_info                      1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:122
load_ipv4_defaults                 1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:298
parse_sysctl_conf                  2 /home/daniel/dev/maatkit/common/ServerSpecs.pm:316
server_specs                       1 /home/daniel/dev/maatkit/common/ServerSpecs.pm:32 
shorten                            6 /home/daniel/dev/maatkit/common/ServerSpecs.pm:400

Uncovered Subroutines
---------------------

Subroutine                     Count Location                                          
------------------------------ ----- --------------------------------------------------
_d                                 0 /home/daniel/dev/maatkit/common/ServerSpecs.pm:419


