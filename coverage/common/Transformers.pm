---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/Transformers.pm   92.7   88.1   81.8   94.1    0.0   71.2   86.2
Transformers.t                100.0   50.0   33.3  100.0    n/a   28.8   96.2
Total                          95.9   86.4   77.8   96.3    0.0  100.0   89.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:42 2010
Finish:       Thu Jun 24 19:38:42 2010

Run:          Transformers.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:44 2010
Finish:       Thu Jun 24 19:38:44 2010

/home/daniel/dev/maatkit/common/Transformers.pm

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
18                                                    # Transformers package $Revision: 6387 $
19                                                    # ###########################################################################
20                                                    
21                                                    # Transformers - Common transformation and beautification subroutines
22                                                    package Transformers;
23                                                    
24             1                    1             5   use strict;
               1                                  2   
               1                                  7   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
26             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
27             1                    1            10   use Time::Local qw(timegm timelocal);
               1                                  3   
               1                                 16   
28             1                    1             9   use Digest::MD5 qw(md5_hex);
               1                                  3   
               1                                  7   
29                                                    
30    ***      1            50      1             8   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 14   
31                                                    
32                                                    require Exporter;
33                                                    our @ISA         = qw(Exporter);
34                                                    our %EXPORT_TAGS = ();
35                                                    our @EXPORT      = ();
36                                                    our @EXPORT_OK   = qw(
37                                                       micro_t
38                                                       percentage_of
39                                                       secs_to_time
40                                                       time_to_secs
41                                                       shorten
42                                                       ts
43                                                       parse_timestamp
44                                                       unix_timestamp
45                                                       any_unix_timestamp
46                                                       make_checksum
47                                                    );
48                                                    
49                                                    our $mysql_ts  = qr/(\d\d)(\d\d)(\d\d) +(\d+):(\d+):(\d+)(\.\d+)?/;
50                                                    our $proper_ts = qr/(\d\d\d\d)-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)(\.\d+)?/;
51                                                    our $n_ts      = qr/(\d{1,5})([shmd]?)/; # Limit \d{1,5} because \d{6} looks
52                                                                                             # like a MySQL YYMMDD without hh:mm:ss.
53                                                    
54                                                    sub micro_t {
55    ***     10                   10      0     49      my ( $t, %args ) = @_;
56            10    100                          46      my $p_ms = defined $args{p_ms} ? $args{p_ms} : 0;  # precision for ms vals
57            10    100                          39      my $p_s  = defined $args{p_s}  ? $args{p_s}  : 0;  # precision for s vals
58            10                                 24      my $f;
59                                                    
60            10    100                          52      $t = 0 if $t < 0;
61                                                    
62                                                       # "Remove" scientific notation so the regex below does not make
63                                                       # 6.123456e+18 into 6.123456.
64    ***     10     50                          43      $t = sprintf('%.17f', $t) if $t =~ /e/;
65                                                    
66                                                       # Truncate after 6 decimal places to avoid 0.9999997 becoming 1
67                                                       # because sprintf() rounds.
68            10                                 98      $t =~ s/\.(\d{1,6})\d*/\.$1/;
69                                                    
70            10    100    100                  146      if ($t > 0 && $t <= 0.000999) {
                    100    100                        
                    100                               
71             1                                 14         $f = ($t * 1000000) . 'us';
72                                                       }
73                                                       elsif ($t >= 0.001000 && $t <= 0.999999) {
74             4                                 46         $f = sprintf("%.${p_ms}f", $t * 1000);
75             4                                 22         $f = ($f * 1) . 'ms'; # * 1 to remove insignificant zeros
76                                                       }
77                                                       elsif ($t >= 1) {
78             3                                 20         $f = sprintf("%.${p_s}f", $t);
79             3                                 16         $f = ($f * 1) . 's'; # * 1 to remove insignificant zeros
80                                                       }
81                                                       else {
82             2                                  7         $f = 0;  # $t should = 0 at this point
83                                                       }
84                                                    
85            10                                 63      return $f;
86                                                    }
87                                                    
88                                                    # Returns what percentage $is of $of.
89                                                    sub percentage_of {
90    ***      2                    2      0     10      my ( $is, $of, %args ) = @_;
91             2           100                   16      my $p   = $args{p} || 0; # float precision
92             2    100                          11      my $fmt = $p ? "%.${p}f" : "%d";
93    ***      2            50                   30      return sprintf $fmt, ($is * 100) / ($of ||= 1);
94                                                    }
95                                                    
96                                                    sub secs_to_time {
97    ***      4                    4      0     17      my ( $secs, $fmt ) = @_;
98             4           100                   14      $secs ||= 0;
99             4    100                          16      return '00:00' unless $secs;
100                                                   
101                                                      # Decide what format to use, if not given
102   ***      3    100     50                   33      $fmt ||= $secs >= 86_400 ? 'd'
                    100                               
103                                                             : $secs >= 3_600  ? 'h'
104                                                             :                   'm';
105                                                   
106                                                      return
107            3    100                          45         $fmt eq 'd' ? sprintf(
                    100                               
108                                                            "%d+%02d:%02d:%02d",
109                                                            int($secs / 86_400),
110                                                            int(($secs % 86_400) / 3_600),
111                                                            int(($secs % 3_600) / 60),
112                                                            $secs % 60)
113                                                         : $fmt eq 'h' ? sprintf(
114                                                            "%02d:%02d:%02d",
115                                                            int(($secs % 86_400) / 3_600),
116                                                            int(($secs % 3_600) / 60),
117                                                            $secs % 60)
118                                                         : sprintf(
119                                                            "%02d:%02d",
120                                                            int(($secs % 3_600) / 60),
121                                                            $secs % 60);
122                                                   }
123                                                   
124                                                   # Convert time values to number of seconds:
125                                                   # 1s = 1, 1m = 60, 1h = 3600, 1d = 86400.
126                                                   sub time_to_secs {
127   ***      5                    5      0     21      my ( $val, $default_suffix ) = @_;
128   ***      5     50                          19      die "I need a val argument" unless defined $val;
129            5                                 14      my $t = 0;
130            5                                 41      my ( $prefix, $num, $suffix ) = $val =~ m/([+-]?)(\d+)([a-z])?$/;
131   ***      5            66                   45      $suffix = $suffix || $default_suffix || 's';
                           100                        
132   ***      5     50                          23      if ( $suffix =~ m/[smhd]/ ) {
133            5    100                          32         $t = $suffix eq 's' ? $num * 1        # Seconds
                    100                               
                    100                               
134                                                            : $suffix eq 'm' ? $num * 60       # Minutes
135                                                            : $suffix eq 'h' ? $num * 3600     # Hours
136                                                            :                  $num * 86400;   # Days
137                                                   
138   ***      5    100     66                   32         $t *= -1 if $prefix && $prefix eq '-';
139                                                      }
140                                                      else {
141   ***      0                                  0         die "Invalid suffix for $val: $suffix";
142                                                      }
143            5                                 25      return $t;
144                                                   }
145                                                   
146                                                   sub shorten {
147   ***      6                    6      0     31      my ( $num, %args ) = @_;
148            6    100                          28      my $p = defined $args{p} ? $args{p} : 2;     # float precision
149            6    100                          25      my $d = defined $args{d} ? $args{d} : 1_024; # divisor
150            6                                 15      my $n = 0;
151            6                                 34      my @units = ('', qw(k M G T P E Z Y));
152            6           100                   62      while ( $num >= $d && $n < @units - 1 ) {
153           17                                 43         $num /= $d;
154           17                                121         ++$n;
155                                                      }
156            6    100    100                  136      return sprintf(
157                                                         $num =~ m/\./ || $n
158                                                            ? "%.${p}f%s"
159                                                            : '%d',
160                                                         $num, $units[$n]);
161                                                   }
162                                                   
163                                                   # Turns a unix timestamp into an ISO8601 formatted date and time.  $gmt makes
164                                                   # this relative to GMT, for test determinism.
165                                                   sub ts {
166   ***      2                    2      0      9      my ( $time, $gmt ) = @_;
167   ***      2     50                          16      my ( $sec, $min, $hour, $mday, $mon, $year )
168                                                         = $gmt ? gmtime($time) : localtime($time);
169            2                                  7      $mon  += 1;
170            2                                  5      $year += 1900;
171            2                                 13      my $val = sprintf("%d-%02d-%02dT%02d:%02d:%02d",
172                                                         $year, $mon, $mday, $hour, $min, $sec);
173            2    100                          39      if ( my ($us) = $time =~ m/(\.\d+)$/ ) {
174            1                                  9         $us = sprintf("%.6f", $us);
175            1                                  5         $us =~ s/^0\././;
176            1                                  3         $val .= $us;
177                                                      }
178            2                                 11      return $val;
179                                                   }
180                                                   
181                                                   # Turns MySQL's 071015 21:43:52 into a properly formatted timestamp.  Also
182                                                   # handles a timestamp with fractions after it.
183                                                   sub parse_timestamp {
184   ***      7                    7      0     29      my ( $val ) = @_;
185   ***      7     50                         152      if ( my($y, $m, $d, $h, $i, $s, $f)
186                                                            = $val =~ m/^$mysql_ts$/ )
187                                                      {
188            7    100                         124         return sprintf "%d-%02d-%02d %02d:%02d:"
                    100                               
189                                                                        . (defined $f ? '%09.6f' : '%02d'),
190                                                                        $y + 2000, $m, $d, $h, $i, (defined $f ? $s + $f : $s);
191                                                      }
192   ***      0                                  0      return $val;
193                                                   }
194                                                   
195                                                   # Turns a properly formatted timestamp like 2007-10-15 01:43:52
196                                                   # into an int (seconds since epoch).  Optional microseconds are printed.  $gmt
197                                                   # makes it use GMT time instead of local time (to make tests deterministic).
198                                                   sub unix_timestamp {
199   ***      9                    9      0     33      my ( $val, $gmt ) = @_;
200   ***      9     50                         143      if ( my($y, $m, $d, $h, $i, $s, $us) = $val =~ m/^$proper_ts$/ ) {
201            9    100                          63         $val = $gmt
202                                                            ? timegm($s, $i, $h, $d, $m - 1, $y)
203                                                            : timelocal($s, $i, $h, $d, $m - 1, $y);
204            9    100                        1420         if ( defined $us ) {
205            1                                 11            $us = sprintf('%.6f', $us);
206            1                                  5            $us =~ s/^0\././;
207            1                                  4            $val .= $us;
208                                                         }
209                                                      }
210            9                                 59      return $val;
211                                                   }
212                                                   
213                                                   # Turns several different types of timestamps into a unix timestamp.
214                                                   # Each type is auto-detected.  Supported types are:
215                                                   #   * N[shdm]                Now - N[shdm]
216                                                   #   * 071015 21:43:52        MySQL slow log timestamp
217                                                   #   * 2009-07-01 [3:43:01]   Proper timestamp with options HH:MM:SS
218                                                   #   * NOW()                  A MySQL time express
219                                                   # For the last type, the callback arg is required.  It is passed the
220                                                   # given value/expression and is expected to return a single value
221                                                   # (the result of the expression).
222                                                   sub any_unix_timestamp {
223   ***     11                   11      0     76      my ( $val, $callback ) = @_;
224                                                   
225           11    100                         202      if ( my ($n, $suffix) = $val =~ m/^$n_ts$/ ) {
                    100                               
                    100                               
                    100                               
226            3    100                          20         $n = $suffix eq 's' ? $n            # Seconds
      ***            50                               
      ***            50                               
                    100                               
227                                                            : $suffix eq 'm' ? $n * 60       # Minutes
228                                                            : $suffix eq 'h' ? $n * 3600     # Hours
229                                                            : $suffix eq 'd' ? $n * 86400    # Days
230                                                            :                  $n;           # default: Seconds
231            3                                  6         MKDEBUG && _d('ts is now - N[shmd]:', $n);
232            3                                 28         return time - $n;
233                                                      }
234                                                      elsif ( $val =~ m/^\d{9,}/ ) {
235                                                         # unix timestamp 100000000 is roughly March, 1973, so older
236                                                         # dates won't be caught here; they'll probably be mistaken
237                                                         # for a MySQL slow log timestamp.
238            1                                  2         MKDEBUG && _d('ts is already a unix timestamp');
239            1                                  6         return $val;
240                                                      }
241                                                      elsif ( my ($ymd, $hms) = $val =~ m/^(\d{6})(?:\s+(\d+:\d+:\d+))?/ ) {
242            2                                  4         MKDEBUG && _d('ts is MySQL slow log timestamp');
243            2    100                           8         $val .= ' 00:00:00' unless $hms;
244            2                                 11         return unix_timestamp(parse_timestamp($val));
245                                                      }
246                                                      elsif ( ($ymd, $hms) = $val =~ m/^(\d{4}-\d\d-\d\d)(?:[T ](\d+:\d+:\d+))?/) {
247            2                                  4         MKDEBUG && _d('ts is properly formatted timestamp');
248            2    100                           9         $val .= ' 00:00:00' unless $hms;
249            2                                  8         return unix_timestamp($val);
250                                                      }
251                                                      else {
252            3                                  9         MKDEBUG && _d('ts is MySQL expression');
253   ***      3    100     66                   26         return $callback->($val) if $callback && ref $callback eq 'CODE';
254                                                      }
255                                                   
256            2                                  5      MKDEBUG && _d('Unknown ts type:', $val);
257            2                                 11      return;
258                                                   }
259                                                   
260                                                   # Returns the rightmost 64 bits of an MD5 checksum of the value.
261                                                   sub make_checksum {
262   ***      1                    1      0      5      my ( $val ) = @_;
263            1                                 27      my $checksum = uc substr(md5_hex($val), -16);
264            1                                  3      MKDEBUG && _d($checksum, 'checksum for', $val);
265            1                                  5      return $checksum;
266                                                   }
267                                                   
268                                                   sub _d {
269   ***      0                    0                    my ($package, undef, $line) = caller 0;
270   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
271   ***      0                                              map { defined $_ ? $_ : 'undef' }
272                                                           @_;
273   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
274                                                   }
275                                                   
276                                                   1;
277                                                   
278                                                   # ###########################################################################
279                                                   # End Transformers package
280                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
56           100      2      8   defined $args{'p_ms'} ? :
57           100      1      9   defined $args{'p_s'} ? :
60           100      1      9   if $t < 0
64    ***     50      0     10   if $t =~ /e/
70           100      1      9   if ($t > 0 and $t <= 0.000999) { }
             100      4      5   elsif ($t >= 0.001 and $t <= 0.999999) { }
             100      3      2   elsif ($t >= 1) { }
92           100      1      1   $p ? :
99           100      1      3   unless $secs
102          100      1      1   $secs >= 3600 ? :
             100      1      2   $secs >= 86400 ? :
107          100      1      1   $fmt eq 'h' ? :
             100      1      2   $fmt eq 'd' ? :
128   ***     50      0      5   unless defined $val
132   ***     50      5      0   if ($suffix =~ /[smhd]/) { }
133          100      1      1   $suffix eq 'h' ? :
             100      1      2   $suffix eq 'm' ? :
             100      2      3   $suffix eq 's' ? :
138          100      1      4   if $prefix and $prefix eq '-'
148          100      3      3   defined $args{'p'} ? :
149          100      3      3   defined $args{'d'} ? :
156          100      5      1   $num =~ /\./ || $n ? :
167   ***     50      2      0   $gmt ? :
173          100      1      1   if (my($us) = $time =~ /(\.\d+)$/)
185   ***     50      7      0   if (my($y, $m, $d, $h, $i, $s, $f) = $val =~ /^$mysql_ts$/)
188          100      4      3   defined $f ? :
             100      4      3   defined $f ? :
200   ***     50      9      0   if (my($y, $m, $d, $h, $i, $s, $us) = $val =~ /^$proper_ts$/)
201          100      2      7   $gmt ? :
204          100      1      8   if (defined $us)
225          100      3      8   if (my($n, $suffix) = $val =~ /^$n_ts$/) { }
             100      1      7   elsif ($val =~ /^\d{9,}/) { }
             100      2      5   elsif (my($ymd, $hms) = $val =~ /^(\d{6})(?:\s+(\d+:\d+:\d+))?/) { }
             100      2      3   elsif (($ymd, $hms) = $val =~ /^(\d{4}-\d\d-\d\d)(?:[T ](\d+:\d+:\d+))?/) { }
226          100      1      1   $suffix eq 'd' ? :
      ***     50      0      2   $suffix eq 'h' ? :
      ***     50      0      2   $suffix eq 'm' ? :
             100      1      2   $suffix eq 's' ? :
243          100      1      1   unless $hms
248          100      1      1   unless $hms
253          100      1      2   if $callback and ref $callback eq 'CODE'
270   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
70           100      2      7      1   $t > 0 and $t <= 0.000999
             100      2      3      4   $t >= 0.001 and $t <= 0.999999
138   ***     66      4      0      1   $prefix and $prefix eq '-'
152          100      5      1     17   $num >= $d and $n < @units - 1
253   ***     66      2      0      1   $callback and ref $callback eq 'CODE'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0
91           100      1      1   $args{'p'} || 0
93    ***     50      2      0   $of ||= 1
98           100      3      1   $secs ||= 0
102   ***     50      0      3   $fmt ||= $secs >= 86400 ? 'd' : ($secs >= 3600 ? 'h' : 'm')
131          100      3      2   $suffix || $default_suffix || 's'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
131   ***     66      3      0      2   $suffix || $default_suffix
156          100      4      1      1   $num =~ /\./ || $n


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                           
------------------ ----- --- ---------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/Transformers.pm:24 
BEGIN                  1     /home/daniel/dev/maatkit/common/Transformers.pm:25 
BEGIN                  1     /home/daniel/dev/maatkit/common/Transformers.pm:26 
BEGIN                  1     /home/daniel/dev/maatkit/common/Transformers.pm:27 
BEGIN                  1     /home/daniel/dev/maatkit/common/Transformers.pm:28 
BEGIN                  1     /home/daniel/dev/maatkit/common/Transformers.pm:30 
any_unix_timestamp    11   0 /home/daniel/dev/maatkit/common/Transformers.pm:223
make_checksum          1   0 /home/daniel/dev/maatkit/common/Transformers.pm:262
micro_t               10   0 /home/daniel/dev/maatkit/common/Transformers.pm:55 
parse_timestamp        7   0 /home/daniel/dev/maatkit/common/Transformers.pm:184
percentage_of          2   0 /home/daniel/dev/maatkit/common/Transformers.pm:90 
secs_to_time           4   0 /home/daniel/dev/maatkit/common/Transformers.pm:97 
shorten                6   0 /home/daniel/dev/maatkit/common/Transformers.pm:147
time_to_secs           5   0 /home/daniel/dev/maatkit/common/Transformers.pm:127
ts                     2   0 /home/daniel/dev/maatkit/common/Transformers.pm:166
unix_timestamp         9   0 /home/daniel/dev/maatkit/common/Transformers.pm:199

Uncovered Subroutines
---------------------

Subroutine         Count Pod Location                                           
------------------ ----- --- ---------------------------------------------------
_d                     0     /home/daniel/dev/maatkit/common/Transformers.pm:269


Transformers.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     
8                                                        # The timestamps for unix_timestamp are East Coast (EST), so GMT-4.
9              1                                  8      $ENV{TZ}='EST5EDT';
10                                                    };
11                                                    
12             1                    1            12   use strict;
               1                                  2   
               1                                  5   
13             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
14             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
15             1                    1            10   use Test::More tests => 48;
               1                                  3   
               1                                 10   
16                                                    
17             1                    1            11   use Transformers;
               1                                  4   
               1                                 10   
18             1                    1            11   use MaatkitTest;
               1                                  6   
               1                                 37   
19                                                    
20             1                                 16   Transformers->import( qw(parse_timestamp micro_t shorten secs_to_time
21                                                       time_to_secs percentage_of unix_timestamp make_checksum any_unix_timestamp
22                                                       ts) );
23                                                    
24                                                    # #############################################################################
25                                                    # micro_t() tests.
26                                                    # #############################################################################
27             1                                320   is(micro_t('0.000001'),       "1us",        'Formats 1 microsecond');
28             1                                  7   is(micro_t('0.001000'),       '1ms',        'Formats 1 milliseconds');
29             1                                  6   is(micro_t('1.000000'),       '1s',         'Formats 1 second');
30             1                                  6   is(micro_t('0.123456789999'), '123ms',  'Truncates long value, does not round');
31             1                                  6   is(micro_t('1.123000000000'), '1s',     'Truncates, removes insignificant zeros');
32             1                                  5   is(micro_t('0.000000'), '0', 'Zero is zero');
33             1                                  6   is(micro_t('-1.123'), '0', 'Negative number becomes zero');
34             1                                  6   is(micro_t('0.9999998', p_ms => 3), '999.999ms', 'ms high edge is not rounded (999.999 ms)');
35             1                                  6   is(micro_t('.060123', p_ms=>1), '60.1ms', 'Can change float precision for ms in micro_t');
36             1                                  6   is(micro_t('123.060123', p_s=>1), '123.1s', 'Can change float precision for seconds in micro_t');
37                                                     
38                                                    # #############################################################################
39                                                    # shorten() tests.
40                                                    # #############################################################################
41             1                                  7   is(shorten('1024.00'), '1.00k', 'Shortens 1024.00 to 1.00k');
42             1                                  5   is(shorten('100'),     '100',   '100 does not shorten (stays 100)');
43             1                                  7   is(shorten('99999', p => 1, d => 1_000), '100.0k', 'Can change float precision and divisor in shorten');
44             1                                  6   is(shorten('6.992e+19', 'p', 1, 'd', 1000), '69.9E', 'really big number');
45             1                                  6   is(shorten('1000e+52'), '8271806125530276833376576995328.00Y', 'Number bigger than any units');
46             1                                  7   is(shorten('583029', p=>0, d=>1_000), '583k', 'Zero float precision');
47                                                    
48                                                    # #############################################################################
49                                                    # secs_to_time() tests.
50                                                    # #############################################################################
51             1                                  6   is(secs_to_time(0), '00:00', 'secs_to_time 0 s = 00:00');
52             1                                  7   is(secs_to_time(60), '01:00', 'secs_to_time 60 s = 1 minute');
53             1                                  5   is(secs_to_time(3600), '01:00:00', 'secs_to_time 3600 s = 1 hour');
54             1                                  5   is(secs_to_time(86400), '1+00:00:00', 'secd_to_time 86400 = 1 day');
55                                                    
56                                                    # #############################################################################
57                                                    # time_to_secs() tests.
58                                                    # #############################################################################
59             1                                  6   is(time_to_secs(0), 0, 'time_to_secs 0 = 0');
60             1                                  5   is(time_to_secs(-42), -42, 'time_to_secs -42 = -42');
61             1                                  7   is(time_to_secs('1m'), 60, 'time_to_secs 1m = 60');
62             1                                  5   is(time_to_secs('1h'), 3600, 'time_to_secs 1h = 3600');
63             1                                  5   is(time_to_secs('1d'), 86400, 'time_to_secs 1d = 86400');
64                                                    
65                                                    # #############################################################################
66                                                    # percentage_of() tests.
67                                                    # #############################################################################
68             1                                  6   is(percentage_of(25, 100, p=>2), '25.00', 'Percentage with precision');
69             1                                  6   is(percentage_of(25, 100), '25', 'Percentage as int');
70                                                    
71                                                    # #############################################################################
72                                                    # parse_timestamp() tests.
73                                                    # #############################################################################
74             1                                  7   is(parse_timestamp('071015  1:43:52'), '2007-10-15 01:43:52', 'timestamp');
75             1                                  8   is(parse_timestamp('071015  1:43:52.108'), '2007-10-15 01:43:52.108000',
76                                                       'timestamp with microseconds');
77                                                    
78             1                                  7   is(parse_timestamp('071015  1:43:00.123456'), '2007-10-15 01:43:00.123456',
79                                                       "timestamp with 0 second.micro");
80             1                                  7   is(parse_timestamp('071015  1:43:01.123456'), '2007-10-15 01:43:01.123456',
81                                                       "timestamp with 1 second.micro");
82             1                                  7   is(parse_timestamp('071015  1:43:09.123456'), '2007-10-15 01:43:09.123456',
83                                                       "timestamp with 9 second.micro");
84                                                    
85                                                    # #############################################################################
86                                                    # unix_timestamp() tests.
87                                                    # #############################################################################
88             1                                  8   is(unix_timestamp('2007-10-15 01:43:52', 1), 1192412632, 'unix_timestamp');
89             1                                  6   is(unix_timestamp('2009-05-14 12:51:10.080017', 1), '1242305470.080017', 'unix_timestamp with microseconds');
90                                                    
91                                                    # #############################################################################
92                                                    # ts() tests.
93                                                    # #############################################################################
94             1                                  5   is(ts(1192412632, 1), '2007-10-15T01:43:52', 'ts');
95             1                                  6   is(ts(1192412632.5, 1), '2007-10-15T01:43:52.500000', 'ts with microseconds');
96                                                    
97                                                    # #############################################################################
98                                                    # make_checksum() tests.
99                                                    # #############################################################################
100            1                                  6   is(make_checksum('hello world'), '93CB22BB8F5ACDC3', 'make_checksum');
101                                                   
102                                                   # #############################################################################
103                                                   # any_unix_timestamp() tests.
104                                                   # #############################################################################
105            1                                  7   is(
106                                                      any_unix_timestamp('5'),
107                                                      time - 5,
108                                                      'any_unix_timestamp simple N'
109                                                   );
110            1                                  7   is(
111                                                      any_unix_timestamp('7s'),
112                                                      time - 7,
113                                                      'any_unix_timestamp simple Ns'
114                                                   );
115            1                                  6   is(
116                                                      any_unix_timestamp('7d'),
117                                                      time - (7 * 86400),
118                                                      'any_unix_timestamp simple 7d'
119                                                   );
120            1                                  6   is(
121                                                      any_unix_timestamp('071015  1:43:52'),
122                                                      unix_timestamp('2007-10-15 01:43:52'),
123                                                      'any_unix_timestamp MySQL timestamp'
124                                                   );
125            1                                  8   is(
126                                                      any_unix_timestamp('071015'),
127                                                      unix_timestamp('2007-10-15 00:00:00'),
128                                                      'any_unix_timestamp MySQL timestamp without hh:mm:ss'
129                                                   );
130            1                                  7   is(
131                                                      any_unix_timestamp('2007-10-15 01:43:52'),
132                                                      1192427032,
133                                                      'any_unix_timestamp proper timestamp'
134                                                   );
135            1                                  6   is(
136                                                      any_unix_timestamp('2007-10-15'),     # Same as above minus
137                                                      1192427032 - (1*3600) - (43*60) - 52, # 1:43:52
138                                                      'any_unix_timestamp proper timestamp without hh:mm:ss'
139                                                   );
140            1                                  6   is(
141                                                      any_unix_timestamp('315550800'),
142                                                      unix_timestamp('1980-01-01 00:00:00'),
143                                                      'any_unix_timestamp already unix timestamp'
144                                                   );
145                                                   
146            1                    1            12   use DSNParser;
               1                                  3   
               1                                 11   
147            1                    1            15   use Sandbox;
               1                                  3   
               1                                  9   
148            1                                 10   my $dp = new DSNParser(opts=>$dsn_opts);
149            1                                228   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
150            1                                 57   my $dbh = $sb->get_dbh_for('master');
151   ***      1     50                           5   SKIP: {
152            1                                360      skip 'Cannot connect to sandbox master', 1 unless $dbh;
153            1                                  2      my $now = $dbh->selectall_arrayref('SELECT NOW()')->[0]->[0];
154                                                      my $callback = sub {
155            1                    1             4         my ( $sql ) = @_;
156            1                                  2         return $dbh->selectall_arrayref($sql)->[0]->[0];
157            1                                138      };
158            1                                  7      is(
159                                                         any_unix_timestamp('SELECT 42', $callback),
160                                                         '42',
161                                                         'any_unix_timestamp MySQL expression'
162                                                      );
163                                                   
164            1                                 77      $dbh->disconnect();
165                                                   };
166                                                   
167            1                                  8   is(
168                                                      any_unix_timestamp('SELECT 42'),
169                                                      undef,
170                                                      'any_unix_timestamp MySQL expression but no callback given'
171                                                   );
172                                                   
173            1                                  5   is(
174                                                      any_unix_timestamp("SELECT '2009-07-27 11:30:00'"),
175                                                      undef,
176                                                      'any_unix_timestamp MySQL expression that looks like another type'
177                                                   );
178                                                   
179                                                   
180                                                   # #############################################################################
181                                                   # Done.
182                                                   # #############################################################################
183            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
151   ***     50      0      1   unless $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location          
---------- ----- ------------------
BEGIN          1 Transformers.t:12 
BEGIN          1 Transformers.t:13 
BEGIN          1 Transformers.t:14 
BEGIN          1 Transformers.t:146
BEGIN          1 Transformers.t:147
BEGIN          1 Transformers.t:15 
BEGIN          1 Transformers.t:17 
BEGIN          1 Transformers.t:18 
BEGIN          1 Transformers.t:4  
__ANON__       1 Transformers.t:155


