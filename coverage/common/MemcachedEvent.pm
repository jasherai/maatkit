---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/MemcachedEvent.pm   78.8   70.8  100.0   76.9    n/a  100.0   77.4
Total                          78.8   70.8  100.0   76.9    n/a  100.0   77.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MemcachedEvent.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:00 2009
Finish:       Sat Aug 29 15:03:00 2009

/home/daniel/dev/maatkit/common/MemcachedEvent.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
18                                                    # MemcachedEvent package $Revision: 4155 $
19                                                    # ###########################################################################
20                                                    package MemcachedEvent;
21                                                    
22                                                    # This package creates events suitable for mk-query-digest
23                                                    # from psuedo-events created by MemcachedProtocolParser.
24                                                    # Since memcached is not strictly MySQL stuff, we have to
25                                                    # fabricate MySQL-like query events from memcached.
26                                                    # 
27                                                    # See http://code.sixapart.com/svn/memcached/trunk/server/doc/protocol.txt
28                                                    # for information about the memcached protocol.
29                                                    
30             1                    1             8   use strict;
               1                                  2   
               1                                  7   
31             1                    1             6   use warnings FATAL => 'all';
               1                                  5   
               1                                  9   
32             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
33                                                    
34             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
35                                                    $Data::Dumper::Indent    = 1;
36                                                    $Data::Dumper::Sortkeys  = 1;
37                                                    $Data::Dumper::Quotekeys = 0;
38                                                    
39             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
40                                                    
41                                                    # cmds that we know how to handle.
42                                                    my %cmds = map { $_ => 1 } qw(
43                                                       set
44                                                       add
45                                                       replace
46                                                       append
47                                                       prepend
48                                                       cas
49                                                       get
50                                                       gets
51                                                       delete
52                                                       incr
53                                                       decr
54                                                    );
55                                                    
56                                                    my %cmd_handler_for = (
57                                                       set      => \&handle_storage_cmd,
58                                                       add      => \&handle_storage_cmd,
59                                                       replace  => \&handle_storage_cmd,
60                                                       append   => \&handle_storage_cmd,
61                                                       prepend  => \&handle_storage_cmd,
62                                                       cas      => \&handle_storage_cmd,
63                                                       get      => \&handle_retr_cmd,
64                                                       gets     => \&handle_retr_cmd,
65                                                    );
66                                                    
67                                                    sub new {
68             1                    1            17      my ( $class, %args ) = @_;
69             1                                  3      my $self = {};
70             1                                 14      return bless $self, $class;
71                                                    }
72                                                    
73                                                    # Given an event from MemcachedProtocolParser, returns an event
74                                                    # more suitable for mk-query-digest.
75                                                    sub make_event {
76            17                   17           830      my ( $self, $event ) = @_;
77    ***     17     50                          67      return unless $event;
78                                                    
79            17    100    100                  168      if ( !$event->{cmd} || !$event->{key} ) {
80             3                                  7         MKDEBUG && _d('Event has no cmd or key:', Dumper($event));
81             3                                 12         return;
82                                                       }
83                                                    
84            14    100                          69      if ( !$cmds{$event->{cmd}} ) {
85             1                                  2         MKDEBUG && _d("Don't know how to handle cmd:", $event->{cmd});
86             1                                  4         return;
87                                                       }
88                                                    
89                                                       # For a normal event, arg is the query.  For memcached, the "query" is
90                                                       # essentially the cmd and key, so this becomes arg.  E.g.: "set mk_key".
91            13                                 83      $event->{arg}         = "$event->{cmd} $event->{key}";
92            13                                 61      $event->{fingerprint} = $self->fingerprint($event->{arg});
93            13                                 56      $event->{key_print}   = $self->fingerprint($event->{key});
94                                                    
95                                                       # Set every cmd so that aggregated totals will be correct.  If we only
96                                                       # set cmd that we get, then all cmds will show as 100% in the report.
97                                                       # This will create a lot of 0% cmds, but --[no]zero-bool will remove them.
98                                                       # Think of events in a Percona-patched log: the attribs like Full_scan are
99                                                       # present for every event.
100           13                                 78      map { $event->{"Memc_$_"} = 'No' } keys %cmds;
             143                                634   
101           13                                 69      $event->{"Memc_$event->{cmd}"} = 'Yes';  # Got this cmd.
102           13                                 45      $event->{Memc_error}           = 'No';  # A handler may change this.
103           13                                 42      $event->{Memc_miss}            = 'No';
104           13    100                          52      if ( $event->{res} ) {
105           11    100                          59         $event->{Memc_miss}         = 'Yes' if $event->{res} eq 'NOT_FOUND';
106                                                      }
107                                                      else {
108                                                         # This normally happens with incr and decr cmds.
109            2                                  4         MKDEBUG && _d('Event has no res:', Dumper($event));
110                                                      }
111                                                   
112                                                      # Handle special results, errors, etc.  The handler should return the
113                                                      # event on success, or nothing on failure.
114           13    100                          67      if ( $cmd_handler_for{$event->{cmd}} ) {
115            7                                 35         return $cmd_handler_for{$event->{cmd}}->($event);
116                                                      }
117                                                   
118            6                                 28      return $event;
119                                                   }
120                                                   
121                                                   # Replace things that look like placeholders with a ?
122                                                   sub fingerprint {
123           26                   26           100      my ( $self, $val ) = @_;
124           26                                176      $val =~ s/[0-9A-Fa-f]{16,}|\d+/?/g;
125           26                               1637      return $val;
126                                                   }
127                                                   
128                                                   # Possible results for storage cmds:
129                                                   # - "STORED\r\n", to indicate success.
130                                                   #
131                                                   # - "NOT_STORED\r\n" to indicate the data was not stored, but not
132                                                   #   because of an error. This normally means that either that the
133                                                   #   condition for an "add" or a "replace" command wasn't met, or that the
134                                                   #   item is in a delete queue (see the "delete" command below).
135                                                   #
136                                                   # - "EXISTS\r\n" to indicate that the item you are trying to store with
137                                                   #   a "cas" command has been modified since you last fetched it.
138                                                   #
139                                                   # - "NOT_FOUND\r\n" to indicate that the item you are trying to store
140                                                   #   with a "cas" command did not exist or has been deleted.
141                                                   sub handle_storage_cmd {
142            2                    2             8      my ( $event ) = @_;
143                                                   
144                                                      # There should be a result for any storage cmd.   
145   ***      2     50                           8      if ( !$event->{res} ) {
146   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
147   ***      0                                  0         return;
148                                                      }
149                                                   
150   ***      2     50                          13      $event->{'Memc_Not_Stored'} = $event->{res} eq 'NOT_STORED' ? 'Yes' : 'No';
151   ***      2     50                          11      $event->{'Memc_Exists'}     = $event->{res} eq 'EXISTS'     ? 'Yes' : 'No';
152                                                   
153            2                                 11      return $event;
154                                                   }
155                                                   
156                                                   # Technically, the only results for a retrieval cmd are the values requested.
157                                                   #  "If some of the keys appearing in a retrieval request are not sent back
158                                                   #   by the server in the item list this means that the server does not
159                                                   #   hold items with such keys (because they were never stored, or stored
160                                                   #   but deleted to make space for more items, or expired, or explicitly
161                                                   #   deleted by a client)."
162                                                   # Contrary to this, MemcacedProtocolParser will set res='VALUE' on
163                                                   # success, res='NOT_FOUND' on failure, or res='INTERRUPTED' if the get
164                                                   # didn't finish.
165                                                   sub handle_retr_cmd {
166            5                    5            19      my ( $event ) = @_;
167                                                   
168                                                      # There should be a result for any retr cmd.   
169   ***      5     50                          24      if ( !$event->{res} ) {
170   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
171   ***      0                                  0         return;
172                                                      }
173                                                   
174            5    100                          27      $event->{'Memc_error'} = $event->{res} eq 'INTERRUPTED' ? 'Yes' : 'No';
175                                                   
176            5                                 28      return $event;
177                                                   }
178                                                   
179                                                   # handle_delete() and handle_incr_decr_cmd() are stub subs in case we
180                                                   # need them later.
181                                                   
182                                                   # Possible results for a delete cmd:
183                                                   # - "DELETED\r\n" to indicate success
184                                                   #
185                                                   # - "NOT_FOUND\r\n" to indicate that the item with this key was not
186                                                   #   found.
187                                                   sub handle_delete {
188   ***      0                    0                    my ( $event ) = @_;
189   ***      0                                         return $event;
190                                                   }
191                                                   
192                                                   # Possible results for an incr or decr cmd:
193                                                   # - "NOT_FOUND\r\n" to indicate the item with this value was not found
194                                                   #
195                                                   # - <value>\r\n , where <value> is the new value of the item's data,
196                                                   #   after the increment/decrement operation was carried out.
197                                                   # On success, MemcachedProtocolParser sets res='' and val=the new val.
198                                                   # On failure, res=the result and val=''.
199                                                   sub handle_incr_decr_cmd {
200   ***      0                    0                    my ( $event ) = @_;
201   ***      0                                         return $event;
202                                                   }
203                                                   
204                                                   sub _d {
205   ***      0                    0                    my ($package, undef, $line) = caller 0;
206   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
207   ***      0                                              map { defined $_ ? $_ : 'undef' }
208                                                           @_;
209   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
210                                                   }
211                                                   
212                                                   1;
213                                                   
214                                                   # ###########################################################################
215                                                   # End MemcachedEvent package
216                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
77    ***     50      0     17   unless $event
79           100      3     14   if (not $$event{'cmd'} or not $$event{'key'})
84           100      1     13   if (not $cmds{$$event{'cmd'}})
104          100     11      2   if ($$event{'res'}) { }
105          100      4      7   if $$event{'res'} eq 'NOT_FOUND'
114          100      7      6   if ($cmd_handler_for{$$event{'cmd'}})
145   ***     50      0      2   if (not $$event{'res'})
150   ***     50      0      2   $$event{'res'} eq 'NOT_STORED' ? :
151   ***     50      0      2   $$event{'res'} eq 'EXISTS' ? :
169   ***     50      0      5   if (not $$event{'res'})
174          100      1      4   $$event{'res'} eq 'INTERRUPTED' ? :
206   ***      0      0      0   defined $_ ? :


Conditions
----------

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
79           100      2      1     14   not $$event{'cmd'} or not $$event{'key'}


Covered Subroutines
-------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:30 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:31 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:32 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:34 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:39 
fingerprint             26 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:123
handle_retr_cmd          5 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:166
handle_storage_cmd       2 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:142
make_event              17 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:76 
new                      1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:68 

Uncovered Subroutines
---------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:205
handle_delete            0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:188
handle_incr_decr_cmd     0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:200


