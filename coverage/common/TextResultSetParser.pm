---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/TextResultSetParser.pm   73.2   50.0   50.0   84.6    0.0   97.9   67.0
TextResultSetParser.t         100.0   50.0   33.3  100.0    n/a    2.1   92.9
Total                          81.2   50.0   40.0   90.0    0.0  100.0   74.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:36 2010
Finish:       Thu Jun 24 19:38:36 2010

Run:          TextResultSetParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:37 2010
Finish:       Thu Jun 24 19:38:37 2010

/home/daniel/dev/maatkit/common/TextResultSetParser.pm

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
18                                                    # TextResultSetParser package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package TextResultSetParser;
21                                                    
22                                                    # TextResultSetParser converts the formatted text output of a result set, like
23                                                    # what SHOW PROCESSLIST and EXPLAIN print, into a data struct, like what
24                                                    # DBI::selectall_arrayref() returns.  So this:
25                                                    #   +----+------+
26                                                    #   | Id | User |
27                                                    #   +----+------+
28                                                    #   | 1  | bob  |
29                                                    #   +----+------+
30                                                    # becomes this:
31                                                    #   [
32                                                    #      {
33                                                    #         Id   => '1',
34                                                    #         User => 'bob',
35                                                    #      },
36                                                    #   ]
37                                                    #
38                                                    # Both horizontal and vertical (\G) text outputs are supported.
39                                                    
40             1                    1             5   use strict;
               1                                  2   
               1                                  7   
41             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
42             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
43                                                    
44             1                    1             5   use Data::Dumper;
               1                                  3   
               1                                  6   
45                                                    $Data::Dumper::Indent    = 1;
46                                                    $Data::Dumper::Sortkeys  = 1;
47                                                    $Data::Dumper::Quotekeys = 0;
48                                                    
49    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 14   
50                                                    
51                                                    # Possible args:
52                                                    #   * value_for    Hashref of original_val => new_val, used to alter values
53                                                    #
54                                                    sub new {
55    ***      1                    1      0      6      my ( $class, %args ) = @_;
56             1                                  5      my $self = { %args };
57             1                                 12      return bless $self, $class;
58                                                    }
59                                                    
60                                                    sub _parse_tabular {
61             2                    2            12      my ( $text, @cols ) = @_;
62             2                                  6      my %row;
63             2                                 39      my @vals = $text =~ m/\| +([^\|]*?)(?= +\|)/msg;
64             2    100                          15      return (undef, \@vals) unless @cols;
65             1                                 11      @row{@cols} = @vals;
66             1                                  6      return (\%row, undef);
67                                                    }
68                                                    
69                                                    sub _parse_tab_sep {
70    ***      0                    0             0      my ( $text, @cols ) = @_;
71    ***      0                                  0      my %row;
72    ***      0                                  0      my @vals = split(/\t/, $text);
73    ***      0      0                           0      return (undef, \@vals) unless @cols;
74    ***      0                                  0      @row{@cols} = @vals;
75    ***      0                                  0      return (\%row, undef);
76                                                    }
77                                                    
78                                                    sub parse_vertical_row {
79    ***    167                  167      0    615      my ( $text ) = @_;
80           167                               3849      my %row = $text =~ m/^\s*(\w+):(?: ([^\n]*))?/msg;
81           167                                674      MKDEBUG && _d('vertical row:', Dumper(\%row));
82           167                                713      return \%row;
83                                                    }
84                                                    
85                                                    # Returns a result set like:
86                                                    # [
87                                                    #    {
88                                                    #       Time     => '5',
89                                                    #       Command  => 'Query',
90                                                    #       db       => 'foo',
91                                                    #    },
92                                                    # ]
93                                                    sub parse {
94    ***      5                    5      0    220      my ( $self, $text ) = @_;
95             5                                 18      my $result_set;
96                                                    
97                                                       # Detect text type: tabular, tab-separated, or vertical
98             5    100                         178      if ( $text =~ m/^\+---/m ) { # standard "tabular" output
      ***            50                               
      ***            50                               
99             1                                  3         MKDEBUG && _d('Result set text is standard tabular');
100            1                                 15         my $line_pattern  = qr/^(\| .*)[\r\n]+/m;
101            1                                  8         $result_set
102                                                            = parse_horizontal_row($text, $line_pattern, \&_parse_tabular);
103                                                      }
104                                                      elsif ( $text =~ m/^id\tselect_type\t/m ) { # tab-separated
105   ***      0                                  0         MKDEBUG && _d('Result set text is tab-separated');
106   ***      0                                  0         my $line_pattern  = qr/^(.*?\t.*)[\r\n]+/m;
107   ***      0                                  0         $result_set
108                                                            = parse_horizontal_row($text, $line_pattern, \&_parse_tab_sep);
109                                                      }
110                                                      elsif ( $text =~ m/\*\*\* \d+\. row/ ) { # "vertical" output
111            4                                 11         MKDEBUG && _d('Result set text is vertical (\G)');
112            4                                 20         foreach my $row ( split_vertical_rows($text) ) {
113          167                                617            push @$result_set, parse_vertical_row($row);
114                                                         }
115                                                      }
116                                                      else {
117   ***      0                                  0         die "Cannot determine if text is tabular, tab-separated or veritcal:\n"
118                                                            . $text;
119                                                      }
120                                                   
121                                                      # Convert values.
122   ***      5     50                          44      if ( $self->{value_for} ) {
123   ***      0                                  0         foreach my $result_set ( @$result_set ) {
124   ***      0                                  0            foreach my $key ( keys %$result_set ) {
125   ***      0      0                           0               $result_set->{$key} = $self->{value_for}->{ $result_set->{$key} }
126                                                                  if exists $self->{value_for}->{ $result_set->{$key} };
127                                                            }
128                                                         }
129                                                      }
130                                                   
131            5                                 64      return $result_set;
132                                                   }
133                                                   
134                                                   sub parse_horizontal_row {
135   ***      1                    1      0      5      my ( $text, $line_pattern, $sub ) = @_;
136            1                                  5      my @result_sets = ();
137            1                                  3      my @cols        = ();
138            1                                 15      foreach my $line ( $text =~ m/$line_pattern/g ) {
139            2                                  9         my ( $row, $cols ) = $sub->($line, @cols);
140            2    100                          10         if ( $row ) {
141            1                                  6            push @result_sets, $row;
142                                                         }
143                                                         else {
144            1                                  8            @cols = @$cols;
145                                                         }
146                                                      }
147            1                                 11      return \@result_sets;
148                                                   }
149                                                   
150                                                   sub split_vertical_rows {
151   ***      4                    4      0     98      my ( $text ) = @_;
152            4                                 16      my $ROW_HEADER = '\*{3,} \d+\. row \*{3,}';
153            4                              13257      my @rows = $text =~ m/($ROW_HEADER.*?)(?=$ROW_HEADER|\z)/omgs;
154            4                                102      return @rows;
155                                                   }
156                                                   
157                                                   sub _d {
158   ***      0                    0                    my ($package, undef, $line) = caller 0;
159   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
160   ***      0                                              map { defined $_ ? $_ : 'undef' }
161                                                           @_;
162   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
163                                                   }
164                                                   
165                                                   1;
166                                                   
167                                                   # ###########################################################################
168                                                   # End TextResultSetParser package
169                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
64           100      1      1   unless @cols
73    ***      0      0      0   unless @cols
98           100      1      4   if ($text =~ /^\+---/m) { }
      ***     50      0      4   elsif ($text =~ /^id\tselect_type\t/m) { }
      ***     50      4      0   elsif ($text =~ /\*\*\* \d+\. row/) { }
122   ***     50      0      5   if ($$self{'value_for'})
125   ***      0      0      0   if exists $$self{'value_for'}{$$result_set{$key}}
140          100      1      1   if ($row) { }
159   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
49    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                                  
-------------------- ----- --- ----------------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:40 
BEGIN                    1     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:41 
BEGIN                    1     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:42 
BEGIN                    1     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:44 
BEGIN                    1     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:49 
_parse_tabular           2     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:61 
new                      1   0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:55 
parse                    5   0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:94 
parse_horizontal_row     1   0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:135
parse_vertical_row     167   0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:79 
split_vertical_rows      4   0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:151

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                                  
-------------------- ----- --- ----------------------------------------------------------
_d                       0     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:158
_parse_tab_sep           0     /home/daniel/dev/maatkit/common/TextResultSetParser.pm:70 


TextResultSetParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            31      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
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
               1                                  8   
12             1                    1            10   use Test::More tests => 6;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use TextResultSetParser;
               1                                  3   
               1                                 10   
15             1                    1            16   use MaatkitTest;
               1                                  5   
               1                                 44   
16                                                    
17             1                                  8   my $r = new TextResultSetParser();
18             1                                 13   isa_ok($r, 'TextResultSetParser');
19                                                    
20             1                                 15   is_deeply(
21                                                       $r->parse( load_file('common/t/samples/pl/recset001.txt') ),
22                                                       [
23                                                          {
24                                                             Time     => '0',
25                                                             Command  => 'Query',
26                                                             db       => '',
27                                                             Id       => '9',
28                                                             Info     => 'show processlist',
29                                                             User     => 'msandbox',
30                                                             State    => '',
31                                                             Host     => 'localhost'
32                                                          },
33                                                       ],
34                                                       'Basic tablular processlist'
35                                                    );
36                                                    
37             1                                 20   is_deeply(
38                                                       $r->parse( load_file('common/t/samples/pl/recset002.txt') ),
39                                                       [
40                                                          {
41                                                             Time     => '4',
42                                                             Command  => 'Query',
43                                                             db       => 'foo',
44                                                             Id       => '1',
45                                                             Info     => 'select * from foo1;',
46                                                             User     => 'user1',
47                                                             State    => 'Locked',
48                                                             Host     => '1.2.3.4:3333'
49                                                          },
50                                                          {
51                                                             Time     => '5',
52                                                             Command  => 'Query',
53                                                             db       => 'foo',
54                                                             Id       => '2',
55                                                             Info     => 'select * from foo2;',
56                                                             User     => 'user1',
57                                                             State    => 'Locked',
58                                                             Host     => '1.2.3.4:5455'
59                                                          },
60                                                       ],
61                                                       '2 row vertical processlist'
62                                                    );
63                                                    
64             1                                 18   my $recset = $r->parse ( load_file('common/t/samples/pl/recset003.txt') );
65             1                                  8   cmp_ok(
66                                                       scalar @$recset,
67                                                       '==',
68                                                       113,
69                                                       '113 row vertical processlist'
70                                                    );
71                                                    
72             1                                  5   $recset = $r->parse( load_file('common/t/samples/pl/recset004.txt') );
73             1                                143   cmp_ok(
74                                                       scalar @$recset,
75                                                       '==',
76                                                       51,
77                                                       '51 row vertical processlist'
78                                                    );
79                                                    
80             1                                  8   is_deeply(
81                                                       $r->parse( load_file('common/t/samples/pl/recset005.txt') ),
82                                                       [
83                                                          {
84                                                             Id    => '29392005',
85                                                             User  => 'remote',
86                                                             Host  => '1.2.3.148:49718',
87                                                             db    => 'happy',
88                                                             Command => 'Sleep',
89                                                             Time  => '17',
90                                                             State => undef,
91                                                             Info  => 'NULL',
92                                                          }
93                                                       ],
94                                                       '1 vertical row, No State value'
95                                                    );
96                                                    
97                                                    # #############################################################################
98                                                    # Done.
99                                                    # #############################################################################
100            1                                  3   exit;


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
---------- ----- ------------------------
BEGIN          1 TextResultSetParser.t:10
BEGIN          1 TextResultSetParser.t:11
BEGIN          1 TextResultSetParser.t:12
BEGIN          1 TextResultSetParser.t:14
BEGIN          1 TextResultSetParser.t:15
BEGIN          1 TextResultSetParser.t:4 
BEGIN          1 TextResultSetParser.t:9 


