---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/ExplainAnalyzer.pm   91.5   65.0   59.1   92.3    0.0   61.1   77.4
ExplainAnalyzer.t             100.0   50.0   40.0  100.0    n/a   38.9   93.9
Total                          95.4   62.5   55.6   96.2    0.0  100.0   83.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Jun  8 16:19:57 2010
Finish:       Tue Jun  8 16:19:57 2010

Run:          ExplainAnalyzer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Jun  8 16:19:59 2010
Finish:       Tue Jun  8 16:19:59 2010

/home/daniel/dev/maatkit/common/ExplainAnalyzer.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010-@CURRENTYEAR@ Percona Inc.
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
18                                                    # ExplainAnalyzer package $Revision: 6326 $
19                                                    # ###########################################################################
20                                                    package ExplainAnalyzer;
21                                                    
22    ***      1            50      1             5   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 15   
23             1                    1             6   use strict;
               1                                  2   
               1                                  7   
24             1                    1             9   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
25                                                    
26             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
27             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32                                                    # This class is a container for some utility methods for getting and
33                                                    # manipulating EXPLAIN data to find out interesting things about it.  It also
34                                                    # has methods to save and retrieve information, so it actually has state itself
35                                                    # if used in this way -- it is not a data-less collection of methods.
36                                                    
37                                                    sub new {
38    ***      1                    1      0      7      my ( $class, %args ) = @_;
39             1                                  5      foreach my $arg ( qw(QueryRewriter QueryParser) ) {
40    ***      2     50                          12         die "I need a $arg argument" unless defined $args{$arg};
41                                                       }
42             1                                  6      my $self = {
43                                                          %args,
44                                                       };
45             1                                 11      return bless $self, $class;
46                                                    }
47                                                    
48                                                    # Gets an EXPLAIN plan for a query.  The arguments are:
49                                                    #  dbh   The $dbh, which should already have the correct default database.  This
50                                                    #        module does not run USE to select a default database.
51                                                    #  sql   The query text.
52                                                    # The return value is an arrayref of hash references gotten from EXPLAIN.  If
53                                                    # the sql is not a SELECT, we try to convert it into one.
54                                                    sub explain_query {
55    ***      2                    2      0     13      my ( $self, %args ) = @_;
56             2                                  9      foreach my $arg ( qw(dbh sql) ) {
57    ***      4     50                          19         die "I need a $arg argument" unless defined $args{$arg};
58                                                       }
59             2                                 12      my ($sql, $dbh) = @args{qw(sql dbh)};
60             2    100                          34      if ( $sql !~ m/^\s*select/i ) {
61             1                                 10         $sql = $self->{QueryRewriter}->convert_to_select($sql);
62                                                       }
63             2                                 30      return $dbh->selectall_arrayref("EXPLAIN $sql", { Slice => {} });
64                                                    }
65                                                    
66                                                    # Normalizes raw EXPLAIN into a format that's easier to work with.  For example,
67                                                    # the Extra column is parsed into a hash.  Accepts the output of explain_query()
68                                                    # as input.
69                                                    sub normalize {
70    ***      5                    5      0     22      my ( $self, $explain ) = @_;
71             5                                 13      my @result; # Don't modify the input.
72                                                    
73             5                                 19      foreach my $row ( @$explain ) {
74            10                                 79         $row = { %$row }; # Make a copy -- don't modify the input.
75                                                    
76                                                          # Several of the columns are really arrays of values in many cases.  For
77                                                          # example, the "key" column has an array when there is an index merge.
78            10                                 43         foreach my $col ( qw(key possible_keys key_len ref) ) {
79            40           100                  317            $row->{$col} = [ split(/,/, $row->{$col} || '') ];
80                                                          }
81                                                    
82                                                          # Handle the Extra column.  Parse it into a hash by splitting on
83                                                          # semicolons.  There are many special cases to handle.
84             9                                 23         $row->{Extra} = {
85                                                             map {
86            10                                 54               my $var = $_;
87                                                    
88                                                                # Index merge query plans have an array of indexes to split up.
89             9    100                          63               if ( my($key, $vals) = $var =~ m/(Using union)\(([^)]+)\)/ ) {
90             2                                 13                  $key => [ split(/,/, $vals) ];
91                                                                }
92                                                    
93                                                                # The default is just "this key/characteristic/flag exists."
94                                                                else {
95             7                                 43                  $var => 1;
96                                                                }
97                                                             }
98                                                             split(/; /, $row->{Extra}) # Split on semicolons.
99                                                          };
100                                                   
101           10                                 40         push @result, $row;
102                                                      }
103                                                   
104            5                                 71      return \@result;
105                                                   }
106                                                   
107                                                   # Trims down alternate indexes to those that were truly alternates (were not
108                                                   # actually used).  For example, if key = 'foo' and possible_keys = 'foo,bar',
109                                                   # then foo isn't an alternate index, only bar is.  The arguments are arrayrefs,
110                                                   # and the return value is an arrayref too.
111                                                   sub get_alternate_indexes {
112   ***      5                    5      0     21      my ( $self, $keys, $possible_keys ) = @_;
113            5                                 19      my %used = map { $_ => 1 } @$keys;
               6                                 30   
114            5                                 27      return [ grep { !$used{$_} } @$possible_keys ];
               8                                 42   
115                                                   }
116                                                   
117                                                   # Returns a data structure that shows which indexes were used and considered for
118                                                   # a given query and EXPLAIN plan.  Input parameters are:
119                                                   #  sql      The SQL of the query.
120                                                   #  db       The default database.  When a table's database is not explicitly
121                                                   #           qualified in the SQL itself, it defaults to this (optional) value.
122                                                   #  explain  The normalized EXPLAIN plan: the output from $self->normalize().
123                                                   # The return value is an arrayref of hashrefs, one per row in the query.  Each
124                                                   # hashref has the following structure:
125                                                   #  db    =>    The database of the table in question
126                                                   #  tbl   =>    The table that was accessed
127                                                   #  idx   =>    An arrayref of indexes accessed in this table
128                                                   #  alt   =>    An arrayref of indexes considered but not accessed
129                                                   sub get_index_usage {
130   ***      3                    3      0     25      my ( $self, %args ) = @_;
131            3                                 11      foreach my $arg ( qw(sql explain) ) {
132   ***      6     50                          30         die "I need a $arg argument" unless defined $args{$arg};
133                                                      }
134            3                                 15      my ($sql, $explain) = @args{qw(sql explain)};
135            3                                  6      my @result;
136                                                   
137                                                      # First we must get a lookup data structure to translate the possibly aliased
138                                                      # names back into real table names.
139            3                                 19      my $lookup = $self->{QueryParser}->get_aliases($sql);
140                                                   
141            3                                812      foreach my $row ( @$explain ) {
142                                                   
143                                                         # Filter out any row that doesn't access a (real) table.  However, a row
144                                                         # that accesses a table but not an index is still interesting, so we do
145                                                         # not filter that out.
146            6    100    100                   86         next if !defined $row->{table}
147                                                            # Tables named like <union1,2> are just internal temp tables, not real
148                                                            # tables that we can analyze.
149                                                            || $row->{table} =~ m/^<(derived|union)\d/;
150                                                   
151   ***      4            33                   23         my $table = $lookup->{TABLE}->{$row->{table}} || $row->{table};
152   ***      4            66                   29         my $db    = $lookup->{DATABASE}->{$table}     || $args{db};
153            4                                 27         push @result, {
154                                                            db  => $db,
155                                                            tbl => $table,
156                                                            idx => $row->{key},
157                                                            alt => $self->get_alternate_indexes(
158                                                                     $row->{key}, $row->{possible_keys}),
159                                                         };
160                                                      }
161                                                   
162            3                                 39      return \@result;
163                                                   }
164                                                   
165                                                   # This method retrieves information about how a query uses indexes, if it
166                                                   # has been saved through save_usage_for().  It is basically a cache for
167                                                   # remembering "oh, I've seen exactly this query before.  No need to re-EXPLAIN
168                                                   # and all that stuff."  The information returned is in the same form as that of
169                                                   # get_index_usage().  If no usage has been saved for the arguments, the return
170                                                   # value is undef.  The arguments are:
171                                                   # - The query's checksum (not the fingerprint's checksum)
172                                                   # - The database connection's default database.  If a query is run against two
173                                                   #   different databases, it might use different tables and indexes.
174                                                   sub get_usage_for {
175   ***      2                    2      0     10      my ( $self, $checksum, $db ) = @_;
176   ***      2     50     33                   19      die "I need a checksum and db" unless defined $checksum && defined $db;
177   ***      2    100     66                   19      if ( exists $self->{usage}->{$db} # Don't auto-vivify
178                                                        && exists $self->{usage}->{$db}->{$checksum} )
179                                                      {
180            1                                 11         return $self->{usage}->{$db}->{$checksum};
181                                                      }
182                                                      else {
183            1                                  5         return undef;
184                                                      }
185                                                   }
186                                                   
187                                                   # This methods saves the query's index usage patterns for later retrieval with
188                                                   # get_usage_for().  See that method for an explanation of the arguments.
189                                                   sub save_usage_for {
190   ***      1                    1      0      6      my ( $self, $checksum, $db, $usage ) = @_;
191   ***      1     50     33                   17      die "I need a checksum and db" unless defined $checksum && defined $db;
192            1                                  8      $self->{usage}->{$db}->{$checksum} = $usage;
193                                                   }
194                                                   
195                                                   sub _d {
196   ***      0                    0                    my ($package, undef, $line) = caller 0;
197   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
198   ***      0                                              map { defined $_ ? $_ : 'undef' }
199                                                           @_;
200   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
201                                                   }
202                                                   
203                                                   1;
204                                                   
205                                                   # ###########################################################################
206                                                   # End ExplainAnalyzer package
207                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
40    ***     50      0      2   unless defined $args{$arg}
57    ***     50      0      4   unless defined $args{$arg}
60           100      1      1   if (not $sql =~ /^\s*select/i)
89           100      2      7   if (my($key, $vals) = $var =~ /(Using union)\(([^)]+)\)/) { }
132   ***     50      0      6   unless defined $args{$arg}
146          100      2      4   if not defined $$row{'table'} or $$row{'table'} =~ /^<(derived|union)\d/
176   ***     50      0      2   unless defined $checksum and defined $db
177          100      1      1   if (exists $$self{'usage'}{$db} and exists $$self{'usage'}{$db}{$checksum}) { }
191   ***     50      0      1   unless defined $checksum and defined $db
197   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
176   ***     33      0      0      2   defined $checksum and defined $db
177   ***     66      1      0      1   exists $$self{'usage'}{$db} and exists $$self{'usage'}{$db}{$checksum}
191   ***     33      0      0      1   defined $checksum and defined $db

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
22    ***     50      0      1   $ENV{'MKDEBUG'} || 0
79           100     14     26   $$row{$col} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
146          100      1      1      4   not defined $$row{'table'} or $$row{'table'} =~ /^<(derived|union)\d/
151   ***     33      4      0      0   $$lookup{'TABLE'}{$$row{'table'}} || $$row{'table'}
152   ***     66      1      3      0   $$lookup{'DATABASE'}{$table} || $args{'db'}


Covered Subroutines
-------------------

Subroutine            Count Pod Location                                              
--------------------- ----- --- ------------------------------------------------------
BEGIN                     1     /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:22 
BEGIN                     1     /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:23 
BEGIN                     1     /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:24 
BEGIN                     1     /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:26 
BEGIN                     1     /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:27 
explain_query             2   0 /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:55 
get_alternate_indexes     5   0 /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:112
get_index_usage           3   0 /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:130
get_usage_for             2   0 /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:175
new                       1   0 /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:38 
normalize                 5   0 /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:70 
save_usage_for            1   0 /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:190

Uncovered Subroutines
---------------------

Subroutine            Count Pod Location                                              
--------------------- ----- --- ------------------------------------------------------
_d                        0     /home/daniel/dev/maatkit/common/ExplainAnalyzer.pm:196


ExplainAnalyzer.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9     ***      1            50      1            12   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 16   
10             1                    1             6   use strict;
               1                                  2   
               1                                  5   
11             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
12             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
13             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                 12   
14             1                                  5   $Data::Dumper::Indent    = 1;
15             1                                  9   $Data::Dumper::Sortkeys  = 1;
16             1                                  3   $Data::Dumper::Quotekeys = 0;
17                                                    
18             1                    1            10   use Test::More tests => 10;
               1                                  3   
               1                                 10   
19                                                    
20             1                    1            51   use ExplainAnalyzer;
               1                                  3   
               1                                 15   
21             1                    1            11   use QueryRewriter;
               1                                  3   
               1                                 10   
22             1                    1            10   use QueryParser;
               1                                  3   
               1                                 11   
23             1                    1            10   use DSNParser;
               1                                  3   
               1                                 13   
24             1                    1            13   use Sandbox;
               1                                  3   
               1                                 10   
25             1                    1            10   use MaatkitTest;
               1                                  5   
               1                                 39   
26                                                    
27             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
28             1                                233   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
29    ***      1     50                          52   my $dbh = $sb->get_dbh_for('master')
30                                                       or BAIL_OUT('Cannot connect to sandbox master');
31             1                                473   $dbh->do('use sakila');
32                                                    
33             1                                 16   my $qr  = new QueryRewriter();
34             1                                 35   my $qp  = new QueryParser();
35             1                                 26   my $exa = new ExplainAnalyzer(QueryRewriter => $qr, QueryParser => $qp);
36                                                    
37                                                    # #############################################################################
38                                                    # Tests for getting an EXPLAIN from a database.
39                                                    # #############################################################################
40                                                    
41             1                                  8   is_deeply(
42                                                       $exa->explain_query(
43                                                          dbh => $dbh,
44                                                          sql => 'select * from actor where actor_id = 5',
45                                                       ),
46                                                       [
47                                                          { id            => 1,
48                                                            select_type   => 'SIMPLE',
49                                                            table         => 'actor',
50                                                            type          => 'const',
51                                                            possible_keys => 'PRIMARY',
52                                                            key           => 'PRIMARY',
53                                                            key_len       => 2,
54                                                            ref           => 'const',
55                                                            rows          => 1,
56                                                            Extra         => '',
57                                                          },
58                                                       ],
59                                                       'Got a simple EXPLAIN result',
60                                                    );
61                                                    
62             1                                 18   is_deeply(
63                                                       $exa->explain_query(
64                                                          dbh => $dbh,
65                                                          sql => 'delete from actor where actor_id = 5',
66                                                       ),
67                                                       [
68                                                          { id            => 1,
69                                                            select_type   => 'SIMPLE',
70                                                            table         => 'actor',
71                                                            type          => 'const',
72                                                            possible_keys => 'PRIMARY',
73                                                            key           => 'PRIMARY',
74                                                            key_len       => 2,
75                                                            ref           => 'const',
76                                                            rows          => 1,
77                                                            Extra         => '',
78                                                          },
79                                                       ],
80                                                       'Got EXPLAIN result for a DELETE',
81                                                    );
82                                                    
83                                                    # #############################################################################
84                                                    # NOTE: EXPLAIN will vary between versions, so rely on the database as little as
85                                                    # possible for tests.  Most things that need an EXPLAIN in the tests below
86                                                    # should be using a hard-coded data structure.  Thus the following, intended to
87                                                    # help prevent $dbh being used too much.
88                                                    # #############################################################################
89                                                    # XXX $dbh->disconnect;
90                                                    
91                                                    # #############################################################################
92                                                    # Tests for normalizing raw EXPLAIN into a format that's easier to work with.
93                                                    # #############################################################################
94             1                                 29   is_deeply(
95                                                       $exa->normalize(
96                                                          [
97                                                             { id            => 1,
98                                                               select_type   => 'SIMPLE',
99                                                               table         => 'film_actor',
100                                                              type          => 'index_merge',
101                                                              possible_keys => 'PRIMARY,idx_fk_film_id',
102                                                              key           => 'PRIMARY,idx_fk_film_id',
103                                                              key_len       => '2,2',
104                                                              ref           => undef,
105                                                              rows          => 34,
106                                                              Extra         => 'Using union(PRIMARY,idx_fk_film_id); Using where',
107                                                            },
108                                                         ],
109                                                      ),
110                                                      [
111                                                         { id            => 1,
112                                                           select_type   => 'SIMPLE',
113                                                           table         => 'film_actor',
114                                                           type          => 'index_merge',
115                                                           possible_keys => [qw(PRIMARY idx_fk_film_id)],
116                                                           key           => [qw(PRIMARY idx_fk_film_id)],
117                                                           key_len       => [2,2],
118                                                           ref           => [qw()],
119                                                           rows          => 34,
120                                                           Extra         => {
121                                                              'Using union' => [qw(PRIMARY idx_fk_film_id)],
122                                                              'Using where' => 1,
123                                                           },
124                                                         },
125                                                      ],
126                                                      'Normalizes an EXPLAIN',
127                                                   );
128                                                   
129            1                                 39   is_deeply(
130                                                      $exa->normalize(
131                                                         [
132                                                            { id            => 1,
133                                                              select_type   => 'PRIMARY',
134                                                              table         => undef,
135                                                              type          => undef,
136                                                              possible_keys => undef,
137                                                              key           => undef,
138                                                              key_len       => undef,
139                                                              ref           => undef,
140                                                              rows          => undef,
141                                                              Extra         => 'No tables used',
142                                                            },
143                                                            { id            => 1,
144                                                              select_type   => 'UNION',
145                                                              table         => 'a',
146                                                              type          => 'index',
147                                                              possible_keys => undef,
148                                                              key           => 'PRIMARY',
149                                                              key_len       => '2',
150                                                              ref           => undef,
151                                                              rows          => 200,
152                                                              Extra         => 'Using index',
153                                                            },
154                                                            { id            => undef,
155                                                              select_type   => 'UNION RESULT',
156                                                              table         => '<union1,2>',
157                                                              type          => 'ALL',
158                                                              possible_keys => undef,
159                                                              key           => undef,
160                                                              key_len       => undef,
161                                                              ref           => undef,
162                                                              rows          => undef,
163                                                              Extra         => '',
164                                                            },
165                                                         ],
166                                                      ),
167                                                      [
168                                                         { id            => 1,
169                                                           select_type   => 'PRIMARY',
170                                                           table         => undef,
171                                                           type          => undef,
172                                                           possible_keys => [],
173                                                           key           => [],
174                                                           key_len       => [],
175                                                           ref           => [],
176                                                           rows          => undef,
177                                                           Extra         => {
178                                                              'No tables used' => 1,
179                                                           },
180                                                         },
181                                                         { id            => 1,
182                                                           select_type   => 'UNION',
183                                                           table         => 'a',
184                                                           type          => 'index',
185                                                           possible_keys => [],
186                                                           key           => ['PRIMARY'],
187                                                           key_len       => [2],
188                                                           ref           => [],
189                                                           rows          => 200,
190                                                           Extra         => {
191                                                            'Using index' => 1,
192                                                           },
193                                                         },
194                                                         { id            => undef,
195                                                           select_type   => 'UNION RESULT',
196                                                           table         => '<union1,2>',
197                                                           type          => 'ALL',
198                                                           possible_keys => [],
199                                                           key           => [],
200                                                           key_len       => [],
201                                                           ref           => [],
202                                                           rows          => undef,
203                                                           Extra         => {},
204                                                         },
205                                                      ],
206                                                      'Normalizes a more complex EXPLAIN',
207                                                   );
208                                                   
209                                                   # #############################################################################
210                                                   # Tests for trimming indexes out of possible_keys.
211                                                   # #############################################################################
212            1                                 43   is_deeply(
213                                                      $exa->get_alternate_indexes(
214                                                         [qw(index1 index2)],
215                                                         [qw(index1 index2 index3 index4)],
216                                                      ),
217                                                      [qw(index3 index4)],
218                                                      'Normalizes alternate indexes',
219                                                   );
220                                                   
221                                                   # #############################################################################
222                                                   # Tests for translating aliased names back to their real names.
223                                                   # #############################################################################
224                                                   
225                                                   # Putting it all together: given a query and an EXPLAIN, determine which indexes
226                                                   # the query used.
227            1                                 28   is_deeply(
228                                                      $exa->get_index_usage(
229                                                         sql => "select * from film_actor as fa inner join sakila.actor as a "
230                                                              . "on a.actor_id = fa.actor_id and a.last_name is not null "
231                                                              . "where a.actor_id = 5 or film_id = 5",
232                                                         db  => 'sakila',
233                                                         explain => $exa->normalize(
234                                                            [
235                                                               { id            => 1,
236                                                                 select_type   => 'SIMPLE',
237                                                                 table         => 'fa',
238                                                                 type          => 'index_merge',
239                                                                 possible_keys => 'PRIMARY,idx_fk_film_id',
240                                                                 key           => 'PRIMARY,idx_fk_film_id',
241                                                                 key_len       => '2,2',
242                                                                 ref           => undef,
243                                                                 rows          => 34,
244                                                                 Extra         => 'Using union(PRIMARY,idx_fk_film_id); Using where',
245                                                               },
246                                                               { id            => 1,
247                                                                 select_type   => 'SIMPLE',
248                                                                 table         => 'a',
249                                                                 type          => 'eq_ref',
250                                                                 possible_keys => 'PRIMARY,idx_actor_last_name',
251                                                                 key           => 'PRIMARY',
252                                                                 key_len       => '2',
253                                                                 ref           => 'sakila.fa.actor_id',
254                                                                 rows          => 1,
255                                                                 Extra         => 'Using where',
256                                                               },
257                                                            ],
258                                                         ),
259                                                      ),
260                                                      [  {  db  => 'sakila',
261                                                            tbl => 'film_actor',
262                                                            idx => [qw(PRIMARY idx_fk_film_id)],
263                                                            alt => [],
264                                                         },
265                                                         {  db  => 'sakila',
266                                                            tbl => 'actor',
267                                                            idx => [qw(PRIMARY)],
268                                                            alt => [qw(idx_actor_last_name)],
269                                                         },
270                                                      ],
271                                                      'Translate an EXPLAIN and a query into simplified index usage',
272                                                   );
273                                                   
274                                                   # This is kind of a pathological case.
275            1                                 46   is_deeply(
276                                                      $exa->get_index_usage(
277                                                         sql => "select 1 union select count(*) from actor a",
278                                                         db  => 'sakila',
279                                                         explain => $exa->normalize(
280                                                            [
281                                                               { id            => 1,
282                                                                 select_type   => 'PRIMARY',
283                                                                 table         => undef,
284                                                                 type          => undef,
285                                                                 possible_keys => undef,
286                                                                 key           => undef,
287                                                                 key_len       => undef,
288                                                                 ref           => undef,
289                                                                 rows          => undef,
290                                                                 Extra         => 'No tables used',
291                                                               },
292                                                               { id            => 1,
293                                                                 select_type   => 'UNION',
294                                                                 table         => 'a',
295                                                                 type          => 'index',
296                                                                 possible_keys => undef,
297                                                                 key           => 'PRIMARY',
298                                                                 key_len       => '2',
299                                                                 ref           => undef,
300                                                                 rows          => 200,
301                                                                 Extra         => 'Using index',
302                                                               },
303                                                               { id            => undef,
304                                                                 select_type   => 'UNION RESULT',
305                                                                 table         => '<union1,2>',
306                                                                 type          => 'ALL',
307                                                                 possible_keys => undef,
308                                                                 key           => undef,
309                                                                 key_len       => undef,
310                                                                 ref           => undef,
311                                                                 rows          => undef,
312                                                                 Extra         => '',
313                                                               },
314                                                            ],
315                                                         ),
316                                                      ),
317                                                      [  {  db  => 'sakila',
318                                                            tbl => 'actor',
319                                                            idx => [qw(PRIMARY)],
320                                                            alt => [],
321                                                         },
322                                                      ],
323                                                      'Translate an EXPLAIN and a query for a harder case',
324                                                   );
325                                                   
326                                                   # Here's a query that uses a table but no indexes in it.
327            1                                 32   is_deeply(
328                                                      $exa->get_index_usage(
329                                                         sql => "select * from film_text",
330                                                         db  => 'sakila',
331                                                         explain => $exa->normalize(
332                                                            [
333                                                               { id            => 1,
334                                                                 select_type   => 'SIMPLE',
335                                                                 table         => 'film_text',
336                                                                 type          => 'ALL',
337                                                                 possible_keys => undef,
338                                                                 key           => undef,
339                                                                 key_len       => undef,
340                                                                 ref           => undef,
341                                                                 rows          => 1000,
342                                                                 Extra         => '',
343                                                               },
344                                                            ],
345                                                         ),
346                                                      ),
347                                                      [  {  db  => 'sakila',
348                                                            tbl => 'film_text',
349                                                            idx => [],
350                                                            alt => [],
351                                                         },
352                                                      ],
353                                                      'Translate an EXPLAIN for a query that uses no indexes',
354                                                   );
355                                                   
356                                                   # #############################################################################
357                                                   # Methods to save and retrieve index usage for a specific query and database.
358                                                   # #############################################################################
359            1                                 22   is_deeply(
360                                                      $exa->get_usage_for('0xdeadbeef', 'sakila'),
361                                                      undef,
362                                                      'No usage recorded for 0xdeadbeef');
363                                                   
364            1                                 13   $exa->save_usage_for('0xdeadbeef', 'sakila',
365                                                      [  {  db  => 'sakila',
366                                                            tbl => 'actor',
367                                                            idx => [qw(PRIMARY)],
368                                                            alt => [],
369                                                         },
370                                                      ]);
371                                                   
372            1                                  5   is_deeply(
373                                                      $exa->get_usage_for('0xdeadbeef','sakila'),
374                                                      [  {  db  => 'sakila',
375                                                            tbl => 'actor',
376                                                            idx => [qw(PRIMARY)],
377                                                            alt => [],
378                                                         },
379                                                      ],
380                                                      'Got saved usage for 0xdeadbeef');
381                                                   
382                                                   # #############################################################################
383                                                   # Done.
384                                                   # #############################################################################
385            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
29    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
9     ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine Count Location            
---------- ----- --------------------
BEGIN          1 ExplainAnalyzer.t:10
BEGIN          1 ExplainAnalyzer.t:11
BEGIN          1 ExplainAnalyzer.t:12
BEGIN          1 ExplainAnalyzer.t:13
BEGIN          1 ExplainAnalyzer.t:18
BEGIN          1 ExplainAnalyzer.t:20
BEGIN          1 ExplainAnalyzer.t:21
BEGIN          1 ExplainAnalyzer.t:22
BEGIN          1 ExplainAnalyzer.t:23
BEGIN          1 ExplainAnalyzer.t:24
BEGIN          1 ExplainAnalyzer.t:25
BEGIN          1 ExplainAnalyzer.t:4 
BEGIN          1 ExplainAnalyzer.t:9 


