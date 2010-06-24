---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/CompareQueryTimes.pm   91.8   64.6   55.6   94.7    0.0   77.5   82.1
CompareQueryTimes.t           100.0   50.0   50.0  100.0    n/a   22.5   94.9
Total                          94.7   63.5   52.9   97.1    0.0  100.0   86.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:12 2010
Finish:       Thu Jun 24 19:32:12 2010

Run:          CompareQueryTimes.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:14 2010
Finish:       Thu Jun 24 19:32:14 2010

/home/daniel/dev/maatkit/common/CompareQueryTimes.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
18                                                    # CompareQueryTimes package $Revision: 5285 $
19                                                    # ###########################################################################
20                                                    package CompareQueryTimes;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  4   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  4   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
25             1                    1             6   use POSIX qw(floor);
               1                                  2   
               1                                  9   
26                                                    
27                                                    Transformers->import(qw(micro_t));
28                                                    
29    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 12   
30                                                    
31             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  8   
32                                                    $Data::Dumper::Indent    = 1;
33                                                    $Data::Dumper::Sortkeys  = 1;
34                                                    $Data::Dumper::Quotekeys = 0;
35                                                    
36                                                    # Significant percentage increase for each bucket.  For example,
37                                                    # 1us to 4us is a 300% increase, but in reality that is not significant.
38                                                    # But a 500% increase to 6us may be significant.  In the 1s+ range (last
39                                                    # bucket), since the time is already so bad, even a 20% increase (e.g. 1s
40                                                    # to 1.2s) is significant.
41                                                    my @bucket_threshold = qw(500 100  100   500 50   50    20 1   );
42                                                    # my @bucket_labels  = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
43                                                    
44                                                    # Required args:
45                                                    #   * get_id  coderef: used by report() to trf query to its ID
46                                                    sub new {
47    ***      1                    1      0      6      my ( $class, %args ) = @_;
48             1                                  5      my @required_args = qw(get_id);
49             1                                  4      foreach my $arg ( @required_args ) {
50    ***      1     50                           8         die "I need a $arg argument" unless $args{$arg};
51                                                       }
52             1                                  9      my $self = {
53                                                          %args,
54                                                          diffs   => {},
55                                                          samples => {},
56                                                       };
57             1                                 16      return bless $self, $class;
58                                                    }
59                                                    
60                                                    # Required args:
61                                                    #   * event  hashref: an event
62                                                    #   * dbh    scalar: active dbh
63                                                    # Optional args:
64                                                    #   * db             scalar: database name to create temp table in unless...
65                                                    #   * temp-database  scalar: ...temp db name is given
66                                                    # Returns: hashref
67                                                    # Can die: yes
68                                                    # before_execute() selects from its special temp table to clear the warnings
69                                                    # if the module was created with the clear arg specified.  The temp table is
70                                                    # created if there's a db or temp db and the table doesn't exist yet.
71                                                    sub before_execute {
72    ***      1                    1      0      6      my ( $self, %args ) = @_;
73             1                                  5      my @required_args = qw(event);
74             1                                  4      foreach my $arg ( @required_args ) {
75    ***      1     50                          10         die "I need a $arg argument" unless $args{$arg};
76                                                       }
77             1                                  7      return $args{event};
78                                                    }
79                                                    
80                                                    # Required args:
81                                                    #   * event  hashref: an event
82                                                    #   * dbh    scalar: active dbh
83                                                    # Returns: hashref
84                                                    # Can die: yes
85                                                    # execute() executes the event's query if is hasn't already been executed. 
86                                                    # Any prep work should have been done in before_execute().  Adds Query_time
87                                                    # attrib to the event.
88                                                    sub execute {
89    ***      1                    1      0      6      my ( $self, %args ) = @_;
90             1                                  6      my @required_args = qw(event dbh);
91             1                                  4      foreach my $arg ( @required_args ) {
92    ***      2     50                          11         die "I need a $arg argument" unless $args{$arg};
93                                                       }
94             1                                  5      my ($event, $dbh) = @args{@required_args};
95                                                    
96    ***      1     50                           5      if ( exists $event->{Query_time} ) {
97    ***      0                                  0         MKDEBUG && _d('Query already executed');
98    ***      0                                  0         return $event;
99                                                       }
100                                                   
101            1                                  2      MKDEBUG && _d('Executing query');
102            1                                  3      my $query = $event->{arg};
103            1                                  4      my ( $start, $end, $query_time );
104                                                   
105            1                                  4      $event->{Query_time} = 0;
106            1                                  4      eval {
107            1                                  4         $start = time();
108            1                                138         $dbh->do($query);
109            1                                  4         $end   = time();
110            1                                 20         $query_time = sprintf '%.6f', $end - $start;
111                                                      };
112   ***      1     50                           5      die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
113                                                   
114            1                                  4      $event->{Query_time} = $query_time;
115                                                   
116            1                                  6      return $event;
117                                                   }
118                                                   
119                                                   # Required args:
120                                                   #   * event  hashref: an event
121                                                   # Returns: hashref
122                                                   # Can die: yes
123                                                   # after_execute() gets any warnings from SHOW WARNINGS.
124                                                   sub after_execute {
125   ***      1                    1      0      7      my ( $self, %args ) = @_;
126            1                                  4      my @required_args = qw(event);
127            1                                  4      foreach my $arg ( @required_args ) {
128   ***      1     50                           6         die "I need a $arg argument" unless $args{$arg};
129                                                      }
130            1                                  7      return $args{event};
131                                                   }
132                                                   
133                                                   # Required args:
134                                                   #   * events  arrayref: events
135                                                   # Returns: array
136                                                   # Can die: yes
137                                                   # compare() compares events that have been run through before_execute(),
138                                                   # execute() and after_execute().  Only a "summary" of differences is
139                                                   # returned.  Specific differences are saved internally and are reported
140                                                   # by calling report() later.
141                                                   sub compare {
142   ***     17                   17      0     79      my ( $self, %args ) = @_;
143           17                                 63      my @required_args = qw(events);
144           17                                 57      foreach my $arg ( @required_args ) {
145   ***     17     50                          90         die "I need a $arg argument" unless $args{$arg};
146                                                      }
147           17                                 67      my ($events) = @args{@required_args};
148                                                   
149           17                                 41      my $different_query_times = 0;
150                                                   
151           17                                 58      my $event0   = $events->[0];
152   ***     17            33                   81      my $item     = $event0->{fingerprint} || $event0->{arg};
153   ***     17            50                  133      my $sampleno = $event0->{sampleno}    || 0;
154           17           100                   79      my $t0       = $event0->{Query_time}  || 0;
155           17                                 60      my $b0       = bucket_for($t0);
156                                                   
157           17                                 48      my $n_events = scalar @$events;
158           17                                 71      foreach my $i ( 1..($n_events-1) ) {
159           17                                 52         my $event = $events->[$i];
160           17                                 53         my $t     = $event->{Query_time};
161           17                                 53         my $b     = bucket_for($t);
162                                                   
163           17    100                          61         if ( $b0 != $b ) {
164                                                            # Save differences.
165            5                                 18            my $diff = abs($t0 - $t);
166            5                                 12            $different_query_times++;
167            5                                 24            $self->{diffs}->{big}->{$item}->{$sampleno}
168                                                               = [ micro_t($t0), micro_t($t), micro_t($diff) ];
169            5                                 34            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
170                                                         }
171                                                         else {
172           12                                 45            my $inc = percentage_increase($t0, $t);
173           12    100                          72            if ( $inc >= $bucket_threshold[$b0] ) {
174                                                               # Save differences.
175           10                                 24               $different_query_times++;
176           10                                 49               $self->{diffs}->{in_bucket}->{$item}->{$sampleno}
177                                                                  = [ micro_t($t0), micro_t($t), $inc, $bucket_threshold[$b0] ];
178           10                                 70               $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
179                                                            }
180                                                         }
181                                                      }
182                                                   
183                                                      return (
184           17                                109         different_query_times => $different_query_times,
185                                                      );
186                                                   }
187                                                   
188                                                   sub bucket_for {
189   ***     34                   34      0    109      my ( $val ) = @_;
190   ***     34     50                         116      die "I need a val" unless defined $val;
191           34    100                         136      return 0 if $val == 0;
192           31                                189      my $bucket = floor(log($val) / log(10)) + 6;
193   ***     31     50                         136      $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
                    100                               
194           31                                 95      return $bucket;
195                                                   }
196                                                   
197                                                   sub percentage_increase {
198   ***     12                   12      0     46      my ( $x, $y ) = @_;
199           12    100                          50      return 0 if $x == $y;
200                                                   
201   ***     11     50                          81      if ( $x > $y ) {
202   ***      0                                  0         my $z = $y;
203   ***      0                                  0            $y = $x;
204   ***      0                                  0            $x = $z;
205                                                      }
206                                                   
207           11    100                          39      if ( $x == 0 ) {
208            1                                  4         return 1000;  # This should trigger all buckets' thresholds.
209                                                      }
210                                                   
211           10                                116      return sprintf '%.2f', (($y - $x) / $x) * 100;
212                                                   }
213                                                   
214                                                   sub report {
215   ***      2                    2      0     10      my ( $self, %args ) = @_;
216            2                                  8      my @required_args = qw(hosts);
217            2                                 11      foreach my $arg ( @required_args ) {
218   ***      2     50                          11         die "I need a $arg argument" unless $args{$arg};
219                                                      }
220            2                                 10      my ($hosts) = @args{@required_args};
221                                                   
222   ***      2     50                           4      return unless keys %{$self->{diffs}};
               2                                 12   
223                                                   
224                                                      # These columns are common to all the reports; make them just once.
225            2                                  9      my $query_id_col = {
226                                                         name        => 'Query ID',
227                                                      };
228            4                                 16      my @host_cols = map {
229            2                                  8         my $col = { name => $_->{name} };
230            4                                 16         $col;
231                                                      } @$hosts;
232                                                   
233            2                                  5      my @reports;
234            2                                  8      foreach my $diff ( qw(big in_bucket) ) {
235            4                               3310         my $report = "_report_diff_$diff";
236            4                                 29         push @reports, $self->$report(
237                                                            query_id_col => $query_id_col,
238                                                            host_cols    => \@host_cols,
239                                                            %args
240                                                         );
241                                                      }
242                                                   
243            2                               3506      return join("\n", @reports);
244                                                   }
245                                                   
246                                                   sub _report_diff_big {
247            2                    2            13      my ( $self, %args ) = @_;
248            2                                  9      my @required_args = qw(query_id_col hosts);
249            2                                  6      foreach my $arg ( @required_args ) {
250   ***      4     50                          24         die "I need a $arg argument" unless $args{$arg};
251                                                      }
252                                                   
253            2                                  9      my $get_id = $self->{get_id};
254                                                   
255            2    100                           5      return unless keys %{$self->{diffs}->{big}};
               2                                 16   
256                                                   
257            1                                  5      my $report = new ReportFormatter();
258            1                                 45      $report->set_title('Big query time differences');
259            3                                 13      $report->set_columns(
260                                                         $args{query_id_col},
261                                                         map {
262            1                                  6            my $col = { name => $_->{name}, right_justify => 1  };
263            3                                 12            $col;
264            1                                 14         } @{$args{hosts}},
265                                                         { name => 'Difference', right_justify => 1 },
266                                                      );
267                                                   
268            1                                332      my $diff_big = $self->{diffs}->{big};
269            1                                  6      foreach my $item ( sort keys %$diff_big ) {
270            1                                 24         map {
271   ***      0                                  0            $report->add_line(
272                                                               $get_id->($item) . '-' . $_,
273            1                                  4               @{$diff_big->{$item}->{$_}},
274                                                            );
275            1                                  3         } sort { $a <=> $b } keys %{$diff_big->{$item}};
               1                                  6   
276                                                      }
277                                                   
278            1                                134      return $report->get_report();
279                                                   }
280                                                   
281                                                   sub _report_diff_in_bucket {
282            2                    2            12      my ( $self, %args ) = @_;
283            2                                  9      my @required_args = qw(query_id_col hosts);
284            2                                  7      foreach my $arg ( @required_args ) {
285   ***      4     50                          19         die "I need a $arg argument" unless $args{$arg};
286                                                      }
287                                                   
288            2                                  7      my $get_id = $self->{get_id};
289                                                   
290            2    100                           6      return unless keys %{$self->{diffs}->{in_bucket}};
               2                                 15   
291                                                   
292            1                                 10      my $report = new ReportFormatter();
293            1                                 63      $report->set_title('Significant query time differences');
294            4                                 23      $report->set_columns(
295                                                         $args{query_id_col},
296                                                         map {
297            1                                  8            my $col = { name => $_->{name}, right_justify => 1  };
298            4                                 16            $col;
299            1                                 16         } @{$args{hosts}},
300                                                         { name => '%Increase',  right_justify => 1 },
301                                                         { name => '%Threshold', right_justify => 1 },
302                                                      );
303                                                   
304            1                                414      my $diff_in_bucket = $self->{diffs}->{in_bucket};
305            1                                  6      foreach my $item ( sort keys %$diff_in_bucket ) {
306            1                                 50         map {
307   ***      0                                  0            $report->add_line(
308                                                               $get_id->($item) . '-' . $_,
309            1                                  5               @{$diff_in_bucket->{$item}->{$_}},
310                                                            );
311            1                                  4         } sort { $a <=> $b } keys %{$diff_in_bucket->{$item}};
               1                                  6   
312                                                      }
313                                                   
314            1                                171      return $report->get_report();
315                                                   }
316                                                   
317                                                   sub samples {
318   ***      0                    0      0      0      my ( $self, $item ) = @_;
319   ***      0      0                           0      return unless $item;
320   ***      0                                  0      my @samples;
321   ***      0                                  0      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
      ***      0                                  0   
322   ***      0                                  0         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
323                                                      }
324   ***      0                                  0      return @samples;
325                                                   }
326                                                   
327                                                   sub reset {
328   ***      2                    2      0      8      my ( $self ) = @_;
329            2                                  8      $self->{diffs}   = {};
330            2                                 16      $self->{samples} = {};
331            2                                  9      return;
332                                                   }
333                                                   
334                                                   sub _d {
335            1                    1             8      my ($package, undef, $line) = caller 0;
336   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                  9   
337            1                                  5           map { defined $_ ? $_ : 'undef' }
338                                                           @_;
339            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
340                                                   }
341                                                   
342                                                   1;
343                                                   
344                                                   # ###########################################################################
345                                                   # End CompareQueryTimes package
346                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
50    ***     50      0      1   unless $args{$arg}
75    ***     50      0      1   unless $args{$arg}
92    ***     50      0      2   unless $args{$arg}
96    ***     50      0      1   if (exists $$event{'Query_time'})
112   ***     50      0      1   if $EVAL_ERROR
128   ***     50      0      1   unless $args{$arg}
145   ***     50      0     17   unless $args{$arg}
163          100      5     12   if ($b0 != $b) { }
173          100     10      2   if ($inc >= $bucket_threshold[$b0])
190   ***     50      0     34   unless defined $val
191          100      3     31   if $val == 0
193   ***     50      0     30   $bucket < 0 ? :
             100      1     30   $bucket > 7 ? :
199          100      1     11   if $x == $y
201   ***     50      0     11   if ($x > $y)
207          100      1     10   if ($x == 0)
218   ***     50      0      2   unless $args{$arg}
222   ***     50      0      2   unless keys %{$$self{'diffs'};}
250   ***     50      0      4   unless $args{$arg}
255          100      1      1   unless keys %{$$self{'diffs'}{'big'};}
285   ***     50      0      4   unless $args{$arg}
290          100      1      1   unless keys %{$$self{'diffs'}{'in_bucket'};}
319   ***      0      0      0   unless $item
336   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
29    ***     50      0      1   $ENV{'MKDEBUG'} || 0
153   ***     50      0     17   $$event0{'sampleno'} || 0
154          100     15      2   $$event0{'Query_time'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
152   ***     33     17      0      0   $$event0{'fingerprint'} || $$event0{'arg'}


Covered Subroutines
-------------------

Subroutine             Count Pod Location                                                
---------------------- ----- --- --------------------------------------------------------
BEGIN                      1     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:22 
BEGIN                      1     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:23 
BEGIN                      1     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:24 
BEGIN                      1     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:25 
BEGIN                      1     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:29 
BEGIN                      1     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:31 
_d                         1     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:335
_report_diff_big           2     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:247
_report_diff_in_bucket     2     /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:282
after_execute              1   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:125
before_execute             1   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:72 
bucket_for                34   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:189
compare                   17   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:142
execute                    1   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:89 
new                        1   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:47 
percentage_increase       12   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:198
report                     2   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:215
reset                      2   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:328

Uncovered Subroutines
---------------------

Subroutine             Count Pod Location                                                
---------------------- ----- --- --------------------------------------------------------
samples                    0   0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:318


CompareQueryTimes.t

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
               1                                  3   
               1                                  5   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1             9   use Test::More tests => 24;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use ReportFormatter;
               1                                  3   
               1                                 19   
15             1                    1            12   use Transformers;
               1                                  3   
               1                                  9   
16             1                    1            10   use DSNParser;
               1                                  3   
               1                                 12   
17             1                    1            14   use Sandbox;
               1                                  3   
               1                                 10   
18             1                    1            14   use CompareQueryTimes;
               1                                  3   
               1                                 10   
19             1                    1            10   use MaatkitTest;
               1                                  4   
               1                                 36   
20                                                    
21             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
22             1                                237   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
23    ***      1     50                          54   my $dbh = $sb->get_dbh_for('master')
24                                                       or BAIL_OUT('Cannot connect to sandbox master');
25                                                    
26             1                                385   $sb->create_dbs($dbh, ['test']);
27                                                    
28             1                                835   Transformers->import(qw(make_checksum));
29                                                    
30             1                                138   my $ct;
31             1                                  4   my $report;
32             1                                 10   my $hosts = [
33                                                       { dbh => $dbh, name => 'server1' },
34                                                       { dbh => $dbh, name => 'server2' },
35                                                    ];
36                                                    
37                                                    sub get_id {
38             2                    2            11      return make_checksum(@_);
39                                                    }
40                                                    
41                                                    # #############################################################################
42                                                    # Test it.
43                                                    # #############################################################################
44                                                    
45                                                    # diag(`/tmp/12345/use < samples/compare-warnings.sql`);
46                                                    
47             1                                  9   $ct = new CompareQueryTimes(
48                                                       get_id => \&get_id,
49                                                    );
50                                                    
51             1                                 11   isa_ok($ct, 'CompareQueryTimes');
52                                                    
53                                                    # #############################################################################
54                                                    # Test query time comparison.
55                                                    # #############################################################################
56                                                    sub compare {
57            17                   17            61      my ( $t1, $t2 ) = @_;
58            17                                157      return $ct->compare(
59                                                          events => [
60                                                             { fingerprint => 'foo', Query_time => $t1, },
61                                                             { fingerprint => 'foo', Query_time => $t2, },
62                                                          ],
63                                                       );
64                                                    }
65                                                    
66                                                    sub test_compare_query_times {
67            15                   15            79      my ( $t1, $t2, $diff, $comment ) = @_;
68            15                                 58      my %diff = compare($t1, $t2);
69            15           100                  189      my $msg  = sprintf("compare t %.6f vs. %.6f %s",
70                                                          $t1, $t2, ($comment || ''));
71            15                                 78      is(
72                                                          $diff{different_query_times},
73                                                          $diff,
74                                                          $msg,
75                                                       );
76                                                    }
77                                                    
78             1                                  8   test_compare_query_times(0, 0, 0);
79             1                                  5   test_compare_query_times(0, 0.000001, 1, 'increase from zero');
80             1                                  5   test_compare_query_times(0.000001, 0.000005, 0, 'no increase in bucket');
81             1                                  5   test_compare_query_times(0.000001, 0.000010, 1, '1 bucket diff on edge');
82             1                                  4   test_compare_query_times(0.000008, 0.000018, 1, '1 bucket diff');
83             1                                  5   test_compare_query_times(0.000001, 10, 1, 'full bucket range diff on edges');
84             1                                  6   test_compare_query_times(0.000008, 1000000, 1, 'huge diff');
85                                                    
86                                                    # Thresholds
87             1                                  5   test_compare_query_times(0.000001, 0.000006, 1, '1us threshold');
88             1                                  5   test_compare_query_times(0.000010, 0.000020, 1, '10us threshold');
89             1                                  5   test_compare_query_times(0.000100, 0.000200, 1, '100us threshold');
90             1                                  4   test_compare_query_times(0.001000, 0.006000, 1, '1ms threshold');
91             1                                  5   test_compare_query_times(0.010000, 0.015000, 1, '10ms threshold');
92             1                                  4   test_compare_query_times(0.100000, 0.150000, 1, '100ms threshold');
93             1                                  5   test_compare_query_times(1.000000, 1.200000, 1, '1s threshold');
94             1                                  5   test_compare_query_times(10.0,     10.1,     1, '10s threshold');
95                                                    
96                                                    # #############################################################################
97                                                    # Test the main actions, which don't do much.
98                                                    # #############################################################################
99             1                                  6   my $event = {
100                                                      fingerprint => 'set @a=?',
101                                                      arg         => 'set @a=3',
102                                                      sampleno    => 4,
103                                                   };
104                                                   
105            1                                186   $dbh->do('set @a=1');
106            1                                  3   is_deeply(
107                                                      $dbh->selectcol_arrayref('select @a'),
108                                                      [1],
109                                                      '@a set'
110                                                   );
111                                                   
112            1                                 15   is_deeply(
113                                                      $ct->before_execute(event => $event),
114                                                      $event,
115                                                      "before_execute() doesn't modify event"
116                                                   );
117                                                   
118            1                                 13   $ct->execute(event => $event, dbh => $dbh);
119                                                   
120   ***      1            33                   17   ok(
121                                                      exists $event->{Query_time}
122                                                      && $event->{Query_time} >= 0,
123                                                      'execute() set Query_time'
124                                                   );
125                                                   
126            1                                  3   is_deeply(
127                                                      $dbh->selectcol_arrayref('select @a'),
128                                                      [3],
129                                                      'Query was actually executed'
130                                                   );
131                                                   
132            1                                 17   is_deeply(
133                                                      $ct->after_execute(event => $event),
134                                                      $event,
135                                                      "after_execute() doesn't modify event"
136                                                   );
137                                                   
138                                                   
139                                                   # #############################################################################
140                                                   # Test the reports.
141                                                   # #############################################################################
142            1                                  9   $ct->reset();
143            1                                  4   compare(0.000100, 0.000250);
144                                                   
145            1                                 12   $report = <<EOF;
146                                                   # Significant query time differences
147                                                   # Query ID           server1 server2 %Increase %Threshold
148                                                   # ================== ======= ======= ========= ==========
149                                                   # EDEF654FCCC4A4D8-0   100us   250us    150.00        100
150                                                   EOF
151                                                   
152            1                                  6   is(
153                                                      $ct->report(hosts => $hosts),
154                                                      $report,
155                                                      'report in bucket difference'
156                                                   );
157                                                   
158            1                                  7   $ct->reset();
159            1                                  4   compare(0.000100, 1.100251);
160                                                   
161            1                                  5   $report = <<EOF;
162                                                   # Big query time differences
163                                                   # Query ID           server1 server2 Difference
164                                                   # ================== ======= ======= ==========
165                                                   # EDEF654FCCC4A4D8-0   100us      1s         1s
166                                                   EOF
167                                                   
168            1                                  5   is(
169                                                      $ct->report(hosts => $hosts),
170                                                      $report,
171                                                      'report in bucket difference'
172                                                   );
173                                                   
174                                                   # #############################################################################
175                                                   # Done.
176                                                   # #############################################################################
177            1                                  5   my $output = '';
178                                                   {
179            1                                  3      local *STDERR;
               1                                  8   
180            1                    1             2      open STDERR, '>', \$output;
               1                                315   
               1                                  2   
               1                                  8   
181            1                                 20      $ct->_d('Complete test coverage');
182                                                   }
183                                                   like(
184            1                                 22      $output,
185                                                      qr/Complete test coverage/,
186                                                      '_d() works'
187                                                   );
188            1                                 15   $sb->wipe_clean($dbh);
189            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
23    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
120   ***     33      0      0      1   exists $$event{'Query_time'} && $$event{'Query_time'} >= 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
69           100     14      1   $comment || ''


Covered Subroutines
-------------------

Subroutine               Count Location               
------------------------ ----- -----------------------
BEGIN                        1 CompareQueryTimes.t:10 
BEGIN                        1 CompareQueryTimes.t:11 
BEGIN                        1 CompareQueryTimes.t:12 
BEGIN                        1 CompareQueryTimes.t:14 
BEGIN                        1 CompareQueryTimes.t:15 
BEGIN                        1 CompareQueryTimes.t:16 
BEGIN                        1 CompareQueryTimes.t:17 
BEGIN                        1 CompareQueryTimes.t:18 
BEGIN                        1 CompareQueryTimes.t:180
BEGIN                        1 CompareQueryTimes.t:19 
BEGIN                        1 CompareQueryTimes.t:4  
BEGIN                        1 CompareQueryTimes.t:9  
compare                     17 CompareQueryTimes.t:57 
get_id                       2 CompareQueryTimes.t:38 
test_compare_query_times    15 CompareQueryTimes.t:67 


