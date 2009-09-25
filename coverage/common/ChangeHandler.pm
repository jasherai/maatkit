---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/ChangeHandler.pm   82.6   59.4   55.6   88.9    n/a  100.0   78.0
Total                          82.6   59.4   55.6   88.9    n/a  100.0   78.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          ChangeHandler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 21:19:46 2009
Finish:       Fri Sep 25 21:19:47 2009

/home/daniel/dev/maatkit/common/ChangeHandler.pm

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
18                                                    # ChangeHandler package $Revision: 4673 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  2   
               1                                  6   
21             1                    1           155   use warnings FATAL => 'all';
               1                                  3   
               1                                 10   
22                                                    
23                                                    package ChangeHandler;
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
26                                                    
27                                                    my $DUPE_KEY  = qr/Duplicate entry/;
28                                                    our @ACTIONS  = qw(DELETE REPLACE INSERT UPDATE);
29                                                    
30             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
31                                                    
32                                                    # Arguments:
33                                                    # * Quoter     Quoter object
34                                                    # * dst_db     Destination database
35                                                    # * dst_tbl    Destination table
36                                                    # * src_db     Source database
37                                                    # * src_tbl    Source table
38                                                    # * actions    arrayref of subroutines to call when handling a change.
39                                                    # * replace    Do UPDATE/INSERT as REPLACE.
40                                                    # * queue      Queue changes until process_changes is called with a greater
41                                                    #              queue level.
42                                                    sub new {
43             2                    2            54      my ( $class, %args ) = @_;
44             2                                 10      foreach my $arg ( qw(Quoter dst_db dst_tbl src_db src_tbl replace queue) ) {
45             8    100                          33         die "I need a $arg argument" unless defined $args{$arg};
46                                                       }
47             1                                  7      my $self = { %args, map { $_ => [] } @ACTIONS };
               4                                 28   
48             1                                  9      $self->{dst_db_tbl} = $self->{Quoter}->quote(@args{qw(dst_db dst_tbl)});
49             1                                  6      $self->{src_db_tbl} = $self->{Quoter}->quote(@args{qw(src_db src_tbl)});
50             1                                  4      $self->{changes} = { map { $_ => 0 } @ACTIONS };
               4                                 21   
51             1                                 14      return bless $self, $class;
52                                                    }
53                                                    
54                                                    # If I'm supposed to fetch-back, that means I have to get the full row from the
55                                                    # database.  For example, someone might call me like so:
56                                                    # $me->change('UPDATE', { a => 1 })
57                                                    # but 'a' is only the primary key. I now need to select that row and make an
58                                                    # UPDATE statement with all of its columns.  The argument is the DB handle used
59                                                    # to fetch.
60                                                    sub fetch_back {
61             1                    1             5      my ( $self, $dbh ) = @_;
62             1                                  7      $self->{fetch_back} = $dbh;
63             1                                  4      MKDEBUG && _d('Will fetch rows from source when updating destination');
64                                                    }
65                                                    
66                                                    sub take_action {
67             6                    6            32      my ( $self, @sql ) = @_;
68             6                                 12      MKDEBUG && _d('Calling subroutines on', @sql);
69             6                                 18      foreach my $action ( @{$self->{actions}} ) {
               6                                 26   
70             6                                 29         $action->(@sql);
71                                                       }
72                                                    }
73                                                    
74                                                    # Arguments: string, hashref, arrayref
75                                                    sub change {
76             6                    6            86      my ( $self, $action, $row, $cols ) = @_;
77             6                                 17      MKDEBUG && _d($action, 'where', $self->make_where_clause($row, $cols));
78                                                       $self->{changes}->{
79    ***      6     50     33                   48         $self->{replace} && $action ne 'DELETE' ? 'REPLACE' : $action
80                                                       }++;
81             6    100                          23      if ( $self->{queue} ) {
82             2                                 11         $self->__queue($action, $row, $cols);
83                                                       }
84                                                       else {
85             4                                 15         eval {
86             4                                 16            my $func = "make_$action";
87             4                                 30            $self->take_action($self->$func($row, $cols));
88                                                          };
89    ***      4     50                          63         if ( $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
      ***            50                               
90    ***      0                                  0            MKDEBUG && _d('Duplicate key violation; will queue and rewrite');
91    ***      0                                  0            $self->{queue}++;
92    ***      0                                  0            $self->{replace} = 1;
93    ***      0                                  0            $self->__queue($action, $row, $cols);
94                                                          }
95                                                          elsif ( $EVAL_ERROR ) {
96    ***      0                                  0            die $EVAL_ERROR;
97                                                          }
98                                                       }
99                                                    }
100                                                   
101                                                   sub __queue {
102            2                    2            10      my ( $self, $action, $row, $cols ) = @_;
103            2                                  5      MKDEBUG && _d('Queueing change for later');
104   ***      2     50                           9      if ( $self->{replace} ) {
105   ***      0      0                           0         $action = $action eq 'DELETE' ? $action : 'REPLACE';
106                                                      }
107            2                                  6      push @{$self->{$action}}, [ $row, $cols ];
               2                                 13   
108                                                   }
109                                                   
110                                                   # If called with 1, will process rows that have been deferred from instant
111                                                   # processing.  If no arg, will process all rows.
112                                                   sub process_rows {
113            3                    3            33      my ( $self, $queue_level ) = @_;
114            3                                  9      my $error_count = 0;
115                                                      TRY: {
116            3    100    100                    8         if ( $queue_level && $queue_level < $self->{queue} ) { # see redo below!
               3                                 26   
117            1                                  3            MKDEBUG && _d('Not processing now', $queue_level, '<', $self->{queue});
118            1                                  3            return;
119                                                         }
120            2                                 12         MKDEBUG && _d('Processing rows:');
121            2                                  6         my ($row, $cur_act);
122            2                                  6         eval {
123            2                                  9            foreach my $action ( @ACTIONS ) {
124            8                                 37               my $func = "make_$action";
125            8                                 25               my $rows = $self->{$action};
126            8                                 20               MKDEBUG && _d(scalar(@$rows), 'to', $action);
127            8                                 20               $cur_act = $action;
128            8                                 33               while ( @$rows ) {
129            2                                  7                  $row = shift @$rows;
130            2                                 13                  $self->take_action($self->$func(@$row));
131                                                               }
132                                                            }
133            2                                 18            $error_count = 0;
134                                                         };
135   ***      2     50     33                   39         if ( !$error_count++ && $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
      ***            50                               
136   ***      0                                  0            MKDEBUG
137                                                               && _d('Duplicate key violation; re-queueing and rewriting');
138   ***      0                                  0            $self->{queue}++; # Defer rows to the very end
139   ***      0                                  0            $self->{replace} = 1;
140   ***      0                                  0            $self->__queue($cur_act, @$row);
141   ***      0                                  0            redo TRY;
142                                                         }
143                                                         elsif ( $EVAL_ERROR ) {
144   ***      0                                  0            die $EVAL_ERROR;
145                                                         }
146                                                      }
147                                                   }
148                                                   
149                                                   # DELETE never needs to be fetched back.
150                                                   sub make_DELETE {
151            2                    2            12      my ( $self, $row, $cols ) = @_;
152            2                                  6      MKDEBUG && _d('Make DELETE');
153            2                                 13      return "DELETE FROM $self->{dst_db_tbl} WHERE "
154                                                         . $self->make_where_clause($row, $cols)
155                                                         . ' LIMIT 1';
156                                                   }
157                                                   
158                                                   sub make_UPDATE {
159            2                    2            10      my ( $self, $row, $cols ) = @_;
160            2                                  6      MKDEBUG && _d('Make UPDATE');
161   ***      2     50                          10      if ( $self->{replace} ) {
162   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
163                                                      }
164            2                                 15      my %in_where = map { $_ => 1 } @$cols;
               2                                 17   
165            2                                 17      my $where = $self->make_where_clause($row, $cols);
166            2    100                          27      if ( my $dbh = $self->{fetch_back} ) {
167            1                                 11         my $sql = "SELECT * FROM $self->{src_db_tbl} WHERE $where LIMIT 1";
168            1                                  3         MKDEBUG && _d('Fetching data for UPDATE:', $sql);
169            1                                  4         my $res = $dbh->selectrow_hashref($sql);
170            1                                  9         @{$row}{keys %$res} = values %$res;
               1                                  6   
171            1                                 13         $cols = [sort keys %$res];
172                                                      }
173                                                      else {
174            1                                 10         $cols = [ sort keys %$row ];
175                                                      }
176            2                                 10      return "UPDATE $self->{dst_db_tbl} SET "
177                                                         . join(', ', map {
178            4                                 17               $self->{Quoter}->quote($_)
179                                                               . '=' .  $self->{Quoter}->quote_val($row->{$_})
180            2                                 15            } grep { !$in_where{$_} } @$cols)
181                                                         . " WHERE $where LIMIT 1";
182                                                   }
183                                                   
184                                                   sub make_INSERT {
185            2                    2            10      my ( $self, $row, $cols ) = @_;
186            2                                  5      MKDEBUG && _d('Make INSERT');
187   ***      2     50                          13      if ( $self->{replace} ) {
188   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
189                                                      }
190            2                                 13      return $self->make_row('INSERT', $row, $cols);
191                                                   }
192                                                   
193                                                   sub make_REPLACE {
194   ***      0                    0             0      my ( $self, $row, $cols ) = @_;
195   ***      0                                  0      MKDEBUG && _d('Make REPLACE');
196   ***      0                                  0      return $self->make_row('REPLACE', $row, $cols);
197                                                   }
198                                                   
199                                                   sub make_row {
200            2                    2             9      my ( $self, $verb, $row, $cols ) = @_;
201            2                                 18      my @cols = sort keys %$row;
202            2    100                          11      if ( my $dbh = $self->{fetch_back} ) {
203            1                                  4         my $where = $self->make_where_clause($row, $cols);
204            1                                  6         my $sql = "SELECT * FROM $self->{src_db_tbl} WHERE $where LIMIT 1";
205            1                                  2         MKDEBUG && _d('Fetching data for UPDATE:', $sql);
206            1                                  2         my $res = $dbh->selectrow_hashref($sql);
207            1                                  8         @{$row}{keys %$res} = values %$res;
               1                                  5   
208            1                                  9         @cols = sort keys %$res;
209                                                      }
210            4                                 18      return "$verb INTO $self->{dst_db_tbl}("
211            2                                  9         . join(', ', map { $self->{Quoter}->quote($_) } @cols)
212                                                         . ') VALUES ('
213            2                                 14         . $self->{Quoter}->quote_val( @{$row}{@cols} )
214                                                         . ')';
215                                                   }
216                                                   
217                                                   sub make_where_clause {
218            5                    5            23      my ( $self, $row, $cols ) = @_;
219            5                                 17      my @clauses = map {
220            5                                 18         my $val = $row->{$_};
221   ***      5     50                          22         my $sep = defined $val ? '=' : ' IS ';
222            5                                 34         $self->{Quoter}->quote($_) . $sep . $self->{Quoter}->quote_val($val);
223                                                      } @$cols;
224            5                                 31      return join(' AND ', @clauses);
225                                                   }
226                                                   
227                                                   sub get_changes {
228            1                    1            13      my ( $self ) = @_;
229            1                                  3      return %{$self->{changes}};
               1                                 18   
230                                                   }
231                                                   
232                                                   sub _d {
233   ***      0                    0                    my ($package, undef, $line) = caller 0;
234   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
235   ***      0                                              map { defined $_ ? $_ : 'undef' }
236                                                           @_;
237   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
238                                                   }
239                                                   
240                                                   1;
241                                                   
242                                                   # ###########################################################################
243                                                   # End ChangeHandler package
244                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45           100      1      7   unless defined $args{$arg}
79    ***     50      0      6   $$self{'replace'} && $action ne 'DELETE' ? :
81           100      2      4   if ($$self{'queue'}) { }
89    ***     50      0      4   if ($EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      4   elsif ($EVAL_ERROR) { }
104   ***     50      0      2   if ($$self{'replace'})
105   ***      0      0      0   $action eq 'DELETE' ? :
116          100      1      2   if ($queue_level and $queue_level < $$self{'queue'})
135   ***     50      0      2   if (not $error_count++ and $EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      2   elsif ($EVAL_ERROR) { }
161   ***     50      0      2   if ($$self{'replace'})
166          100      1      1   if (my $dbh = $$self{'fetch_back'}) { }
187   ***     50      0      2   if ($$self{'replace'})
202          100      1      1   if (my $dbh = $$self{'fetch_back'})
221   ***     50      5      0   defined $val ? :
234   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
79    ***     33      6      0      0   $$self{'replace'} && $action ne 'DELETE'
116          100      1      1      1   $queue_level and $queue_level < $$self{'queue'}
135   ***     33      0      2      0   not $error_count++ and $EVAL_ERROR =~ /$DUPE_KEY/


Covered Subroutines
-------------------

Subroutine        Count Location                                            
----------------- ----- ----------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:20 
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:21 
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:25 
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:30 
__queue               2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:102
change                6 /home/daniel/dev/maatkit/common/ChangeHandler.pm:76 
fetch_back            1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:61 
get_changes           1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:228
make_DELETE           2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:151
make_INSERT           2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:185
make_UPDATE           2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:159
make_row              2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:200
make_where_clause     5 /home/daniel/dev/maatkit/common/ChangeHandler.pm:218
new                   2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:43 
process_rows          3 /home/daniel/dev/maatkit/common/ChangeHandler.pm:113
take_action           6 /home/daniel/dev/maatkit/common/ChangeHandler.pm:67 

Uncovered Subroutines
---------------------

Subroutine        Count Location                                            
----------------- ----- ----------------------------------------------------
_d                    0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:233
make_REPLACE          0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:194


