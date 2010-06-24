---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...UpgradeReportFormatter.pm   78.8   36.7   55.0   90.9    0.0   10.6   68.0
UpgradeReportFormatter.t      100.0   50.0   33.3  100.0    n/a   89.4   96.6
Total                          86.8   37.5   52.2   95.8    0.0  100.0   77.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:45 2010
Finish:       Thu Jun 24 19:38:45 2010

Run:          UpgradeReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:47 2010
Finish:       Thu Jun 24 19:38:47 2010

/home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009 Percona Inc.
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
19                                                    # UpgradeReportFormatter package $Revision: 6190 $
20                                                    # ###########################################################################
21                                                    
22                                                    package UpgradeReportFormatter;
23                                                    
24             1                    1             5   use strict;
               1                                  3   
               1                                  5   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
26             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
27                                                    Transformers->import(qw(make_checksum percentage_of shorten micro_t));
28                                                    
29             1                    1             6   use constant MKDEBUG           => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
30             1                    1             6   use constant LINE_LENGTH       => 74;
               1                                  2   
               1                                  4   
31             1                    1             6   use constant MAX_STRING_LENGTH => 10;
               1                                  2   
               1                                  4   
32                                                    
33                                                    # Special formatting functions
34                                                    my %formatting_function = (
35                                                       ts => sub {
36                                                          my ( $stats ) = @_;
37                                                          my $min = parse_timestamp($stats->{min} || '');
38                                                          my $max = parse_timestamp($stats->{max} || '');
39                                                          return $min && $max ? "$min to $max" : '';
40                                                       },
41                                                    );
42                                                    
43                                                    my $bool_format = '# %3s%% %-6s %s';
44                                                    
45                                                    sub new {
46    ***      1                    1      0      5      my ( $class, %args ) = @_;
47             1                                 10      return bless { }, $class;
48                                                    }
49                                                    
50                                                    sub event_report {
51    ***      1                    1      0      9      my ( $self, %args ) = @_;
52             1                                  6      my @required_args = qw(where rank worst meta_ea hosts);
53             1                                  8      foreach my $arg ( @required_args ) {
54    ***      5     50                          24         die "I need a $arg argument" unless $args{$arg};
55                                                       }
56             1                                  7      my ($where, $rank, $worst, $meta_ea, $hosts) = @args{@required_args};
57             1                                  8      my $meta_stats = $meta_ea->results;
58             1                                 21      my @result;
59                                                    
60                                                    
61                                                       # First line
62    ***      1            50                    8      my $line = sprintf(
63                                                          '# Query %d: ID 0x%s at byte %d ',
64                                                          $rank || 0,
65                                                          make_checksum($where),
66                                                          0, # $sample->{pos_in_log} || 0
67                                                       );
68             1                                 49      $line .= ('_' x (LINE_LENGTH - length($line)));
69             1                                  3      push @result, $line;
70                                                    
71                                                       # Differences report.  This relies on a sampleno attrib in each class
72                                                       # since all other attributes (except maybe Query_time) are optional.
73             1                                  5      my $class = $meta_stats->{classes}->{$where};
74    ***      1            50                   12      push @result,
75                                                          '# Found ' . ($class->{differences}->{sum} || 0)
76                                                          . ' differences in ' . $class->{sampleno}->{cnt} . " samples:\n";
77                                                    
78             1                                  3      my $fmt = "# %-17s %d\n";
79             1                                  6      my @diffs = grep { $_ =~ m/^different_/ } keys %$class;
               5                                 26   
80             1                                 10      foreach my $diff ( sort @diffs ) {
81             2                                  9         push @result,
82                                                             sprintf $fmt, '  ' . make_label($diff), $class->{$diff}->{sum};
83                                                       }
84                                                    
85                                                       # Side-by-side hosts report.
86             1                                 12      my $report = new ReportFormatter(
87                                                          underline_header => 0,
88                                                       );
89             2                                 16      $report->set_columns(
90                                                          { name => '' },
91             1                                 65         map { { name => $_->{name}, right_justify => 1 } } @$hosts,
92                                                       );
93                                                       # Bool values.
94             1                                270      foreach my $thing ( qw(Errors Warnings) ) {
95             2                                132         my @vals = $thing;
96             2                                  7         foreach my $host ( @$hosts ) {
97             4                                 58            my $ea    = $host->{ea};
98             4                                 16            my $stats = $ea->results->{classes}->{$where};
99    ***      4    100     66                  104            if ( $stats && $stats->{$thing} ) {
100            2                                 15               push @vals, shorten($stats->{$thing}->{sum}, d=>1_000, p=>0)
101                                                            }
102                                                            else {
103            2                                  8               push @vals, 0;
104                                                            }
105                                                         }
106            2                                 50         $report->add_line(@vals);
107                                                      }
108                                                      # Fully aggregated numeric values.
109            1                                 99      foreach my $thing ( qw(Query_time row_count) ) {
110            2                                101         my @vals;
111                                                   
112            2                                 18         foreach my $host ( @$hosts ) {
113            4                                 14            my $ea    = $host->{ea};
114            4                                 16            my $stats = $ea->results->{classes}->{$where};
115   ***      4    100     66                  100            if ( $stats && $stats->{$thing} ) {
116            2                                  7               my $vals = $stats->{$thing};
117   ***      2     50                          11               my $func = $thing =~ m/time$/ ? \&micro_t : \&shorten;
118            2                                 18               my $metrics = $host->{ea}->metrics(attrib=>$thing, where=>$where);
119            2                                 17               my @n = (
120            2                                 19                  @{$vals}{qw(sum min max)},
121                                                                  ($vals->{sum} || 0) / ($vals->{cnt} || 1),
122   ***      2            50                  243                  @{$metrics}{qw(pct_95 stddev median)},
      ***                   50                        
123                                                               );
124   ***      2     50                           9               @n = map { defined $_ ? $func->($_) : '' } @n;
              14                                661   
125            2                                118               push @vals, \@n;
126                                                            }
127                                                            else {
128            2                                  9               push @vals, undef;
129                                                            }
130                                                         }
131                                                   
132   ***      2    100     66                   15         if ( scalar @vals && grep { defined } @vals ) {
               4                                 22   
133            1                                  3            $report->add_line($thing, map { '' } @$hosts);
               2                                  8   
134            1                                106            my @metrics = qw(sum min max avg pct_95 stddev median);
135            1                                  7            for my $i ( 0..$#metrics ) {
136            7                                591               my @n = '  ' . $metrics[$i];
137   ***      7     50     33                   21               push @n, map { $_ && defined $_->[$i] ? $_->[$i] : '' } @vals;
              14                                124   
138            7                                 37               $report->add_line(@n);
139                                                            }
140                                                         }
141                                                      }
142                                                   
143            1                                  6      push @result, $report->get_report();
144                                                   
145            1                               3676      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
               5                                 31   
               5                                 35   
146                                                   }
147                                                   
148                                                   # Convert attribute names into labels
149                                                   sub make_label {
150   ***      2                    2      0      8      my ( $val ) = @_;
151                                                   
152            2                                  8      $val =~ s/^different_//;
153            2                                  9      $val =~ s/_/ /g;
154                                                   
155            2                                 16      return $val;
156                                                   }
157                                                   
158                                                   # Does pretty-printing for lists of strings like users, hosts, db.
159                                                   sub format_string_list {
160   ***      0                    0      0      0      my ( $stats ) = @_;
161   ***      0      0                           0      if ( exists $stats->{unq} ) {
162                                                         # Only class stats have unq.
163   ***      0                                  0         my $cnt_for = $stats->{unq};
164   ***      0      0                           0         if ( 1 == keys %$cnt_for ) {
165   ***      0                                  0            my ($str) = keys %$cnt_for;
166                                                            # - 30 for label, spacing etc.
167   ***      0      0                           0            $str = substr($str, 0, LINE_LENGTH - 30) . '...'
168                                                               if length $str > LINE_LENGTH - 30;
169   ***      0                                  0            return (1, $str);
170                                                         }
171   ***      0                                  0         my $line = '';
172   ***      0      0                           0         my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
      ***      0                                  0   
173                                                                        keys %$cnt_for;
174   ***      0                                  0         my $i = 0;
175   ***      0                                  0         foreach my $str ( @top ) {
176   ***      0                                  0            my $print_str;
177   ***      0      0                           0            if ( length $str > MAX_STRING_LENGTH ) {
178   ***      0                                  0               $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
179                                                            }
180                                                            else {
181   ***      0                                  0               $print_str = $str;
182                                                            }
183   ***      0      0                           0            last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
184   ***      0                                  0            $line .= "$print_str ($cnt_for->{$str}), ";
185   ***      0                                  0            $i++;
186                                                         }
187   ***      0                                  0         $line =~ s/, $//;
188   ***      0      0                           0         if ( $i < @top ) {
189   ***      0                                  0            $line .= "... " . (@top - $i) . " more";
190                                                         }
191   ***      0                                  0         return (scalar keys %$cnt_for, $line);
192                                                      }
193                                                      else {
194                                                         # Global stats don't have unq.
195   ***      0                                  0         return ($stats->{cnt});
196                                                      }
197                                                   }
198                                                   
199                                                   sub _d {
200            1                    1             8      my ($package, undef, $line) = caller 0;
201   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  7   
               2                                 10   
202            1                                  4           map { defined $_ ? $_ : 'undef' }
203                                                           @_;
204            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
205                                                   }
206                                                   
207                                                   1;
208                                                   
209                                                   # ###########################################################################
210                                                   # End UpgradeReportFormatter package
211                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
54    ***     50      0      5   unless $args{$arg}
99           100      2      2   if ($stats and $$stats{$thing}) { }
115          100      2      2   if ($stats and $$stats{$thing}) { }
117   ***     50      2      0   $thing =~ /time$/ ? :
124   ***     50     14      0   defined $_ ? :
132          100      1      1   if (scalar @vals and grep {defined $_;} @vals)
137   ***     50     14      0   $_ && defined $$_[$i] ? :
161   ***      0      0      0   if (exists $$stats{'unq'}) { }
164   ***      0      0      0   if (1 == keys %$cnt_for)
167   ***      0      0      0   if length $str > 44
172   ***      0      0      0   unless $$cnt_for{$b} <=> $$cnt_for{$a}
177   ***      0      0      0   if (length $str > 10) { }
183   ***      0      0      0   if length($line) + length($print_str) > 47
188   ***      0      0      0   if ($i < @top)
201   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
99    ***     66      0      2      2   $stats and $$stats{$thing}
115   ***     66      0      2      2   $stats and $$stats{$thing}
132   ***     66      0      1      1   scalar @vals and grep {defined $_;} @vals
137   ***     33      0      0     14   $_ && defined $$_[$i]

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
62    ***     50      1      0   $rank || 0
74    ***     50      1      0   $$class{'differences'}{'sum'} || 0
122   ***     50      2      0   $$vals{'sum'} || 0
      ***     50      2      0   $$vals{'cnt'} || 1


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                                     
------------------ ----- --- -------------------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:24 
BEGIN                  1     /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:25 
BEGIN                  1     /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:26 
BEGIN                  1     /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:29 
BEGIN                  1     /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:30 
BEGIN                  1     /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:31 
_d                     1     /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:200
event_report           1   0 /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:51 
make_label             2   0 /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:150
new                    1   0 /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:46 

Uncovered Subroutines
---------------------

Subroutine         Count Pod Location                                                     
------------------ ----- --- -------------------------------------------------------------
format_string_list     0   0 /home/daniel/dev/maatkit/common/UpgradeReportFormatter.pm:160


UpgradeReportFormatter.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            11   use Test::More tests => 3;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            13   use Transformers;
               1                                  3   
               1                                 10   
15             1                    1            10   use EventAggregator;
               1                                  4   
               1                                 20   
16             1                    1            14   use QueryRewriter;
               1                                  3   
               1                                 11   
17             1                    1            11   use ReportFormatter;
               1                                  3   
               1                                 11   
18             1                    1            12   use UpgradeReportFormatter;
               1                                  3   
               1                                 10   
19             1                    1            14   use MaatkitTest;
               1                                  6   
               1                                 41   
20                                                    
21             1                                  4   my $result;
22             1                                  3   my $expected;
23             1                                  5   my ($meta_events, $events1, $events2, $meta_ea, $ea1, $ea2);
24                                                    
25             1                                 10   my $qr  = new QueryRewriter();
26             1                                 32   my $urf = new UpgradeReportFormatter();
27                                                    
28                                                    sub aggregate {
29             1                    1             4      foreach my $event (@$meta_events) {
30             3                                 21         $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
31             3                                251         $meta_ea->aggregate($event);
32                                                       }
33             1                                  5      foreach my $event (@$events1) {
34             3                                 29         $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
35             3                                203         $ea1->aggregate($event);
36                                                       }
37             1                                 13      $ea1->calculate_statistical_metrics();
38             1                              29741      foreach my $event (@$events2) {
39             3                                 27         $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
40             3                                217         $ea2->aggregate($event);
41                                                       }
42             1                                  9      $ea2->calculate_statistical_metrics(); 
43                                                    }
44                                                    
45             1                                 10   $meta_ea = new EventAggregator(
46                                                       groupby => 'fingerprint',
47                                                       worst   => 'differences',
48                                                    );
49             1                                107   $ea1 = new EventAggregator(
50                                                       groupby => 'fingerprint',
51                                                       worst   => 'Query_time',
52                                                    );
53             1                                 90   $ea2 = new EventAggregator(
54                                                       groupby => 'fingerprint',
55                                                       worst   => 'Query_time',
56                                                    );
57                                                    
58             1                                 84   isa_ok($urf, 'UpgradeReportFormatter');
59                                                    
60             1                                 26   $events1 = [
61                                                       {
62                                                          cmd           => 'Query',
63                                                          arg           => "SELECT id FROM users WHERE name='foo'",
64                                                          Query_time    => '8.000652',
65                                                          pos_in_log    => 1,
66                                                          db            => 'test1',
67                                                          Errors        => 'No',
68                                                       },
69                                                       {
70                                                          cmd  => 'Query',
71                                                          arg           => "SELECT id FROM users WHERE name='foo'",
72                                                          Query_time    => '1.001943',
73                                                          pos_in_log    => 2,
74                                                          db            => 'test1',
75                                                          Errors        => 'Yes',
76                                                       },
77                                                       {
78                                                          cmd           => 'Query',
79                                                          arg           => "SELECT id FROM users WHERE name='bar'",
80                                                          Query_time    => '1.000682',
81                                                          pos_in_log    => 5,
82                                                          db            => 'test1',
83                                                          Errors        => 'No',
84                                                       },
85                                                    ];
86             1                                  3   $events2 = $events1;
87             1                                 19   $meta_events = [
88                                                       {
89                                                          arg => "SELECT id FROM users WHERE name='bar'",
90                                                          differences          => 0,
91                                                          different_row_counts => 0,
92                                                          different_checksums  => 0,
93                                                          sampleno             => 1,
94                                                       },
95                                                       {
96                                                          arg => "SELECT id FROM users WHERE name='bar'",
97                                                          differences          => 0,
98                                                          different_row_counts => 0,
99                                                          different_checksums  => 0,
100                                                         sampleno             => 2,
101                                                      },
102                                                      {
103                                                         arg => "SELECT id FROM users WHERE name='bar'",
104                                                         differences          => 1,
105                                                         different_row_counts => 1,
106                                                         different_checksums  => 0,
107                                                         sampleno             => 3,
108                                                      },
109                                                   ];
110                                                   
111            1                                  3   $expected = <<EOF;
112                                                   # Query 1: ID 0x82860EDA9A88FCC5 at byte 0 _______________________________
113                                                   # Found 1 differences in 3 samples:
114                                                   #   checksums       0
115                                                   #   row counts      1
116                                                   #            host1 host2
117                                                   # Errors         1     1
118                                                   # Warnings       0     0
119                                                   # Query_time            
120                                                   #   sum        10s   10s
121                                                   #   min         1s    1s
122                                                   #   max         8s    8s
123                                                   #   avg         3s    3s
124                                                   #   pct_95      8s    8s
125                                                   #   stddev      3s    3s
126                                                   #   median   992ms 992ms
127                                                   EOF
128                                                   
129            1                                  4   aggregate();
130                                                   
131            1                              29707   $result = $urf->event_report(
132                                                      meta_ea  => $meta_ea,
133                                                      hosts    => [ {name=>'host1', ea=>$ea1},
134                                                                    {name=>'host2', ea=>$ea2} ],
135                                                      where   => 'select id from users where name=?',
136                                                      rank    => 1,
137                                                      worst   => 'differences',
138                                                   );
139                                                   
140            1                                  8   is($result, $expected, 'Event report');
141                                                   
142                                                   # #############################################################################
143                                                   # Done.
144                                                   # #############################################################################
145            1                                  4   my $output = '';
146                                                   {
147            1                                  3      local *STDERR;
               1                                  7   
148            1                    1             2      open STDERR, '>', \$output;
               1                                308   
               1                                  3   
               1                                  6   
149            1                                 18      $urf->_d('Complete test coverage');
150                                                   }
151                                                   like(
152            1                                 17      $output,
153                                                      qr/Complete test coverage/,
154                                                      '_d() works'
155                                                   );
156            1                                  3   exit;


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
---------- ----- ----------------------------
BEGIN          1 UpgradeReportFormatter.t:10 
BEGIN          1 UpgradeReportFormatter.t:11 
BEGIN          1 UpgradeReportFormatter.t:12 
BEGIN          1 UpgradeReportFormatter.t:14 
BEGIN          1 UpgradeReportFormatter.t:148
BEGIN          1 UpgradeReportFormatter.t:15 
BEGIN          1 UpgradeReportFormatter.t:16 
BEGIN          1 UpgradeReportFormatter.t:17 
BEGIN          1 UpgradeReportFormatter.t:18 
BEGIN          1 UpgradeReportFormatter.t:19 
BEGIN          1 UpgradeReportFormatter.t:4  
BEGIN          1 UpgradeReportFormatter.t:9  
aggregate      1 UpgradeReportFormatter.t:29 


