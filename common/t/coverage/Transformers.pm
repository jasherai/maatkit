---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/Transformers.pm   82.4   88.1   90.0   86.7    n/a  100.0   85.4
Total                          82.4   88.1   90.0   86.7    n/a  100.0   85.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Transformers.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:42 2009
Finish:       Wed Jun 10 17:21:42 2009

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
18                                                    # Transformers package $Revision: 3407 $
19                                                    # ###########################################################################
20                                                    
21                                                    # Transformers - Common transformation and beautification subroutines
22                                                    package Transformers;
23                                                    
24             1                    1             5   use strict;
               1                                  2   
               1                                  5   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
26             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
27             1                    1            10   use Time::Local qw(timelocal);
               1                                  3   
               1                                 25   
28             1                    1            10   use Digest::MD5 qw(md5_hex);
               1                                  3   
               1                                115   
29                                                    
30             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  8   
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
44                                                       make_checksum
45                                                    );
46                                                    
47                                                    sub micro_t {
48            10                   10            49      my ( $t, %args ) = @_;
49            10    100                          51      my $p_ms = defined $args{p_ms} ? $args{p_ms} : 0;  # precision for ms vals
50            10    100                          42      my $p_s  = defined $args{p_s}  ? $args{p_s}  : 0;  # precision for s vals
51            10                                 24      my $f;
52                                                    
53            10    100                          50      $t = 0 if $t < 0;
54                                                    
55                                                       # "Remove" scientific notation so the regex below does not make
56                                                       # 6.123456e+18 into 6.123456.
57    ***     10     50                          40      $t = sprintf('%.17f', $t) if $t =~ /e/;
58                                                    
59                                                       # Truncate after 6 decimal places to avoid 0.9999997 becoming 1
60                                                       # because sprintf() rounds.
61            10                                 93      $t =~ s/\.(\d{1,6})\d*/\.$1/;
62                                                    
63            10    100    100                  137      if ($t > 0 && $t <= 0.000999) {
                    100    100                        
                    100                               
64             1                                 15         $f = ($t * 1000000) . 'us';
65                                                       }
66                                                       elsif ($t >= 0.001000 && $t <= 0.999999) {
67             4                                 46         $f = sprintf("%.${p_ms}f", $t * 1000);
68             4                                 22         $f = ($f * 1) . 'ms'; # * 1 to remove insignificant zeros
69                                                       }
70                                                       elsif ($t >= 1) {
71             3                                 18         $f = sprintf("%.${p_s}f", $t);
72             3                                 16         $f = ($f * 1) . 's'; # * 1 to remove insignificant zeros
73                                                       }
74                                                       else {
75             2                                  6         $f = 0;  # $t should = 0 at this point
76                                                       }
77                                                    
78            10                                 63      return $f;
79                                                    }
80                                                    
81                                                    # Returns what percentage $is of $of.
82                                                    sub percentage_of {
83             2                    2            12      my ( $is, $of, %args ) = @_;
84             2           100                   15      my $p   = $args{p} || 0; # float precision
85             2    100                           8      my $fmt = $p ? "%.${p}f" : "%d";
86    ***      2            50                   50      return sprintf $fmt, ($is * 100) / ($of ||= 1);
87                                                    }
88                                                    
89                                                    sub secs_to_time {
90             4                    4            15      my ( $secs, $fmt ) = @_;
91             4           100                   17      $secs ||= 0;
92             4    100                          17      return '00:00' unless $secs;
93                                                    
94                                                       # Decide what format to use, if not given
95    ***      3    100     50                   22      $fmt ||= $secs >= 86_400 ? 'd'
                    100                               
96                                                              : $secs >= 3_600  ? 'h'
97                                                              :                   'm';
98                                                    
99                                                       return
100            3    100                          49         $fmt eq 'd' ? sprintf(
                    100                               
101                                                            "%d+%02d:%02d:%02d",
102                                                            int($secs / 86_400),
103                                                            int(($secs % 86_400) / 3_600),
104                                                            int(($secs % 3_600) / 60),
105                                                            $secs % 60)
106                                                         : $fmt eq 'h' ? sprintf(
107                                                            "%02d:%02d:%02d",
108                                                            int(($secs % 86_400) / 3_600),
109                                                            int(($secs % 3_600) / 60),
110                                                            $secs % 60)
111                                                         : sprintf(
112                                                            "%02d:%02d",
113                                                            int(($secs % 3_600) / 60),
114                                                            $secs % 60);
115                                                   }
116                                                   
117                                                   sub shorten {
118            5                    5            30      my ( $num, %args ) = @_;
119            5    100                          24      my $p = defined $args{p} ? $args{p} : 2;     # float precision
120            5    100                          20      my $d = defined $args{d} ? $args{d} : 1_024; # divisor
121            5                                 13      my $n = 0;
122            5                                 30      my @units = ('', qw(k M G T P E Z Y));
123            5           100                   54      while ( $num >= $d && $n < @units - 1 ) {
124           16                                 46         $num /= $d;
125           16                                113         ++$n;
126                                                      }
127            5    100    100                  119      return sprintf(
128                                                         $num =~ m/\./ || $n
129                                                            ? "%.${p}f%s"
130                                                            : '%d',
131                                                         $num, $units[$n]);
132                                                   }
133                                                   
134                                                   sub ts {
135   ***      0                    0             0      my ( $time ) = @_;
136   ***      0                                  0      my ( $sec, $min, $hour, $mday, $mon, $year )
137                                                         = localtime($time);
138   ***      0                                  0      $mon  += 1;
139   ***      0                                  0      $year += 1900;
140   ***      0                                  0      return sprintf("%d-%02d-%02dT%02d:%02d:%02d",
141                                                         $year, $mon, $mday, $hour, $min, $sec);
142                                                   }
143                                                   
144                                                   # Turns MySQL's 071015 21:43:52 into a properly formatted timestamp.  Also
145                                                   # handles a timestamp with fractions after it.
146                                                   sub parse_timestamp {
147            2                    2             9      my ( $val ) = @_;
148   ***      2     50                          31      if ( my($y, $m, $d, $h, $i, $s, $f)
149                                                            = $val =~ m/^(\d\d)(\d\d)(\d\d) +(\d+):(\d+):(\d+)(\.\d+)?$/ )
150                                                      {
151            2    100                          37         return sprintf "%d-%02d-%02d %02d:%02d:"
                    100                               
152                                                                        . (defined $f ? '%02.6f' : '%02d'),
153                                                                        $y + 2000, $m, $d, $h, $i, (defined $f ? $s + $f : $s);
154                                                      }
155   ***      0                                  0      return $val;
156                                                   }
157                                                   
158                                                   # Turns a properly formatted timestamp like 2007-10-15 01:43:52
159                                                   # into an int (seconds since epoch)
160                                                   sub unix_timestamp {
161            1                    1             4      my ( $val ) = @_;
162   ***      1     50                          12      if ( my($y, $m, $d, $h, $i, $s)
163                                                            = $val =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)$/ )
164                                                      {
165            1                                  8         return timelocal($s, $i, $h, $d, $m - 1, $y);
166                                                      }
167   ***      0                                  0      return $val;
168                                                   }
169                                                   
170                                                   # Returns the rightmost 64 bits of an MD5 checksum of the value.
171                                                   sub make_checksum {
172            1                    1             5      my ( $val ) = @_;
173            1                                 26      my $checksum = uc substr(md5_hex($val), -16);
174            1                                 14      MKDEBUG && _d($checksum, 'checksum for', $val);
175            1                                  5      return $checksum;
176                                                   }
177                                                   
178                                                   sub _d {
179   ***      0                    0                    my ($package, undef, $line) = caller 0;
180   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
181   ***      0                                              map { defined $_ ? $_ : 'undef' }
182                                                           @_;
183   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
184                                                   }
185                                                   
186                                                   1;
187                                                   
188                                                   # ###########################################################################
189                                                   # End Transformers package
190                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
49           100      2      8   defined $args{'p_ms'} ? :
50           100      1      9   defined $args{'p_s'} ? :
53           100      1      9   if $t < 0
57    ***     50      0     10   if $t =~ /e/
63           100      1      9   if ($t > 0 and $t <= 0.000999) { }
             100      4      5   elsif ($t >= 0.001 and $t <= 0.999999) { }
             100      3      2   elsif ($t >= 1) { }
85           100      1      1   $p ? :
92           100      1      3   unless $secs
95           100      1      1   $secs >= 3600 ? :
             100      1      2   $secs >= 86400 ? :
100          100      1      1   $fmt eq 'h' ? :
             100      1      2   $fmt eq 'd' ? :
119          100      2      3   defined $args{'p'} ? :
120          100      2      3   defined $args{'d'} ? :
127          100      4      1   $num =~ /\./ || $n ? :
148   ***     50      2      0   if (my($y, $m, $d, $h, $i, $s, $f) = $val =~ /^(\d\d)(\d\d)(\d\d) +(\d+):(\d+):(\d+)(\.\d+)?$/)
151          100      1      1   defined $f ? :
             100      1      1   defined $f ? :
162   ***     50      1      0   if (my($y, $m, $d, $h, $i, $s) = $val =~ /^(\d\d\d\d)-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)$/)
180   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
63           100      2      7      1   $t > 0 and $t <= 0.000999
             100      2      3      4   $t >= 0.001 and $t <= 0.999999
123          100      4      1     16   $num >= $d and $n < @units - 1

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
84           100      1      1   $args{'p'} || 0
86    ***     50      2      0   $of ||= 1
91           100      3      1   $secs ||= 0
95    ***     50      0      3   $fmt ||= $secs >= 86400 ? 'd' : ($secs >= 3600 ? 'h' : 'm')

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
127          100      3      1      1   $num =~ /\./ || $n


Covered Subroutines
-------------------

Subroutine      Count Location                                           
--------------- ----- ---------------------------------------------------
BEGIN               1 /home/daniel/dev/maatkit/common/Transformers.pm:24 
BEGIN               1 /home/daniel/dev/maatkit/common/Transformers.pm:25 
BEGIN               1 /home/daniel/dev/maatkit/common/Transformers.pm:26 
BEGIN               1 /home/daniel/dev/maatkit/common/Transformers.pm:27 
BEGIN               1 /home/daniel/dev/maatkit/common/Transformers.pm:28 
BEGIN               1 /home/daniel/dev/maatkit/common/Transformers.pm:30 
make_checksum       1 /home/daniel/dev/maatkit/common/Transformers.pm:172
micro_t            10 /home/daniel/dev/maatkit/common/Transformers.pm:48 
parse_timestamp     2 /home/daniel/dev/maatkit/common/Transformers.pm:147
percentage_of       2 /home/daniel/dev/maatkit/common/Transformers.pm:83 
secs_to_time        4 /home/daniel/dev/maatkit/common/Transformers.pm:90 
shorten             5 /home/daniel/dev/maatkit/common/Transformers.pm:118
unix_timestamp      1 /home/daniel/dev/maatkit/common/Transformers.pm:161

Uncovered Subroutines
---------------------

Subroutine      Count Location                                           
--------------- ----- ---------------------------------------------------
_d                  0 /home/daniel/dev/maatkit/common/Transformers.pm:179
ts                  0 /home/daniel/dev/maatkit/common/Transformers.pm:135


