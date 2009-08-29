---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/TextResultSetParser.pm   73.2   50.0    n/a   84.6    n/a  100.0   70.6
Total                          73.2   50.0    n/a   84.6    n/a  100.0   70.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TextResultSetParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:04:29 2009
Finish:       Sat Aug 29 15:04:29 2009

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
18                                                    # TextResultSetParser package $Revision: 4198 $
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
41             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
42             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
43                                                    
44             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  9   
45                                                    $Data::Dumper::Indent    = 1;
46                                                    $Data::Dumper::Sortkeys  = 1;
47                                                    $Data::Dumper::Quotekeys = 0;
48                                                    
49             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
50                                                    
51                                                    # Possible args:
52                                                    #   * value_for    Hashref of original_val => new_val, used to alter values
53                                                    #
54                                                    sub new {
55             1                    1             5      my ( $class, %args ) = @_;
56             1                                  4      my $self = { %args };
57             1                                 13      return bless $self, $class;
58                                                    }
59                                                    
60                                                    sub _parse_tabular {
61             2                    2             9      my ( $text, @cols ) = @_;
62             2                                  6      my %row;
63             2                                 34      my @vals = $text =~ m/\| +([^\|]*?)(?= +\|)/msg;
64             2    100                          14      return (undef, \@vals) unless @cols;
65             1                                  8      @row{@cols} = @vals;
66             1                                  5      return (\%row, undef);
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
79           167                  167           621      my ( $text ) = @_;
80           167                               4383      my %row = $text =~ m/^\s*(\w+):(?: ([^\n]*))?/msg;
81           167                                662      MKDEBUG && _d('vertical row:', Dumper(\%row));
82           167                               2076      return \%row;
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
94             5                    5           194      my ( $self, $text ) = @_;
95             5                                 16      my $result_set;
96                                                    
97                                                       # Detect text type: tabular, tab-separated, or vertical
98             5    100                         168      if ( $text =~ m/^\+---/m ) { # standard "tabular" output
      ***            50                               
      ***            50                               
99             1                                  2         MKDEBUG && _d('Result set text is standard tabular');
100            1                                 10         my $line_pattern  = qr/^(\| .*)[\r\n]+/m;
101            1                                  4         $result_set
102                                                            = parse_horizontal_row($text, $line_pattern, \&_parse_tabular);
103                                                      }
104                                                      elsif ( $text =~ m/^id\tselect_type\t/m ) { # tab-separated
105   ***      0                                  0         MKDEBUG && _d('Result set text is tab-separated');
106   ***      0                                  0         my $line_pattern  = qr/^(.*?\t.*)[\r\n]+/m;
107   ***      0                                  0         $result_set
108                                                            = parse_horizontal_row($text, $line_pattern, \&_parse_tab_sep);
109                                                      }
110                                                      elsif ( $text =~ m/\*\*\* \d+\. row/ ) { # "vertical" output
111            4                                 10         MKDEBUG && _d('Result set text is vertical (\G)');
112            4                                 18         foreach my $row ( split_vertical_rows($text) ) {
113          167                                623            push @$result_set, parse_vertical_row($row);
114                                                         }
115                                                      }
116                                                      else {
117   ***      0                                  0         die "Cannot determine if text is tabular, tab-separated or veritcal:\n"
118                                                            . $text;
119                                                      }
120                                                   
121                                                      # Convert values.
122   ***      5     50                          49      if ( $self->{value_for} ) {
123   ***      0                                  0         foreach my $result_set ( @$result_set ) {
124   ***      0                                  0            foreach my $key ( keys %$result_set ) {
125   ***      0      0                           0               $result_set->{$key} = $self->{value_for}->{ $result_set->{$key} }
126                                                                  if exists $self->{value_for}->{ $result_set->{$key} };
127                                                            }
128                                                         }
129                                                      }
130                                                   
131            5                                 59      return $result_set;
132                                                   }
133                                                   
134                                                   sub parse_horizontal_row {
135            1                    1             5      my ( $text, $line_pattern, $sub ) = @_;
136            1                                  3      my @result_sets = ();
137            1                                  3      my @cols        = ();
138            1                                 15      foreach my $line ( $text =~ m/$line_pattern/g ) {
139            2                                 10         my ( $row, $cols ) = $sub->($line, @cols);
140            2    100                           8         if ( $row ) {
141            1                                  9            push @result_sets, $row;
142                                                         }
143                                                         else {
144            1                                  7            @cols = @$cols;
145                                                         }
146                                                      }
147            1                                 10      return \@result_sets;
148                                                   }
149                                                   
150                                                   sub split_vertical_rows {
151            4                    4           100      my ( $text ) = @_;
152            4                                 14      my $ROW_HEADER = '\*{3,} \d+\. row \*{3,}';
153            4                              10139      my @rows = $text =~ m/($ROW_HEADER.*?)(?=$ROW_HEADER|\z)/omgs;
154            4                                104      return @rows;
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


Covered Subroutines
-------------------

Subroutine           Count Location                                                  
-------------------- ----- ----------------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:40 
BEGIN                    1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:41 
BEGIN                    1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:42 
BEGIN                    1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:44 
BEGIN                    1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:49 
_parse_tabular           2 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:61 
new                      1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:55 
parse                    5 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:94 
parse_horizontal_row     1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:135
parse_vertical_row     167 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:79 
split_vertical_rows      4 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:151

Uncovered Subroutines
---------------------

Subroutine           Count Location                                                  
-------------------- ----- ----------------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:158
_parse_tab_sep           0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:70 


