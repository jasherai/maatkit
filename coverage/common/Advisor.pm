---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...ng-copy/common/Advisor.pm   67.1   42.9   50.0   80.0    0.0   44.6   59.1
...py/common/AdvisorRules.pm   80.4   43.8   40.0   77.8    0.0   23.3   67.1
...mmon/QueryAdvisorRules.pm   13.6    0.0    1.6   26.9    0.0   12.5    8.8
Advisor.t                     100.0   50.0   33.3  100.0    n/a   19.6   95.6
Total                          47.7   15.2    6.8   59.6    0.0  100.0   35.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jul  8 23:13:22 2010
Finish:       Thu Jul  8 23:13:22 2010

Run:          Advisor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jul  8 23:13:23 2010
Finish:       Thu Jul  8 23:13:23 2010

/home/daniel/dev/maatkit/working-copy/common/Advisor.pm

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
18                                                    # Advisor package $Revision: 6678 $
19                                                    # ###########################################################################
20                                                    package Advisor;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  5   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                 57   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
25    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 19   
26                                                    
27                                                    # Arguments:
28                                                    #   * match_type    string: how rules match, bool or pos
29                                                    #   * ignore_rules  hashref: rule IDs to ignore
30                                                    sub new {
31    ***      2                    2      0     12      my ( $class, %args ) = @_;
32             2                                  9      foreach my $arg ( qw(match_type) ) {
33    ***      2     50                         234         die "I need a $arg argument" unless $args{$arg};
34                                                       }
35                                                    
36             2                                 16      my $self = {
37                                                          %args,
38                                                          rules          => [],  # Rules from all advisor modules.
39                                                          rule_index_for => {},  # Maps rules by ID to their array index in $rules.
40                                                          rule_info      => {},  # ID, severity, description, etc. for each rule.
41                                                       };
42                                                    
43             2                                 18      return bless $self, $class;
44                                                    }
45                                                    
46                                                    # Load rules from the given advisor module.  Will die on duplicate
47                                                    # rule IDs.
48                                                    sub load_rules {
49    ***      3                    3      0     11      my ( $self, $advisor ) = @_;
50    ***      3     50                          13      return unless $advisor;
51             3                                  6      MKDEBUG && _d('Loading rules from', ref $advisor);
52                                                    
53                                                       # Starting index value in rules arrayref for these rules.
54                                                       # This is >0 if rules from other advisor modules have
55                                                       # already been loaded.
56             3                                  8      my $i = scalar @{$self->{rules}};
               3                                 12   
57                                                    
58                                                       RULE:
59             3                                 15      foreach my $rule ( $advisor->get_rules() ) {
60            39                                114         my $id = $rule->{id};
61            39    100                         174         if ( $self->{ignore_rules}->{uc $id} ) {
62             1                                  2            MKDEBUG && _d("Ignoring rule", $id);
63             1                                  4            next RULE;
64                                                          }
65            38    100                         164         die "Rule $id already exists and cannot be redefined"
66                                                             if defined $self->{rule_index_for}->{$id};
67            37                                 96         push @{$self->{rules}}, $rule;
              37                                139   
68            37                                182         $self->{rule_index_for}->{$id} = $i++;
69                                                       }
70                                                    
71             2                                 15      return;
72                                                    }
73                                                    
74                                                    sub load_rule_info {
75    ***      3                    3      0     12      my ( $self, $advisor ) = @_;
76    ***      3     50                          11      return unless $advisor;
77             3                                  8      MKDEBUG && _d('Loading rule info from', ref $advisor);
78             3                                  9      my $rules = $self->{rules};
79             3                                 11      foreach my $rule ( @$rules ) {
80            38                                123         my $id = $rule->{id};
81    ***     38     50                         167         if ( $self->{ignore_rules}->{uc $id} ) {
82                                                             # This shouldn't happen.  load_rules() should keep any ignored
83                                                             # rules out of $self->{rules}.
84    ***      0                                  0            die "Rule $id was loaded but should be ignored";
85                                                          }
86            38                                160         my $rule_info = $advisor->get_rule_info($id);
87    ***     38     50                         130         next unless $rule_info;
88            38    100                         156         die "Info for rule $id already exists and cannot be redefined"
89                                                             if $self->{rule_info}->{$id};
90            37                                158         $self->{rule_info}->{$id} = $rule_info;
91                                                       }
92             2                                  7      return;
93                                                    }
94                                                    
95                                                    sub run_rules {
96    ***      0                    0      0      0      my ( $self, %args ) = @_;
97    ***      0                                  0      my @matched_rules;
98    ***      0                                  0      my @matched_pos;
99    ***      0                                  0      my $rules      = $self->{rules};
100   ***      0                                  0      my $match_type = lc $self->{match_type};
101   ***      0                                  0      foreach my $rule ( @$rules ) {
102   ***      0                                  0         my $match = $rule->{code}->(%args);
103   ***      0      0                           0         if ( $match_type eq 'pos' ) {
      ***             0                               
104   ***      0      0                           0            if ( defined $match ) {
105   ***      0                                  0               MKDEBUG && _d('Matches rule', $rule->{id}, 'near pos', $match);
106   ***      0                                  0               push @matched_rules, $rule->{id};
107   ***      0                                  0               push @matched_pos,   $match;
108                                                            }
109                                                         }
110                                                         elsif ( $match_type eq 'bool' ) {
111   ***      0      0                           0            if ( $match ) {
112   ***      0                                  0               MKDEBUG && _d("Matches rule", $rule->{id});
113   ***      0                                  0               push @matched_rules, $rule->{id};
114                                                            }
115                                                         }
116                                                      }
117   ***      0                                  0      return \@matched_rules, \@matched_pos;
118                                                   };
119                                                   
120                                                   sub get_rule_info {
121   ***      2                    2      0      9      my ( $self, $id ) = @_;
122   ***      2     50                           9      return unless $id;
123            2                                 24      return $self->{rule_info}->{$id};
124                                                   }
125                                                   
126                                                   sub _d {
127   ***      0                    0                    my ($package, undef, $line) = caller 0;
128   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
129   ***      0                                              map { defined $_ ? $_ : 'undef' }
130                                                           @_;
131   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
132                                                   }
133                                                   
134                                                   1;
135                                                   
136                                                   # ###########################################################################
137                                                   # End Advisor package
138                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
33    ***     50      0      2   unless $args{$arg}
50    ***     50      0      3   unless $advisor
61           100      1     38   if ($$self{'ignore_rules'}{uc $id})
65           100      1     37   if defined $$self{'rule_index_for'}{$id}
76    ***     50      0      3   unless $advisor
81    ***     50      0     38   if ($$self{'ignore_rules'}{uc $id})
87    ***     50      0     38   unless $rule_info
88           100      1     37   if $$self{'rule_info'}{$id}
103   ***      0      0      0   if ($match_type eq 'pos') { }
      ***      0      0      0   elsif ($match_type eq 'bool') { }
104   ***      0      0      0   if (defined $match)
111   ***      0      0      0   if ($match)
122   ***     50      0      2   unless $id
128   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
25    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine     Count Pod Location                                                   
-------------- ----- --- -----------------------------------------------------------
BEGIN              1     /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:22 
BEGIN              1     /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:23 
BEGIN              1     /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:24 
BEGIN              1     /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:25 
get_rule_info      2   0 /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:121
load_rule_info     3   0 /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:75 
load_rules         3   0 /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:49 
new                2   0 /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:31 

Uncovered Subroutines
---------------------

Subroutine     Count Pod Location                                                   
-------------- ----- --- -----------------------------------------------------------
_d                 0     /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:127
run_rules          0   0 /home/daniel/dev/maatkit/working-copy/common/Advisor.pm:96 


/home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm

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
18                                                    # AdvisorRules package $Revision: 6678 $
19                                                    # ###########################################################################
20                                                    package AdvisorRules;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                 12   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                 11   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  6   
               1                                  7   
25    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 22   
26                                                    
27                                                    sub new {
28    ***      1                    1      0      5      my ( $class, %args ) = @_;
29             1                                  6      foreach my $arg ( qw(PodParser) ) {
30    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
31                                                       }
32             1                                  7      my $self = {
33                                                          %args,
34                                                          rules     => [],
35                                                          rule_info => {},
36                                                       };
37             1                                 12      return bless $self, $class;
38                                                    }
39                                                    
40                                                    # Arguments:
41                                                    #   * file     scalar: file name with POD to parse rules from
42                                                    #   * section  scalar: section name for rule items, should be RULES
43                                                    #   * rules    arrayref: optional list of rules to load info for
44                                                    # Parses rules from the POD section/subsection in file, adding rule
45                                                    # info found therein to %rule_info.  Then checks that rule info
46                                                    # was gotten for all the required rules.
47                                                    sub load_rule_info {
48    ***      1                    1      0      9      my ( $self, %args ) = @_;
49             1                                  5      foreach my $arg ( qw(file section ) ) {
50    ***      2     50                          11         die "I need a $arg argument" unless $args{$arg};
51                                                       }
52    ***      1            33                    5      my $rules = $args{rules} || $self->{rules};
53             1                                  4      my $p     = $self->{PodParser};
54                                                    
55                                                       # Parse rules and their info from the file's POD, saving
56                                                       # values to %rule_info.
57             1                                  7      $p->parse_from_file($args{file});
58             1                                 18      my $rule_items = $p->get_items($args{section});
59             1                                 18      my %seen;
60             1                                 13      foreach my $rule_id ( keys %$rule_items ) {
61            19                                 62         my $rule = $rule_items->{$rule_id};
62    ***     19     50                          84         die "Rule $rule_id has no description" unless $rule->{desc};
63    ***     19     50                          79         die "Rule $rule_id has no severity"    unless $rule->{severity};
64    ***     19     50                          82         die "Rule $rule_id is already defined"
65                                                             if exists $self->{rule_info}->{$rule_id};
66            19                                155         $self->{rule_info}->{$rule_id} = {
67                                                             id          => $rule_id,
68                                                             severity    => $rule->{severity},
69                                                             description => $rule->{desc},
70                                                          };
71                                                       }
72                                                    
73                                                       # Check that rule info was gotten for each requested rule.
74             1                                  6      foreach my $rule ( @$rules ) {
75    ***     19     50                         101         die "There is no info for rule $rule->{id} in $args{file}"
76                                                             unless $self->{rule_info}->{ $rule->{id} };
77                                                       }
78                                                    
79             1                                  5      return;
80                                                    }
81                                                    
82                                                    sub get_rule_info {
83    ***     38                   38      0    134      my ( $self, $id ) = @_;
84    ***     38     50                         131      return unless $id;
85            38                                177      return $self->{rule_info}->{$id};
86                                                    }
87                                                    
88                                                    # Used for testing.
89                                                    sub _reset_rule_info {
90    ***      0                    0                    my ( $self ) = @_;
91    ***      0                                         $self->{rule_info} = {};
92    ***      0                                         return;
93                                                    }
94                                                    
95                                                    sub _d {
96    ***      0                    0                    my ($package, undef, $line) = caller 0;
97    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
98    ***      0                                              map { defined $_ ? $_ : 'undef' }
99                                                            @_;
100   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
101                                                   }
102                                                   
103                                                   1;
104                                                   
105                                                   # ###########################################################################
106                                                   # End AdvisorRules package
107                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
30    ***     50      0      1   unless $args{$arg}
50    ***     50      0      2   unless $args{$arg}
62    ***     50      0     19   unless $$rule{'desc'}
63    ***     50      0     19   unless $$rule{'severity'}
64    ***     50      0     19   if exists $$self{'rule_info'}{$rule_id}
75    ***     50      0     19   unless $$self{'rule_info'}{$$rule{'id'}}
84    ***     50      0     38   unless $id
97    ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
25    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
52    ***     33      1      0      0   $args{'rules'} || $$self{'rules'}


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                                       
---------------- ----- --- ---------------------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:22
BEGIN                1     /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:23
BEGIN                1     /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:24
BEGIN                1     /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:25
get_rule_info       38   0 /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:83
load_rule_info       1   0 /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:48
new                  1   0 /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:28

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                                       
---------------- ----- --- ---------------------------------------------------------------
_d                   0     /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:96
_reset_rule_info     0     /home/daniel/dev/maatkit/working-copy/common/AdvisorRules.pm:90


/home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm

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
18                                                    # QueryAdvisorRules package $Revision: 6679 $
19                                                    # ###########################################################################
20                                                    package QueryAdvisorRules;
21             1                    1             9   use base 'AdvisorRules';
               1                                  4   
               1                                 33   
22                                                    
23             1                    1             7   use strict;
               1                                  2   
               1                                  5   
24             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  4   
25             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 18   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      6      my ( $class, %args ) = @_;
30             1                                 28      my $self = $class->SUPER::new(%args);
31             1                                  5      @{$self->{rules}} = $self->get_rules();
               1                                  7   
32             1                                  5      MKDEBUG && _d(scalar @{$self->{rules}}, "rules");
33             1                                  4      return $self;
34                                                    }
35                                                    
36                                                    # Each rules is a hashref with two keys:
37                                                    #   * id       Unique PREFIX.NUMBER for the rule.  The prefix is three chars
38                                                    #              which hints to the nature of the rule.  See example below.
39                                                    #   * code     Coderef to check rule, returns undef if rule does not match,
40                                                    #              else returns the string pos near where the rule matches or 0
41                                                    #              to indicate it doesn't know the pos.  The code is passed a\
42                                                    #              single arg: a hashref event.
43                                                    sub get_rules {
44                                                       return
45                                                       {
46                                                          id   => 'ALI.001',      # Implicit alias
47                                                          code => sub {
48    ***      0                    0             0            my ( %args ) = @_;
49    ***      0                                  0            my $event  = $args{event};
50    ***      0                                  0            my $struct = $event->{query_struct};
51    ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
52    ***      0      0                           0            return unless $tbls;
53    ***      0                                  0            foreach my $tbl ( @$tbls ) {
54    ***      0      0      0                    0               return 0 if $tbl->{alias} && !$tbl->{explicit_alias};
55                                                             }
56    ***      0                                  0            my $cols = $struct->{columns};
57    ***      0      0                           0            return unless $cols;
58    ***      0                                  0            foreach my $col ( @$cols ) {
59    ***      0      0      0                    0               return 0 if $col->{alias} && !$col->{explicit_alias};
60                                                             }
61    ***      0                                  0            return;
62                                                          },
63                                                       },
64                                                       {
65                                                          id   => 'ALI.002',      # tbl.* alias
66                                                          code => sub {
67    ***      0                    0             0            my ( %args ) = @_;
68    ***      0                                  0            my $event = $args{event};
69    ***      0                                  0            my $cols  = $event->{query_struct}->{columns};
70    ***      0      0                           0            return unless $cols;
71    ***      0                                  0            foreach my $col ( @$cols ) {
72    ***      0      0      0                    0               return 0 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
      ***                    0                        
73                                                             }
74    ***      0                                  0            return;
75                                                          },
76                                                       },
77                                                       {
78                                                          id   => 'ALI.003',      # tbl AS tbl
79                                                          code => sub {
80    ***      0                    0             0            my ( %args ) = @_;
81    ***      0                                  0            my $event  = $args{event};
82    ***      0                                  0            my $struct = $event->{query_struct};
83    ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
84    ***      0      0                           0            return unless $tbls;
85    ***      0                                  0            foreach my $tbl ( @$tbls ) {
86    ***      0      0      0                    0               return 0 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
87                                                             }
88    ***      0                                  0            my $cols = $struct->{columns};
89    ***      0      0                           0            return unless $cols;
90    ***      0                                  0            foreach my $col ( @$cols ) {
91    ***      0      0      0                    0               return 0 if $col->{alias} && $col->{alias} eq $col->{name};
92                                                             }
93    ***      0                                  0            return;
94                                                          },
95                                                       },
96                                                       {
97                                                          id   => 'ARG.001',      # col = '%foo'
98                                                          code => sub {
99    ***      0                    0             0            my ( %args ) = @_;
100   ***      0                                  0            my $event = $args{event};
101   ***      0      0                           0            return 0 if $event->{arg} =~ m/[\'\"][\%\_]./;
102   ***      0                                  0            return;
103                                                         },
104                                                      },
105                                                      {
106                                                         id   => 'ARG.002',      # LIKE w/o wildcard
107                                                         code => sub {
108   ***      0                    0             0            my ( %args ) = @_;
109   ***      0                                  0            my $event = $args{event};        
110                                                            # TODO: this pattern doesn't handle spaces.
111   ***      0                                  0            my @like_args = $event->{arg} =~ m/\bLIKE\s+(\S+)/gi;
112   ***      0                                  0            foreach my $arg ( @like_args ) {
113   ***      0      0                           0               return 0 if $arg !~ m/[%_]/;
114                                                            }
115   ***      0                                  0            return;
116                                                         },
117                                                      },
118                                                      {
119                                                         id   => 'CLA.001',      # SELECT w/o WHERE
120                                                         code => sub {
121   ***      0                    0             0            my ( %args ) = @_;
122   ***      0                                  0            my $event = $args{event};
123   ***      0      0      0                    0            return unless ($event->{query_struct}->{type} || '') eq 'select';
124   ***      0      0                           0            return unless $event->{query_struct}->{from};
125   ***      0      0                           0            return 0 unless $event->{query_struct}->{where};
126   ***      0                                  0            return;
127                                                         },
128                                                      },
129                                                      {
130                                                         id   => 'CLA.002',      # ORDER BY RAND()
131                                                         code => sub {
132   ***      0                    0             0            my ( %args ) = @_;
133   ***      0                                  0            my $event   = $args{event};
134   ***      0                                  0            my $orderby = $event->{query_struct}->{order_by};
135   ***      0      0                           0            return unless $orderby;
136   ***      0                                  0            foreach my $col ( @$orderby ) {
137   ***      0      0                           0               return 0 if $col =~ m/RAND\([^\)]*\)/i;
138                                                            }
139   ***      0                                  0            return;
140                                                         },
141                                                      },
142                                                      {
143                                                         id   => 'CLA.003',      # LIMIT w/ OFFSET
144                                                         code => sub {
145   ***      0                    0             0            my ( %args ) = @_;
146   ***      0                                  0            my $event = $args{event};
147   ***      0      0                           0            return unless $event->{query_struct}->{limit};
148   ***      0      0                           0            return unless defined $event->{query_struct}->{limit}->{offset};
149   ***      0                                  0            return 0;
150                                                         },
151                                                      },
152                                                      {
153                                                         id   => 'CLA.004',      # GROUP BY <number>
154                                                         code => sub {
155   ***      0                    0             0            my ( %args ) = @_;
156   ***      0                                  0            my $event   = $args{event};
157   ***      0                                  0            my $groupby = $event->{query_struct}->{group_by};
158   ***      0      0                           0            return unless $groupby;
159   ***      0                                  0            foreach my $col ( @{$groupby->{columns}} ) {
      ***      0                                  0   
160   ***      0      0                           0               return 0 if $col =~ m/^\d+\b/;
161                                                            }
162   ***      0                                  0            return;
163                                                         },
164                                                      },
165                                                      {
166                                                         id   => 'COL.001',      # SELECT *
167                                                         code => sub {
168   ***      0                    0             0            my ( %args ) = @_;
169   ***      0                                  0            my $event = $args{event};
170   ***      0      0      0                    0            return unless ($event->{query_struct}->{type} || '') eq 'select';
171   ***      0                                  0            my $cols = $event->{query_struct}->{columns};
172   ***      0      0                           0            return unless $cols;
173   ***      0                                  0            foreach my $col ( @$cols ) {
174   ***      0      0                           0               return 0 if $col->{name} eq '*';
175                                                            }
176   ***      0                                  0            return;
177                                                         },
178                                                      },
179                                                      {
180                                                         id   => 'COL.002',      # INSERT w/o (cols) def
181                                                         code => sub {
182   ***      0                    0             0            my ( %args ) = @_;
183   ***      0                                  0            my $event = $args{event};
184   ***      0             0                    0            my $type  = $event->{query_struct}->{type} || '';
185   ***      0      0      0                    0            return unless $type eq 'insert' || $type eq 'replace';
186   ***      0      0                           0            return 0 unless $event->{query_struct}->{columns};
187   ***      0                                  0            return;
188                                                         },
189                                                      },
190                                                      {
191                                                         id   => 'LIT.001',      # IP as string
192                                                         code => sub {
193   ***      0                    0             0            my ( %args ) = @_;
194   ***      0                                  0            my $event = $args{event};
195   ***      0      0                           0            if ( $event->{arg} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/gc ) {
196   ***      0             0                    0               return (pos $event->{arg}) || 0;
197                                                            }
198   ***      0                                  0            return;
199                                                         },
200                                                      },
201                                                      {
202                                                         id   => 'LIT.002',      # Date not quoted
203                                                         code => sub {
204   ***      0                    0             0            my ( %args ) = @_;
205   ***      0                                  0            my $event = $args{event};
206                                                            # YYYY-MM-DD
207   ***      0      0                           0            if ( $event->{arg} =~ m/(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/gc ) {
208   ***      0             0                    0               return (pos $event->{arg}) || 0;
209                                                            }
210                                                            # YY-MM-DD
211   ***      0      0                           0            if ( $event->{arg} =~ m/(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/gc ) {
212   ***      0             0                    0               return (pos $event->{arg}) || 0;
213                                                            }
214   ***      0                                  0            return;
215                                                         },
216                                                      },
217                                                      {
218                                                         id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
219                                                         code => sub {
220   ***      0                    0             0            my ( %args ) = @_;
221   ***      0                                  0            my $event = $args{event};
222   ***      0      0                           0            return 0 if $event->{query_struct}->{keywords}->{sql_calc_found_rows};
223   ***      0                                  0            return;
224                                                         },
225                                                      },
226                                                      {
227                                                         id   => 'JOI.001',      # comma and ansi joins
228                                                         code => sub {
229   ***      0                    0             0            my ( %args ) = @_;
230   ***      0                                  0            my $event  = $args{event};
231   ***      0                                  0            my $struct = $event->{query_struct};
232   ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
233   ***      0      0                           0            return unless $tbls;
234   ***      0                                  0            my $comma_join = 0;
235   ***      0                                  0            my $ansi_join  = 0;
236   ***      0                                  0            foreach my $tbl ( @$tbls ) {
237   ***      0      0                           0               if ( $tbl->{join} ) {
238   ***      0      0                           0                  if ( $tbl->{join}->{ansi} ) {
239   ***      0                                  0                     $ansi_join = 1;
240                                                                  }
241                                                                  else {
242   ***      0                                  0                     $comma_join = 1;
243                                                                  }
244                                                               }
245   ***      0      0      0                    0               return 0 if $comma_join && $ansi_join;
246                                                            }
247   ***      0                                  0            return;
248                                                         },
249                                                      },
250                                                      {
251                                                         id   => 'RES.001',      # non-deterministic GROUP BY
252                                                         code => sub {
253   ***      0                    0             0            my ( %args ) = @_;
254   ***      0                                  0            my $event = $args{event};
255   ***      0      0      0                    0            return unless ($event->{query_struct}->{type} || '') eq 'select';
256   ***      0                                  0            my $groupby = $event->{query_struct}->{group_by};
257   ***      0      0                           0            return unless $groupby;
258                                                            # Only check GROUP BY column names, not numbers.  GROUP BY number
259                                                            # is handled in CLA.004.
260   ***      0                                  0            my %groupby_col = map { $_ => 1 }
      ***      0                                  0   
261   ***      0                                  0                              grep { m/^[^\d]+\b/ }
262   ***      0                                  0                              @{$groupby->{columns}};
263   ***      0      0                           0            return unless scalar %groupby_col;
264   ***      0                                  0            my $cols = $event->{query_struct}->{columns};
265                                                            # All SELECT cols must be in GROUP BY cols clause.
266                                                            # E.g. select a, b, c from tbl group by a; -- non-deterministic
267   ***      0                                  0            foreach my $col ( @$cols ) {
268   ***      0      0                           0               return 0 unless $groupby_col{ $col->{name} };
269                                                            }
270   ***      0                                  0            return;
271                                                         },
272                                                      },
273                                                      {
274                                                         id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
275                                                         code => sub {
276   ***      0                    0             0            my ( %args ) = @_;
277   ***      0                                  0            my $event = $args{event};
278   ***      0      0                           0            return unless $event->{query_struct}->{limit};
279                                                            # If query doesn't use tables then this check isn't applicable.
280   ***      0      0      0                    0            return unless    $event->{query_struct}->{from}
      ***                    0                        
281                                                                            || $event->{query_struct}->{into}
282                                                                            || $event->{query_struct}->{tables};
283   ***      0      0                           0            return 0 unless $event->{query_struct}->{order_by};
284   ***      0                                  0            return;
285                                                         },
286                                                      },
287                                                      {
288                                                         id   => 'STA.001',      # != instead of <>
289                                                         code => sub {
290   ***      0                    0             0            my ( %args ) = @_;
291   ***      0                                  0            my $event = $args{event};
292   ***      0      0                           0            return 0 if $event->{arg} =~ m/!=/;
293   ***      0                                  0            return;
294                                                         },
295                                                      },
296                                                      {
297                                                         id   => 'SUB.001',      # IN(<subquery>)
298                                                         code => sub {
299   ***      0                    0             0            my ( %args ) = @_;
300   ***      0                                  0            my $event = $args{event};
301   ***      0      0                           0            if ( $event->{arg} =~ m/\bIN\s*\(\s*SELECT\b/gi ) {
302   ***      0                                  0               return pos $event->{arg};
303                                                            }
304   ***      0                                  0            return;
305                                                         },
306                                                      },
307   ***      5                    5      0    495   };
308                                                   
309                                                   1;
310                                                   
311                                                   # ###########################################################################
312                                                   # End QueryAdvisorRules package
313                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
52    ***      0      0      0   unless $tbls
54    ***      0      0      0   if $$tbl{'alias'} and not $$tbl{'explicit_alias'}
57    ***      0      0      0   unless $cols
59    ***      0      0      0   if $$col{'alias'} and not $$col{'explicit_alias'}
70    ***      0      0      0   unless $cols
72    ***      0      0      0   if $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
84    ***      0      0      0   unless $tbls
86    ***      0      0      0   if $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
89    ***      0      0      0   unless $cols
91    ***      0      0      0   if $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
101   ***      0      0      0   if $$event{'arg'} =~ /[\'\"][\%\_]./
113   ***      0      0      0   if not $arg =~ /[%_]/
123   ***      0      0      0   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
124   ***      0      0      0   unless $$event{'query_struct'}{'from'}
125   ***      0      0      0   unless $$event{'query_struct'}{'where'}
135   ***      0      0      0   unless $orderby
137   ***      0      0      0   if $col =~ /RAND\([^\)]*\)/i
147   ***      0      0      0   unless $$event{'query_struct'}{'limit'}
148   ***      0      0      0   unless defined $$event{'query_struct'}{'limit'}{'offset'}
158   ***      0      0      0   unless $groupby
160   ***      0      0      0   if $col =~ /^\d+\b/
170   ***      0      0      0   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
172   ***      0      0      0   unless $cols
174   ***      0      0      0   if $$col{'name'} eq '*'
185   ***      0      0      0   unless $type eq 'insert' or $type eq 'replace'
186   ***      0      0      0   unless $$event{'query_struct'}{'columns'}
195   ***      0      0      0   if ($$event{'arg'} =~ /['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/cg)
207   ***      0      0      0   if ($$event{'arg'} =~ /(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/cg)
211   ***      0      0      0   if ($$event{'arg'} =~ /(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/cg)
222   ***      0      0      0   if $$event{'query_struct'}{'keywords'}{'sql_calc_found_rows'}
233   ***      0      0      0   unless $tbls
237   ***      0      0      0   if ($$tbl{'join'})
238   ***      0      0      0   if ($$tbl{'join'}{'ansi'}) { }
245   ***      0      0      0   if $comma_join and $ansi_join
255   ***      0      0      0   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
257   ***      0      0      0   unless $groupby
263   ***      0      0      0   unless scalar %groupby_col
268   ***      0      0      0   unless $groupby_col{$$col{'name'}}
278   ***      0      0      0   unless $$event{'query_struct'}{'limit'}
280   ***      0      0      0   unless $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}
283   ***      0      0      0   unless $$event{'query_struct'}{'order_by'}
292   ***      0      0      0   if $$event{'arg'} =~ /!=/
301   ***      0      0      0   if ($$event{'arg'} =~ /\bIN\s*\(\s*SELECT\b/gi)


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
54    ***      0      0      0      0   $$tbl{'alias'} and not $$tbl{'explicit_alias'}
59    ***      0      0      0      0   $$col{'alias'} and not $$col{'explicit_alias'}
72    ***      0      0      0      0   $$col{'db'} and $$col{'name'} eq '*'
      ***      0      0      0      0   $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
86    ***      0      0      0      0   $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
91    ***      0      0      0      0   $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
245   ***      0      0      0      0   $comma_join and $ansi_join

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0
123   ***      0      0      0   $$event{'query_struct'}{'type'} || ''
170   ***      0      0      0   $$event{'query_struct'}{'type'} || ''
184   ***      0      0      0   $$event{'query_struct'}{'type'} || ''
196   ***      0      0      0   pos $$event{'arg'} || 0
208   ***      0      0      0   pos $$event{'arg'} || 0
212   ***      0      0      0   pos $$event{'arg'} || 0
255   ***      0      0      0   $$event{'query_struct'}{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
51    ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
83    ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
185   ***      0      0      0      0   $type eq 'insert' or $type eq 'replace'
232   ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
280   ***      0      0      0      0   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'}
      ***      0      0      0      0   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}


Covered Subroutines
-------------------

Subroutine Count Pod Location                                                             
---------- ----- --- ---------------------------------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:21 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:23 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:24 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:25 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:26 
get_rules      5   0 /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:307
new            1   0 /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:29 

Uncovered Subroutines
---------------------

Subroutine Count Pod Location                                                             
---------- ----- --- ---------------------------------------------------------------------
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:108
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:121
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:132
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:145
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:155
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:168
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:182
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:193
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:204
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:220
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:229
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:253
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:276
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:290
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:299
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:48 
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:67 
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:80 
__ANON__       0     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:99 


Advisor.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 5;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            15   use MaatkitTest;
               1                                  5   
               1                                 39   
15             1                    1            28   use QueryAdvisorRules;
               1                                  3   
               1                                 12   
16             1                    1            12   use Advisor;
               1                                  3   
               1                                 11   
17             1                    1            10   use PodParser;
               1                                  3   
               1                                  9   
18                                                    
19                                                    # This module's purpose is to run rules and return a list of the IDs of the
20                                                    # triggered rules.  It should be very simple.  (But we don't want to put the two
21                                                    # modules together.  Their purposes are distinct.)
22             1                                  9   my $p   = new PodParser();
23             1                                 37   my $qar = new QueryAdvisorRules(PodParser => $p);
24             1                                  7   my $adv = new Advisor(match_type=>"pos");
25                                                    
26                                                    # This should make $qa internally call get_rules() on $qar and save the rules
27                                                    # into its own list.  If the user plugs in his own module, we'd call
28                                                    # load_rules() on that too, and just append the rules (with checks that they
29                                                    # don't redefine any rule IDs).
30             1                                  5   $adv->load_rules($qar);
31                                                    
32                                                    # To test the above, we ask it to load the same rules twice.  It should die with
33                                                    # an error like "Rule LIT.001 already exists, and cannot be redefined"
34                                                    throws_ok (
35             1                    1            15      sub { $adv->load_rules($qar) },
36             1                                 16      qr/Rule \S+ already exists and cannot be redefined/,
37                                                       'Duplicate rules are caught',
38                                                    );
39                                                    
40                                                    # We'll also load the rule info, so we can test $adv->get_rule_info() after the
41                                                    # POD is loaded.
42             1                                 17   $qar->load_rule_info(
43                                                       rules   => [ $qar->get_rules() ],
44                                                       file    => "$trunk/mk-query-advisor/mk-query-advisor",
45                                                       section => 'RULES',
46                                                    );
47                                                    
48                                                    # This should make $qa call $qar->get_rule_info('....') for every rule ID it
49                                                    # has, and store the info, and make sure that nothing is redefined.  A user
50                                                    # shouldn't be able to load a plugin that redefines the severity/desc of a
51                                                    # built-in rule.  Maybe we'll provide a way to override that, though by default
52                                                    # we want to warn and be strict.
53             1                                125   $adv->load_rule_info($qar);
54                                                    
55                                                    # TODO: write a test that the rules are described as defined in the POD of the
56                                                    # tool.  Testing one rule should be enough.
57                                                    
58                                                    # Test that it can't be redefined...
59                                                    throws_ok (
60             1                    1            15      sub { $adv->load_rule_info($qar) },
61             1                                 16      qr/Info for rule \S+ already exists and cannot be redefined/,
62                                                       'Duplicate rule info is caught',
63                                                    );
64                                                    
65             1                                 12   is_deeply(
66                                                       $adv->get_rule_info('ALI.001'),
67                                                       {
68                                                          id          => 'ALI.001',
69                                                          severity    => 'note',
70                                                          description => 'Aliasing without the AS keyword.  Explicitly using the AS keyword in column or table aliases, such as "tbl AS alias," is more readable than implicit aliases such as "tbl alias".',
71                                                       },
72                                                       'get_rule_info()'
73                                                    );
74                                                    
75                                                    
76                                                    # #############################################################################
77                                                    # Ignore rules.
78                                                    # #############################################################################
79             1                                 15   $adv = new Advisor(
80                                                       match_type   => "pos",
81                                                       ignore_rules => { 'LIT.002' => 1 },
82                                                    );
83             1                                108   $adv->load_rules($qar);
84             1                                  5   $adv->load_rule_info($qar);
85             1                                  6   is(
86                                                       $adv->get_rule_info('LIT.002'),
87                                                       undef,
88                                                       "Didn't load ignored rule"
89                                                    );
90                                                    
91                                                    # #############################################################################
92                                                    # Done.
93                                                    # #############################################################################
94             1                                  4   my $output = '';
95                                                    {
96             1                                  3      local *STDERR;
               1                                  6   
97             1                    1             2      open STDERR, '>', \$output;
               1                                306   
               1                                  3   
               1                                  7   
98             1                                 16      $p->_d('Complete test coverage');
99                                                    }
100                                                   like(
101            1                                 15      $output,
102                                                      qr/Complete test coverage/,
103                                                      '_d() works'
104                                                   );
105            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}


Covered Subroutines
-------------------

Subroutine Count Location    
---------- ----- ------------
BEGIN          1 Advisor.t:10
BEGIN          1 Advisor.t:11
BEGIN          1 Advisor.t:12
BEGIN          1 Advisor.t:14
BEGIN          1 Advisor.t:15
BEGIN          1 Advisor.t:16
BEGIN          1 Advisor.t:17
BEGIN          1 Advisor.t:4 
BEGIN          1 Advisor.t:9 
BEGIN          1 Advisor.t:97
__ANON__       1 Advisor.t:35
__ANON__       1 Advisor.t:60


