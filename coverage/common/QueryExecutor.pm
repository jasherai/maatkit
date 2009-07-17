---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryExecutor.pm   93.9   54.2    n/a  100.0    n/a  100.0   87.3
Total                          93.9   54.2    n/a  100.0    n/a  100.0   87.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryExecutor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 17 15:51:26 2009
Finish:       Fri Jul 17 15:51:27 2009

/home/daniel/dev/maatkit/common/QueryExecutor.pm

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
18                                                    # QueryExecutor package $Revision: 4184 $
19                                                    # ###########################################################################
20                                                    package QueryExecutor;
21                                                    
22             1                    1             9   use strict;
               1                                  3   
               1                                 11   
23             1                    1            11   use warnings FATAL => 'all';
               1                                  3   
               1                                 14   
24                                                    
25             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                 19   
26             1                    1            22   use Time::HiRes qw(time);
               1                                  5   
               1                                  9   
27             1                    1            12   use Data::Dumper;
               1                                  4   
               1                                 13   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32             1                    1            11   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  4   
               1                                 18   
33                                                    
34                                                    sub new {
35             1                    1            16      my ( $class, %args ) = @_;
36             1                                 16      foreach my $arg ( qw() ) {
37    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
38                                                       }
39             1                                  9      my $self = {};
40             1                                 62      return bless $self, $class;
41                                                    }
42                                                    
43                                                    # Executes the given query on the two given host dbhs.
44                                                    # Returns a hashref with query execution time and number of errors
45                                                    # and warnings produced on each host:
46                                                    #    {
47                                                    #       host1 => {
48                                                    #          Query_time    => 1.123456,  # Query execution time
49                                                    #          warning_count => 3,         # @@warning_count,
50                                                    #          warnings      => {          # SHOW WARNINGS
51                                                    #             1062 => {
52                                                    #                Level   => "Error",
53                                                    #                Code    => "1062",
54                                                    #                Message => "Duplicate entry '1' for key 1",
55                                                    #             }
56                                                    #          },
57                                                    #       },
58                                                    #       host2 => {
59                                                    #          etc.
60                                                    #       }
61                                                    #    }
62                                                    # If the query cannot be executed on a host, an error string is returned
63                                                    # for that host instead of the hashref of results.
64                                                    #
65                                                    # Optional arguments are:
66                                                    #   * pre_exec_query     Execute this query before executing main query
67                                                    #   * post_exec_query    Execute this query after executing main query
68                                                    #
69                                                    sub exec {
70             5                    5           105      my ( $self, %args ) = @_;
71             5                                 50      foreach my $arg ( qw(query host1_dbh host2_dbh) ) {
72    ***     15     50                         129         die "I need a $arg argument" unless $args{$arg};
73                                                       }
74                                                    
75             5    100                          40      if ( $args{pre_exec_query} ) {
76             2                                  8         MKDEBUG && _d('pre-exec query:', $args{pre_exec_query});
77             2                                 22         $self->_exec_query($args{pre_exec_query}, $args{host1_dbh});
78             2                                 23         $self->_exec_query($args{pre_exec_query}, $args{host2_dbh});
79                                                       }
80                                                    
81             5                                 20      MKDEBUG && _d('query:', $args{query});
82             5                                 81      my $host1_results = $self->_exec_query($args{query}, $args{host1_dbh});
83             5                                 59      my $host2_results = $self->_exec_query($args{query}, $args{host2_dbh});
84                                                    
85             5    100                          44      if ( $args{post_exec_query} ) {
86             2                                  8         MKDEBUG && _d('post-exec query:', $args{post_exec_query});
87             2                                 23         $self->_exec_query($args{post_exec_query}, $args{host1_dbh});
88             2                                 23         $self->_exec_query($args{post_exec_query}, $args{host2_dbh});
89                                                       }
90                                                    
91                                                       return {
92             5                                 78         host1 => $host1_results,
93                                                          host2 => $host2_results,
94                                                       };
95                                                    }
96                                                    
97                                                    # This sub is called by exec() to do its common work:
98                                                    # execute, time and get warnings for a query on a given host.
99                                                    sub _exec_query {
100           18                   18           140      my ( $self, $query, $dbh ) = @_;
101   ***     18     50                         123      die "I need a query" unless $query;
102   ***     18     50                         113      die "I need a dbh"   unless $dbh;
103                                                   
104           18                                 85      my ( $start, $end, $query_time );
105           18                                 82      eval {
106           18                                174         $start = time();
107           18                              99630         $dbh->do($query);
108           18                                194         $end   = time();
109           18                                417         $query_time = sprintf '%.6f', $end - $start;
110                                                      };
111   ***     18     50                         125      if ( $EVAL_ERROR ) {
112   ***      0                                  0         MKDEBUG && _d($EVAL_ERROR);
113   ***      0                                  0         return $EVAL_ERROR;
114                                                      }
115                                                   
116           18                                 70      my $warnings = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
117           18                                588      MKDEBUG && _d('warnings:', Dumper($warnings));
118                                                   
119           18                                197      my $warning_count = $dbh->selectall_arrayref('SELECT @@warning_count',
120                                                         { Slice => {} });
121           18                                190      MKDEBUG && _d('warning count:', Dumper($warning_count));
122                                                   
123           18                                254      my $results = {
124                                                         Query_time    => $query_time,
125                                                         warnings      => $warnings,
126                                                         warning_count => $warning_count->[0]->{'@@warning_count'},
127                                                      };
128                                                   
129           18                                159      return $results;
130                                                   }   
131                                                   
132                                                   sub checksum_results {
133            2                    2            39      my ( $self, %args ) = @_;
134            2                                 25      foreach my $arg ( qw(query host1_dbh host2_dbh database
135                                                                           Quoter MySQLDump TableParser) ) {
136   ***     14     50                         106         die "I need a $arg argument" unless $args{$arg};
137                                                      }
138                                                   
139            2                                  8      MKDEBUG && _d('query:', $args{query});
140            2                                 32      my $host1_results = $self->_checksum_results(%args, dbh => $args{host1_dbh});
141            2                                 30      my $host2_results = $self->_checksum_results(%args, dbh => $args{host2_dbh});
142                                                   
143                                                      return {
144            2                                 35         host1 => $host1_results,
145                                                         host2 => $host2_results,
146                                                      };
147                                                   }
148                                                   
149                                                   
150                                                   sub _checksum_results {
151            4                    4            62      my ( $self, %args ) = @_;
152                                                      # args are checked in checksum_results().
153            4                                 31      my $query = $args{query};
154            4                                 22      my $db    = $args{database};
155            4                                 20      my $dbh   = $args{dbh};
156            4                                 20      my $du    = $args{MySQLDump};
157            4                                 20      my $tp    = $args{TableParser};
158            4                                 17      my $q     = $args{Quoter};
159                                                   
160            4                                 16      my $tmp_tbl    = 'mk_upgrade';
161            4                                 36      my $tmp_db_tbl = $q->quote($db, $tmp_tbl);
162                                                   
163            4                                 20      eval {
164            4                               2131         $dbh->do("DROP TABLE IF EXISTS $tmp_db_tbl");
165            4                                678         $dbh->do("SET storage_engine=MyISAM");
166            4                                 46         my $sql = "CREATE TEMPORARY TABLE $tmp_db_tbl AS $query";
167            4                               4796         $dbh->do($sql)
168                                                      };
169   ***      4     50                          47      if ( $EVAL_ERROR ) {
170   ***      0                                  0         MKDEBUG && _d($EVAL_ERROR);
171   ***      0                                  0         return $EVAL_ERROR;
172                                                      }
173                                                   
174            4                                 20      my $n_rows = $dbh->selectall_arrayref("SELECT COUNT(*) FROM $tmp_db_tbl");
175            4                                 16      my $tbl_checksum = $dbh->selectall_arrayref("CHECKSUM TABLE $tmp_db_tbl");
176                                                   
177            4                               1058      my $tbl_struct;
178            4                                 57      my $ddl = $du->get_create_table($dbh, $q, $db, $tmp_tbl);
179   ***      4     50                          43      if ( $ddl->[0] eq 'table' ) {
180            4                                 16         eval { $tbl_struct = $tp->parse($ddl) };
               4                                 44   
181   ***      4     50                          36         if ( $EVAL_ERROR ) {
182   ***      0                                  0            MKDEBUG && _d('Failed to parse', $tmp_db_tbl, ':', $EVAL_ERROR);
183                                                         }
184                                                      }
185                                                   
186            4                                 56      my $results = {
187                                                         table_checksum => $tbl_checksum->[0]->[1],
188                                                         n_rows         => $n_rows->[0]->[0],
189                                                         table_struct   => $tbl_struct,
190                                                      };
191            4                                 16      MKDEBUG && _d('checksum results:', Dumper($results));
192                                                   
193            4                                 54      return $results;
194                                                   }   
195                                                   
196                                                   sub _d {
197            1                    1            14      my ($package, undef, $line) = caller 0;
198   ***      2     50                          19      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 18   
199            1                                  8           map { defined $_ ? $_ : 'undef' }
200                                                           @_;
201            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
202                                                   }
203                                                   
204                                                   1;
205                                                   
206                                                   # ###########################################################################
207                                                   # End QueryExecutor package
208                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
37    ***      0      0      0   unless $args{$arg}
72    ***     50      0     15   unless $args{$arg}
75           100      2      3   if ($args{'pre_exec_query'})
85           100      2      3   if ($args{'post_exec_query'})
101   ***     50      0     18   unless $query
102   ***     50      0     18   unless $dbh
111   ***     50      0     18   if ($EVAL_ERROR)
136   ***     50      0     14   unless $args{$arg}
169   ***     50      0      4   if ($EVAL_ERROR)
179   ***     50      4      0   if ($$ddl[0] eq 'table')
181   ***     50      0      4   if ($EVAL_ERROR)
198   ***     50      2      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine        Count Location                                            
----------------- ----- ----------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:22 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:23 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:25 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:26 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:27 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:32 
_checksum_results     4 /home/daniel/dev/maatkit/common/QueryExecutor.pm:151
_d                    1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:197
_exec_query          18 /home/daniel/dev/maatkit/common/QueryExecutor.pm:100
checksum_results      2 /home/daniel/dev/maatkit/common/QueryExecutor.pm:133
exec                  5 /home/daniel/dev/maatkit/common/QueryExecutor.pm:70 
new                   1 /home/daniel/dev/maatkit/common/QueryExecutor.pm:35 


