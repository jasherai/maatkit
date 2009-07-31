---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/ChangeHandler.pm   82.7   59.4   55.6   88.9    n/a  100.0   78.0
Total                          82.7   59.4   55.6   88.9    n/a  100.0   78.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          ChangeHandler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:24 2009
Finish:       Fri Jul 31 18:51:25 2009

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
18                                                    # ChangeHandler package $Revision: 3186 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  3   
               1                                  7   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                109   
22                                                    
23                                                    package ChangeHandler;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
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
33                                                    # * quoter     Quoter()
34                                                    # * database   database name
35                                                    # * table      table name
36                                                    # * sdatabase  source database name
37                                                    # * stable     source table name
38                                                    # * actions    arrayref of subroutines to call when handling a change.
39                                                    # * replace    Do UPDATE/INSERT as REPLACE.
40                                                    # * queue      Queue changes until process_changes is called with a greater
41                                                    #              queue level.
42                                                    sub new {
43             2                    2            52      my ( $class, %args ) = @_;
44             2                                 11      foreach my $arg ( qw(quoter database table sdatabase stable replace queue)
45                                                       ) {
46             8    100                          33         die "I need a $arg argument" unless defined $args{$arg};
47                                                       }
48             1                                  7      my $self = { %args, map { $_ => [] } @ACTIONS };
               4                                 28   
49             1                                  9      $self->{db_tbl}  = $self->{quoter}->quote(@args{qw(database table)});
50             1                                  7      $self->{sdb_tbl} = $self->{quoter}->quote(@args{qw(sdatabase stable)});
51             1                                  4      $self->{changes} = { map { $_ => 0 } @ACTIONS };
               4                                 21   
52             1                                 13      return bless $self, $class;
53                                                    }
54                                                    
55                                                    # If I'm supposed to fetch-back, that means I have to get the full row from the
56                                                    # database.  For example, someone might call me like so:
57                                                    # $me->change('UPDATE', { a => 1 })
58                                                    # but 'a' is only the primary key. I now need to select that row and make an
59                                                    # UPDATE statement with all of its columns.  The argument is the DB handle used
60                                                    # to fetch.
61                                                    sub fetch_back {
62             1                    1             5      my ( $self, $dbh ) = @_;
63             1                                 11      $self->{fetch_back} = $dbh;
64             1                                  4      MKDEBUG && _d('Will fetch rows from source when updating destination');
65                                                    }
66                                                    
67                                                    sub take_action {
68             6                    6            27      my ( $self, @sql ) = @_;
69             6                                 14      MKDEBUG && _d('Calling subroutines on', @sql);
70             6                                 15      foreach my $action ( @{$self->{actions}} ) {
               6                                 26   
71             6                                 28         $action->(@sql);
72                                                       }
73                                                    }
74                                                    
75                                                    # Arguments: string, hashref, arrayref
76                                                    sub change {
77             6                    6            83      my ( $self, $action, $row, $cols ) = @_;
78             6                                 17      MKDEBUG && _d($action, 'where', $self->make_where_clause($row, $cols));
79                                                       $self->{changes}->{
80    ***      6     50     33                   49         $self->{replace} && $action ne 'DELETE' ? 'REPLACE' : $action
81                                                       }++;
82             6    100                          27      if ( $self->{queue} ) {
83             2                                  8         $self->__queue($action, $row, $cols);
84                                                       }
85                                                       else {
86             4                                 15         eval {
87             4                                 14            my $func = "make_$action";
88             4                                 30            $self->take_action($self->$func($row, $cols));
89                                                          };
90    ***      4     50                          67         if ( $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
      ***            50                               
91    ***      0                                  0            MKDEBUG && _d('Duplicate key violation; will queue and rewrite');
92    ***      0                                  0            $self->{queue}++;
93    ***      0                                  0            $self->{replace} = 1;
94    ***      0                                  0            $self->__queue($action, $row, $cols);
95                                                          }
96                                                          elsif ( $EVAL_ERROR ) {
97    ***      0                                  0            die $EVAL_ERROR;
98                                                          }
99                                                       }
100                                                   }
101                                                   
102                                                   sub __queue {
103            2                    2             9      my ( $self, $action, $row, $cols ) = @_;
104            2                                  9      MKDEBUG && _d('Queueing change for later');
105   ***      2     50                           8      if ( $self->{replace} ) {
106   ***      0      0                           0         $action = $action eq 'DELETE' ? $action : 'REPLACE';
107                                                      }
108            2                                  6      push @{$self->{$action}}, [ $row, $cols ];
               2                                 12   
109                                                   }
110                                                   
111                                                   # If called with 1, will process rows that have been deferred from instant
112                                                   # processing.  If no arg, will process all rows.
113                                                   sub process_rows {
114            3                    3            30      my ( $self, $queue_level ) = @_;
115            3                                  7      my $error_count = 0;
116                                                      TRY: {
117            3    100    100                    8         if ( $queue_level && $queue_level < $self->{queue} ) { # see redo below!
               3                                 24   
118            1                                  2            MKDEBUG && _d('Not processing now', $queue_level, '<', $self->{queue});
119            1                                  4            return;
120                                                         }
121                                                   
122            2                                  6         my ($row, $cur_act);
123            2                                  5         eval {
124            2                                  8            foreach my $action ( @ACTIONS ) {
125            8                                 33               my $func = "make_$action";
126            8                                 27               my $rows = $self->{$action};
127            8                                 16               MKDEBUG && _d(scalar(@$rows), 'to', $action);
128            8                                 21               $cur_act = $action;
129            8                                 34               while ( @$rows ) {
130            2                                  6                  $row = shift @$rows;
131            2                                 11                  $self->take_action($self->$func(@$row));
132                                                               }
133                                                            }
134            2                                 15            $error_count = 0;
135                                                         };
136   ***      2     50     33                   28         if ( !$error_count++ && $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
      ***            50                               
137   ***      0                                  0            MKDEBUG
138                                                               && _d('Duplicate key violation; re-queueing and rewriting');
139   ***      0                                  0            $self->{queue}++; # Defer rows to the very end
140   ***      0                                  0            $self->{replace} = 1;
141   ***      0                                  0            $self->__queue($cur_act, @$row);
142   ***      0                                  0            redo TRY;
143                                                         }
144                                                         elsif ( $EVAL_ERROR ) {
145   ***      0                                  0            die $EVAL_ERROR;
146                                                         }
147                                                      }
148                                                   }
149                                                   
150                                                   # DELETE never needs to be fetched back.
151                                                   sub make_DELETE {
152            2                    2             8      my ( $self, $row, $cols ) = @_;
153            2                                 14      return "DELETE FROM $self->{db_tbl} WHERE "
154                                                         . $self->make_where_clause($row, $cols)
155                                                         . ' LIMIT 1';
156                                                   }
157                                                   
158                                                   sub make_UPDATE {
159            2                    2            10      my ( $self, $row, $cols ) = @_;
160   ***      2     50                          10      if ( $self->{replace} ) {
161   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
162                                                      }
163            2                                  8      my %in_where = map { $_ => 1 } @$cols;
               2                                 18   
164            2                                 17      my $where = $self->make_where_clause($row, $cols);
165            2    100                          13      if ( my $dbh = $self->{fetch_back} ) {
166            1                                 11         my $sql = "SELECT * FROM $self->{sdb_tbl} WHERE $where LIMIT 1";
167            1                                  3         MKDEBUG && _d('Fetching data for UPDATE:', $sql);
168            1                                  3         my $res = $dbh->selectrow_hashref($sql);
169            1                                  9         @{$row}{keys %$res} = values %$res;
               1                                  6   
170            1                                 14         $cols = [sort keys %$res];
171                                                      }
172                                                      else {
173            1                                  8         $cols = [ sort keys %$row ];
174                                                      }
175            2                                 11      return "UPDATE $self->{db_tbl} SET "
176                                                         . join(', ', map {
177            4                                 21               $self->{quoter}->quote($_)
178                                                               . '=' .  $self->{quoter}->quote_val($row->{$_})
179            2                                 15            } grep { !$in_where{$_} } @$cols)
180                                                         . " WHERE $where LIMIT 1";
181                                                   }
182                                                   
183                                                   sub make_INSERT {
184            2                    2            10      my ( $self, $row, $cols ) = @_;
185   ***      2     50                           9      if ( $self->{replace} ) {
186   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
187                                                      }
188            2                                 12      return $self->make_row('INSERT', $row, $cols);
189                                                   }
190                                                   
191                                                   sub make_REPLACE {
192   ***      0                    0             0      my ( $self, $row, $cols ) = @_;
193   ***      0                                  0      return $self->make_row('REPLACE', $row, $cols);
194                                                   }
195                                                   
196                                                   sub make_row {
197            2                    2            12      my ( $self, $verb, $row, $cols ) = @_;
198            2                                 17      my @cols = sort keys %$row;
199            2    100                          11      if ( my $dbh = $self->{fetch_back} ) {
200            1                                  6         my $where = $self->make_where_clause($row, $cols);
201            1                                  6         my $sql = "SELECT * FROM $self->{sdb_tbl} WHERE $where LIMIT 1";
202            1                                  2         MKDEBUG && _d('Fetching data for UPDATE:', $sql);
203            1                                  2         my $res = $dbh->selectrow_hashref($sql);
204            1                                  8         @{$row}{keys %$res} = values %$res;
               1                                  5   
205            1                                  9         @cols = sort keys %$res;
206                                                      }
207            4                                 18      return "$verb INTO $self->{db_tbl}("
208            2                                 11         . join(', ', map { $self->{quoter}->quote($_) } @cols)
209                                                         . ') VALUES ('
210            2                                 15         . $self->{quoter}->quote_val( @{$row}{@cols} )
211                                                         . ')';
212                                                   }
213                                                   
214                                                   sub make_where_clause {
215            5                    5            22      my ( $self, $row, $cols ) = @_;
216            5                                 18      my @clauses = map {
217            5                                 18         my $val = $row->{$_};
218   ***      5     50                          19         my $sep = defined $val ? '=' : ' IS ';
219            5                                 33         $self->{quoter}->quote($_) . $sep . $self->{quoter}->quote_val($val);
220                                                      } @$cols;
221            5                                 30      return join(' AND ', @clauses);
222                                                   }
223                                                   
224                                                   sub get_changes {
225            1                    1            13      my ( $self ) = @_;
226            1                                  4      return %{$self->{changes}};
               1                                 11   
227                                                   }
228                                                   
229                                                   sub _d {
230   ***      0                    0                    my ($package, undef, $line) = caller 0;
231   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
232   ***      0                                              map { defined $_ ? $_ : 'undef' }
233                                                           @_;
234   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
235                                                   }
236                                                   
237                                                   1;
238                                                   
239                                                   # ###########################################################################
240                                                   # End ChangeHandler package
241                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
46           100      1      7   unless defined $args{$arg}
80    ***     50      0      6   $$self{'replace'} && $action ne 'DELETE' ? :
82           100      2      4   if ($$self{'queue'}) { }
90    ***     50      0      4   if ($EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      4   elsif ($EVAL_ERROR) { }
105   ***     50      0      2   if ($$self{'replace'})
106   ***      0      0      0   $action eq 'DELETE' ? :
117          100      1      2   if ($queue_level and $queue_level < $$self{'queue'})
136   ***     50      0      2   if (not $error_count++ and $EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      2   elsif ($EVAL_ERROR) { }
160   ***     50      0      2   if ($$self{'replace'})
165          100      1      1   if (my $dbh = $$self{'fetch_back'}) { }
185   ***     50      0      2   if ($$self{'replace'})
199          100      1      1   if (my $dbh = $$self{'fetch_back'})
218   ***     50      5      0   defined $val ? :
231   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
80    ***     33      6      0      0   $$self{'replace'} && $action ne 'DELETE'
117          100      1      1      1   $queue_level and $queue_level < $$self{'queue'}
136   ***     33      0      2      0   not $error_count++ and $EVAL_ERROR =~ /$DUPE_KEY/


Covered Subroutines
-------------------

Subroutine        Count Location                                            
----------------- ----- ----------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:20 
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:21 
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:25 
BEGIN                 1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:30 
__queue               2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:103
change                6 /home/daniel/dev/maatkit/common/ChangeHandler.pm:77 
fetch_back            1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:62 
get_changes           1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:225
make_DELETE           2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:152
make_INSERT           2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:184
make_UPDATE           2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:159
make_row              2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:197
make_where_clause     5 /home/daniel/dev/maatkit/common/ChangeHandler.pm:215
new                   2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:43 
process_rows          3 /home/daniel/dev/maatkit/common/ChangeHandler.pm:114
take_action           6 /home/daniel/dev/maatkit/common/ChangeHandler.pm:68 

Uncovered Subroutines
---------------------

Subroutine        Count Location                                            
----------------- ----- ----------------------------------------------------
_d                    0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:230
make_REPLACE          0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:192


