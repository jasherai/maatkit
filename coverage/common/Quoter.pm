---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../maatkit/common/Quoter.pm  100.0   90.0   75.0  100.0    0.0   71.2   88.8
Quoter.t                      100.0   50.0   33.3  100.0    n/a   28.8   95.2
Total                         100.0   86.4   63.6  100.0    0.0  100.0   91.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:15 2010
Finish:       Thu Jun 24 19:36:15 2010

Run:          Quoter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:16 2010
Finish:       Thu Jun 24 19:36:16 2010

/home/daniel/dev/maatkit/common/Quoter.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Baron Schwartz.
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
18                                                    # Quoter package $Revision: 6240 $
19                                                    # ###########################################################################
20                                                    package Quoter;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      4      my ( $class ) = @_;
30             1                                 16      return bless {}, $class;
31                                                    }
32                                                    
33                                                    sub quote {
34    ***      5                    5      0     24      my ( $self, @vals ) = @_;
35             5                                 19      foreach my $val ( @vals ) {
36             7                                 34         $val =~ s/`/``/g;
37                                                       }
38             5                                 18      return join('.', map { '`' . $_ . '`' } @vals);
               7                                 48   
39                                                    }
40                                                    
41                                                    # Quote everything, even numbers to avoid problems where
42                                                    # the col is char so user really means col="3".
43                                                    sub quote_val {
44    ***     10                   10      0     47      my ( $self, $val ) = @_;
45                                                    
46            10    100                          44      return 'NULL' unless defined $val;         # undef = NULL
47             9    100                          38      return "''" if $val eq '';                 # blank string = ''
48             8    100                          37      return $val if $val =~ m/^0x[0-9a-fA-F]/;  # hex value like 0xe5f190
49                                                    
50                                                       # Quote and return non-numeric vals.
51             7                                 37      $val =~ s/(['\\])/\\$1/g;
52             7                                 45      return "'$val'";
53                                                    }
54                                                    
55                                                    sub split_unquote {
56    ***      4                    4      0     20      my ( $self, $db_tbl, $default_db ) = @_;
57             4                                 18      $db_tbl =~ s/`//g;
58             4                                 18      my ( $db, $tbl ) = split(/[.]/, $db_tbl);
59             4    100                          17      if ( !$tbl ) {
60             2                                  6         $tbl = $db;
61             2                                  5         $db  = $default_db;
62                                                       }
63             4                                 35      return ($db, $tbl);
64                                                    }
65                                                    
66                                                    # Escapes LIKE wildcard % and _.
67                                                    sub literal_like {
68    ***      4                    4      0     19      my ( $self, $like ) = @_;
69    ***      4     50                          20      return unless $like;
70             4                                 33      $like =~ s/([%_])/\\$1/g;
71             4                                 26      return "'$like'";
72                                                    }
73                                                    
74                                                    # The opposite of split_unquote.
75                                                    sub join_quote {
76    ***      6                    6      0     30      my ( $self, $default_db, $db_tbl ) = @_;
77    ***      6     50                          24      return unless $db_tbl;
78             6                                 29      my ($db, $tbl) = split(/[.]/, $db_tbl);
79             6    100                          23      if ( !$tbl ) {
80             4                                 11         $tbl = $db;
81             4                                 13         $db  = $default_db;
82                                                       }
83             6    100    100                   54      $db  = "`$db`"  if $db  && $db  !~ m/^`/;
84    ***      6    100     66                   54      $tbl = "`$tbl`" if $tbl && $tbl !~ m/^`/;
85             6    100                          69      return $db ? "$db.$tbl" : $tbl;
86                                                    }
87                                                    
88                                                    1;
89                                                    
90                                                    # ###########################################################################
91                                                    # End Quoter package
92                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
46           100      1      9   unless defined $val
47           100      1      8   if $val eq ''
48           100      1      7   if $val =~ /^0x[0-9a-fA-F]/
59           100      2      2   if (not $tbl)
69    ***     50      0      4   unless $like
77    ***     50      0      6   unless $db_tbl
79           100      4      2   if (not $tbl)
83           100      2      4   if $db and not $db =~ /^`/
84           100      3      3   if $tbl and not $tbl =~ /^`/
85           100      4      2   $db ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
83           100      2      2      2   $db and not $db =~ /^`/
84    ***     66      0      3      3   $tbl and not $tbl =~ /^`/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine    Count Pod Location                                    
------------- ----- --- --------------------------------------------
BEGIN             1     /home/daniel/dev/maatkit/common/Quoter.pm:22
BEGIN             1     /home/daniel/dev/maatkit/common/Quoter.pm:23
BEGIN             1     /home/daniel/dev/maatkit/common/Quoter.pm:24
BEGIN             1     /home/daniel/dev/maatkit/common/Quoter.pm:26
join_quote        6   0 /home/daniel/dev/maatkit/common/Quoter.pm:76
literal_like      4   0 /home/daniel/dev/maatkit/common/Quoter.pm:68
new               1   0 /home/daniel/dev/maatkit/common/Quoter.pm:29
quote             5   0 /home/daniel/dev/maatkit/common/Quoter.pm:34
quote_val        10   0 /home/daniel/dev/maatkit/common/Quoter.pm:44
split_unquote     4   0 /home/daniel/dev/maatkit/common/Quoter.pm:56


Quoter.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            13   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 29;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use Quoter;
               1                                  3   
               1                                  9   
15             1                    1            11   use MaatkitTest;
               1                                  3   
               1                                 38   
16                                                    
17             1                                  8   my $q = new Quoter;
18                                                    
19             1                                  5   is(
20                                                       $q->quote('a'),
21                                                       '`a`',
22                                                       'Simple quote OK',
23                                                    );
24                                                    
25             1                                  7   is(
26                                                       $q->quote('a','b'),
27                                                       '`a`.`b`',
28                                                       'multi value',
29                                                    );
30                                                    
31             1                                  6   is(
32                                                       $q->quote('`a`'),
33                                                       '```a```',
34                                                       'already quoted',
35                                                    );
36                                                    
37             1                                  6   is(
38                                                       $q->quote('a`b'),
39                                                       '`a``b`',
40                                                       'internal quote',
41                                                    );
42                                                    
43             1                                  6   is(
44                                                       $q->quote('my db', 'my tbl'),
45                                                       '`my db`.`my tbl`',
46                                                       'quotes db with space and tbl with space'
47                                                    );
48                                                    
49             1                                  6   is( $q->quote_val(1), "'1'", 'number' );
50             1                                  8   is( $q->quote_val('001'), "'001'", 'number with leading zero' );
51                                                    # is( $q->quote_val(qw(1 2 3)), '1, 2, 3', 'three numbers');
52             1                                  7   is( $q->quote_val(qw(a)), "'a'", 'letter');
53             1                                  6   is( $q->quote_val("a'"), "'a\\''", 'letter with quotes');
54             1                                  5   is( $q->quote_val(undef), 'NULL', 'NULL');
55             1                                  7   is( $q->quote_val(''), "''", 'Empty string');
56             1                                  5   is( $q->quote_val('\\\''), "'\\\\\\\''", 'embedded backslash');
57                                                    # is( $q->quote_val(42, 0), "'42'", 'non-numeric number' );
58                                                    # is( $q->quote_val(42, 1), "42", 'number is numeric' );
59             1                                  6   is( $q->quote_val('123-abc'), "'123-abc'", 'looks numeric but is string');
60             1                                  6   is( $q->quote_val('123abc'), "'123abc'", 'looks numeric but is string');
61             1                                  6   is( $q->quote_val('0x89504E470'), '0x89504E470', 'hex string');
62                                                    
63                                                    # Splitting DB and tbl apart
64             1                                  8   is_deeply(
65                                                       [$q->split_unquote("`db`.`tbl`")],
66                                                       [qw(db tbl)],
67                                                       'splits with a quoted db.tbl',
68                                                    );
69                                                    
70             1                                 11   is_deeply(
71                                                       [$q->split_unquote("db.tbl")],
72                                                       [qw(db tbl)],
73                                                       'splits with a db.tbl',
74                                                    );
75                                                    
76             1                                 11   is_deeply(
77                                                       [$q->split_unquote("tbl")],
78                                                       [undef, 'tbl'],
79                                                       'splits without a db',
80                                                    );
81                                                    
82             1                                 10   is_deeply(
83                                                       [$q->split_unquote("tbl", "db")],
84                                                       [qw(db tbl)],
85                                                       'splits with a db',
86                                                    );
87                                                    
88             1                                 11   is( $q->literal_like('foo'), "'foo'", 'LIKE foo');
89             1                                  6   is( $q->literal_like('foo_bar'), "'foo\\_bar'", 'LIKE foo_bar');
90             1                                  6   is( $q->literal_like('foo%bar'), "'foo\\%bar'", 'LIKE foo%bar');
91             1                                  5   is( $q->literal_like('v_b%a c_'), "'v\\_b\\%a c\\_'", 'LIKE v_b%a c_');
92                                                    
93             1                                  9   is( $q->join_quote('db', 'tbl'), '`db`.`tbl`', 'join_merge(db, tbl)' );
94             1                                  6   is( $q->join_quote(undef, 'tbl'), '`tbl`', 'join_merge(undef, tbl)'  );
95             1                                  6   is( $q->join_quote('db', 'foo.tbl'), '`foo`.`tbl`', 'join_merge(db, foo.tbl)' );
96             1                                  7   is( $q->join_quote('`db`', '`tbl`'), '`db`.`tbl`', 'join_merge(`db`, `tbl`)' );
97             1                                  7   is( $q->join_quote(undef, '`tbl`'), '`tbl`', 'join_merge(undef, `tbl`)'  );
98             1                                  6   is( $q->join_quote('`db`', '`foo`.`tbl`'), '`foo`.`tbl`', 'join_merge(`db`, `foo`.`tbl`)' );
99                                                    
100            1                                  3   exit;


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
---------- ----- -----------
BEGIN          1 Quoter.t:10
BEGIN          1 Quoter.t:11
BEGIN          1 Quoter.t:12
BEGIN          1 Quoter.t:14
BEGIN          1 Quoter.t:15
BEGIN          1 Quoter.t:4 
BEGIN          1 Quoter.t:9 


