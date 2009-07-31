---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/EventTimeline.pm   90.9   67.9   50.0   92.9    n/a  100.0   85.0
Total                          90.9   67.9   50.0   92.9    n/a  100.0   85.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          EventTimeline.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:50 2009
Finish:       Fri Jul 31 18:51:50 2009

/home/daniel/dev/maatkit/common/EventTimeline.pm

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
19                                                    # EventTimeline package $Revision: 3539 $
20                                                    # ###########################################################################
21                                                    
22                                                    package EventTimeline;
23                                                    
24                                                    # This package's function is to take hashrefs and aggregate them together by a
25                                                    # specified attribute, but only if they are adjacent to each other.
26                                                    
27             1                    1             7   use strict;
               1                                  3   
               1                                  5   
28             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
29             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
30                                                    Transformers->import(qw(parse_timestamp secs_to_time unix_timestamp));
31                                                    
32             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
33             1                    1             5   use constant KEY     => 0;
               1                                  3   
               1                                  4   
34             1                    1             5   use constant CNT     => 1;
               1                                  3   
               1                                 13   
35             1                    1             6   use constant ATT     => 2;
               1                                  6   
               1                                  4   
36                                                    
37                                                    # The best way to see how to use this is to look at the .t file.
38                                                    #
39                                                    # %args is a hash containing:
40                                                    # groupby      An arrayref of names of properties to group/aggregate by.
41                                                    # attributes   An arrayref of names of properties to aggregate.
42                                                    #              Aggregation keeps the min, max and sum if it's a numeric
43                                                    #              attribute.
44                                                    sub new {
45             1                    1            20      my ( $class, %args ) = @_;
46             1                                  4      foreach my $arg ( qw(groupby attributes) ) {
47    ***      2     50                          11         die "I need a $arg argument" unless $args{$arg};
48                                                       }
49                                                    
50             1                                  3      my %is_groupby = map { $_ => 1 } @{$args{groupby}};
               1                                  5   
               1                                  4   
51                                                    
52             2                                 17      return bless {
53                                                          groupby    => $args{groupby},
54             1                                  4         attributes => [ grep { !$is_groupby{$_} } @{$args{attributes}} ],
               1                                  3   
55                                                          results    => [],
56                                                       }, $class;
57                                                    }
58                                                    
59                                                    # Reset the aggregated data, but not anything the code has learned about
60                                                    # incoming data.
61                                                    sub reset_aggregated_data {
62             1                    1             4      my ( $self ) = @_;
63             1                                  8      $self->{results} = [];
64                                                    }
65                                                    
66                                                    # Aggregate an event hashref's properties.
67                                                    sub aggregate {
68             4                    4            28      my ( $self, $event ) = @_;
69             4                                 13      my $handler = $self->{handler};
70             4    100                          15      if ( !$handler ) {
71             1                                  4         $handler = $self->make_handler($event);
72             1                                  4         $self->{handler} = $handler;
73                                                       }
74    ***      4     50                          16      return unless $handler;
75             4                                 14      $handler->($event);
76                                                    }
77                                                    
78                                                    # Return the aggregated results.
79                                                    sub results {
80             3                    3            14      my ( $self ) = @_;
81             3                                 21      return $self->{results};
82                                                    }
83                                                    
84                                                    # Make subroutines that do things with events.
85                                                    #
86                                                    # $event:  a sample event
87                                                    #
88                                                    # Return value:
89                                                    # a subroutine with this signature:
90                                                    #    my ( $event ) = @_;
91                                                    sub make_handler {
92             1                    1             3      my ( $self, $event ) = @_;
93                                                    
94                                                       # Ripped off from Regexp::Common::number.
95             1                                  5      my $float_re = qr{[+-]?(?:(?=\d|[.])\d*(?:[.])\d{0,})?(?:[E](?:[+-]?\d+)|)}i;
96             1                                  3      my @lines; # lines of code for the subroutine
97                                                    
98             1                                  2      foreach my $attrib ( @{$self->{attributes}} ) {
               1                                  5   
99             2                                  8         my ($val) = $event->{$attrib};
100   ***      2     50                           8         next unless defined $val; # Can't decide type if it's undef.
101                                                   
102   ***      2     50                          63         my $type = $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
                    100                               
103                                                                  : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
104                                                                  :                                    'string';
105            2                                  5         MKDEBUG && _d('Type for', $attrib, 'is', $type, '(sample:', $val, ')');
106            2                                  7         $self->{type_for}->{$attrib} = $type;
107                                                   
108            2                                 14         push @lines, (
109                                                            "\$val = \$event->{$attrib};",
110                                                            'defined $val && do {',
111                                                            "# type: $type",
112                                                            "\$store = \$last->[ATT]->{$attrib} ||= {};",
113                                                         );
114                                                   
115   ***      2     50                           8         if ( $type eq 'bool' ) {
116   ***      0                                  0            push @lines, q{$val = $val eq 'Yes' ? 1 : 0;};
117   ***      0                                  0            $type = 'num';
118                                                         }
119            2    100                           7         my $op   = $type eq 'num' ? '<' : 'lt';
120            2                                  9         push @lines, (
121                                                            '$store->{min} = $val if !defined $store->{min} || $val '
122                                                               . $op . ' $store->{min};',
123                                                         );
124            2    100                          10         $op = ($type eq 'num') ? '>' : 'gt';
125            2                                  8         push @lines, (
126                                                            '$store->{max} = $val if !defined $store->{max} || $val '
127                                                               . $op . ' $store->{max};',
128                                                         );
129            2    100                           8         if ( $type eq 'num' ) {
130            1                                  3            push @lines, '$store->{sum} += $val;';
131                                                         }
132            2                                  9         push @lines, '};';
133                                                      }
134                                                   
135                                                      # Build a subroutine with the code.
136            1                                 10      unshift @lines, (
137                                                         'sub {',
138                                                         'my ( $event ) = @_;',
139                                                         'my ($val, $last, $store);', # NOTE: define all variables here
140                                                         '$last = $results->[-1];',
141                                                         'if ( !$last || '
142                                                            . join(' || ',
143            1                                 11               map { "\$last->[KEY]->[$_] ne (\$event->{$self->{groupby}->[$_]} || 0)" }
144            1                                 10                   (0 .. @{$self->{groupby}} -1))
145                                                            . ' ) {',
146                                                         '  $last = [['
147                                                            . join(', ',
148            1                                  5               map { "(\$event->{$self->{groupby}->[$_]} || 0)" }
149            1                                  5                   (0 .. @{$self->{groupby}} -1))
150                                                            . '], 0, {} ];',
151                                                         '  push @$results, $last;',
152                                                         '}',
153                                                         '++$last->[CNT];',
154                                                      );
155            1                                  3      push @lines, '}';
156            1                                  4      my $results = $self->{results}; # Referred to by the eval
157            1                                 10      my $code = join("\n", @lines);
158            1                                  3      $self->{code} = $code;
159                                                   
160            1                                  2      MKDEBUG && _d('Timeline handler:', $code);
161            1                                  2      my $sub = eval $code;
162   ***      1     50                           5      die if $EVAL_ERROR;
163            1                                 11      return $sub;
164                                                   }
165                                                   
166                                                   sub report {
167            1                    1             5      my ( $self, $results, $callback ) = @_;
168            1                                  7      $callback->("# " . ('#' x 72) . "\n");
169            1                                  6      $callback->("# " . join(',', @{$self->{groupby}}) . " report\n");
               1                                  7   
170            1                                  8      $callback->("# " . ('#' x 72) . "\n");
171            1                                  7      foreach my $res ( @$results ) {
172            3                                 17         my $t;
173            3                                  8         my @vals;
174   ***      3     50     33                   29         if ( ($t = $res->[ATT]->{ts}) && $t->{min} ) {
175            3                                 14            my $min = parse_timestamp($t->{min});
176            3                                 12            push @vals, $min;
177   ***      3    100     66                   30            if ( $t->{max} && $t->{max} gt $t->{min} ) {
178            1                                  4               my $max  = parse_timestamp($t->{max});
179            1                                  5               my $diff = secs_to_time(unix_timestamp($max) - unix_timestamp($min));
180            1                                  5               push @vals, $diff;
181                                                            }
182                                                            else {
183            2                                  6               push @vals, '0:00';
184                                                            }
185                                                         }
186                                                         else {
187   ***      0                                  0            push @vals, ('', '');
188                                                         }
189            3                                 28         $callback->(sprintf("# %19s %7s %3d %s\n", @vals, $res->[CNT], $res->[KEY]->[0]));
190                                                      }
191                                                   }
192                                                   
193                                                   sub _d {
194   ***      0                    0                    my ($package, undef, $line) = caller 0;
195   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
196   ***      0                                              map { defined $_ ? $_ : 'undef' }
197                                                           @_;
198   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
199                                                   }
200                                                   
201                                                   1;
202                                                   
203                                                   # ###########################################################################
204                                                   # End EventTimeline package
205                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
47    ***     50      0      2   unless $args{$arg}
70           100      1      3   if (not $handler)
74    ***     50      0      4   unless $handler
100   ***     50      0      2   unless defined $val
102   ***     50      0      1   $val =~ /^(?:Yes|No)$/ ? :
             100      1      1   $val =~ /^(?:\d+|$float_re)$/o ? :
115   ***     50      0      2   if ($type eq 'bool')
119          100      1      1   $type eq 'num' ? :
124          100      1      1   $type eq 'num' ? :
129          100      1      1   if ($type eq 'num')
162   ***     50      0      1   if $EVAL_ERROR
174   ***     50      3      0   if ($t = $$res[2]{'ts'} and $$t{'min'}) { }
177          100      1      2   if ($$t{'max'} and $$t{'max'} gt $$t{'min'}) { }
195   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
174   ***     33      0      0      3   $t = $$res[2]{'ts'} and $$t{'min'}
177   ***     66      0      2      1   $$t{'max'} and $$t{'max'} gt $$t{'min'}


Covered Subroutines
-------------------

Subroutine            Count Location                                            
--------------------- ----- ----------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:27 
BEGIN                     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:28 
BEGIN                     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:29 
BEGIN                     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:32 
BEGIN                     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:33 
BEGIN                     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:34 
BEGIN                     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:35 
aggregate                 4 /home/daniel/dev/maatkit/common/EventTimeline.pm:68 
make_handler              1 /home/daniel/dev/maatkit/common/EventTimeline.pm:92 
new                       1 /home/daniel/dev/maatkit/common/EventTimeline.pm:45 
report                    1 /home/daniel/dev/maatkit/common/EventTimeline.pm:167
reset_aggregated_data     1 /home/daniel/dev/maatkit/common/EventTimeline.pm:62 
results                   3 /home/daniel/dev/maatkit/common/EventTimeline.pm:80 

Uncovered Subroutines
---------------------

Subroutine            Count Location                                            
--------------------- ----- ----------------------------------------------------
_d                        0 /home/daniel/dev/maatkit/common/EventTimeline.pm:194


