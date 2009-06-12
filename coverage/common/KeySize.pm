---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/KeySize.pm   95.1   79.2   66.7  100.0    n/a  100.0   91.2
Total                          95.1   79.2   66.7  100.0    n/a  100.0   91.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          KeySize.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 11 23:20:15 2009
Finish:       Thu Jun 11 23:20:16 2009

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
18                                                    # KeySize package $Revision: 3290 $
19                                                    # ###########################################################################
20                                                    package KeySize;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25             1                    1            11   use DBI;
               1                                  4   
               1                                 10   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 60   
28                                                    
29                                                    sub new {
30             1                    1            15      my ( $class, %args ) = @_;
31             1                                  5      foreach my $arg ( qw(q) ) {
32    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
33                                                       }
34             1                                  6      my $self = { %args };
35             1                                 12      return bless $self, $class;
36                                                    }
37                                                    
38                                                    # Returns the key's size in scalar context; returns the key's size
39                                                    # and the key that MySQL actually chose in list context.
40                                                    # Required args:
41                                                    #    name       => name of key
42                                                    #    cols       => arrayref of key's cols
43                                                    #    tbl_name   => quoted, db-qualified table name like `db`.`tbl`
44                                                    #    tbl_struct => hashref returned by TableParser::parse for tbl
45                                                    #    dbh        => dbh
46                                                    # If the key exists in the tbl (it should), then we can FORCE INDEX.
47                                                    # This is what we want to do because it's more reliable.  But, if the
48                                                    # key does not exist in the tbl (which happens with foreign keys),
49                                                    # then we let MySQL choose the index.  If there's an error, nothing
50                                                    # is returned and you can get the last error, query and EXPLAIN with
51                                                    # error(), query() and explain().
52                                                    sub get_key_size {
53             6                    6           101      my ( $self, %args ) = @_;
54             6                                 42      foreach my $arg ( qw(name cols tbl_name tbl_struct dbh) ) {
55    ***     30     50                         133         die "I need a $arg argument" unless $args{$arg};
56                                                       }
57             6                                 22      my $name = $args{name};
58             6                                 18      my @cols = map { $self->{q}->quote($_); } @{$args{cols}};
               8                                 57   
               6                                 30   
59                                                    
60             6                                 29      $self->{explain} = '';
61             6                                 67      $self->{query}   = '';
62             6                                 27      $self->{error}   = '';
63                                                    
64    ***      6     50                          29      if ( @cols == 0 ) {
65    ***      0                                  0         $self->{error} = "No columns for key $name";
66    ***      0                                  0         return;
67                                                       }
68                                                    
69             6                                 40      my $key_exists = $self->_key_exists(%args);
70             6                                 17      MKDEBUG && _d('Key', $name, 'exists in', $args{tbl_name}, ':',
71                                                          $key_exists ? 'yes': 'no');
72                                                    
73                                                       # Construct a SQL statement with WHERE conditions on all key
74                                                       # cols that will get EXPLAIN to tell us 1) the full length of
75                                                       # the key and 2) the total number of rows in the table.
76                                                       # For 1), all key cols must be used because key_len in EXPLAIN only
77                                                       # only covers the portion of the key needed to satisfy the query.
78                                                       # For 2), we have to break normal index usage which normally
79                                                       # allows MySQL to access only the limited number of rows needed
80                                                       # to satisify the query because we want to know total table rows.
81             6    100                          56      my $sql = 'EXPLAIN SELECT ' . join(', ', @cols)
82                                                               . ' FROM ' . $args{tbl_name}
83                                                               . ($key_exists ? " FORCE INDEX (`$name`)" : '')
84                                                               . ' WHERE ';
85             6                                 15      my @where_cols;
86             6                                 28      foreach my $col ( @cols ) {
87             8                                 37         push @where_cols, "$col=1";
88                                                       }
89                                                       # For single column indexes we have to trick MySQL into scanning
90                                                       # the whole index by giving it two irreducible condtions. Otherwise,
91                                                       # EXPLAIN rows will report only the rows that satisfy the query
92                                                       # using the key, but this is not what we want. We want total table rows.
93                                                       # In other words, we need an EXPLAIN type index, not ref or range.
94             6    100                          31      if ( scalar @cols == 1 ) {
95             4                                 16         push @where_cols, "$cols[0]<>1";
96                                                       }
97             6                                 25      $sql .= join(' OR ', @where_cols);
98             6                                 20      $self->{query} = $sql;
99             6                                 14      MKDEBUG && _d('sql:', $sql);
100                                                   
101            6                                 14      my $explain;
102            6                                 19      eval { $explain = $args{dbh}->selectall_hashref($sql, 'id'); };
               6                                 13   
103   ***      6     50                         193      if ( $args{dbh}->err ) {
104   ***      0                                  0         $self->{error} = "Cannot get size of $name key: $DBI::errstr";
105   ***      0                                  0         return;
106                                                      }
107            6                                 28      $self->{explain} = $explain;
108            6                                 30      my $key_len      = $explain->{1}->{key_len};
109            6                                 23      my $rows         = $explain->{1}->{rows};
110            6                                 26      my $chosen_key   = $explain->{1}->{key};  # May differ from $name
111            6                                 12      MKDEBUG && _d('MySQL chose key:', $chosen_key, 'len:', $key_len,
112                                                         'rows:', $rows);
113                                                   
114            6                                 19      my $key_size = 0;
115   ***      6    100     66                   50      if ( $key_len && $rows ) {
116   ***      5    100     66                   52         if ( $chosen_key =~ m/,/ && $key_len =~ m/,/ ) {
117            1                                  6            $self->{error} = "MySQL chose multiple keys: $chosen_key";
118            1                                  9            return;
119                                                         }
120            4                                 23         $key_size = $key_len * $rows;
121                                                      }
122                                                      else {
123            1                                  7         $self->{error} = "key_len or rows NULL in EXPLAIN:\n"
124                                                                        . _explain_to_text($explain);
125            1                                 20         return;
126                                                      }
127                                                   
128            4    100                          42      return wantarray ? ($key_size, $chosen_key) : $key_size;
129                                                   }
130                                                   
131                                                   # Returns the last explained query.
132                                                   sub query {
133            2                    2             9      my ( $self ) = @_;
134            2                                 13      return $self->{query};
135                                                   }
136                                                   
137                                                   # Returns the last explain plan.
138                                                   sub explain {
139            1                    1             5      my ( $self ) = @_;
140            1                                 11      return _explain_to_text($self->{explain});
141                                                   }
142                                                   
143                                                   # Returns the last error.
144                                                   sub error {
145            2                    2            26      my ( $self ) = @_;
146            2                                 17      return $self->{error};
147                                                   }
148                                                   
149                                                   sub _key_exists {
150            7                    7           120      my ( $self, %args ) = @_;
151            7    100                          84      return exists $args{tbl_struct}->{keys}->{ lc $args{name} } ? 1 : 0;
152                                                   }
153                                                   
154                                                   sub _explain_to_text {
155            2                    2             9      my ( $explain ) = @_;
156           20    100                         128      return join("\n",
157            2                                 31         map { "$_: ".($explain->{1}->{$_} ? $explain->{1}->{$_} : 'NULL') }
158            2                                  6         sort keys %{$explain->{1}}
159                                                      );
160                                                   }
161                                                   
162                                                   sub _d {
163            1                    1            25      my ($package, undef, $line) = caller 0;
164   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 41   
165            1                                  5           map { defined $_ ? $_ : 'undef' }
166                                                           @_;
167            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
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
32    ***     50      0      1   unless $args{$arg}
55    ***     50      0     30   unless $args{$arg}
64    ***     50      0      6   if (@cols == 0)
81           100      4      2   $key_exists ? :
94           100      4      2   if (scalar @cols == 1)
103   ***     50      0      6   if ($args{'dbh'}->err)
115          100      5      1   if ($key_len and $rows) { }
116          100      1      4   if ($chosen_key =~ /,/ and $key_len =~ /,/)
128          100      2      2   wantarray ? :
151          100      5      2   exists $args{'tbl_struct'}{'keys'}{lc $args{'name'}} ? :
156          100     12      8   $$explain{1}{$_} ? :
164   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
115   ***     66      1      0      5   $key_len and $rows
116   ***     66      4      0      1   $chosen_key =~ /,/ and $key_len =~ /,/


Covered Subroutines
-------------------

Subroutine       Count Location                                      
---------------- ----- ----------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:22 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:23 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:24 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:25 
BEGIN                1 /home/daniel/dev/maatkit/common/KeySize.pm:27 
_d                   1 /home/daniel/dev/maatkit/common/KeySize.pm:163
_explain_to_text     2 /home/daniel/dev/maatkit/common/KeySize.pm:155
_key_exists          7 /home/daniel/dev/maatkit/common/KeySize.pm:150
error                2 /home/daniel/dev/maatkit/common/KeySize.pm:145
explain              1 /home/daniel/dev/maatkit/common/KeySize.pm:139
get_key_size         6 /home/daniel/dev/maatkit/common/KeySize.pm:53 
new                  1 /home/daniel/dev/maatkit/common/KeySize.pm:30 
query                2 /home/daniel/dev/maatkit/common/KeySize.pm:133


