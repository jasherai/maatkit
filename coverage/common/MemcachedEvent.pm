---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/MemcachedEvent.pm   77.4   70.0  100.0   76.9    n/a  100.0   76.5
Total                          77.4   70.0  100.0   76.9    n/a  100.0   76.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MemcachedEvent.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sun Jul 12 16:40:32 2009
Finish:       Sun Jul 12 16:40:32 2009

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
18                                                    # MemcachedEvent package $Revision: 4150 $
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
               1                                  6   
31             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
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
39             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  9   
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
70             1                                 13      return bless $self, $class;
71                                                    }
72                                                    
73                                                    # Given an event from MemcachedProtocolParser, returns an event
74                                                    # more suitable for mk-query-digest.
75                                                    sub make_event {
76            17                   17           737      my ( $self, $event ) = @_;
77    ***     17     50                          78      return unless $event;
78                                                    
79            17    100    100                  153      if ( !$event->{cmd} || !$event->{key} ) {
80             3                                  8         MKDEBUG && _d('Event has no cmd or key:', Dumper($event));
81             3                                 12         return;
82                                                       }
83                                                    
84            14    100                          65      if ( !$cmds{$event->{cmd}} ) {
85             1                                  2         MKDEBUG && _d("Don't know how to handle cmd:", $event->{cmd});
86             1                                  4         return;
87                                                       }
88                                                    
89                                                       # For a normal event, arg is the query.  For memcached, the "query" is
90                                                       # essentially the cmd and key, so this becomes arg.  E.g.: "set mk_key".
91            13                                 74      $event->{arg}         = "$event->{cmd} $event->{key}";
92            13                                 59      $event->{fingerprint} = $self->fingerprint($event->{arg});
93            13                                 54      $event->{key_print}   = $self->fingerprint($event->{key});
94                                                    
95                                                       # Set every cmd so that aggregated totals will be correct.  If we only
96                                                       # set cmd that we get, then all cmds will show as 100% in the report.
97                                                       # This will create a lot of 0% cmds, but --[no]zero-bool will remove them.
98                                                       # Think of events in a Percona-patched log: the attribs like Full_scan are
99                                                       # present for every event.
100           13                                 65      map { $event->{"Memc_$_"} = 'No' } keys %cmds;
             143                                592   
101           13                                 67      $event->{"Memc_$event->{cmd}"} = 'Yes';  # Got this cmd.
102           13    100                          66      $event->{Memc_miss}            = $event->{res} eq 'NOT_FOUND' ? 'Yes' : 'No';
103           13                                 44      $event->{Memc_error}           = 'No';  # A handler may change this.
104                                                   
105                                                      # Handle special results, errors, etc.  The handler should return the
106                                                      # event on success, or nothing on failure.
107           13    100                          58      if ( $cmd_handler_for{$event->{cmd}} ) {
108            7                                 32         return $cmd_handler_for{$event->{cmd}}->($event);
109                                                      }
110                                                   
111            6                                 27      return $event;
112                                                   }
113                                                   
114                                                   # Replace things that look like placeholders with a ?
115                                                   sub fingerprint {
116           26                   26            95      my ( $self, $val ) = @_;
117           26                                162      $val =~ s/[0-9A-Fa-f]{16,}|\d+/?/g;
118           26                                105      return $val;
119                                                   }
120                                                   
121                                                   # Possible results for storage cmds:
122                                                   # - "STORED\r\n", to indicate success.
123                                                   #
124                                                   # - "NOT_STORED\r\n" to indicate the data was not stored, but not
125                                                   #   because of an error. This normally means that either that the
126                                                   #   condition for an "add" or a "replace" command wasn't met, or that the
127                                                   #   item is in a delete queue (see the "delete" command below).
128                                                   #
129                                                   # - "EXISTS\r\n" to indicate that the item you are trying to store with
130                                                   #   a "cas" command has been modified since you last fetched it.
131                                                   #
132                                                   # - "NOT_FOUND\r\n" to indicate that the item you are trying to store
133                                                   #   with a "cas" command did not exist or has been deleted.
134                                                   sub handle_storage_cmd {
135            2                    2             8      my ( $event ) = @_;
136                                                      
137                                                      # There should be a result for any storage cmd.   
138   ***      2     50                           8      if ( !$event->{res} ) {
139   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
140   ***      0                                  0         return;
141                                                      }
142                                                   
143                                                      # Technically NOT_STORED is not an error, but we treat it as one.
144   ***      2     50                          10      $event->{'Memc_error'} = $event->{res} eq 'STORED' ? 'No'  : 'Yes';
145                                                   
146            2                                 10      return $event;
147                                                   }
148                                                   
149                                                   # Technically, the only results for a retrieval cmd are the values requested.
150                                                   #  "If some of the keys appearing in a retrieval request are not sent back
151                                                   #   by the server in the item list this means that the server does not
152                                                   #   hold items with such keys (because they were never stored, or stored
153                                                   #   but deleted to make space for more items, or expired, or explicitly
154                                                   #   deleted by a client)."
155                                                   # Contrary to this, MemcacedProtocolParser will set res='VALUE' on
156                                                   # success, res='NOT_FOUND' on failure, or res='INTERRUPTED' if the get
157                                                   # didn't finish.
158                                                   sub handle_retr_cmd {
159            5                    5            18      my ( $event ) = @_;
160                                                   
161                                                      # There should be a result for any retr cmd.   
162   ***      5     50                          21      if ( !$event->{res} ) {
163   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
164   ***      0                                  0         return;
165                                                      }
166                                                   
167            5    100                          25      $event->{'Memc_error'} = $event->{res} eq 'INTERRUPTED' ? 'Yes' : 'No';
168                                                   
169            5                                 26      return $event;
170                                                   }
171                                                   
172                                                   # handle_delete() and handle_incr_decr_cmd() are stub subs in case we
173                                                   # need them later.
174                                                   
175                                                   # Possible results for a delete cmd:
176                                                   # - "DELETED\r\n" to indicate success
177                                                   #
178                                                   # - "NOT_FOUND\r\n" to indicate that the item with this key was not
179                                                   #   found.
180                                                   sub handle_delete {
181   ***      0                    0                    my ( $event ) = @_;
182   ***      0                                         return $event;
183                                                   }
184                                                   
185                                                   # Possible results for an incr or decr cmd:
186                                                   # - "NOT_FOUND\r\n" to indicate the item with this value was not found
187                                                   #
188                                                   # - <value>\r\n , where <value> is the new value of the item's data,
189                                                   #   after the increment/decrement operation was carried out.
190                                                   # On success, MemcachedProtocolParser sets res='' and val=the new val.
191                                                   # On failure, res=the result and val=''.
192                                                   sub handle_incr_decr_cmd {
193   ***      0                    0                    my ( $event ) = @_;
194   ***      0                                         return $event;
195                                                   }
196                                                   
197                                                   sub _d {
198   ***      0                    0                    my ($package, undef, $line) = caller 0;
199   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
200   ***      0                                              map { defined $_ ? $_ : 'undef' }
201                                                           @_;
202   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
203                                                   }
204                                                   
205                                                   1;
206                                                   
207                                                   # ###########################################################################
208                                                   # End MemcachedEvent package
209                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
77    ***     50      0     17   unless $event
79           100      3     14   if (not $$event{'cmd'} or not $$event{'key'})
84           100      1     13   if (not $cmds{$$event{'cmd'}})
102          100      4      9   $$event{'res'} eq 'NOT_FOUND' ? :
107          100      7      6   if ($cmd_handler_for{$$event{'cmd'}})
138   ***     50      0      2   if (not $$event{'res'})
144   ***     50      2      0   $$event{'res'} eq 'STORED' ? :
162   ***     50      0      5   if (not $$event{'res'})
167          100      1      4   $$event{'res'} eq 'INTERRUPTED' ? :
199   ***      0      0      0   defined $_ ? :


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
fingerprint             26 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:116
handle_retr_cmd          5 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:159
handle_storage_cmd       2 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:135
make_event              17 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:76 
new                      1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:68 

Uncovered Subroutines
---------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:198
handle_delete            0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:181
handle_incr_decr_cmd     0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:193


