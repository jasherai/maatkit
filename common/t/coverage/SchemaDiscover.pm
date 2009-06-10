---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/SchemaDiscover.pm   91.4   41.7  100.0   87.5    n/a  100.0   86.0
Total                          91.4   41.7  100.0   87.5    n/a  100.0   86.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SchemaDiscover.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:58 2009
Finish:       Wed Jun 10 17:20:58 2009

/home/daniel/dev/maatkit/common/SchemaDiscover.pm

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
18                                                    # SchemaDiscover package $Revision: 3467 $
19                                                    # ###########################################################################
20                                                    package SchemaDiscover;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  7   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
28                                                    
29                                                    sub new {
30             1                    1            10      my ( $class, %args ) = @_;
31             1                                  5      foreach my $arg ( qw(du q tp vp) ) {
32    ***      4     50                          18         die "I need a $arg argument" unless $args{$arg};
33                                                       }
34             1                                  6      my $self = {
35                                                          %args
36                                                       };
37             1                                 10      return bless $self, $class;
38                                                    }
39                                                    
40                                                    sub discover {
41             1                    1             4      my ( $self, $dbh ) = @_;
42    ***      1     50                           5      die "I need a dbh" unless $dbh;
43                                                    
44             1                                  7      my $schema = {
45                                                          dbs         => {},
46                                                          counts      => {},
47                                                          stored_code => undef,  # may be either arrayref of error string
48                                                       };
49                                                       # brevity:
50             1                                  4      my $dbs     = $schema->{dbs};
51             1                                  3      my $counts  = $schema->{counts};
52             1                                  3      my $du      = $self->{du};
53             1                                  4      my $q       = $self->{q};
54             1                                  3      my $tp      = $self->{tp};
55             1                                  3      my $vp      = $self->{vp};
56                                                    
57             1                                  6      %$dbs = map { $_ => {} } $du->get_databases($dbh, $q);
               3                                 15   
58                                                    
59    ***      1     50                           8      delete $dbs->{information_schema}
60                                                          if exists $dbs->{information_schema};
61                                                    
62             1                                  3      $counts->{TOTAL}->{dbs} = scalar keys %{$dbs};
               1                                  7   
63                                                    
64             1                                  5      foreach my $db ( keys %$dbs ) {
65             2                                 39         %{$dbs->{$db}}
              40                                156   
66             2                                 13            = map { $_->{name} => {} } $du->get_table_list($dbh, $q, $db);
67             2                                 20         foreach my $tbl_stat ($du->get_table_status($dbh, $q, $db)) {
68            40                                202            %{$dbs->{$db}->{"$tbl_stat->{name}"}} = %$tbl_stat;
              40                                617   
69                                                          }
70             2                                  8         foreach my $table ( keys %{$dbs->{$db}} ) {
               2                                 14   
71            40                                217            my $ddl        = $du->get_create_table($dbh, $q, $db, $table);
72            40                                210            my $table_info = $tp->parse($ddl);
73            40                                165            my $n_indexes  = scalar keys %{ $table_info->{keys} };
              40                                187   
74                                                             # TODO: pass mysql version to TableParser->parse()
75                                                             # TODO: also aggregate indexes by type: BTREE, HASH, FULLTEXT etc
76                                                             #       so we can get a count + size along that dimension too
77                                                    
78            40           100                  346            my $data_size  = $dbs->{$db}->{$table}->{data_length}  ||= 0;
79            40           100                  252            my $index_size = $dbs->{$db}->{$table}->{index_length} ||= 0;
80            40           100                  263            my $rows       = $dbs->{$db}->{$table}->{rows}         ||= 0;
81            40                                170            my $engine     = $dbs->{$db}->{$table}->{engine}; 
82                                                    
83                                                             # Per-db counts
84            40                                203            $counts->{dbs}->{$db}->{tables}             += 1;
85            40                                159            $counts->{dbs}->{$db}->{indexes}            += $n_indexes;
86            40                                189            $counts->{dbs}->{$db}->{engines}->{$engine} += 1;
87            40                                170            $counts->{dbs}->{$db}->{rows}               += $rows;
88            40                                163            $counts->{dbs}->{$db}->{data_size}          += $data_size;
89            40                                163            $counts->{dbs}->{$db}->{index_size}         += $index_size;
90                                                    
91                                                             # Per-engline counts
92            40                                166            $counts->{engines}->{$engine}->{tables}     += 1;
93            40                                163            $counts->{engines}->{$engine}->{indexes}    += $n_indexes;
94            40                                160            $counts->{engines}->{$engine}->{data_size}  += $data_size;
95            40                                162            $counts->{engines}->{$engine}->{index_size} += $index_size; 
96                                                    
97                                                             # Grand total schema counts
98            40                                149            $counts->{TOTAL}->{tables}     += 1;
99            40                                142            $counts->{TOTAL}->{indexes}    += $n_indexes;
100           40                                134            $counts->{TOTAL}->{rows}       += $rows;
101           40                                145            $counts->{TOTAL}->{data_size}  += $data_size;
102           40                                569            $counts->{TOTAL}->{index_size} += $index_size;
103                                                         }
104                                                      }
105                                                   
106   ***      1     50                           9      if ( $vp->version_ge($dbh, '5.0.0') ) {
107            1                                  6         $schema->{stored_code} = $self->discover_stored_code($dbh);
108                                                      }
109                                                      else {
110   ***      0                                  0         $schema->{stored_code}
111                                                            = 'This version of MySQL does not support stored code.';
112                                                      }
113                                                   
114            1                                  7      return $schema;
115                                                   }
116                                                   
117                                                   # Returns an arrayref of strings which summarize the stored code
118                                                   # objects like: "db obj_type count".
119                                                   sub discover_stored_code {
120            1                    1             4      my ( $self, $dbh ) = @_;
121   ***      1     50                           5      die "I need a dbh" unless $dbh;
122                                                   
123            1                                  2      my @stored_code_objs  =
124            1                                  3         @{ $dbh->selectall_arrayref(
125                                                               "SELECT EVENT_OBJECT_SCHEMA AS db,
126                                                               CONCAT(LEFT(LOWER(EVENT_MANIPULATION), 3), '_trg') AS what,
127                                                               COUNT(*) AS num
128                                                               FROM INFORMATION_SCHEMA.TRIGGERS GROUP BY db, what
129                                                               UNION ALL
130                                                               SELECT ROUTINE_SCHEMA AS db,
131                                                               LEFT(LOWER(ROUTINE_TYPE), 4) AS what,
132                                                               COUNT(*) AS num
133                                                               FROM INFORMATION_SCHEMA.ROUTINES GROUP BY db, what
134                                                               /*!50106
135                                                                  UNION ALL
136                                                                  SELECT EVENT_SCHEMA AS db, 'evt' AS what, COUNT(*) AS num
137                                                                  FROM INFORMATION_SCHEMA.EVENTS GROUP BY db, what
138                                                               */")
139                                                         };
140                                                   
141            1                               3807      my @formatted_code_objs;
142            1                                  6      foreach my $code_obj ( @stored_code_objs ) {
143            5                                 35         push @formatted_code_objs, "$code_obj->[0] $code_obj->[1] $code_obj->[2]";
144                                                      }
145                                                   
146            1                                 12      return \@formatted_code_objs;
147                                                   }
148                                                   
149                                                   sub _d {
150   ***      0                    0                    my ($package, undef, $line) = caller 0;
151   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
152   ***      0                                              map { defined $_ ? $_ : 'undef' }
153                                                           @_;
154   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
155                                                   }
156                                                   
157                                                   1;
158                                                   
159                                                   # ###########################################################################
160                                                   # End SchemaDiscover package
161                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
32    ***     50      0      4   unless $args{$arg}
42    ***     50      0      1   unless $dbh
59    ***     50      1      0   if exists $$dbs{'information_schema'}
106   ***     50      1      0   if ($vp->version_ge($dbh, '5.0.0')) { }
121   ***     50      0      1   unless $dbh
151   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
78           100     23     17   $$dbs{$db}{$table}{'data_length'} ||= 0
79           100     30     10   $$dbs{$db}{$table}{'index_length'} ||= 0
80           100     23     17   $$dbs{$db}{$table}{'rows'} ||= 0


Covered Subroutines
-------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:22 
BEGIN                    1 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:23 
BEGIN                    1 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:25 
BEGIN                    1 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:27 
discover                 1 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:41 
discover_stored_code     1 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:120
new                      1 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:30 

Uncovered Subroutines
---------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/SchemaDiscover.pm:150


