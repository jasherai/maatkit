---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryReview.pm   91.0   68.2   64.3   91.7    0.0    3.8   80.3
QueryReview.t                 100.0   66.7   33.3  100.0    n/a   96.2   95.9
Total                          96.2   67.6   58.8   97.1    0.0  100.0   88.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:07 2010
Finish:       Thu Jun 24 19:36:07 2010

Run:          QueryReview.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:09 2010
Finish:       Thu Jun 24 19:36:09 2010

/home/daniel/dev/maatkit/common/QueryReview.pm

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
18                                                    # QueryReview package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    
21                                                    package QueryReview;
22                                                    
23                                                    # This module is an interface to a "query review table" in which certain
24                                                    # historical information about classes of queries is stored.  See the docs on
25                                                    # mk-query-digest for context.
26                                                    
27             1                    1             5   use strict;
               1                                  2   
               1                                  6   
28             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
29             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
30                                                    Transformers->import(qw(make_checksum parse_timestamp));
31                                                    
32             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
33                                                    
34    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 11   
35                                                    
36                                                    # These columns are the minimal set of columns for every review table.  TODO:
37                                                    # maybe it's possible to specify this in the tool's POD and pass it in so it's
38                                                    # not hardcoded here and liable to get out of sync.
39                                                    my %basic_cols = map { $_ => 1 }
40                                                       qw(checksum fingerprint sample first_seen last_seen reviewed_by
41                                                          reviewed_on comments);
42                                                    my %skip_cols  = map { $_ => 1 } qw(fingerprint sample checksum);
43                                                    
44                                                    # Required args:
45                                                    # dbh           A dbh to the server with the query review table.
46                                                    # db_tbl        Full quoted db.tbl name of the query review table.
47                                                    #               Make sure the table exists! It's not checked here;
48                                                    #               check it before instantiating an object.
49                                                    # tbl_struct    Return val from TableParser::parse() for db_tbl.
50                                                    #               This is used to discover what columns db_tbl has.
51                                                    # quoter        Quoter object.
52                                                    #
53                                                    # Optional args:
54                                                    # ts_default    SQL expression to use when inserting a new row into
55                                                    #               the review table.  If nothing else is specified, NOW()
56                                                    #               is the default.  This is for dependency injection while
57                                                    #               testing.
58                                                    sub new {
59    ***      1                    1      0     17      my ( $class, %args ) = @_;
60             1                                 13      foreach my $arg ( qw(dbh db_tbl tbl_struct quoter) ) {
61    ***      4     50                          37         die "I need a $arg argument" unless $args{$arg};
62                                                       }
63                                                    
64             1                                 11      foreach my $col ( keys %basic_cols ) {
65    ***      8     50                          73         die "Query review table $args{db_tbl} does not have a $col column"
66                                                             unless $args{tbl_struct}->{is_col}->{$col};
67                                                       }
68                                                    
69    ***      1     50                          16      my $now = defined $args{ts_default} ? $args{ts_default} : 'NOW()';
70                                                    
71                                                       # Design statements to INSERT and statements to SELECT from the review table.
72             1                                 19      my $sql = <<"      SQL";
73                                                          INSERT INTO $args{db_tbl}
74                                                          (checksum, fingerprint, sample, first_seen, last_seen)
75                                                          VALUES(CONV(?, 16, 10), ?, ?, COALESCE(?, $now), COALESCE(?, $now))
76                                                          ON DUPLICATE KEY UPDATE
77                                                             first_seen = IF(
78                                                                first_seen IS NULL,
79                                                                COALESCE(?, $now),
80                                                                LEAST(first_seen, COALESCE(?, $now))),
81                                                             last_seen = IF(
82                                                                last_seen IS NULL,
83                                                                COALESCE(?, $now),
84                                                                GREATEST(last_seen, COALESCE(?, $now)))
85                                                          SQL
86             1                                  4      MKDEBUG && _d('SQL to insert into review table:', $sql);
87             1                                  4      my $insert_sth = $args{dbh}->prepare($sql);
88                                                    
89                                                       # The SELECT statement does not need to get the fingerprint, sample or
90                                                       # checksum.
91             1                                 10      my @review_cols = grep { !$skip_cols{$_} } @{$args{tbl_struct}->{cols}};
               8                                 58   
               1                                 10   
92             5                                204      $sql = "SELECT "
93             1                                  9           . join(', ', map { $args{quoter}->quote($_) } @review_cols)
94                                                            . ", CONV(checksum, 10, 16) AS checksum_conv FROM $args{db_tbl}"
95                                                            . " WHERE checksum=CONV(?, 16, 10)";
96             1                                 54      MKDEBUG && _d('SQL to select from review table:', $sql);
97             1                                  4      my $select_sth = $args{dbh}->prepare($sql);
98                                                    
99             1                                 23      my $self = {
100                                                         dbh         => $args{dbh},
101                                                         db_tbl      => $args{db_tbl},
102                                                         insert_sth  => $insert_sth,
103                                                         select_sth  => $select_sth,
104                                                         tbl_struct  => $args{tbl_struct},
105                                                         quoter      => $args{quoter},
106                                                         ts_default  => $now,
107                                                      };
108            1                                 44      return bless $self, $class;
109                                                   }
110                                                   
111                                                   # Tell QueryReview object to also prepare to save values in the review history
112                                                   # table.
113                                                   sub set_history_options {
114   ***      1                    1      0     17      my ( $self, %args ) = @_;
115            1                                 12      foreach my $arg ( qw(table dbh tbl_struct col_pat) ) {
116   ***      4     50                          40         die "I need a $arg argument" unless $args{$arg};
117                                                      }
118                                                   
119                                                      # Pick out columns, attributes and metrics that need to be stored in the
120                                                      # table.
121            1                                  6      my @cols;
122            1                                 73      my @metrics;
123            1                                  6      foreach my $col ( @{$args{tbl_struct}->{cols}} ) {
               1                                 12   
124           29                                443         my ( $attr, $metric ) = $col =~ m/$args{col_pat}/;
125   ***     29    100     66                  394         next unless $attr && $metric;
126           27    100                         206         $attr = ucfirst $attr if $attr =~ m/_/; # TableParser lowercases
127           27                                130         push @cols, $col;
128           27                                220         push @metrics, [$attr, $metric];
129                                                      }
130                                                   
131           29                               1567      my $sql = "REPLACE INTO $args{table}("
132                                                         . join(', ',
133           27    100    100                  460            map { $self->{quoter}->quote($_) } ('checksum', 'sample', @cols))
134                                                         . ') VALUES (CONV(?, 16, 10), ?, '
135                                                         . join(', ', map {
136                                                            # ts_min and ts_max might be part of the PK, in which case they must
137                                                            # not be NULL.
138            1                                 13            $_ eq 'ts_min' || $_ eq 'ts_max'
139                                                               ? "COALESCE(?, $self->{ts_default})"
140                                                               : '?'
141                                                           } @cols) . ')';
142            1                                 14      MKDEBUG && _d($sql);
143                                                   
144            1                                 14      $self->{history_sth}     = $args{dbh}->prepare($sql);
145            1                                 18      $self->{history_cols}    = \@cols;
146            1                                 13      $self->{history_metrics} = \@metrics;
147                                                   }
148                                                   
149                                                   # Save review history for a class of queries.  The incoming data is a bunch
150                                                   # of hashes.  Each top-level key is an attribute name, and each second-level key
151                                                   # is a metric name.  Look at the test for more examples.
152                                                   sub set_review_history {
153   ***      2                    2      0     25      my ( $self, $id, $sample, %data ) = @_;
154                                                      # Need to transform ts->min/max into timestamps
155            2                                 16      foreach my $thing ( qw(min max) ) {
156   ***      4    100     66                  164         next unless defined $data{ts} && defined $data{ts}->{$thing};
157            2                                 21         $data{ts}->{$thing} = parse_timestamp($data{ts}->{$thing});
158                                                      }
159           54                               1674      $self->{history_sth}->execute(
160                                                         make_checksum($id),
161                                                         $sample,
162            2                                 89         map { $data{$_->[0]}->{$_->[1]} } @{$self->{history_metrics}});
               2                                 86   
163                                                   }
164                                                   
165                                                   # Fetch information from the database about a query that's been reviewed.
166                                                   sub get_review_info {
167   ***      1                    1      0     10      my ( $self, $id ) = @_;
168            1                                 11      $self->{select_sth}->execute(make_checksum($id));
169            1                                 13      my $review_vals = $self->{select_sth}->fetchall_arrayref({});
170   ***      1     50     33                   28      if ( $review_vals && @$review_vals == 1 ) {
171            1                                 11         return $review_vals->[0];
172                                                      }
173   ***      0                                  0      return undef;
174                                                   }
175                                                   
176                                                   # Store a query into the table.  The arguments are:
177                                                   #  *  fingerprint
178                                                   #  *  sample
179                                                   #  *  first_seen
180                                                   #  *  last_seen
181                                                   # There's no need to convert the fingerprint to a checksum, no need to parse
182                                                   # timestamps either.
183                                                   sub set_review_info {
184   ***      9                    9      0    125      my ( $self, %args ) = @_;
185           54    100                        3869      $self->{insert_sth}->execute(
186                                                         make_checksum($args{fingerprint}),
187                                                         @args{qw(fingerprint sample)},
188            9                                113         map { $args{$_} ? parse_timestamp($args{$_}) : undef }
189                                                            qw(first_seen last_seen first_seen first_seen last_seen last_seen));
190                                                   }
191                                                   
192                                                   # Return the columns we'll be using from the review table.
193                                                   sub review_cols {
194   ***      1                    1      0      6      my ( $self ) = @_;
195            1                                  6      return grep { !$skip_cols{$_} } @{$self->{tbl_struct}->{cols}};
               8                                 77   
               1                                 12   
196                                                   }
197                                                   
198                                                   sub _d {
199   ***      0                    0                    my ($package, undef, $line) = caller 0;
200   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
201   ***      0                                              map { defined $_ ? $_ : 'undef' }
202                                                           @_;
203   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
204                                                   }
205                                                   
206                                                   1;
207                                                   # ###########################################################################
208                                                   # End QueryReview package
209                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
61    ***     50      0      4   unless $args{$arg}
65    ***     50      0      8   unless $args{'tbl_struct'}{'is_col'}{$col}
69    ***     50      1      0   defined $args{'ts_default'} ? :
116   ***     50      0      4   unless $args{$arg}
125          100      2     27   unless $attr and $metric
126          100     24      3   if $attr =~ /_/
133          100      2     25   $_ eq 'ts_min' || $_ eq 'ts_max' ? :
156          100      2      2   unless defined $data{'ts'} and defined $data{'ts'}{$thing}
170   ***     50      1      0   if ($review_vals and @$review_vals == 1)
185          100     48      6   $args{$_} ? :
200   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
125   ***     66      2      0     27   $attr and $metric
156   ***     66      0      2      2   defined $data{'ts'} and defined $data{'ts'}{$thing}
170   ***     33      0      0      1   $review_vals and @$review_vals == 1

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
34    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
133          100      1      1     25   $_ eq 'ts_min' || $_ eq 'ts_max'


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                          
------------------- ----- --- --------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/QueryReview.pm:27 
BEGIN                   1     /home/daniel/dev/maatkit/common/QueryReview.pm:28 
BEGIN                   1     /home/daniel/dev/maatkit/common/QueryReview.pm:29 
BEGIN                   1     /home/daniel/dev/maatkit/common/QueryReview.pm:32 
BEGIN                   1     /home/daniel/dev/maatkit/common/QueryReview.pm:34 
get_review_info         1   0 /home/daniel/dev/maatkit/common/QueryReview.pm:167
new                     1   0 /home/daniel/dev/maatkit/common/QueryReview.pm:59 
review_cols             1   0 /home/daniel/dev/maatkit/common/QueryReview.pm:194
set_history_options     1   0 /home/daniel/dev/maatkit/common/QueryReview.pm:114
set_review_history      2   0 /home/daniel/dev/maatkit/common/QueryReview.pm:153
set_review_info         9   0 /home/daniel/dev/maatkit/common/QueryReview.pm:184

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                          
------------------- ----- --- --------------------------------------------------
_d                      0     /home/daniel/dev/maatkit/common/QueryReview.pm:199


QueryReview.t

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
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
12             1                    1            22   use Test::More tests => 6;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use Transformers;
               1                                  3   
               1                                 10   
15             1                    1            10   use QueryReview;
               1                                  3   
               1                                 10   
16             1                    1            10   use QueryRewriter;
               1                                  3   
               1                                 12   
17             1                    1            11   use MySQLDump;
               1                                  3   
               1                                 11   
18             1                    1            11   use TableParser;
               1                                  3   
               1                                 11   
19             1                    1            16   use Quoter;
               1                                  3   
               1                                  8   
20             1                    1            10   use SlowLogParser;
               1                                  2   
               1                                 10   
21             1                    1            10   use OptionParser;
               1                                  3   
               1                                 16   
22             1                    1            13   use DSNParser;
               1                                  3   
               1                                 12   
23             1                    1            14   use Sandbox;
               1                                  3   
               1                                  9   
24             1                    1            11   use MaatkitTest;
               1                                  6   
               1                                 39   
25                                                    
26             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
27             1                                226   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
28    ***      1     50                          56   my $dbh = $sb->get_dbh_for('master')
29                                                       or BAIL_OUT('Cannot connect to sandbox master');
30             1                                357   $sb->create_dbs($dbh, ['test']);
31             1                                794   $sb->load_file('master', "common/t/samples/query_review.sql");
32                                                    
33             1                             140406   my $qr = new QueryRewriter();
34             1                                153   my $lp = new SlowLogParser;
35             1                                111   my $q  = new Quoter();
36             1                                 88   my $tp = new TableParser(Quoter => $q);
37             1                                120   my $du = new MySQLDump();
38             1                                 89   my $opt_parser = new OptionParser( description => 'hi' );
39             1                                414   my $tbl_struct = $tp->parse(
40                                                       $du->get_create_table($dbh, $q, 'test', 'query_review'));
41                                                    
42             1                               1971   my $qv = new QueryReview(
43                                                       dbh        => $dbh,
44                                                       db_tbl     => '`test`.`query_review`',
45                                                       tbl_struct => $tbl_struct,
46                                                       ts_default => '"2009-01-01"',
47                                                       quoter     => $q,
48                                                    );
49                                                    
50             1                                 23   isa_ok($qv, 'QueryReview');
51                                                    
52                                                    my $callback = sub {
53             8                    8            51      my ( $event ) = @_;
54             8                                 91      my $fp = $qr->fingerprint($event->{arg});
55             8                               1135      $qv->set_review_info(
56                                                          fingerprint => $fp,
57                                                          sample      => $event->{arg},
58                                                          first_seen  => $event->{ts},
59                                                          last_seen   => $event->{ts},
60                                                       );
61             1                                 23   };
62                                                    
63             1                                  6   my $event       = {};
64             1                                  4   my $more_events = 1;
65             1                                  3   my $log;
66    ***      1     50                         190   open $log, '<', "$trunk/common/t/samples/slow006.txt" or die $OS_ERROR;
67             1                                  8   while ( $more_events ) {
68                                                       $event = $lp->parse_event(
69             7                    7           292         next_event => sub { return <$log>;    },
70            13                   13           790         tell       => sub { return tell $log; },
71             1                    1            26         oktorun    => sub { $more_events = $_[0]; },
72             7                               3864      );
73             7    100                        4251      $callback->($event) if $event;
74                                                    }
75             1                                 27   close $log;
76             1                                  5   $more_events = 1;
77    ***      1     50                          54   open $log, '<', "$trunk/common/t/samples/slow021.txt" or die $OS_ERROR;
78             1                                  9   while ( $more_events ) {
79                                                       $event = $lp->parse_event(
80             3                    3           130         next_event => sub { return <$log>;    },
81             5                    5           412         tell       => sub { return tell $log; },
82             1                    1            23         oktorun    => sub { $more_events = $_[0]; },
83             3                                581      );
84             3    100                         976      $callback->($event) if $event;
85                                                    }
86             1                                 15   close $log;
87                                                    
88             1                                 71   my $res = $dbh->selectall_arrayref(
89                                                       'SELECT checksum, first_seen, last_seen FROM query_review order by checksum',
90                                                       { Slice => {} });
91             1                                 52   is_deeply(
92                                                       $res,
93                                                       [  {  checksum   => '4222630712410165197',
94                                                             last_seen  => '2007-10-15 21:45:10',
95                                                             first_seen => '2007-10-15 21:45:10'
96                                                          },
97                                                          {  checksum   => '9186595214868493422',
98                                                             last_seen  => '2009-01-01 00:00:00',
99                                                             first_seen => '2009-01-01 00:00:00'
100                                                         },
101                                                         {  checksum   => '11676753765851784517',
102                                                            last_seen  => '2007-12-18 11:49:30',
103                                                            first_seen => '2007-12-18 11:48:27'
104                                                         },
105                                                         {  checksum   => '15334040482108055940',
106                                                            last_seen  => '2007-12-18 11:49:07',
107                                                            first_seen => '2005-12-19 16:56:31'
108                                                         }
109                                                      ],
110                                                      'Updates last_seen'
111                                                   );
112                                                   
113            1                                 29   $event = {
114                                                      arg => "UPDATE foo SET bar='nada' WHERE 1",
115                                                      ts  => '081222 13:13:13',
116                                                   };
117            1                                 13   my $fp = $qr->fingerprint($event->{arg});
118            1                                202   my $checksum = Transformers::make_checksum($fp);
119            1                                 50   $qv->set_review_info(
120                                                      fingerprint => $fp,
121                                                      sample      => $event->{arg},
122                                                      first_seen  => $event->{ts},
123                                                      last_seen   => $event->{ts},
124                                                   );
125                                                   
126            1                                709   $res = $qv->get_review_info($fp);
127            1                                 26   is_deeply(
128                                                      $res,
129                                                      {
130                                                         checksum_conv => 'D3A1C1CD468791EE',
131                                                         first_seen    => '2008-12-22 13:13:13',
132                                                         last_seen     => '2008-12-22 13:13:13',
133                                                         reviewed_by   => undef,
134                                                         reviewed_on   => undef,
135                                                         comments      => undef,
136                                                      },
137                                                      'Stores a new event with default values'
138                                                   );
139                                                   
140            1                                 23   is_deeply([$qv->review_cols],
141                                                      [qw(first_seen last_seen reviewed_by reviewed_on comments)],
142                                                      'review columns');
143                                                   
144                                                   # ##############################################################################
145                                                   # Test review history stuff
146                                                   # ##############################################################################
147            1                                 70   my $pat = $opt_parser->read_para_after("$trunk/mk-query-digest/mk-query-digest",
148                                                      qr/MAGIC_history_cols/);
149            1                                 43   $pat =~ s/\s+//g;
150            1                                 22   my $create_table = $opt_parser->read_para_after(
151                                                      "$trunk/mk-query-digest/mk-query-digest", qr/MAGIC_create_review_history/);
152            1                                 35   $create_table =~ s/query_review_history/test.query_review_history/;
153            1                             106866   $dbh->do($create_table);
154            1                                 29   my $hist_struct = $tp->parse(
155                                                      $du->get_create_table($dbh, $q, 'test', 'query_review_history'));
156                                                   
157            1                               4518   $qv->set_history_options(
158                                                      table      => 'test.query_review_history',
159                                                      dbh        => $dbh,
160                                                      quoter     => $q,
161                                                      tbl_struct => $hist_struct,
162                                                      col_pat    => qr/^(.*?)_($pat)$/,
163                                                   );
164                                                   
165            1                                 50   $qv->set_review_history(
166                                                      'foo',
167                                                      'foo sample',
168                                                      Query_time => {
169                                                         pct    => 1/3,
170                                                         sum    => '0.000682',
171                                                         cnt    => 1,
172                                                         min    => '0.000682',
173                                                         max    => '0.000682',
174                                                         avg    => '0.000682',
175                                                         median => '0.000682',
176                                                         stddev => 0,
177                                                         pct_95 => '0.000682',
178                                                      },
179                                                      ts => {
180                                                         min => '090101 12:39:12',
181                                                         max => '090101 13:19:12',
182                                                         cnt => 1,
183                                                      },
184                                                   );
185                                                   
186            1                                 11   $res = $dbh->selectall_arrayref(
187                                                      'SELECT * FROM test.query_review_history',
188                                                      { Slice => {} });
189            1                                 56   is_deeply(
190                                                      $res,
191                                                      [  {  checksum          => '17145033699835028696',
192                                                            sample            => 'foo sample',
193                                                            ts_min            => '2009-01-01 12:39:12',
194                                                            ts_max            => '2009-01-01 13:19:12',
195                                                            ts_cnt            => 1,
196                                                            Query_time_sum    => '0.000682',
197                                                            Query_time_min    => '0.000682',
198                                                            Query_time_max    => '0.000682',
199                                                            Query_time_median => '0.000682',
200                                                            Query_time_stddev => 0,
201                                                            Query_time_pct_95 => '0.000682',
202                                                            Lock_time_sum        => undef,
203                                                            Lock_time_min        => undef,
204                                                            Lock_time_max        => undef,
205                                                            Lock_time_pct_95     => undef,
206                                                            Lock_time_stddev     => undef,
207                                                            Lock_time_median     => undef,
208                                                            Rows_sent_sum        => undef,
209                                                            Rows_sent_min        => undef,
210                                                            Rows_sent_max        => undef,
211                                                            Rows_sent_pct_95     => undef,
212                                                            Rows_sent_stddev     => undef,
213                                                            Rows_sent_median     => undef,
214                                                            Rows_examined_sum    => undef,
215                                                            Rows_examined_min    => undef,
216                                                            Rows_examined_max    => undef,
217                                                            Rows_examined_pct_95 => undef,
218                                                            Rows_examined_stddev => undef,
219                                                            Rows_examined_median => undef,
220                                                         },
221                                                      ],
222                                                      'Review history information is in the DB',
223                                                   );
224                                                   
225            1                                 22   eval {
226            1                                 19      $qv->set_review_history(
227                                                         'foo',
228                                                         'foo sample',
229                                                         ts => {
230                                                            min => undef,
231                                                            max => undef,
232                                                            cnt => 1,
233                                                         },
234                                                      );
235                                                   };
236            1                                 25   is($EVAL_ERROR, '', 'No error on undef ts_min and ts_max');
237                                                   
238            1                                 19   $sb->wipe_clean($dbh);


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
28    ***     50      0      1   unless my $dbh = $sb->get_dbh_for('master')
66    ***     50      0      1   unless open $log, '<', "$trunk/common/t/samples/slow006.txt"
73           100      6      1   if $event
77    ***     50      0      1   unless open $log, '<', "$trunk/common/t/samples/slow021.txt"
84           100      2      1   if $event


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location        
---------- ----- ----------------
BEGIN          1 QueryReview.t:10
BEGIN          1 QueryReview.t:11
BEGIN          1 QueryReview.t:12
BEGIN          1 QueryReview.t:14
BEGIN          1 QueryReview.t:15
BEGIN          1 QueryReview.t:16
BEGIN          1 QueryReview.t:17
BEGIN          1 QueryReview.t:18
BEGIN          1 QueryReview.t:19
BEGIN          1 QueryReview.t:20
BEGIN          1 QueryReview.t:21
BEGIN          1 QueryReview.t:22
BEGIN          1 QueryReview.t:23
BEGIN          1 QueryReview.t:24
BEGIN          1 QueryReview.t:4 
BEGIN          1 QueryReview.t:9 
__ANON__       8 QueryReview.t:53
__ANON__       7 QueryReview.t:69
__ANON__      13 QueryReview.t:70
__ANON__       1 QueryReview.t:71
__ANON__       3 QueryReview.t:80
__ANON__       5 QueryReview.t:81
__ANON__       1 QueryReview.t:82


