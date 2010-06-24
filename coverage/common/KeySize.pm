---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/KeySize.pm   93.7   80.0   62.5  100.0    0.0    0.6   86.3
KeySize.t                     100.0   50.0   50.0  100.0    n/a   99.4   95.6
Total                          97.0   75.0   57.1  100.0    0.0  100.0   90.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:38 2010
Finish:       Thu Jun 24 19:33:38 2010

Run:          KeySize.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:40 2010
Finish:       Thu Jun 24 19:33:41 2010

/home/daniel/dev/maatkit/common/KeySize.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-@CURRENTYEAR@ Percona Inc.
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
18                                                    # KeySize package $Revision: 6439 $
19                                                    # ###########################################################################
20                                                    package KeySize;
21                                                    
22             1                    1             9   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                 12   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      6      my ( $class, %args ) = @_;
30             1                                  5      my $self = { %args };
31             1                                 12      return bless $self, $class;
32                                                    }
33                                                    
34                                                    # Returns the key's size and the key that MySQL actually chose.
35                                                    # Required args:
36                                                    #    name       => name of key
37                                                    #    cols       => arrayref of key's cols
38                                                    #    tbl_name   => quoted, db-qualified table name like `db`.`tbl`
39                                                    #    tbl_struct => hashref returned by TableParser::parse for tbl
40                                                    #    dbh        => dbh
41                                                    # If the key exists in the tbl (it should), then we can FORCE INDEX.
42                                                    # This is what we want to do because it's more reliable.  But, if the
43                                                    # key does not exist in the tbl (which happens with foreign keys),
44                                                    # then we let MySQL choose the index.  If there's an error, nothing
45                                                    # is returned and you can get the last error, query and EXPLAIN with
46                                                    # error(), query() and explain().
47                                                    sub get_key_size {
48    ***      6                    6      0     88      my ( $self, %args ) = @_;
49             6                                 64      foreach my $arg ( qw(name cols tbl_name tbl_struct dbh) ) {
50    ***     30     50                         230         die "I need a $arg argument" unless $args{$arg};
51                                                       }
52             6                                 38      my $name = $args{name};
53             6                                 31      my @cols = @{$args{cols}};
               6                                 57   
54             6                                 35      my $dbh  = $args{dbh};
55                                                    
56             6                                 46      $self->{explain} = '';
57             6                                 95      $self->{query}   = '';
58             6                                 37      $self->{error}   = '';
59                                                    
60    ***      6     50                          45      if ( @cols == 0 ) {
61    ***      0                                  0         $self->{error} = "No columns for key $name";
62    ***      0                                  0         return;
63                                                       }
64                                                    
65             6                                 73      my $key_exists = $self->_key_exists(%args);
66             6                                 25      MKDEBUG && _d('Key', $name, 'exists in', $args{tbl_name}, ':',
67                                                          $key_exists ? 'yes': 'no');
68                                                    
69                                                       # Construct a SQL statement with WHERE conditions on all key
70                                                       # cols that will get EXPLAIN to tell us 1) the full length of
71                                                       # the key and 2) the total number of rows in the table.
72                                                       # For 1), all key cols must be used because key_len in EXPLAIN only
73                                                       # only covers the portion of the key needed to satisfy the query.
74                                                       # For 2), we have to break normal index usage which normally
75                                                       # allows MySQL to access only the limited number of rows needed
76                                                       # to satisify the query because we want to know total table rows.
77             6    100                         102      my $sql = 'EXPLAIN SELECT ' . join(', ', @cols)
78                                                               . ' FROM ' . $args{tbl_name}
79                                                               . ($key_exists ? " FORCE INDEX (`$name`)" : '')
80                                                               . ' WHERE ';
81             6                                 24      my @where_cols;
82             6                                 36      foreach my $col ( @cols ) {
83             8                                 61         push @where_cols, "$col=1";
84                                                       }
85                                                       # For single column indexes we have to trick MySQL into scanning
86                                                       # the whole index by giving it two irreducible condtions. Otherwise,
87                                                       # EXPLAIN rows will report only the rows that satisfy the query
88                                                       # using the key, but this is not what we want. We want total table rows.
89                                                       # In other words, we need an EXPLAIN type index, not ref or range.
90             6    100                          78      if ( scalar @cols == 1 ) {
91             4                                 27         push @where_cols, "$cols[0]<>1";
92                                                       }
93             6                                 38      $sql .= join(' OR ', @where_cols);
94             6                                 34      $self->{query} = $sql;
95             6                                 26      MKDEBUG && _d('sql:', $sql);
96                                                    
97             6                                 22      my $explain;
98             6                                 22      my $sth = $dbh->prepare($sql);
99             6                                 62      eval { $sth->execute(); };
               6                               2976   
100   ***      6     50                          51      if ( $EVAL_ERROR ) {
101   ***      0                                  0         chomp $EVAL_ERROR;
102   ***      0                                  0         $self->{error} = "Cannot get size of $name key: $EVAL_ERROR";
103   ***      0                                  0         return;
104                                                      }
105            6                                193      $explain = $sth->fetchrow_hashref();
106                                                   
107            6                                257      $self->{explain} = $explain;
108            6                                 36      my $key_len      = $explain->{key_len};
109            6                                 34      my $rows         = $explain->{rows};
110            6                                 39      my $chosen_key   = $explain->{key};  # May differ from $name
111            6                                 19      MKDEBUG && _d('MySQL chose key:', $chosen_key, 'len:', $key_len,
112                                                         'rows:', $rows);
113                                                   
114            6                                 26      my $key_size = 0;
115   ***      6    100     66                  100      if ( $key_len && $rows ) {
116   ***      5    100     66                   95         if ( $chosen_key =~ m/,/ && $key_len =~ m/,/ ) {
117            1                                  9            $self->{error} = "MySQL chose multiple keys: $chosen_key";
118            1                                 43            return;
119                                                         }
120            4                                 31         $key_size = $key_len * $rows;
121                                                      }
122                                                      else {
123            1                                  9         $self->{error} = "key_len or rows NULL in EXPLAIN:\n"
124                                                                        . _explain_to_text($explain);
125            1                                 64         return;
126                                                      }
127                                                   
128            4                                205      return $key_size, $chosen_key;
129                                                   }
130                                                   
131                                                   # Returns the last explained query.
132                                                   sub query {
133   ***      2                    2      0     13      my ( $self ) = @_;
134            2                                 22      return $self->{query};
135                                                   }
136                                                   
137                                                   # Returns the last explain plan.
138                                                   sub explain {
139   ***      1                    1      0      6      my ( $self ) = @_;
140            1                                 12      return _explain_to_text($self->{explain});
141                                                   }
142                                                   
143                                                   # Returns the last error.
144                                                   sub error {
145   ***      2                    2      0     15      my ( $self ) = @_;
146            2                                 20      return $self->{error};
147                                                   }
148                                                   
149                                                   sub _key_exists {
150            7                    7           129      my ( $self, %args ) = @_;
151            7    100                         157      return exists $args{tbl_struct}->{keys}->{ lc $args{name} } ? 1 : 0;
152                                                   }
153                                                   
154                                                   sub _explain_to_text {
155            2                    2            17      my ( $explain ) = @_;
156           20    100                         198      return join("\n",
157            2                                 52         map { "$_: ".($explain->{$_} ? $explain->{$_} : 'NULL') }
158                                                         sort keys %$explain
159                                                      );
160                                                   }
161                                                   
162                                                   sub _d {
163            1                    1            13      my ($package, undef, $line) = caller 0;
164   ***      2     50                          19      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 13   
               2                                 19   
165            1                                  9           map { defined $_ ? $_ : 'undef' }
166                                                           @_;
167            1                                  6      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
168                                                   }
169                                                   
170                                                   1;
171                                                   
172                                                   # ###########################################################################
173                                                   # End KeySize package
174                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
50    ***     50      0     30   unless $args{$arg}
60    ***     50      0      6   if (@cols == 0)
77           100      4      2   $key_exists ? :
90           100      4      2   if (scalar @cols == 1)
100   ***     50      0      6   if ($EVAL_ERROR)
115          100      5      1   if ($key_len and $rows) { }
116          100      1      4   if ($chosen_key =~ /,/ and $key_len =~ /,/)
151          100      5      2   exists $args{'tbl_struct'}{'keys'}{lc $args{'name'}} ? :
156          100     12      8   $$explain{$_} ? :
164   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
115   ***     66      1      0      5   $key_len and $rows
116   ***     66      4      0      1   $chosen_key =~ /,/ and $key_len =~ /,/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                      
---------------- ----- --- ----------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/KeySize.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/KeySize.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/KeySize.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/KeySize.pm:26 
_d                   1     /home/daniel/dev/maatkit/common/KeySize.pm:163
_explain_to_text     2     /home/daniel/dev/maatkit/common/KeySize.pm:155
_key_exists          7     /home/daniel/dev/maatkit/common/KeySize.pm:150
error                2   0 /home/daniel/dev/maatkit/common/KeySize.pm:145
explain              1   0 /home/daniel/dev/maatkit/common/KeySize.pm:139
get_key_size         6   0 /home/daniel/dev/maatkit/common/KeySize.pm:48 
new                  1   0 /home/daniel/dev/maatkit/common/KeySize.pm:29 
query                2   0 /home/daniel/dev/maatkit/common/KeySize.pm:133


KeySize.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  3   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            10   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 18;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use KeySize;
               1                                  3   
               1                                 14   
15             1                    1            12   use TableParser;
               1                                  3   
               1                                 11   
16             1                    1            10   use Quoter;
               1                                  3   
               1                                  9   
17             1                    1            10   use DSNParser;
               1                                  3   
               1                                 12   
18             1                    1            15   use Sandbox;
               1                                  3   
               1                                 10   
19             1                    1            11   use MaatkitTest;
               1                                  5   
               1                                 38   
20                                                    
21             1                                 16   my $dp  = new DSNParser(opts=>$dsn_opts);
22             1                                230   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
23    ***      1     50                          53   my $dbh = $sb->get_dbh_for('master')
24                                                       or BAIL_OUT('Cannot connect to sandbox master');
25             1                                390   my $q  = new Quoter();
26             1                                 30   my $tp = new TableParser(Quoter => $q);
27             1                                 48   my $ks = new KeySize(Quoter=>$q);
28                                                    
29             1                                  3   my $tbl;
30             1                                  3   my $struct;
31             1                                  2   my %key;
32             1                                  4   my ($size, $chosen_key); 
33                                                    
34                                                    sub key_info {
35             3                    3            49      my ( $file, $db, $tbl, $key, $cols ) = @_;
36             3                                 77      $sb->load_file('master', $file, $db);
37             3                             652741      my $tbl_name = $q->quote($db, $tbl);
38             3                                409      my $struct   = $tp->parse( load_file($file) );
39                                                       return (
40    ***      3            66                 4729         name       => $key,
41                                                          cols       => $cols || $struct->{keys}->{$key}->{cols},
42                                                          tbl_name   => $tbl_name,
43                                                          tbl_struct => $struct,
44                                                          dbh        => $dbh,
45                                                       );
46                                                    }
47                                                    
48             1                                  8   $sb->create_dbs($dbh, ['test']);
49                                                    
50             1                                643   isa_ok($ks, 'KeySize');
51                                                    
52                                                    # With an empty table, the WHERE is impossible, so MySQL should optimize
53                                                    # away the query, and key_len and rows will be NULL in EXPLAIN.
54             1                                  8   %key = key_info('common/t/samples/dupe_key.sql', 'test', 'dupe_key', 'a');
55             1                                 41   is(
56                                                       $ks->get_key_size(%key),
57                                                       undef,
58                                                       'Empty table, impossible where'
59                                                    );
60                                                    
61                                                    # Populate the table to make the WHERE possible.
62             1                                417   $dbh->do('INSERT INTO test.dupe_key VALUE (1,2,3),(4,5,6),(7,8,9),(0,0,0)');
63             1                                 18   is_deeply(
64                                                       [$ks->get_key_size(%key)],
65                                                       [20, 'a'],
66                                                       'Single column int key'
67                                                    );
68                                                    
69             1                                 16   $key{name} = 'a_2';
70             1                                 20   is_deeply(
71                                                       [$ks->get_key_size(%key)],
72                                                       [40, 'a_2'],
73                                                       'Two column int key'
74                                                    );
75                                                    
76             1                                 30   $sb->load_file('master', 'common/t/samples/issue_331-parent.sql', 'test');
77             1                             231506   %key = key_info('common/t/samples/issue_331.sql', 'test', 'issue_331_t2', 'fk_1', ['id']);
78             1                                 36   ($size, $chosen_key) = $ks->get_key_size(%key);
79             1                                 30   is(
80                                                       $size,
81                                                       8,
82                                                       'Foreign key size'
83                                                    );
84             1                                  9   is(
85                                                       $chosen_key,
86                                                       'PRIMARY',
87                                                       'PRIMARY key chosen for foreign key'
88                                                    );
89                                                    
90                                                    # #############################################################################
91                                                    # Issue 364: Argument "9,8" isn't numeric in multiplication (*) at
92                                                    # mk-duplicate-key-checker line 1894
93                                                    # #############################################################################
94             1                                218   $dbh->do('USE test');
95             1                               1527   $dbh->do('DROP TABLE IF EXISTS test.issue_364');
96             1                                 36   %key = key_info(
97                                                       'common/t/samples/issue_364.sql',
98                                                       'test',
99                                                       'issue_364',
100                                                      'BASE_KID_ID',
101                                                      [qw(BASE_KID_ID ID)]
102                                                   );
103            1                                 34   $sb->load_file('master', 'common/t/samples/issue_364-data.sql', 'test');
104                                                   
105                                                   # This issue had another issue: the key is ALL CAPS, but TableParser
106                                                   # lowercases all identifies, so KeySize said the key didn't exist.
107                                                   # This was the root problem.  Once KeySize saw the key it added a
108                                                   # FORCE INDEX and the index_merge went away.  Later, we'll drop the
109                                                   # real key and add one back over the same columns so that KeySize
110                                                   # won't see its key but one will exist with which to do merge_index.
111            1                             216643   ok(
112                                                      $ks->_key_exists(%key),
113                                                      'Key exists (issue 364)'
114                                                   );
115                                                   
116            1                              19525   my $output = `/tmp/12345/use -D test -e 'EXPLAIN SELECT BASE_KID_ID, ID FROM test.issue_364 WHERE BASE_KID_ID=1 OR ID=1'`;
117            1                                106   like(
118                                                      $output,
119                                                      qr/index_merge/,
120                                                      'Query uses index_merge (issue 364)'
121                                                   );
122                                                   
123                                                   
124            1                                 59   ($size, $chosen_key) = $ks->get_key_size(%key);
125            1                                 19   is(
126                                                      $size,
127                                                      17 * 176,
128                                                      'Key size (issue 364)'
129                                                   );
130            1                                 13   is(
131                                                      $chosen_key,
132                                                      'BASE_KID_ID',
133                                                      'Chosen key (issue 364)'
134                                                   );
135            1                                 16   is(
136                                                      $ks->error(),
137                                                      '',
138                                                      'No error (issue 364)'
139                                                   );
140            1                                 17   is(
141                                                      $ks->explain(),
142                                                      "Extra: Using where; Using index
143                                                   id: 1
144                                                   key: BASE_KID_ID
145                                                   key_len: 17
146                                                   possible_keys: BASE_KID_ID
147                                                   ref: NULL
148                                                   rows: 176
149                                                   select_type: SIMPLE
150                                                   table: issue_364
151                                                   type: index",
152                                                      'EXPLAIN plan (issue 364)'
153                                                   );
154            1                                 12   is(
155                                                      $ks->query(),
156                                                      'EXPLAIN SELECT BASE_KID_ID, ID FROM `test`.`issue_364` FORCE INDEX (`BASE_KID_ID`) WHERE BASE_KID_ID=1 OR ID=1',
157                                                      'Query (issue 364)'
158                                                   );
159                                                   
160                                                   # KeySize doesn't actually check the table to see if the key exists.
161                                                   # It trusts that tbl_struct->{keys} is accurate.  So if we delete the
162                                                   # key here, we'll fool KeySize and simulate the original problem.
163            1                                 24   delete $key{tbl_struct}->{keys}->{'base_kid_id'};
164            1                                 15   ($size, $chosen_key) = $ks->get_key_size(%key);
165            1                                 11   is(
166                                                      $size,
167                                                      undef,
168                                                      'Key size 0 (issue 364)'
169                                                   );
170            1                                  9   is(
171                                                      $chosen_key,
172                                                      undef,
173                                                      'Chose multiple keys (issue 364)'
174                                                   );
175            1                                 11   is(
176                                                      $ks->error(),
177                                                      'MySQL chose multiple keys: BASE_KID_ID,PRIMARY',
178                                                      'Error about multiple keys (issue 364)'
179                                                   );
180            1                                 10   is(
181                                                      $ks->query(),
182                                                      'EXPLAIN SELECT BASE_KID_ID, ID FROM `test`.`issue_364` WHERE BASE_KID_ID=1 OR ID=1',
183                                                      'Query without FORCE INDEX (issue 364)'
184                                                   );
185                                                   
186                                                   # #############################################################################
187                                                   # Done.
188                                                   # #############################################################################
189            1                                  6   $output = '';
190                                                   {
191            1                                  4      local *STDERR;
               1                                 21   
192            1                    1             4      open STDERR, '>', \$output;
               1                                615   
               1                                  4   
               1                                 12   
193            1                                 34      $ks->_d('Complete test coverage');
194                                                   }
195                                                   like(
196            1                                 28      $output,
197                                                      qr/Complete test coverage/,
198                                                      '_d() works'
199                                                   );
200            1                                 36   $sb->wipe_clean($dbh);
201            1                                  6   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
23    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
40    ***     66      2      1      0   $cols || $$struct{'keys'}{$key}{'cols'}


Covered Subroutines
-------------------

Subroutine Count Location     
---------- ----- -------------
BEGIN          1 KeySize.t:10 
BEGIN          1 KeySize.t:11 
BEGIN          1 KeySize.t:12 
BEGIN          1 KeySize.t:14 
BEGIN          1 KeySize.t:15 
BEGIN          1 KeySize.t:16 
BEGIN          1 KeySize.t:17 
BEGIN          1 KeySize.t:18 
BEGIN          1 KeySize.t:19 
BEGIN          1 KeySize.t:192
BEGIN          1 KeySize.t:4  
BEGIN          1 KeySize.t:9  
key_info       3 KeySize.t:35 


