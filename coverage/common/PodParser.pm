---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/PodParser.pm   85.1   71.4   75.0   81.8    0.0   98.4   77.0
PodParser.t                   100.0   50.0   33.3  100.0    n/a    1.6   93.0
Total                          89.4   70.0   68.4   89.5    0.0  100.0   80.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:37 2010
Finish:       Thu Jun 24 19:35:37 2010

Run:          PodParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:39 2010
Finish:       Thu Jun 24 19:35:39 2010

/home/daniel/dev/maatkit/common/PodParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010 Percona Inc.
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
18                                                    # PodParser package $Revision: 6025 $
19                                                    # ###########################################################################
20                                                    package PodParser;
21                                                    
22                                                    # This package wants to subclasses Pod::Parser but because some people
23                                                    # still run ancient systems on which even "core" modules are missing,
24                                                    # we have to roll our own pod parser.
25                                                    
26             1                    1             6   use strict;
               1                                  2   
               1                                 12   
27             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                 11   
28             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  9   
29                                                    
30    ***      1            50      1            12   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 22   
31                                                    
32                                                    # List =item from these head1 sections will be parsed into a hash
33                                                    # with the item's name as the key and its paragraphs parsed as
34                                                    # another hash of attribute-value pairs.  The first para is usually
35                                                    # a single line of attrib: value; ..., but this is optional.  The
36                                                    # other paras are the item's description, saved under the desc key.
37                                                    my %parse_items_from = (
38                                                       'OPTIONS'     => 1,
39                                                       'DSN OPTIONS' => 1,
40                                                       'RULES'       => 1,
41                                                    );
42                                                    
43                                                    # Pattern to match and capture the item's name after "=item ".
44                                                    my %item_pattern_for = (
45                                                       'OPTIONS'     => qr/--(.*)/,
46                                                       'DSN OPTIONS' => qr/\* (.)/,
47                                                       'RULES'       => qr/(.*)/,
48                                                    );
49                                                    
50                                                    # True if the head1 section's paragraphs before its first =item
51                                                    # define rules, one per para/line.  These rules are saved in an
52                                                    # arrayref under the rules key.
53                                                    my %section_has_rules = (
54                                                       'OPTIONS'     => 1,
55                                                       'DSN OPTIONS' => 0,
56                                                       'RULES'       => 0,
57                                                    );
58                                                    
59                                                    sub new {
60    ***      1                    1      0      5      my ( $class, %args ) = @_;
61             1                                  9      my $self = {
62                                                          current_section => '',
63                                                          current_item    => '',
64                                                          in_list         => 0,
65                                                          items           => {},
66                                                       };
67             1                                 12      return bless $self, $class;
68                                                    }
69                                                     
70                                                    sub get_items {
71    ***      1                    1      0      5      my ( $self, $section ) = @_;
72    ***      1     50                          24      return $section ? $self->{items}->{$section} : $self->{items};
73                                                    }
74                                                    
75                                                    sub parse_from_file {
76    ***      1                    1      0      5      my ( $self, $file ) = @_;
77    ***      1     50                          21      return unless $file;
78                                                    
79    ***      1     50                          58      open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
80             1                                  7      local $INPUT_RECORD_SEPARATOR = '';  # read paragraphs
81             1                                  3      my $para;
82                                                    
83                                                       # Skip past file contents until we reach start of POD.
84    ***      1            66                12850      1 while defined($para = <$fh>) && $para !~ m/^=pod/;
85    ***      1     50                           9      die "$file does not contain =pod" unless $para;
86                                                    
87    ***      1            66                   23      while ( defined($para = <$fh>) && $para !~ m/^=cut/ ) {
88            43    100                         178         if ( $para =~ m/^=(head|item|over|back)/ ) {
89            16                                117            my ($cmd, $name) = $para =~ m/^=(\w+)(?:\s+(.+))?/;
90            16           100                   70            $name ||= '';
91            16                                 35            MKDEBUG && _d('cmd:', $cmd, 'name:', $name);
92            16                                 79            $self->command($cmd, $name);
93                                                          }
94                                                          else {
95            27                                 95            $self->textblock($para);
96                                                          }
97                                                       }
98                                                    
99             1                                  3      close $fh;
100                                                   }
101                                                   
102                                                   # Commands like =head1, =over, =item and =back.  Paragraphs following
103                                                   # these command are passed to textblock().
104                                                   sub command {
105   ***     16                   16      0     71      my ( $self, $cmd, $name ) = @_;
106                                                      
107           16                                 64      $name =~ s/\s+\Z//m;  # Remove \n and blank line after name.
108                                                      
109           16    100    100                  160      if  ( $cmd eq 'head1' && $parse_items_from{$name} ) {
                    100                               
                    100                               
      ***            50                               
110            1                                  4         MKDEBUG && _d('In section', $name);
111            1                                  3         $self->{current_section} = $name;
112            1                                  5         $self->{items}->{$name}  = {};
113                                                      }
114                                                      elsif ( $cmd eq 'over' ) {
115            1                                  3         MKDEBUG && _d('Start items in', $self->{current_section});
116            1                                  3         $self->{in_list} = 1;
117                                                      }
118                                                      elsif ( $cmd eq 'item' ) {
119            3                                118         my $pat = $item_pattern_for{ $self->{current_section} };
120            3                                 24         my ($item) = $name =~ m/$pat/;
121   ***      3     50                          11         if ( $item ) {
122            3                                  7            MKDEBUG && _d($self->{current_section}, 'item:', $item);
123            3                                 22            $self->{items}->{ $self->{current_section} }->{$item} = {
124                                                               desc => '',  # every item should have a desc
125                                                            };
126            3                                 12            $self->{current_item} = $item;
127                                                         }
128                                                         else {
129   ***      0                                  0            warn "Item $name does not match $pat";
130                                                         }
131                                                      }
132                                                      elsif ( $cmd eq '=back' ) {
133   ***      0                                  0         MKDEBUG && _d('End items');
134   ***      0                                  0         $self->{in_list} = 0;
135                                                      }
136                                                      else {
137           11                                 41         $self->{current_section} = '';
138           11                                 46         $self->{in_list}         = 0;
139                                                      }
140                                                      
141           16                                202      return;
142                                                   }
143                                                   
144                                                   # Paragraphs after a command.
145                                                   sub textblock {
146   ***     27                   27      0    112      my ( $self, $para ) = @_;
147                                                   
148   ***     27    100     66                  345      return unless $self->{current_section} && $self->{current_item};
149                                                   
150            6                                 19      my $section = $self->{current_section};
151            6                                 37      my $item    = $self->{items}->{$section}->{ $self->{current_item} };
152                                                   
153            6                                 35      $para =~ s/\s+\Z//;
154                                                   
155            6    100                          29      if ( $para =~ m/\b\w+: / ) {
156            3                                  7         MKDEBUG && _d('Item attributes:', $para);
157            4                                 21         map {
158            3                                 14            my ($attrib, $val) = split(/: /, $_);
159            4    100                          23            $item->{$attrib} = defined $val ? $val : 1;
160                                                         } split(/; /, $para);
161                                                      }
162                                                      else {
163            3                                  7         MKDEBUG && _d('Item desc:', substr($para, 0, 40),
164                                                            length($para) > 40 ? '...' : '');
165            3                                 10         $para =~ s/\n+/ /g;
166            3                                 13         $item->{desc} .= $para;
167                                                      }
168                                                   
169            6                                 69      return;
170                                                   }
171                                                   
172                                                   # Indented blocks of text, e.g. SYNOPSIS examples.  We don't
173                                                   # do anything with these yet.
174                                                   sub verbatim {
175   ***      0                    0      0             my ( $self, $para ) = @_;
176   ***      0                                         return;
177                                                   }
178                                                   
179                                                   sub _d {
180   ***      0                    0                    my ($package, undef, $line) = caller 0;
181   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
182   ***      0                                              map { defined $_ ? $_ : 'undef' }
183                                                           @_;
184   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
185                                                   }
186                                                   
187                                                   1;
188                                                   
189                                                   # ###########################################################################
190                                                   # End PodParser package
191                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
72    ***     50      0      1   $section ? :
77    ***     50      0      1   unless $file
79    ***     50      0      1   unless open my $fh, '<', $file
85    ***     50      0      1   unless $para
88           100     16     27   if ($para =~ /^=(head|item|over|back)/) { }
109          100      1     15   if ($cmd eq 'head1' and $parse_items_from{$name}) { }
             100      1     14   elsif ($cmd eq 'over') { }
             100      3     11   elsif ($cmd eq 'item') { }
      ***     50      0     11   elsif ($cmd eq '=back') { }
121   ***     50      3      0   if ($item) { }
148          100     21      6   unless $$self{'current_section'} and $$self{'current_item'}
155          100      3      3   if ($para =~ /\b\w+: /) { }
159          100      3      1   defined $val ? :
181   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
84    ***     66      0      1      1   defined($para = <$fh>) and not $para =~ /^=pod/
87    ***     66      0      1     43   defined($para = <$fh>) and not $para =~ /^=cut/
109          100      9      6      1   $cmd eq 'head1' and $parse_items_from{$name}
148   ***     66     21      0      6   $$self{'current_section'} and $$self{'current_item'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0
90           100     14      2   $name ||= ''


Covered Subroutines
-------------------

Subroutine      Count Pod Location                                        
--------------- ----- --- ------------------------------------------------
BEGIN               1     /home/daniel/dev/maatkit/common/PodParser.pm:26 
BEGIN               1     /home/daniel/dev/maatkit/common/PodParser.pm:27 
BEGIN               1     /home/daniel/dev/maatkit/common/PodParser.pm:28 
BEGIN               1     /home/daniel/dev/maatkit/common/PodParser.pm:30 
command            16   0 /home/daniel/dev/maatkit/common/PodParser.pm:105
get_items           1   0 /home/daniel/dev/maatkit/common/PodParser.pm:71 
new                 1   0 /home/daniel/dev/maatkit/common/PodParser.pm:60 
parse_from_file     1   0 /home/daniel/dev/maatkit/common/PodParser.pm:76 
textblock          27   0 /home/daniel/dev/maatkit/common/PodParser.pm:146

Uncovered Subroutines
---------------------

Subroutine      Count Pod Location                                        
--------------- ----- --- ------------------------------------------------
_d                  0     /home/daniel/dev/maatkit/common/PodParser.pm:180
verbatim            0   0 /home/daniel/dev/maatkit/common/PodParser.pm:175


PodParser.t

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
               1                                  2   
               1                                  6   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 1;
               1                                  4   
               1                                  8   
13                                                    
14             1                    1            15   use MaatkitTest;
               1                                  5   
               1                                 40   
15             1                    1            13   use PodParser;
               1                                  2   
               1                                  9   
16                                                    
17             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  6   
18             1                                  5   $Data::Dumper::Indent    = 1;
19             1                                  3   $Data::Dumper::Sortkeys  = 1;
20             1                                  2   $Data::Dumper::Quotekeys = 0;
21                                                    
22             1                                  7   my $p = new PodParser();
23                                                    
24             1                                  6   $p->parse_from_file("$trunk/common/t/samples/pod/pod_sample_mqa.txt");
25                                                    
26             1                                 11   is_deeply(
27                                                       $p->get_items(),
28                                                       {
29                                                          OPTIONS => {
30                                                             define => {
31                                                                desc => 'Define these check IDs.  If L<"--verbose"> is zero (i.e. not specified) then a terse definition is given.  If one then a fuller definition is given.  If two then the complete definition is given.',
32                                                                type => 'array',
33                                                             },
34                                                             'ignore-checks' => {
35                                                                desc => 'Ignore these L<"CHECKS">.',
36                                                                type => 'array',
37                                                             },
38                                                             verbose => {
39                                                                cumulative => 1,
40                                                                default    => '0',
41                                                                desc       => 'Print more information.',
42                                                             },
43                                                          },
44                                                       },
45                                                       'Parse pod_sample_mqa.txt'
46                                                    );
47                                                    
48                                                    # #############################################################################
49                                                    # Done.
50                                                    # #############################################################################
51             1                                  3   exit;


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
---------- ----- --------------
BEGIN          1 PodParser.t:10
BEGIN          1 PodParser.t:11
BEGIN          1 PodParser.t:12
BEGIN          1 PodParser.t:14
BEGIN          1 PodParser.t:15
BEGIN          1 PodParser.t:17
BEGIN          1 PodParser.t:4 
BEGIN          1 PodParser.t:9 


