---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/CompareQueryTimes.pm   91.8   64.6   57.1   94.7    n/a  100.0   85.7
Total                          91.8   64.6   57.1   94.7    n/a  100.0   85.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          CompareQueryTimes.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Nov  6 22:49:04 2009
Finish:       Fri Nov  6 22:49:04 2009

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
18                                                    # CompareQueryTimes package $Revision$
19                                                    # ###########################################################################
20                                                    package CompareQueryTimes;
21                                                    
22             1                    1             7   use strict;
               1                                  7   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
25             1                    1            12   use POSIX qw(floor);
               1                                  4   
               1                                  8   
26                                                    
27                                                    Transformers->import(qw(micro_t));
28                                                    
29             1                    1             8   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
30                                                    
31             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                 13   
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
47             1                    1           168      my ( $class, %args ) = @_;
48             1                                  5      my @required_args = qw(get_id);
49             1                                  4      foreach my $arg ( @required_args ) {
50    ***      1     50                           6         die "I need a $arg argument" unless $args{$arg};
51                                                       }
52             1                                  8      my $self = {
53                                                          %args,
54                                                          diffs   => {},
55                                                          samples => {},
56                                                       };
57             1                                 17      return bless $self, $class;
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
72             1                    1             6      my ( $self, %args ) = @_;
73             1                                  5      my @required_args = qw(event);
74             1                                  4      foreach my $arg ( @required_args ) {
75    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
76                                                       }
77             1                                  6      return $args{event};
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
89             1                    1             6      my ( $self, %args ) = @_;
90             1                                  5      my @required_args = qw(event dbh);
91             1                                  4      foreach my $arg ( @required_args ) {
92    ***      2     50                          11         die "I need a $arg argument" unless $args{$arg};
93                                                       }
94             1                                  5      my ($event, $dbh) = @args{@required_args};
95                                                    
96    ***      1     50                           6      if ( exists $event->{Query_time} ) {
97    ***      0                                  0         MKDEBUG && _d('Query already executed');
98    ***      0                                  0         return $event;
99                                                       }
100                                                   
101            1                                  2      MKDEBUG && _d('Executing query');
102            1                                  4      my $query = $event->{arg};
103            1                                  2      my ( $start, $end, $query_time );
104                                                   
105            1                                  4      $event->{Query_time} = 0;
106            1                                  3      eval {
107            1                                  4         $start = time();
108            1                                149         $dbh->do($query);
109            1                                  5         $end   = time();
110            1                                 13         $query_time = sprintf '%.6f', $end - $start;
111                                                      };
112   ***      1     50                           5      die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
113                                                   
114            1                                  4      $event->{Query_time} = $query_time;
115                                                   
116            1                                 12      return $event;
117                                                   }
118                                                   
119                                                   # Required args:
120                                                   #   * event  hashref: an event
121                                                   # Returns: hashref
122                                                   # Can die: yes
123                                                   # after_execute() gets any warnings from SHOW WARNINGS.
124                                                   sub after_execute {
125            1                    1             6      my ( $self, %args ) = @_;
126            1                                  5      my @required_args = qw(event);
127            1                                  4      foreach my $arg ( @required_args ) {
128   ***      1     50                           8         die "I need a $arg argument" unless $args{$arg};
129                                                      }
130            1                                 14      return $args{event};
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
142           17                   17           535      my ( $self, %args ) = @_;
143           17                                 64      my @required_args = qw(events);
144           17                                 55      foreach my $arg ( @required_args ) {
145   ***     17     50                          92         die "I need a $arg argument" unless $args{$arg};
146                                                      }
147           17                                 65      my ($events) = @args{@required_args};
148                                                   
149           17                                 46      my $different_query_times = 0;
150                                                   
151           17                                 54      my $event0   = $events->[0];
152   ***     17            33                   76      my $item     = $event0->{fingerprint} || $event0->{arg};
153   ***     17            50                  131      my $sampleno = $event0->{sampleno}    || 0;
154           17           100                   79      my $t0       = $event0->{Query_time}  || 0;
155           17                                 59      my $b0       = bucket_for($t0);
156                                                   
157           17                                 51      my $n_events = scalar @$events;
158           17                                 81      foreach my $i ( 1..($n_events-1) ) {
159           17                                 55         my $event = $events->[$i];
160           17                                 55         my $t     = $event->{Query_time};
161           17                                 56         my $b     = bucket_for($t);
162                                                   
163           17    100                          66         if ( $b0 != $b ) {
164                                                            # Save differences.
165            5                                 19            my $diff = abs($t0 - $t);
166            5                                 14            $different_query_times++;
167            5                                 21            $self->{diffs}->{big}->{$item}->{$sampleno}
168                                                               = [ micro_t($t0), micro_t($t), micro_t($diff) ];
169            5                                 37            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
170                                                         }
171                                                         else {
172           12                                 43            my $inc = percentage_increase($t0, $t);
173           12    100                          74            if ( $inc >= $bucket_threshold[$b0] ) {
174                                                               # Save differences.
175           10                                 27               $different_query_times++;
176           10                                 48               $self->{diffs}->{in_bucket}->{$item}->{$sampleno}
177                                                                  = [ micro_t($t0), micro_t($t), $inc, $bucket_threshold[$b0] ];
178           10                                 78               $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
179                                                            }
180                                                         }
181                                                      }
182                                                   
183                                                      return (
184           17                                108         different_query_times => $different_query_times,
185                                                      );
186                                                   }
187                                                   
188                                                   sub bucket_for {
189           34                   34           112      my ( $val ) = @_;
190   ***     34     50                         125      die "I need a val" unless defined $val;
191           34    100                         141      return 0 if $val == 0;
192           31                                199      my $bucket = floor(log($val) / log(10)) + 6;
193   ***     31     50                         153      $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
                    100                               
194           31                                100      return $bucket;
195                                                   }
196                                                   
197                                                   sub percentage_increase {
198           12                   12            45      my ( $x, $y ) = @_;
199           12    100                          48      return 0 if $x == $y;
200                                                   
201   ***     11     50                          46      if ( $x > $y ) {
202   ***      0                                  0         my $z = $y;
203   ***      0                                  0            $y = $x;
204   ***      0                                  0            $x = $z;
205                                                      }
206                                                   
207           11    100                          47      if ( $x == 0 ) {
208            1                                  4         return 1000;  # This should trigger all buckets' thresholds.
209                                                      }
210                                                   
211           10                                140      return sprintf '%.2f', (($y - $x) / $x) * 100;
212                                                   }
213                                                   
214                                                   sub report {
215            2                    2            12      my ( $self, %args ) = @_;
216            2                                  9      my @required_args = qw(hosts);
217            2                                  8      foreach my $arg ( @required_args ) {
218   ***      2     50                          10         die "I need a $arg argument" unless $args{$arg};
219                                                      }
220            2                                  9      my ($hosts) = @args{@required_args};
221                                                   
222   ***      2     50                           6      return unless keys %{$self->{diffs}};
               2                                 13   
223                                                   
224                                                      # These columns are common to all the reports; make them just once.
225            2                                 13      my $query_id_col = {
226                                                         name        => 'Query ID',
227                                                         fixed_width => 18,
228                                                      };
229            4                                 22      my @host_cols = map {
230            2                                  8         my $col = { name => $_->{name} };
231            4                                 16         $col;
232                                                      } @$hosts;
233                                                   
234            2                                  5      my @reports;
235            2                                  7      foreach my $diff ( qw(big in_bucket) ) {
236            4                                 13         my $report = "_report_diff_$diff";
237            4                                 31         push @reports, $self->$report(
238                                                            query_id_col => $query_id_col,
239                                                            host_cols    => \@host_cols,
240                                                            %args
241                                                         );
242                                                      }
243                                                   
244            2                                 20      return join("\n", @reports);
245                                                   }
246                                                   
247                                                   sub _report_diff_big {
248            2                    2            13      my ( $self, %args ) = @_;
249            2                                  8      my @required_args = qw(query_id_col hosts);
250            2                                  7      foreach my $arg ( @required_args ) {
251   ***      4     50                          19         die "I need a $arg argument" unless $args{$arg};
252                                                      }
253                                                   
254            2                                  8      my $get_id = $self->{get_id};
255                                                   
256            2    100                           6      return unless keys %{$self->{diffs}->{big}};
               2                                 15   
257                                                   
258            1                                  5      my $report = new ReportFormatter();
259            1                                  4      $report->set_title('Big query time differences');
260            3                                 13      $report->set_columns(
261                                                         $args{query_id_col},
262                                                         map {
263            1                                  7            my $col = { name => $_->{name}, right_justify => 1  };
264            3                                 18            $col;
265            1                                  5         } @{$args{hosts}},
266                                                         { name => 'Difference', right_justify => 1 },
267                                                      );
268                                                   
269            1                                  5      my $diff_big = $self->{diffs}->{big};
270            1                                  7      foreach my $item ( sort keys %$diff_big ) {
271            1                                  6         map {
272   ***      0                                  0            $report->add_line(
273                                                               $get_id->($item) . '-' . $_,
274            1                                  5               @{$diff_big->{$item}->{$_}},
275                                                            );
276            1                                  3         } sort { $a <=> $b } keys %{$diff_big->{$item}};
               1                                  5   
277                                                      }
278                                                   
279            1                                  5      return $report->get_report();
280                                                   }
281                                                   
282                                                   sub _report_diff_in_bucket {
283            2                    2            13      my ( $self, %args ) = @_;
284            2                                  9      my @required_args = qw(query_id_col hosts);
285            2                                  7      foreach my $arg ( @required_args ) {
286   ***      4     50                          19         die "I need a $arg argument" unless $args{$arg};
287                                                      }
288                                                   
289            2                                  8      my $get_id = $self->{get_id};
290                                                   
291            2    100                           5      return unless keys %{$self->{diffs}->{in_bucket}};
               2                                 19   
292                                                   
293            1                                 10      my $report = new ReportFormatter();
294            1                                  5      $report->set_title('Significant query time differences');
295            4                                 18      $report->set_columns(
296                                                         $args{query_id_col},
297                                                         map {
298            1                                  9            my $col = { name => $_->{name}, right_justify => 1  };
299            4                                 18            $col;
300            1                                  4         } @{$args{hosts}},
301                                                         { name => '%Increase',  right_justify => 1 },
302                                                         { name => '%Threshold', right_justify => 1 },
303                                                      );
304                                                   
305            1                                  5      my $diff_in_bucket = $self->{diffs}->{in_bucket};
306            1                                  7      foreach my $item ( sort keys %$diff_in_bucket ) {
307            1                                 24         map {
308   ***      0                                  0            $report->add_line(
309                                                               $get_id->($item) . '-' . $_,
310            1                                  5               @{$diff_in_bucket->{$item}->{$_}},
311                                                            );
312            1                                  2         } sort { $a <=> $b } keys %{$diff_in_bucket->{$item}};
               1                                  6   
313                                                      }
314                                                   
315            1                                  5      return $report->get_report();
316                                                   }
317                                                   
318                                                   sub samples {
319   ***      0                    0             0      my ( $self, $item ) = @_;
320   ***      0      0                           0      return unless $item;
321   ***      0                                  0      my @samples;
322   ***      0                                  0      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
      ***      0                                  0   
323   ***      0                                  0         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
324                                                      }
325   ***      0                                  0      return @samples;
326                                                   }
327                                                   
328                                                   sub reset {
329            2                    2             8      my ( $self ) = @_;
330            2                                 19      $self->{diffs}   = {};
331            2                                 15      $self->{samples} = {};
332            2                                  8      return;
333                                                   }
334                                                   
335                                                   sub _d {
336            1                    1            27      my ($package, undef, $line) = caller 0;
337   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  9   
               2                                 10   
338            1                                  6           map { defined $_ ? $_ : 'undef' }
339                                                           @_;
340            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
341                                                   }
342                                                   
343                                                   1;
344                                                   
345                                                   # ###########################################################################
346                                                   # End CompareQueryTimes package
347                                                   # ###########################################################################


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
251   ***     50      0      4   unless $args{$arg}
256          100      1      1   unless keys %{$$self{'diffs'}{'big'};}
286   ***     50      0      4   unless $args{$arg}
291          100      1      1   unless keys %{$$self{'diffs'}{'in_bucket'};}
320   ***      0      0      0   unless $item
337   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
153   ***     50      0     17   $$event0{'sampleno'} || 0
154          100     15      2   $$event0{'Query_time'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
152   ***     33     17      0      0   $$event0{'fingerprint'} || $$event0{'arg'}


Covered Subroutines
-------------------

Subroutine             Count Location                                                
---------------------- ----- --------------------------------------------------------
BEGIN                      1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:22 
BEGIN                      1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:23 
BEGIN                      1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:24 
BEGIN                      1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:25 
BEGIN                      1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:29 
BEGIN                      1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:31 
_d                         1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:336
_report_diff_big           2 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:248
_report_diff_in_bucket     2 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:283
after_execute              1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:125
before_execute             1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:72 
bucket_for                34 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:189
compare                   17 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:142
execute                    1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:89 
new                        1 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:47 
percentage_increase       12 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:198
report                     2 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:215
reset                      2 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:329

Uncovered Subroutines
---------------------

Subroutine             Count Location                                                
---------------------- ----- --------------------------------------------------------
samples                    0 /home/daniel/dev/maatkit/common/CompareQueryTimes.pm:319


