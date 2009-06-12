---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryReview.pm   91.0   68.2   66.7   91.7    n/a  100.0   84.7
Total                          91.0   68.2   66.7   91.7    n/a  100.0   84.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryReview.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:49 2009
Finish:       Wed Jun 10 17:20:49 2009

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
18                                                    # QueryReview package $Revision: 3277 $
19                                                    # ###########################################################################
20                                                    
21                                                    package QueryReview;
22                                                    
23                                                    # This module is an interface to a "query review table" in which certain
24                                                    # historical information about classes of queries is stored.  See the docs on
25                                                    # mk-query-digest for context.
26                                                    
27             1                    1             7   use strict;
               1                                  2   
               1                                  6   
28             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                 11   
29             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
30                                                    Transformers->import(qw(make_checksum parse_timestamp));
31                                                    
32             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  5   
33                                                    
34             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
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
59             1                    1            47      my ( $class, %args ) = @_;
60             1                                  8      foreach my $arg ( qw(dbh db_tbl tbl_struct quoter) ) {
61    ***      4     50                          33         die "I need a $arg argument" unless $args{$arg};
62                                                       }
63                                                    
64             1                                 10      foreach my $col ( keys %basic_cols ) {
65    ***      8     50                          70         die "Query review table $args{db_tbl} does not have a $col column"
66                                                             unless $args{tbl_struct}->{is_col}->{$col};
67                                                       }
68                                                    
69    ***      1     50                          11      my $now = defined $args{ts_default} ? $args{ts_default} : 'NOW()';
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
86             1                                  3      MKDEBUG && _d('SQL to insert into review table:', $sql);
87             1                                  4      my $insert_sth = $args{dbh}->prepare($sql);
88                                                    
89                                                       # The SELECT statement does not need to get the fingerprint, sample or
90                                                       # checksum.
91             1                                  9      my @review_cols = grep { !$skip_cols{$_} } @{$args{tbl_struct}->{cols}};
               8                                 50   
               1                                 10   
92             5                                 36      $sql = "SELECT "
93             1                                  7           . join(', ', map { $args{quoter}->quote($_) } @review_cols)
94                                                            . ", CONV(checksum, 10, 16) AS checksum_conv FROM $args{db_tbl}"
95                                                            . " WHERE checksum=CONV(?, 16, 10)";
96             1                                  4      MKDEBUG && _d('SQL to select from review table:', $sql);
97             1                                  3      my $select_sth = $args{dbh}->prepare($sql);
98                                                    
99             1                                 21      my $self = {
100                                                         dbh         => $args{dbh},
101                                                         db_tbl      => $args{db_tbl},
102                                                         insert_sth  => $insert_sth,
103                                                         select_sth  => $select_sth,
104                                                         tbl_struct  => $args{tbl_struct},
105                                                         quoter      => $args{quoter},
106                                                         ts_default  => $now,
107                                                      };
108            1                                 25      return bless $self, $class;
109                                                   }
110                                                   
111                                                   # Tell QueryReview object to also prepare to save values in the review history
112                                                   # table.
113                                                   sub set_history_options {
114            1                    1           147      my ( $self, %args ) = @_;
115            1                                  9      foreach my $arg ( qw(table dbh tbl_struct col_pat) ) {
116   ***      4     50                          32         die "I need a $arg argument" unless $args{$arg};
117                                                      }
118                                                   
119                                                      # Pick out columns, attributes and metrics that need to be stored in the
120                                                      # table.
121            1                                  5      my @cols;
122            1                                  5      my @metrics;
123            1                                  4      foreach my $col ( @{$args{tbl_struct}->{cols}} ) {
               1                                 10   
124           29                                424         my ( $attr, $metric ) = $col =~ m/$args{col_pat}/;
125   ***     29    100     66                  434         next unless $attr && $metric;
126           27    100                         204         $attr = ucfirst $attr if $attr =~ m/_/; # TableParser lowercases
127           27                                128         push @cols, $col;
128           27                                205         push @metrics, [$attr, $metric];
129                                                      }
130                                                   
131           29                                208      my $sql = "REPLACE INTO $args{table}("
132                                                         . join(', ',
133           27    100    100                  418            map { $self->{quoter}->quote($_) } ('checksum', 'sample', @cols))
134                                                         . ') VALUES (CONV(?, 16, 10), ?, '
135                                                         . join(', ', map {
136                                                            # ts_min and ts_max might be part of the PK, in which case they must
137                                                            # not be NULL.
138            1                                 12            $_ eq 'ts_min' || $_ eq 'ts_max'
139                                                               ? "COALESCE(?, $self->{ts_default})"
140                                                               : '?'
141                                                           } @cols) . ')';
142            1                                 14      MKDEBUG && _d($sql);
143                                                   
144            1                                  5      $self->{history_sth}     = $args{dbh}->prepare($sql);
145            1                                 17      $self->{history_cols}    = \@cols;
146            1                                 12      $self->{history_metrics} = \@metrics;
147                                                   }
148                                                   
149                                                   # Save review history for a class of queries.  The incoming data is a bunch
150                                                   # of hashes.  Each top-level key is an attribute name, and each second-level key
151                                                   # is a metric name.  Look at the test for more examples.
152                                                   sub set_review_history {
153            2                    2           135      my ( $self, $id, $sample, %data ) = @_;
154                                                      # Need to transform ts->min/max into timestamps
155            2                                 14      foreach my $thing ( qw(min max) ) {
156   ***      4    100     66                   79         next unless defined $data{ts} && defined $data{ts}->{$thing};
157            2                                 19         $data{ts}->{$thing} = parse_timestamp($data{ts}->{$thing});
158                                                      }
159           54                               1911      $self->{history_sth}->execute(
160                                                         make_checksum($id),
161                                                         $sample,
162            2                                 20         map { $data{$_->[0]}->{$_->[1]} } @{$self->{history_metrics}});
               2                                 16   
163                                                   }
164                                                   
165                                                   # Fetch information from the database about a query that's been reviewed.
166                                                   sub get_review_info {
167            1                    1            41      my ( $self, $id ) = @_;
168            1                                 12      $self->{select_sth}->execute(make_checksum($id));
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
184            9                    9           370      my ( $self, %args ) = @_;
185           54    100                        1199      $self->{insert_sth}->execute(
186                                                         make_checksum($args{fingerprint}),
187                                                         @args{qw(fingerprint sample)},
188            9                                111         map { $args{$_} ? parse_timestamp($args{$_}) : undef }
189                                                            qw(first_seen last_seen first_seen first_seen last_seen last_seen));
190                                                   }
191                                                   
192                                                   # Return the columns we'll be using from the review table.
193                                                   sub review_cols {
194            1                    1            26      my ( $self ) = @_;
195            1                                  5      return grep { !$skip_cols{$_} } @{$self->{tbl_struct}->{cols}};
               8                                 57   
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

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
133          100      1      1     25   $_ eq 'ts_min' || $_ eq 'ts_max'


Covered Subroutines
-------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryReview.pm:27 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryReview.pm:28 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryReview.pm:29 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryReview.pm:32 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryReview.pm:34 
get_review_info         1 /home/daniel/dev/maatkit/common/QueryReview.pm:167
new                     1 /home/daniel/dev/maatkit/common/QueryReview.pm:59 
review_cols             1 /home/daniel/dev/maatkit/common/QueryReview.pm:194
set_history_options     1 /home/daniel/dev/maatkit/common/QueryReview.pm:114
set_review_history      2 /home/daniel/dev/maatkit/common/QueryReview.pm:153
set_review_info         9 /home/daniel/dev/maatkit/common/QueryReview.pm:184

Uncovered Subroutines
---------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/QueryReview.pm:199


