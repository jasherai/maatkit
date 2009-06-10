---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...maatkit/common/KeySize.pm   81.8   66.7   66.7   85.7    n/a  100.0   78.3
Total                          81.8   66.7   66.7   85.7    n/a  100.0   78.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          KeySize.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:50 2009
Finish:       Wed Jun 10 17:19:51 2009

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
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
27                                                    
28                                                    sub new {
29             1                    1            12      my ( $class, %args ) = @_;
30             1                                  3      my $self = {};
31             1                                 10      return bless $self, $class;
32                                                    }
33                                                    
34                                                    # Returns the key's size in scalar context; returns the key's size
35                                                    # and the key that MySQL actually chose in list context.
36                                                    # Required args:
37                                                    #    name       => name of key
38                                                    #    cols       => arrayref of key's cols
39                                                    #    tbl_name   => quoted, db-qualified table name like `db`.`tbl`
40                                                    #    tbl_struct => hashref returned by TableParser::parse for tbl
41                                                    #    dbh        => dbh
42                                                    # If the key exists in the tbl (it should), then we can FORCE INDEX.
43                                                    # This is what we want to do because it's more reliable. But, if the
44                                                    # key does not exist in the tbl (which happens with foreign keys),
45                                                    # then we let MySQL choose the index.
46                                                    sub get_key_size {
47             4                    4           130      my ( $self, %args ) = @_;
48             4                                 39      foreach my $arg ( qw(name cols tbl_name tbl_struct dbh) ) {
49    ***     20     50                         150         die "I need a $arg argument" unless $args{$arg};
50                                                       }
51                                                    
52             4                                 22      my $name = $args{name};
53             4                                 16      my @cols = @{$args{cols}};
               4                                 31   
54                                                    
55    ***      4     50                          36      if ( @cols == 0 ) {
56    ***      0                                  0         warn "No columns for key $name";
57    ***      0                                  0         return 0;
58                                                       }
59                                                      
60             4    100                          42      my $key_exists = exists $args{tbl_struct}->{keys}->{ $name } ? 1 : 0;
61             4                                 14      MKDEBUG && _d('Key', $name, 'exists in', $args{tbl_name}, ':', $key_exists);
62                                                    
63                                                       # Construct a SQL statement with WHERE conditions on all key
64                                                       # cols that will get EXPLAIN to tell us 1) the full length of
65                                                       # the key and 2) the total number of rows in the table.
66                                                       # For 1), all key cols must be used because key_len in EXPLAIN only
67                                                       # only covers the portion of the key needed to satisfy the query.
68                                                       # For 2), we have to break normal index usage which normally
69                                                       # allows MySQL to access only the limited number of rows needed
70                                                       # to satisify the query because we want to know total table rows.
71             4    100                          60      my $sql = 'EXPLAIN SELECT ' . join(', ', @cols)
72                                                               . ' FROM ' . $args{tbl_name}
73                                                               . ($key_exists ? " FORCE INDEX (`$name`)" : '')
74                                                               . ' WHERE ';
75             4                                 15      my @where_cols;
76             4                                 23      foreach my $col ( @cols ) {
77             4                                 32         push @where_cols, "$col=1";
78                                                       }
79                                                       # For single column indexes we have to trick MySQL into scanning
80                                                       # the whole index by giving it two irreducible condtions. Otherwise,
81                                                       # EXPLAIN rows will report only the rows that satisfy the query
82                                                       # using the key, but this is not what we want. We want total table rows.
83                                                       # In other words, we need an EXPLAIN type index, not ref or range.
84    ***      4     50                          33      if ( scalar @cols == 1 ) {
85             4                                 27         push @where_cols, "$cols[0]<>1";
86                                                       }
87             4                                 24      $sql .= join(' OR ', @where_cols);
88             4                                 13      MKDEBUG && _d('sql:', $sql);
89                                                    
90             4                                 15      my $explain;
91             4                                 16      eval { $explain = $args{dbh}->selectall_hashref($sql, 'id'); };
               4                                 15   
92    ***      4     50                         237      if ( $args{dbh}->err ) {
93    ***      0                                  0         warn "Cannot get size of $name key: $DBI::errstr";
94    ***      0                                  0         return 0;
95                                                       }
96             4                                 32      my $key_len = $explain->{1}->{key_len};
97             4                                 29      my $rows    = $explain->{1}->{rows};
98             4                                 23      my $key     = $explain->{1}->{key};
99                                                    
100            4                                 13      MKDEBUG && _d('MySQL chose key:', $key, 'len:', $key_len, 'rows:', $rows);
101                                                   
102            4                                 17      my $key_size = 0;
103   ***      4    100     66                   65      if ( defined $key_len && defined $rows ) {
104            3                                 26         $key_size = $key_len * $rows;
105                                                      }
106                                                      else {
107                                                         MKDEBUG && _d("key_len or rows NULL in EXPLAIN:\n",
108                                                            join("\n",
109                                                               map { "$_: ".($explain->{1}->{$_} ? $explain->{1}->{$_} : 'NULL') }
110            1                                  3               keys %{$explain->{1}}));
111                                                      }
112                                                   
113            4    100                          95      return wantarray ? ($key_size, $key) : $key_size;
114                                                   }
115                                                   
116                                                   sub _d {
117   ***      0                    0                    my ($package, undef, $line) = caller 0;
118   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
119   ***      0                                              map { defined $_ ? $_ : 'undef' }
120                                                           @_;
121   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
122                                                   }
123                                                   
124                                                   1;
125                                                   
126                                                   # ###########################################################################
127                                                   # End KeySize package
128                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
49    ***     50      0     20   unless $args{$arg}
55    ***     50      0      4   if (@cols == 0)
60           100      3      1   exists $args{'tbl_struct'}{'keys'}{$name} ? :
71           100      3      1   $key_exists ? :
84    ***     50      4      0   if (scalar @cols == 1)
92    ***     50      0      4   if ($args{'dbh'}->err)
103          100      3      1   if (defined $key_len and defined $rows) { }
113          100      1      3   wantarray ? :
118   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
103   ***     66      1      0      3   defined $key_len and defined $rows


Covered Subroutines
-------------------

Subroutine   Count Location                                      
------------ ----- ----------------------------------------------
BEGIN            1 /home/daniel/dev/maatkit/common/KeySize.pm:22 
BEGIN            1 /home/daniel/dev/maatkit/common/KeySize.pm:23 
BEGIN            1 /home/daniel/dev/maatkit/common/KeySize.pm:24 
BEGIN            1 /home/daniel/dev/maatkit/common/KeySize.pm:26 
get_key_size     4 /home/daniel/dev/maatkit/common/KeySize.pm:47 
new              1 /home/daniel/dev/maatkit/common/KeySize.pm:29 

Uncovered Subroutines
---------------------

Subroutine   Count Location                                      
------------ ----- ----------------------------------------------
_d               0 /home/daniel/dev/maatkit/common/KeySize.pm:117


