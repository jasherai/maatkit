---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/TextResultSetParser.pm   75.3   55.0    n/a   84.6    n/a  100.0   72.7
Total                          75.3   55.0    n/a   84.6    n/a  100.0   72.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TextResultSetParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jul 15 15:29:51 2009
Finish:       Wed Jul 15 15:29:51 2009

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
18                                                    # TextResultSetParser package $Revision: 4176 $
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
40             1                    1             8   use strict;
               1                                  2   
               1                                  6   
41             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
42             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
43                                                    
44             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
45                                                    
46                                                    # Possible args:
47                                                    #   * value_for    Hashref of original_val => new_val, used to alter values
48                                                    #
49                                                    sub new {
50             1                    1            16      my ( $class, %args ) = @_;
51             1                                  5      my $self = { %args };
52             1                                 14      return bless $self, $class;
53                                                    }
54                                                    
55                                                    sub parse_tabular {
56             2                    2            15      my ( $text, @cols ) = @_;
57             2                                  5      my %row;
58             2                                 37      my @vals = $text =~ m/\| +([^\|]*?)(?= +\|)/msg;
59             2    100                          13      return (undef, \@vals) unless @cols;
60             1                                  8      @row{@cols} = @vals;
61             1                                  5      return (\%row, undef);
62                                                    }
63                                                    
64                                                    sub parse_tab_sep {
65    ***      0                    0             0      my ( $text, @cols ) = @_;
66    ***      0                                  0      my %row;
67    ***      0                                  0      my @vals = split(/\t/, $text);
68    ***      0      0                           0      return (undef, \@vals) unless @cols;
69    ***      0                                  0      @row{@cols} = @vals;
70    ***      0                                  0      return (\%row, undef);
71                                                    }
72                                                    
73                                                    sub parse_vertical {
74           166                  166           550      my ( $text ) = @_;
75           166                               3640      my %row = $text =~ m/^\s*(\w+): ([^\n]*)/msg;
76           166                               1015      return \%row;
77                                                    }
78                                                    
79                                                    # Returns a result set like:
80                                                    # [
81                                                    #    {
82                                                    #       Time     => '5',
83                                                    #       Command  => 'Query',
84                                                    #       db       => 'foo',
85                                                    #    },
86                                                    # ]
87                                                    sub parse {
88           170                  170           906      my ( $self, $text ) = @_;
89           170                                457      my $result_set;
90                                                    
91                                                       # Detect text type: tabular, tab-separated, or vertical
92           170    100                        1461      if ( $text =~ m/^\+---/m ) { # standard "tabular" output
      ***            50                               
      ***            50                               
93             1                                  3         MKDEBUG && _d('text type: standard tabular');
94             1                                  8         my $line_pattern  = qr/^(\| .*)[\r\n]+/m;
95             1                                  5         $result_set
96                                                             = _parse_horizontal_result_set($text, $line_pattern, \&parse_tabular);
97                                                       }
98                                                       elsif ( $text =~ m/^id\tselect_type\t/m ) { # tab-separated
99    ***      0                                  0         MKDEBUG && _d('text type: tab-separated');
100   ***      0                                  0         my $line_pattern  = qr/^(.*?\t.*)[\r\n]+/m;
101   ***      0                                  0         $result_set
102                                                            = _parse_horizontal_result_set($text, $line_pattern, \&parse_tab_sep);
103                                                      }
104                                                      elsif ( $text =~ m/\*\*\* \d+\. row/ ) { # "vertical" output
105          169                                382         my $n_recs;
106          169                               3524         $n_recs++ while $text =~ m/ \d+\. row /g;
107          169                                356         MKDEBUG && _d('text-type: vertical,', $n_recs, 'n_recs');
108          169    100                         597         if ( $n_recs > 1 ) {
109            3                                  7            MKDEBUG && _d('Multiple result sets');
110            3                                  7            my @v_result_sets;
111            3                                 19            my $v_result_set = _split_vertical_result_sets($text);
112            3                                 18            foreach my $v_result_set ( @$v_result_set ) {
113          166                                633               push @v_result_sets, $self->parse($v_result_set);
114                                                            }
115            3                                 61            return \@v_result_sets;
116                                                         }
117          166                                650         $result_set = _parse_vertical_result_set($text, \&parse_vertical);
118                                                      }
119                                                      else {
120   ***      0                                  0         die "Cannot determine if text is tabular, tab-separated or veritcal:\n"
121                                                            . $text;
122                                                      }
123                                                   
124                                                      # Convert values.
125   ***    167     50                         702      if ( $self->{value_for} ) {
126   ***      0                                  0         foreach my $result_set ( @$result_set ) {
127   ***      0                                  0            foreach my $key ( keys %$result_set ) {
128   ***      0      0                           0               $result_set->{$key} = $self->{value_for}->{ $result_set->{$key} }
129                                                                  if exists $self->{value_for}->{ $result_set->{$key} };
130                                                            }
131                                                         }
132                                                      }
133                                                   
134          167                                632      return $result_set;
135                                                   }
136                                                   
137                                                   sub _parse_horizontal_result_set {
138            1                    1             4      my ( $text, $line_pattern, $sub ) = @_;
139            1                                  4      my @result_sets = ();
140            1                                  2      my @cols        = ();
141            1                                 10      foreach my $line ( $text =~ m/$line_pattern/g ) {
142            2                                  8         my ( $row, $cols ) = $sub->($line, @cols);
143            2    100                           8         if ( $row ) {
144            1                                  4            push @result_sets, $row;
145                                                         }
146                                                         else {
147            1                                  8            @cols = @$cols;
148                                                         }
149                                                      }
150            1                                 10      return \@result_sets;
151                                                   }
152                                                   
153                                                   sub _parse_vertical_result_set {
154          166                  166           662      my ( $text, $sub ) = @_;
155          166                                618      return $sub->($text);
156                                                   }
157                                                   
158                                                   sub _split_vertical_result_sets {
159            3                    3           106      my ( $text ) = @_;
160            3                                 11      my $ROW_HEADER = '\*{3,} \d+\. row \*{3,}';
161            3                              11919      my @result_sets = $text =~ m/($ROW_HEADER.*?)(?=$ROW_HEADER|\z)/omgs;
162            3                                 59      return \@result_sets;
163                                                   }
164                                                   
165                                                   sub _d {
166   ***      0                    0                    my ($package, undef, $line) = caller 0;
167   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
168   ***      0                                              map { defined $_ ? $_ : 'undef' }
169                                                           @_;
170   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
171                                                   }
172                                                   
173                                                   1;
174                                                   
175                                                   # ###########################################################################
176                                                   # End TextResultSetParser package
177                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
59           100      1      1   unless @cols
68    ***      0      0      0   unless @cols
92           100      1    169   if ($text =~ /^\+---/m) { }
      ***     50      0    169   elsif ($text =~ /^id\tselect_type\t/m) { }
      ***     50    169      0   elsif ($text =~ /\*\*\* \d+\. row/) { }
108          100      3    166   if ($n_recs > 1)
125   ***     50      0    167   if ($$self{'value_for'})
128   ***      0      0      0   if exists $$self{'value_for'}{$$result_set{$key}}
143          100      1      1   if ($row) { }
167   ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine                   Count Location                                                  
---------------------------- ----- ----------------------------------------------------------
BEGIN                            1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:40 
BEGIN                            1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:41 
BEGIN                            1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:42 
BEGIN                            1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:44 
_parse_horizontal_result_set     1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:138
_parse_vertical_result_set     166 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:154
_split_vertical_result_sets      3 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:159
new                              1 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:50 
parse                          170 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:88 
parse_tabular                    2 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:56 
parse_vertical                 166 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:74 

Uncovered Subroutines
---------------------

Subroutine                   Count Location                                                  
---------------------------- ----- ----------------------------------------------------------
_d                               0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:166
parse_tab_sep                    0 /home/daniel/dev/maatkit/common/TextResultSetParser.pm:65 


