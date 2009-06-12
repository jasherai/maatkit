---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/RecordsetFromText.pm   75.0   54.2    n/a   86.7    n/a  100.0   72.4
Total                          75.0   54.2    n/a   86.7    n/a  100.0   72.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          RecordsetFromText.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:55 2009
Finish:       Wed Jun 10 17:20:55 2009

/home/daniel/dev/maatkit/common/RecordsetFromText.pm

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
18                                                    # RecordsetFromText package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    
21                                                    # RecordsetFromText - Create recordset (array of hashes) from text output
22                                                    package RecordsetFromText;
23                                                    
24             1                    1             9   use strict;
               1                                  2   
               1                                  8   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  9   
26             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                 10   
27             1                    1             7   use Carp;
               1                                  3   
               1                                  8   
28             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
29                                                    
30             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
31                                                    
32                                                    # At present $params can contain a hash of alternate values:
33                                                    #    key:   value_for
34                                                    #    value: {
35                                                    #       key:   value from text
36                                                    #       value: alternate value
37                                                    #    }
38                                                    # Example:
39                                                    # $params = { value_for => {
40                                                    #                NULL => undef,
41                                                    #             }
42                                                    #           }
43                                                    # That would cause any NULL value in the text to be changed to
44                                                    # undef in the returned recset.
45                                                    
46                                                    sub new {
47             1                    1            19      my ( $class, $params ) = @_;
48    ***      1     50                           6      my $self = defined $params ? { %{ $params } } : {};
      ***      0                                  0   
49             1                                 14      return bless $self, $class;
50                                                    }
51                                                    
52                                                    sub parse_tabular {
53             2                    2            10      my ( $text, @cols ) = @_;
54             2                                  6      my %row;
55             2                                 34      my @vals = $text =~ m/\| +([^\|]*?)(?= +\|)/msg;
56             2    100                          13      return (undef, \@vals) unless @cols;
57             1                                  8      @row{@cols} = @vals;
58             1                                  5      return (\%row, undef);
59                                                    }
60                                                    
61                                                    sub parse_tab_sep {
62    ***      0                    0             0      my ( $text, @cols ) = @_;
63    ***      0                                  0      my %row;
64    ***      0                                  0      my @vals = split(/\t/, $text);
65    ***      0      0                           0      return (undef, \@vals) unless @cols;
66    ***      0                                  0      @row{@cols} = @vals;
67    ***      0                                  0      return (\%row, undef);
68                                                    }
69                                                    
70                                                    sub parse_vertical {
71           166                  166           535      my ( $text ) = @_;
72           166                               3676      my %row = $text =~ m/^\s*(\w+): ([^\n]*)/msg;
73           166                               1016      return \%row;
74                                                    }
75                                                    
76                                                    # parse() returns an array of recordset hashes where column/field => value
77                                                    sub parse {
78           170                  170           874      my ( $self, $text ) = @_;
79           170                                457      my $recsets_ref;
80                                                    
81                                                       # Detect text type: tabular, tab-separated, or vertical
82           170    100                        1426      if ( $text =~ m/^\+---/m ) { # standard "tabular" output
      ***            50                               
      ***            50                               
83             1                                  2         MKDEBUG && _d('text type: standard tabular');
84             1                                  9         my $line_pattern  = qr/^(\| .*)[\r\n]+/m;
85             1                                  5         $recsets_ref
86                                                             = _parse_horizontal_recset($text, $line_pattern, \&parse_tabular);
87                                                       }
88                                                       elsif ( $text =~ m/^id\tselect_type\t/m ) { # tab-separated
89    ***      0                                  0         MKDEBUG && _d('text type: tab-separated');
90    ***      0                                  0         my $line_pattern  = qr/^(.*?\t.*)[\r\n]+/m;
91    ***      0                                  0         $recsets_ref
92                                                             = _parse_horizontal_recset($text, $line_pattern, \&parse_tab_sep);
93                                                       }
94                                                       elsif ( $text =~ m/\*\*\* \d+\. row/ ) { # "vertical" output
95           169                                386         my $n_recs;
96           169                               3569         $n_recs++ while $text =~ m/ \d+\. row /g;
97           169                                346         MKDEBUG && _d('text-type: vertical,', $n_recs, 'n_recs');
98           169    100                         614         if ( $n_recs > 1 ) {
99             3                                 10            MKDEBUG && _d('Multiple recsets');
100            3                                 10            my @v_recsets;
101            3                                 14            my $v_recsets_ref = _split_vertical_recsets($text);
102            3                                  8            foreach my $v_recset ( @{ $v_recsets_ref } ) {
               3                                 14   
103          166                                625               push @v_recsets, $self->parse($v_recset);
104                                                            }
105            3                                 38            return \@v_recsets;
106                                                         }
107          166                                652         $recsets_ref = _parse_vertical_recset($text, \&parse_vertical);
108                                                      }
109                                                      else {
110   ***      0                                  0         croak "Cannot determine text type in RecordsetFromText::parse():\n"
111                                                               . $text;
112                                                      }
113                                                   
114   ***    167     50                         770      my $value_for
115                                                         = (exists $self->{value_for} ? $self->{value_for} : 0);
116   ***    167     50                         560      if ( $value_for ) {
117   ***      0                                  0         foreach my $recset ( @{ $recsets_ref } ) {
      ***      0                                  0   
118   ***      0                                  0            foreach my $key ( %{ $recset } ) {
      ***      0                                  0   
119   ***      0      0                           0               $recset->{$key} = $value_for->{ $recset->{$key} }
120                                                                  if exists $value_for->{ $recset->{$key} };
121                                                            }
122                                                         }
123                                                      }
124                                                   
125          167                                640      return $recsets_ref;
126                                                   }
127                                                   
128                                                   sub _parse_horizontal_recset {
129            1                    1             5      my ( $text, $line_pattern, $sub ) = @_;
130            1                                  3      my @recsets = ();
131            1                                  3      my @cols    = ();
132            1                                 10      foreach my $line ( $text =~ m/$line_pattern/g ) {
133            2                                  9         my ( $row, $cols ) = $sub->($line, @cols);
134            2    100                           8         if ( $row ) {
135            1                                  4            push @recsets, $row;
136                                                         }
137                                                         else {
138            1                                  8            @cols = @$cols;
139                                                         }
140                                                      }
141            1                                 10      return \@recsets;
142                                                   }
143                                                   
144                                                   sub _parse_vertical_recset {
145          166                  166           666      my ( $text, $sub ) = @_;
146          166                                607      return $sub->($text);
147                                                   }
148                                                   
149                                                   sub _split_vertical_recsets {
150            3                    3            82      my ( $text ) = @_;
151            3                                 14      my $ROW_HEADER = '\*{3,} \d+\. row \*{3,}';
152            3                              10331      my @recsets = $text =~ m/($ROW_HEADER.*?)(?=$ROW_HEADER|\z)/omgs;
153            3                                 38      return \@recsets;
154                                                   }
155                                                   
156                                                   sub _d {
157   ***      0                    0                    my ($package, undef, $line) = caller 0;
158   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
159   ***      0                                              map { defined $_ ? $_ : 'undef' }
160                                                           @_;
161   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
162                                                   }
163                                                   
164                                                   1;
165                                                   
166                                                   # ###########################################################################
167                                                   # End RecordsetFromText package
168                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
48    ***     50      0      1   defined $params ? :
56           100      1      1   unless @cols
65    ***      0      0      0   unless @cols
82           100      1    169   if ($text =~ /^\+---/m) { }
      ***     50      0    169   elsif ($text =~ /^id\tselect_type\t/m) { }
      ***     50    169      0   elsif ($text =~ /\*\*\* \d+\. row/) { }
98           100      3    166   if ($n_recs > 1)
114   ***     50      0    167   exists $$self{'value_for'} ? :
116   ***     50      0    167   if ($value_for)
119   ***      0      0      0   if exists $$value_for{$$recset{$key}}
134          100      1      1   if ($row) { }
158   ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine               Count Location                                                
------------------------ ----- --------------------------------------------------------
BEGIN                        1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:24 
BEGIN                        1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:25 
BEGIN                        1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:26 
BEGIN                        1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:27 
BEGIN                        1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:28 
BEGIN                        1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:30 
_parse_horizontal_recset     1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:129
_parse_vertical_recset     166 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:145
_split_vertical_recsets      3 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:150
new                          1 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:47 
parse                      170 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:78 
parse_tabular                2 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:53 
parse_vertical             166 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:71 

Uncovered Subroutines
---------------------

Subroutine               Count Location                                                
------------------------ ----- --------------------------------------------------------
_d                           0 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:157
parse_tab_sep                0 /home/daniel/dev/maatkit/common/RecordsetFromText.pm:62 


