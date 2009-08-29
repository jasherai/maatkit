---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/Transformers.pm   85.4   88.7   87.0   87.5    n/a  100.0   86.8
Total                          85.4   88.7   87.0   87.5    n/a  100.0   86.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Transformers.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:04:31 2009
Finish:       Sat Aug 29 15:04:31 2009

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
18                                                    # Transformers package $Revision: 4299 $
19                                                    # ###########################################################################
20                                                    
21                                                    # Transformers - Common transformation and beautification subroutines
22                                                    package Transformers;
23                                                    
24             1                    1             4   use strict;
               1                                  3   
               1                                  5   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
26             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 17   
27             1                    1            10   use Time::Local qw(timelocal);
               1                                  3   
               1                                 18   
28             1                    1             7   use Digest::MD5 qw(md5_hex);
               1                                  2   
               1                                 94   
29                                                    
30             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  6   
31                                                    
32                                                    require Exporter;
33                                                    our @ISA         = qw(Exporter);
34                                                    our %EXPORT_TAGS = ();
35                                                    our @EXPORT      = ();
36                                                    our @EXPORT_OK   = qw(
37                                                       micro_t
38                                                       percentage_of
39                                                       secs_to_time
40                                                       shorten
41                                                       ts
42                                                       parse_timestamp
43                                                       unix_timestamp
44                                                       any_unix_timestamp
45                                                       make_checksum
46                                                    );
47                                                    
48                                                    our $mysql_ts  = qr/(\d\d)(\d\d)(\d\d) +(\d+):(\d+):(\d+)(\.\d+)?/;
49                                                    our $proper_ts = qr/(\d\d\d\d)-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)(?:\.\d+)?/;
50                                                    our $n_ts      = qr/(\d{1,5})([shmd]?)/; # Limit \d{1,5} because \d{6} looks
51                                                                                             # like a MySQL YYMMDD without hh:mm:ss.
52                                                    
53                                                    sub micro_t {
54            10                   10            58      my ( $t, %args ) = @_;
55            10    100                          45      my $p_ms = defined $args{p_ms} ? $args{p_ms} : 0;  # precision for ms vals
56            10    100                          37      my $p_s  = defined $args{p_s}  ? $args{p_s}  : 0;  # precision for s vals
57            10                                 25      my $f;
58                                                    
59            10    100                          58      $t = 0 if $t < 0;
60                                                    
61                                                       # "Remove" scientific notation so the regex below does not make
62                                                       # 6.123456e+18 into 6.123456.
63    ***     10     50                          41      $t = sprintf('%.17f', $t) if $t =~ /e/;
64                                                    
65                                                       # Truncate after 6 decimal places to avoid 0.9999997 becoming 1
66                                                       # because sprintf() rounds.
67            10                                101      $t =~ s/\.(\d{1,6})\d*/\.$1/;
68                                                    
69            10    100    100                  140      if ($t > 0 && $t <= 0.000999) {
                    100    100                        
                    100                               
70             1                                 14         $f = ($t * 1000000) . 'us';
71                                                       }
72                                                       elsif ($t >= 0.001000 && $t <= 0.999999) {
73             4                                 54         $f = sprintf("%.${p_ms}f", $t * 1000);
74             4                                 23         $f = ($f * 1) . 'ms'; # * 1 to remove insignificant zeros
75                                                       }
76                                                       elsif ($t >= 1) {
77             3                                 20         $f = sprintf("%.${p_s}f", $t);
78             3                                 16         $f = ($f * 1) . 's'; # * 1 to remove insignificant zeros
79                                                       }
80                                                       else {
81             2                                  6         $f = 0;  # $t should = 0 at this point
82                                                       }
83                                                    
84            10                                 63      return $f;
85                                                    }
86                                                    
87                                                    # Returns what percentage $is of $of.
88                                                    sub percentage_of {
89             2                    2            11      my ( $is, $of, %args ) = @_;
90             2           100                   15      my $p   = $args{p} || 0; # float precision
91             2    100                           9      my $fmt = $p ? "%.${p}f" : "%d";
92    ***      2            50                   26      return sprintf $fmt, ($is * 100) / ($of ||= 1);
93                                                    }
94                                                    
95                                                    sub secs_to_time {
96             4                    4            14      my ( $secs, $fmt ) = @_;
97             4           100                   15      $secs ||= 0;
98             4    100                          38      return '00:00' unless $secs;
99                                                    
100                                                      # Decide what format to use, if not given
101   ***      3    100     50                   19      $fmt ||= $secs >= 86_400 ? 'd'
                    100                               
102                                                             : $secs >= 3_600  ? 'h'
103                                                             :                   'm';
104                                                   
105                                                      return
106            3    100                          41         $fmt eq 'd' ? sprintf(
                    100                               
107                                                            "%d+%02d:%02d:%02d",
108                                                            int($secs / 86_400),
109                                                            int(($secs % 86_400) / 3_600),
110                                                            int(($secs % 3_600) / 60),
111                                                            $secs % 60)
112                                                         : $fmt eq 'h' ? sprintf(
113                                                            "%02d:%02d:%02d",
114                                                            int(($secs % 86_400) / 3_600),
115                                                            int(($secs % 3_600) / 60),
116                                                            $secs % 60)
117                                                         : sprintf(
118                                                            "%02d:%02d",
119                                                            int(($secs % 3_600) / 60),
120                                                            $secs % 60);
121                                                   }
122                                                   
123                                                   sub shorten {
124            6                    6            37      my ( $num, %args ) = @_;
125            6    100                          29      my $p = defined $args{p} ? $args{p} : 2;     # float precision
126            6    100                          24      my $d = defined $args{d} ? $args{d} : 1_024; # divisor
127            6                                 18      my $n = 0;
128            6                                 32      my @units = ('', qw(k M G T P E Z Y));
129            6           100                   70      while ( $num >= $d && $n < @units - 1 ) {
130           17                                 46         $num /= $d;
131           17                                121         ++$n;
132                                                      }
133            6    100    100                  157      return sprintf(
134                                                         $num =~ m/\./ || $n
135                                                            ? "%.${p}f%s"
136                                                            : '%d',
137                                                         $num, $units[$n]);
138                                                   }
139                                                   
140                                                   sub ts {
141   ***      0                    0             0      my ( $time ) = @_;
142   ***      0                                  0      my ( $sec, $min, $hour, $mday, $mon, $year )
143                                                         = localtime($time);
144   ***      0                                  0      $mon  += 1;
145   ***      0                                  0      $year += 1900;
146   ***      0                                  0      return sprintf("%d-%02d-%02dT%02d:%02d:%02d",
147                                                         $year, $mon, $mday, $hour, $min, $sec);
148                                                   }
149                                                   
150                                                   # Turns MySQL's 071015 21:43:52 into a properly formatted timestamp.  Also
151                                                   # handles a timestamp with fractions after it.
152                                                   sub parse_timestamp {
153            4                    4            19      my ( $val ) = @_;
154   ***      4     50                         109      if ( my($y, $m, $d, $h, $i, $s, $f)
155                                                            = $val =~ m/^$mysql_ts$/ )
156                                                      {
157            4    100                          74         return sprintf "%d-%02d-%02d %02d:%02d:"
                    100                               
158                                                                        . (defined $f ? '%02.6f' : '%02d'),
159                                                                        $y + 2000, $m, $d, $h, $i, (defined $f ? $s + $f : $s);
160                                                      }
161   ***      0                                  0      return $val;
162                                                   }
163                                                   
164                                                   # Turns a properly formatted timestamp like 2007-10-15 01:43:52
165                                                   # into an int (seconds since epoch).  Optional microseconds are ignored.
166                                                   sub unix_timestamp {
167            8                    8           370      my ( $val ) = @_;
168   ***      8     50                         139      if ( my($y, $m, $d, $h, $i, $s)
169                                                        = $val =~ m/^$proper_ts$/ )
170                                                      {
171            8                                 49         return timelocal($s, $i, $h, $d, $m - 1, $y);
172                                                      }
173   ***      0                                  0      return $val;
174                                                   }
175                                                   
176                                                   # Turns several different types of timestamps into a unix timestamp.
177                                                   # Each type is auto-detected.  Supported types are:
178                                                   #   * N[shdm]                Now - N[shdm]
179                                                   #   * 071015 21:43:52        MySQL slow log timestamp
180                                                   #   * 2009-07-01 [3:43:01]   Proper timestamp with options HH:MM:SS
181                                                   #   * NOW()                  A MySQL time express
182                                                   # For the last type, the callback arg is required.  It is passed the
183                                                   # given value/expression and is expected to return a single value
184                                                   # (the result of the expression).
185                                                   sub any_unix_timestamp {
186           10                   10           235      my ( $val, $callback ) = @_;
187                                                   
188           10    100                         187      if ( my ($n, $suffix) = $val =~ m/^$n_ts$/ ) {
                    100                               
                    100                               
189            3    100                          21         $n = $suffix eq 's' ? $n            # Seconds
      ***            50                               
      ***            50                               
                    100                               
190                                                            : $suffix eq 'm' ? $n * 60       # Minutes
191                                                            : $suffix eq 'h' ? $n * 3600     # Hours
192                                                            : $suffix eq 'd' ? $n * 86400    # Days
193                                                            :                  $n;           # default: Seconds
194            3                                 14         MKDEBUG && _d('ts is now - N[shmd]:', $n);
195            3                                 29         return time - $n;
196                                                      }
197                                                      elsif ( my ($ymd, $hms) = $val =~ m/^(\d{6})(?:\s+(\d+:\d+:\d+))?/ ) {
198            2                                  6         MKDEBUG && _d('ts is MySQL slow log timestamp');
199            2    100                           8         $val .= ' 00:00:00' unless $hms;
200            2                                  9         return unix_timestamp(parse_timestamp($val));
201                                                      }
202                                                      elsif ( ($ymd, $hms) = $val =~ m/^(\d{4}-\d\d-\d\d)(?:[T ](\d+:\d+:\d+))?/) {
203            2                                  6         MKDEBUG && _d('ts is properly formatted timestamp');
204            2    100                           9         $val .= ' 00:00:00' unless $hms;
205            2                                  8         return unix_timestamp($val);
206                                                      }
207                                                      else {
208            3                                  7         MKDEBUG && _d('ts is MySQL expression');
209   ***      3    100     66                   27         return $callback->($val) if $callback && ref $callback eq 'CODE';
210                                                      }
211                                                   
212            2                                  4      MKDEBUG && _d('Unknown ts type:', $val);
213            2                                 11      return;
214                                                   }
215                                                   
216                                                   # Returns the rightmost 64 bits of an MD5 checksum of the value.
217                                                   sub make_checksum {
218            1                    1             5      my ( $val ) = @_;
219            1                                 29      my $checksum = uc substr(md5_hex($val), -16);
220            1                                  3      MKDEBUG && _d($checksum, 'checksum for', $val);
221            1                                  5      return $checksum;
222                                                   }
223                                                   
224                                                   sub _d {
225   ***      0                    0                    my ($package, undef, $line) = caller 0;
226   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
227   ***      0                                              map { defined $_ ? $_ : 'undef' }
228                                                           @_;
229   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
230                                                   }
231                                                   
232                                                   1;
233                                                   
234                                                   # ###########################################################################
235                                                   # End Transformers package
236                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
55           100      2      8   defined $args{'p_ms'} ? :
56           100      1      9   defined $args{'p_s'} ? :
59           100      1      9   if $t < 0
63    ***     50      0     10   if $t =~ /e/
69           100      1      9   if ($t > 0 and $t <= 0.000999) { }
             100      4      5   elsif ($t >= 0.001 and $t <= 0.999999) { }
             100      3      2   elsif ($t >= 1) { }
91           100      1      1   $p ? :
98           100      1      3   unless $secs
101          100      1      1   $secs >= 3600 ? :
             100      1      2   $secs >= 86400 ? :
106          100      1      1   $fmt eq 'h' ? :
             100      1      2   $fmt eq 'd' ? :
125          100      3      3   defined $args{'p'} ? :
126          100      3      3   defined $args{'d'} ? :
133          100      5      1   $num =~ /\./ || $n ? :
154   ***     50      4      0   if (my($y, $m, $d, $h, $i, $s, $f) = $val =~ /^$mysql_ts$/)
157          100      1      3   defined $f ? :
             100      1      3   defined $f ? :
168   ***     50      8      0   if (my($y, $m, $d, $h, $i, $s) = $val =~ /^$proper_ts$/)
188          100      3      7   if (my($n, $suffix) = $val =~ /^$n_ts$/) { }
             100      2      5   elsif (my($ymd, $hms) = $val =~ /^(\d{6})(?:\s+(\d+:\d+:\d+))?/) { }
             100      2      3   elsif (($ymd, $hms) = $val =~ /^(\d{4}-\d\d-\d\d)(?:[T ](\d+:\d+:\d+))?/) { }
189          100      1      1   $suffix eq 'd' ? :
      ***     50      0      2   $suffix eq 'h' ? :
      ***     50      0      2   $suffix eq 'm' ? :
             100      1      2   $suffix eq 's' ? :
199          100      1      1   unless $hms
204          100      1      1   unless $hms
209          100      1      2   if $callback and ref $callback eq 'CODE'
226   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
69           100      2      7      1   $t > 0 and $t <= 0.000999
             100      2      3      4   $t >= 0.001 and $t <= 0.999999
129          100      5      1     17   $num >= $d and $n < @units - 1
209   ***     66      2      0      1   $callback and ref $callback eq 'CODE'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
90           100      1      1   $args{'p'} || 0
92    ***     50      2      0   $of ||= 1
97           100      3      1   $secs ||= 0
101   ***     50      0      3   $fmt ||= $secs >= 86400 ? 'd' : ($secs >= 3600 ? 'h' : 'm')

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
133          100      4      1      1   $num =~ /\./ || $n


Covered Subroutines
-------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/Transformers.pm:24 
BEGIN                  1 /home/daniel/dev/maatkit/common/Transformers.pm:25 
BEGIN                  1 /home/daniel/dev/maatkit/common/Transformers.pm:26 
BEGIN                  1 /home/daniel/dev/maatkit/common/Transformers.pm:27 
BEGIN                  1 /home/daniel/dev/maatkit/common/Transformers.pm:28 
BEGIN                  1 /home/daniel/dev/maatkit/common/Transformers.pm:30 
any_unix_timestamp    10 /home/daniel/dev/maatkit/common/Transformers.pm:186
make_checksum          1 /home/daniel/dev/maatkit/common/Transformers.pm:218
micro_t               10 /home/daniel/dev/maatkit/common/Transformers.pm:54 
parse_timestamp        4 /home/daniel/dev/maatkit/common/Transformers.pm:153
percentage_of          2 /home/daniel/dev/maatkit/common/Transformers.pm:89 
secs_to_time           4 /home/daniel/dev/maatkit/common/Transformers.pm:96 
shorten                6 /home/daniel/dev/maatkit/common/Transformers.pm:124
unix_timestamp         8 /home/daniel/dev/maatkit/common/Transformers.pm:167

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
_d                     0 /home/daniel/dev/maatkit/common/Transformers.pm:225
ts                     0 /home/daniel/dev/maatkit/common/Transformers.pm:141


