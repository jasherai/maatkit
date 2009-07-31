---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/KeySize.pm   95.1   81.8   66.7  100.0    n/a  100.0   91.8
Total                          95.1   81.8   66.7  100.0    n/a  100.0   91.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          KeySize.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:55 2009
Finish:       Fri Jul 31 18:51:56 2009

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
18                                                    # KeySize package $Revision: 3923 $
19                                                    # ###########################################################################
20                                                    package KeySize;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 10   
25             1                    1            10   use DBI;
               1                                  4   
               1                                 10   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
28                                                    
29                                                    sub new {
30             1                    1            15      my ( $class, %args ) = @_;
31             1                                 11      my $self = { %args };
32             1                                 13      return bless $self, $class;
33                                                    }
34                                                    
35                                                    # Returns the key's size in scalar context; returns the key's size
36                                                    # and the key that MySQL actually chose in list context.
37                                                    # Required args:
38                                                    #    name       => name of key
39                                                    #    cols       => arrayref of key's cols
40                                                    #    tbl_name   => quoted, db-qualified table name like `db`.`tbl`
41                                                    #    tbl_struct => hashref returned by TableParser::parse for tbl
42                                                    #    dbh        => dbh
43                                                    # If the key exists in the tbl (it should), then we can FORCE INDEX.
44                                                    # This is what we want to do because it's more reliable.  But, if the
45                                                    # key does not exist in the tbl (which happens with foreign keys),
46                                                    # then we let MySQL choose the index.  If there's an error, nothing
47                                                    # is returned and you can get the last error, query and EXPLAIN with
48                                                    # error(), query() and explain().
49                                                    sub get_key_size {
50             6                    6           101      my ( $self, %args ) = @_;
51             6                                 40      foreach my $arg ( qw(name cols tbl_name tbl_struct dbh) ) {
52    ***     30     50                         135         die "I need a $arg argument" unless $args{$arg};
53                                                       }
54             6                                 24      my $name = $args{name};
55             6                                 22      my @cols = @{$args{cols}};
               6                                 37   
56             6                                 22      my $dbh  = $args{dbh};
57                                                    
58             6                                 25      $self->{explain} = '';
59             6                                 65      $self->{query}   = '';
60             6                                 26      $self->{error}   = '';
61                                                    
62    ***      6     50                          27      if ( @cols == 0 ) {
63    ***      0                                  0         $self->{error} = "No columns for key $name";
64    ***      0                                  0         return;
65                                                       }
66                                                    
67             6                                 40      my $key_exists = $self->_key_exists(%args);
68             6                                 16      MKDEBUG && _d('Key', $name, 'exists in', $args{tbl_name}, ':',
69                                                          $key_exists ? 'yes': 'no');
70                                                    
71                                                       # Construct a SQL statement with WHERE conditions on all key
72                                                       # cols that will get EXPLAIN to tell us 1) the full length of
73                                                       # the key and 2) the total number of rows in the table.
74                                                       # For 1), all key cols must be used because key_len in EXPLAIN only
75                                                       # only covers the portion of the key needed to satisfy the query.
76                                                       # For 2), we have to break normal index usage which normally
77                                                       # allows MySQL to access only the limited number of rows needed
78                                                       # to satisify the query because we want to know total table rows.
79             6    100                          54      my $sql = 'EXPLAIN SELECT ' . join(', ', @cols)
80                                                               . ' FROM ' . $args{tbl_name}
81                                                               . ($key_exists ? " FORCE INDEX (`$name`)" : '')
82                                                               . ' WHERE ';
83             6                                 16      my @where_cols;
84             6                                 21      foreach my $col ( @cols ) {
85             8                                 37         push @where_cols, "$col=1";
86                                                       }
87                                                       # For single column indexes we have to trick MySQL into scanning
88                                                       # the whole index by giving it two irreducible condtions. Otherwise,
89                                                       # EXPLAIN rows will report only the rows that satisfy the query
90                                                       # using the key, but this is not what we want. We want total table rows.
91                                                       # In other words, we need an EXPLAIN type index, not ref or range.
92             6    100                          31      if ( scalar @cols == 1 ) {
93             4                                 17         push @where_cols, "$cols[0]<>1";
94                                                       }
95             6                                 26      $sql .= join(' OR ', @where_cols);
96             6                                 21      $self->{query} = $sql;
97             6                                 18      MKDEBUG && _d('sql:', $sql);
98                                                    
99             6                                 15      my $explain;
100            6                                 15      my $sth = $dbh->prepare($sql);
101            6                                 35      eval { $sth->execute(); };
               6                               2040   
102   ***      6     50                          31      if ( $EVAL_ERROR ) {
103   ***      0                                  0         $self->{error} = "Cannot get size of $name key: $DBI::errstr";
104   ***      0                                  0         return;
105                                                      }
106            6                                104      $explain = $sth->fetchrow_hashref();
107                                                   
108            6                                171      $self->{explain} = $explain;
109            6                                 23      my $key_len      = $explain->{key_len};
110            6                                 23      my $rows         = $explain->{rows};
111            6                                 24      my $chosen_key   = $explain->{key};  # May differ from $name
112            6                                 13      MKDEBUG && _d('MySQL chose key:', $chosen_key, 'len:', $key_len,
113                                                         'rows:', $rows);
114                                                   
115            6                                 19      my $key_size = 0;
116   ***      6    100     66                   65      if ( $key_len && $rows ) {
117   ***      5    100     66                   48         if ( $chosen_key =~ m/,/ && $key_len =~ m/,/ ) {
118            1                                  7            $self->{error} = "MySQL chose multiple keys: $chosen_key";
119            1                                 24            return;
120                                                         }
121            4                                 27         $key_size = $key_len * $rows;
122                                                      }
123                                                      else {
124            1                                  7         $self->{error} = "key_len or rows NULL in EXPLAIN:\n"
125                                                                        . _explain_to_text($explain);
126            1                                 47         return;
127                                                      }
128                                                   
129            4    100                         109      return wantarray ? ($key_size, $chosen_key) : $key_size;
130                                                   }
131                                                   
132                                                   # Returns the last explained query.
133                                                   sub query {
134            2                    2            11      my ( $self ) = @_;
135            2                                 13      return $self->{query};
136                                                   }
137                                                   
138                                                   # Returns the last explain plan.
139                                                   sub explain {
140            1                    1             4      my ( $self ) = @_;
141            1                                  9      return _explain_to_text($self->{explain});
142                                                   }
143                                                   
144                                                   # Returns the last error.
145                                                   sub error {
146            2                    2            19      my ( $self ) = @_;
147            2                                 12      return $self->{error};
148                                                   }
149                                                   
150                                                   sub _key_exists {
151            7                    7           105      my ( $self, %args ) = @_;
152            7    100                          94      return exists $args{tbl_struct}->{keys}->{ lc $args{name} } ? 1 : 0;
153                                                   }
154                                                   
155                                                   sub _explain_to_text {
156            2                    2             9      my ( $explain ) = @_;
157           20    100                         146      return join("\n",
158            2                                 30         map { "$_: ".($explain->{$_} ? $explain->{$_} : 'NULL') }
159                                                         sort keys %$explain
160                                                      );
161                                                   }
162                                                   
163                                                   sub _d {
164            1                    1            25      my ($package, undef, $line) = caller 0;
165   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  9   
               2                                 10   
166            1                                  5           map { defined $_ ? $_ : 'undef' }
167                                                           @_;
168            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
169                                                   }
170                                                   
171                                                   1;
172                                                   
173                                                   # ###########################################################################
174                                                   # End KeySize package
175                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
52    ***     50      0     30   unless $args{$arg}
62    ***     50      0      6   if (@cols == 0)
79           100      4      2   $key_exists ? :
92           100      4      2   if (scalar @cols == 1)
102   ***     50      0      6   if ($EVAL_ERROR)
116          100      5      1   if ($key_len and $rows) { }
117          100      1      4   if ($chosen_key =~ /,/ and $key_len =~ /,/)
129          100      2      2   wantarray ? :
152          100      5      2   exists $args{'tbl_struct'}{'keys'}{lc $args{'name'}} ? :
157          100     12      8   $$explain{$_} ? :
165   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
116   ***     66      1      0      5   $key_len and $rows
117   ***     66      4      0      1   $chosen_key =~ /,/ and $key_len =~ /,/


Covered Subroutines
-------------------

Subroutine       Count Location                                      
---------------- ----- ----------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:22 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:23 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:24 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:25 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:27 
_d                   1 /home/daniel/dev/maatkit/common/KeySize.pm:164
_explain_to_text     2 /home/daniel/dev/maatkit/common/KeySize.pm:156
_key_exists          7 /home/daniel/dev/maatkit/common/KeySize.pm:151
error                2 /home/daniel/dev/maatkit/common/KeySize.pm:146
explain              1 /home/daniel/dev/maatkit/common/KeySize.pm:140
get_key_size         6 /home/daniel/dev/maatkit/common/KeySize.pm:50 
new                  1 /home/daniel/dev/maatkit/common/KeySize.pm:30 
query                2 /home/daniel/dev/maatkit/common/KeySize.pm:134


