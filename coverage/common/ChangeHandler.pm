---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/ChangeHandler.pm   70.1   53.1   55.6   83.3    n/a  100.0   67.7
Total                          70.1   53.1   55.6   83.3    n/a  100.0   67.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          ChangeHandler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:27 2009
Finish:       Wed Jun 10 17:19:27 2009

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
20             1                    1             8   use strict;
               1                                  2   
               1                                  9   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
22                                                    
23                                                    package ChangeHandler;
24                                                    
25             1                    1             7   use English qw(-no_match_vars);
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
43             2                    2            47      my ( $class, %args ) = @_;
44             2                                  9      foreach my $arg ( qw(quoter database table sdatabase stable replace queue)
45                                                       ) {
46             8    100                          32         die "I need a $arg argument" unless defined $args{$arg};
47                                                       }
48             1                                  7      my $self = { %args, map { $_ => [] } @ACTIONS };
               4                                 19   
49             1                                  7      $self->{db_tbl}  = $self->{quoter}->quote(@args{qw(database table)});
50             1                                  6      $self->{sdb_tbl} = $self->{quoter}->quote(@args{qw(sdatabase stable)});
51             1                                  4      $self->{changes} = { map { $_ => 0 } @ACTIONS };
               4                                 16   
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
62    ***      0                    0             0      my ( $self, $dbh ) = @_;
63    ***      0                                  0      $self->{fetch_back} = $dbh;
64    ***      0                                  0      MKDEBUG && _d('Will fetch rows from source when updating destination');
65                                                    }
66                                                    
67                                                    sub take_action {
68             3                    3            14      my ( $self, @sql ) = @_;
69             3                                  6      MKDEBUG && _d('Calling subroutines on', @sql);
70             3                                  7      foreach my $action ( @{$self->{actions}} ) {
               3                                 17   
71             3                                 12         $action->(@sql);
72                                                       }
73                                                    }
74                                                    
75                                                    # Arguments: string, hashref, arrayref
76                                                    sub change {
77             3                    3            64      my ( $self, $action, $row, $cols ) = @_;
78             3                                  8      MKDEBUG && _d($action, 'where', $self->make_where_clause($row, $cols));
79                                                       $self->{changes}->{
80    ***      3     50     33                   21         $self->{replace} && $action ne 'DELETE' ? 'REPLACE' : $action
81                                                       }++;
82             3    100                          18      if ( $self->{queue} ) {
83             2                                  9         $self->__queue($action, $row, $cols);
84                                                       }
85                                                       else {
86             1                                  3         eval {
87             1                                  4            my $func = "make_$action";
88             1                                  6            $self->take_action($self->$func($row, $cols));
89                                                          };
90    ***      1     50                          16         if ( $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
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
103            2                    2            11      my ( $self, $action, $row, $cols ) = @_;
104            2                                  9      MKDEBUG && _d('Queueing change for later');
105   ***      2     50                           8      if ( $self->{replace} ) {
106   ***      0      0                           0         $action = $action eq 'DELETE' ? $action : 'REPLACE';
107                                                      }
108            2                                  6      push @{$self->{$action}}, [ $row, $cols ];
               2                                 13   
109                                                   }
110                                                   
111                                                   # If called with 1, will process rows that have been deferred from instant
112                                                   # processing.  If no arg, will process all rows.
113                                                   sub process_rows {
114            3                    3            36      my ( $self, $queue_level ) = @_;
115            3                                  7      my $error_count = 0;
116                                                      TRY: {
117            3    100    100                    9         if ( $queue_level && $queue_level < $self->{queue} ) { # see redo below!
               3                                 26   
118            1                                  2            MKDEBUG && _d('Not processing now', $queue_level, '<', $self->{queue});
119            1                                  5            return;
120                                                         }
121                                                   
122            2                                  7         my ($row, $cur_act);
123            2                                  5         eval {
124            2                                  8            foreach my $action ( @ACTIONS ) {
125            8                                 35               my $func = "make_$action";
126            8                                 31               my $rows = $self->{$action};
127            8                                 16               MKDEBUG && _d(scalar(@$rows), 'to', $action);
128            8                                 21               $cur_act = $action;
129            8                                 37               while ( @$rows ) {
130            2                                  6                  $row = shift @$rows;
131            2                                 13                  $self->take_action($self->$func(@$row));
132                                                               }
133                                                            }
134            2                                 17            $error_count = 0;
135                                                         };
136   ***      2     50     33                   32         if ( !$error_count++ && $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
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
152            1                    1             3      my ( $self, $row, $cols ) = @_;
153            1                                  7      return "DELETE FROM $self->{db_tbl} WHERE "
154                                                         . $self->make_where_clause($row, $cols)
155                                                         . ' LIMIT 1';
156                                                   }
157                                                   
158                                                   sub make_UPDATE {
159            1                    1             6      my ( $self, $row, $cols ) = @_;
160   ***      1     50                           5      if ( $self->{replace} ) {
161   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
162                                                      }
163            1                                  4      my %in_where = map { $_ => 1 } @$cols;
               1                                  6   
164            1                                  6      my $where = $self->make_where_clause($row, $cols);
165   ***      1     50                           6      if ( my $dbh = $self->{fetch_back} ) {
166   ***      0                                  0         my $sql = "SELECT * FROM $self->{sdb_tbl} WHERE $where LIMIT 1";
167   ***      0                                  0         MKDEBUG && _d('Fetching data for UPDATE:', $sql);
168   ***      0                                  0         my $res = $dbh->selectrow_hashref($sql);
169   ***      0                                  0         @{$row}{keys %$res} = values %$res;
      ***      0                                  0   
170   ***      0                                  0         $cols = [sort keys %$res];
171                                                      }
172                                                      else {
173            1                                 14         $cols = [ sort keys %$row ];
174                                                      }
175            1                                  5      return "UPDATE $self->{db_tbl} SET "
176                                                         . join(', ', map {
177            2                                 15               $self->{quoter}->quote($_)
178                                                               . '=' .  $self->{quoter}->quote_val($row->{$_})
179            1                                  7            } grep { !$in_where{$_} } @$cols)
180                                                         . " WHERE $where LIMIT 1";
181                                                   }
182                                                   
183                                                   sub make_INSERT {
184            1                    1             4      my ( $self, $row, $cols ) = @_;
185   ***      1     50                           9      if ( $self->{replace} ) {
186   ***      0                                  0         return $self->make_row('REPLACE', $row, $cols);
187                                                      }
188            1                                  4      return $self->make_row('INSERT', $row, $cols);
189                                                   }
190                                                   
191                                                   sub make_REPLACE {
192   ***      0                    0             0      my ( $self, $row, $cols ) = @_;
193   ***      0                                  0      return $self->make_row('REPLACE', $row, $cols);
194                                                   }
195                                                   
196                                                   sub make_row {
197            1                    1             5      my ( $self, $verb, $row, $cols ) = @_;
198            1                                 12      my @cols = sort keys %$row;
199   ***      1     50                           6      if ( my $dbh = $self->{fetch_back} ) {
200   ***      0                                  0         my $where = $self->make_where_clause($row, $cols);
201   ***      0                                  0         my $sql = "SELECT * FROM $self->{sdb_tbl} WHERE $where LIMIT 1";
202   ***      0                                  0         MKDEBUG && _d('Fetching data for UPDATE:', $sql);
203   ***      0                                  0         my $res = $dbh->selectrow_hashref($sql);
204   ***      0                                  0         @{$row}{keys %$res} = values %$res;
      ***      0                                  0   
205   ***      0                                  0         @cols = sort keys %$res;
206                                                      }
207            2                                  9      return "$verb INTO $self->{db_tbl}("
208            1                                  5         . join(', ', map { $self->{quoter}->quote($_) } @cols)
209                                                         . ') VALUES ('
210            1                                  5         . $self->{quoter}->quote_val( @{$row}{@cols} )
211                                                         . ')';
212                                                   }
213                                                   
214                                                   sub make_where_clause {
215            2                    2             8      my ( $self, $row, $cols ) = @_;
216            2                                  6      my @clauses = map {
217            2                                  9         my $val = $row->{$_};
218   ***      2     50                          10         my $sep = defined $val ? '=' : ' IS ';
219            2                                 16         $self->{quoter}->quote($_) . $sep . $self->{quoter}->quote_val($val);
220                                                      } @$cols;
221            2                                 13      return join(' AND ', @clauses);
222                                                   }
223                                                   
224                                                   sub get_changes {
225            1                    1            15      my ( $self ) = @_;
226            1                                  3      return %{$self->{changes}};
               1                                 13   
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
80    ***     50      0      3   $$self{'replace'} && $action ne 'DELETE' ? :
82           100      2      1   if ($$self{'queue'}) { }
90    ***     50      0      1   if ($EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      1   elsif ($EVAL_ERROR) { }
105   ***     50      0      2   if ($$self{'replace'})
106   ***      0      0      0   $action eq 'DELETE' ? :
117          100      1      2   if ($queue_level and $queue_level < $$self{'queue'})
136   ***     50      0      2   if (not $error_count++ and $EVAL_ERROR =~ /$DUPE_KEY/) { }
      ***     50      0      2   elsif ($EVAL_ERROR) { }
160   ***     50      0      1   if ($$self{'replace'})
165   ***     50      0      1   if (my $dbh = $$self{'fetch_back'}) { }
185   ***     50      0      1   if ($$self{'replace'})
199   ***     50      0      1   if (my $dbh = $$self{'fetch_back'})
218   ***     50      2      0   defined $val ? :
231   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
80    ***     33      3      0      0   $$self{'replace'} && $action ne 'DELETE'
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
change                3 /home/daniel/dev/maatkit/common/ChangeHandler.pm:77 
get_changes           1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:225
make_DELETE           1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:152
make_INSERT           1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:184
make_UPDATE           1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:159
make_row              1 /home/daniel/dev/maatkit/common/ChangeHandler.pm:197
make_where_clause     2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:215
new                   2 /home/daniel/dev/maatkit/common/ChangeHandler.pm:43 
process_rows          3 /home/daniel/dev/maatkit/common/ChangeHandler.pm:114
take_action           3 /home/daniel/dev/maatkit/common/ChangeHandler.pm:68 

Uncovered Subroutines
---------------------

Subroutine        Count Location                                            
----------------- ----- ----------------------------------------------------
_d                    0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:230
fetch_back            0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:62 
make_REPLACE          0 /home/daniel/dev/maatkit/common/ChangeHandler.pm:192


