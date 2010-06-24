---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/MemcachedEvent.pm   79.1   70.8   80.0   76.9    0.0   61.4   72.4
MemcachedEvent.t              100.0   50.0   33.3  100.0    n/a   38.6   95.7
Total                          88.6   69.2   62.5   85.7    0.0  100.0   81.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:34:58 2010
Finish:       Thu Jun 24 19:34:58 2010

Run:          MemcachedEvent.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:00 2010
Finish:       Thu Jun 24 19:35:00 2010

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
18                                                    # MemcachedEvent package $Revision: 5266 $
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
30             1                    1             5   use strict;
               1                                  2   
               1                                  6   
31             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
32             1                    1            10   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
33                                                    
34             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
35                                                    $Data::Dumper::Indent    = 1;
36                                                    $Data::Dumper::Sortkeys  = 1;
37                                                    $Data::Dumper::Quotekeys = 0;
38                                                    
39    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
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
68    ***      1                    1      0      5      my ( $class, %args ) = @_;
69             1                                  4      my $self = {};
70             1                                 12      return bless $self, $class;
71                                                    }
72                                                    
73                                                    # Given an event from MemcachedProtocolParser, returns an event
74                                                    # more suitable for mk-query-digest.
75                                                    sub parse_event {
76    ***     17                   17      0     85      my ( $self, %args ) = @_;
77            17                                 58      my $event = $args{event};
78    ***     17     50                          64      return unless $event;
79                                                    
80            17    100    100                  163      if ( !$event->{cmd} || !$event->{key} ) {
81             3                                  6         MKDEBUG && _d('Event has no cmd or key:', Dumper($event));
82             3                                 14         return;
83                                                       }
84                                                    
85            14    100                          71      if ( !$cmds{$event->{cmd}} ) {
86             1                                  2         MKDEBUG && _d("Don't know how to handle cmd:", $event->{cmd});
87             1                                  5         return;
88                                                       }
89                                                    
90                                                       # For a normal event, arg is the query.  For memcached, the "query" is
91                                                       # essentially the cmd and key, so this becomes arg.  E.g.: "set mk_key".
92            13                                 77      $event->{arg}         = "$event->{cmd} $event->{key}";
93            13                                 60      $event->{fingerprint} = $self->fingerprint($event->{arg});
94            13                                 54      $event->{key_print}   = $self->fingerprint($event->{key});
95                                                    
96                                                       # Set every cmd so that aggregated totals will be correct.  If we only
97                                                       # set cmd that we get, then all cmds will show as 100% in the report.
98                                                       # This will create a lot of 0% cmds, but --[no]zero-bool will remove them.
99                                                       # Think of events in a Percona-patched log: the attribs like Full_scan are
100                                                      # present for every event.
101           13                                 72      map { $event->{"Memc_$_"} = 'No' } keys %cmds;
             143                                614   
102           13                                 70      $event->{"Memc_$event->{cmd}"} = 'Yes';  # Got this cmd.
103           13                                 44      $event->{Memc_error}           = 'No';  # A handler may change this.
104           13                                 44      $event->{Memc_miss}            = 'No';
105           13    100                          50      if ( $event->{res} ) {
106           11    100                          61         $event->{Memc_miss}         = 'Yes' if $event->{res} eq 'NOT_FOUND';
107                                                      }
108                                                      else {
109                                                         # This normally happens with incr and decr cmds.
110            2                                  5         MKDEBUG && _d('Event has no res:', Dumper($event));
111                                                      }
112                                                   
113                                                      # Handle special results, errors, etc.  The handler should return the
114                                                      # event on success, or nothing on failure.
115           13    100                          65      if ( $cmd_handler_for{$event->{cmd}} ) {
116            7                                 42         return $cmd_handler_for{$event->{cmd}}->($event);
117                                                      }
118                                                   
119            6                                 32      return $event;
120                                                   }
121                                                   
122                                                   # Replace things that look like placeholders with a ?
123                                                   sub fingerprint {
124   ***     26                   26      0     93      my ( $self, $val ) = @_;
125           26                                155      $val =~ s/[0-9A-Fa-f]{16,}|\d+/?/g;
126           26                                111      return $val;
127                                                   }
128                                                   
129                                                   # Possible results for storage cmds:
130                                                   # - "STORED\r\n", to indicate success.
131                                                   #
132                                                   # - "NOT_STORED\r\n" to indicate the data was not stored, but not
133                                                   #   because of an error. This normally means that either that the
134                                                   #   condition for an "add" or a "replace" command wasn't met, or that the
135                                                   #   item is in a delete queue (see the "delete" command below).
136                                                   #
137                                                   # - "EXISTS\r\n" to indicate that the item you are trying to store with
138                                                   #   a "cas" command has been modified since you last fetched it.
139                                                   #
140                                                   # - "NOT_FOUND\r\n" to indicate that the item you are trying to store
141                                                   #   with a "cas" command did not exist or has been deleted.
142                                                   sub handle_storage_cmd {
143   ***      2                    2      0      6      my ( $event ) = @_;
144                                                   
145                                                      # There should be a result for any storage cmd.   
146   ***      2     50                           8      if ( !$event->{res} ) {
147   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
148   ***      0                                  0         return;
149                                                      }
150                                                   
151   ***      2     50                          14      $event->{'Memc_Not_Stored'} = $event->{res} eq 'NOT_STORED' ? 'Yes' : 'No';
152   ***      2     50                           9      $event->{'Memc_Exists'}     = $event->{res} eq 'EXISTS'     ? 'Yes' : 'No';
153                                                   
154            2                                 12      return $event;
155                                                   }
156                                                   
157                                                   # Technically, the only results for a retrieval cmd are the values requested.
158                                                   #  "If some of the keys appearing in a retrieval request are not sent back
159                                                   #   by the server in the item list this means that the server does not
160                                                   #   hold items with such keys (because they were never stored, or stored
161                                                   #   but deleted to make space for more items, or expired, or explicitly
162                                                   #   deleted by a client)."
163                                                   # Contrary to this, MemcacedProtocolParser will set res='VALUE' on
164                                                   # success, res='NOT_FOUND' on failure, or res='INTERRUPTED' if the get
165                                                   # didn't finish.
166                                                   sub handle_retr_cmd {
167   ***      5                    5      0     21      my ( $event ) = @_;
168                                                   
169                                                      # There should be a result for any retr cmd.   
170   ***      5     50                          24      if ( !$event->{res} ) {
171   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
172   ***      0                                  0         return;
173                                                      }
174                                                   
175            5    100                          32      $event->{'Memc_error'} = $event->{res} eq 'INTERRUPTED' ? 'Yes' : 'No';
176                                                   
177            5                                 31      return $event;
178                                                   }
179                                                   
180                                                   # handle_delete() and handle_incr_decr_cmd() are stub subs in case we
181                                                   # need them later.
182                                                   
183                                                   # Possible results for a delete cmd:
184                                                   # - "DELETED\r\n" to indicate success
185                                                   #
186                                                   # - "NOT_FOUND\r\n" to indicate that the item with this key was not
187                                                   #   found.
188                                                   sub handle_delete {
189   ***      0                    0      0             my ( $event ) = @_;
190   ***      0                                         return $event;
191                                                   }
192                                                   
193                                                   # Possible results for an incr or decr cmd:
194                                                   # - "NOT_FOUND\r\n" to indicate the item with this value was not found
195                                                   #
196                                                   # - <value>\r\n , where <value> is the new value of the item's data,
197                                                   #   after the increment/decrement operation was carried out.
198                                                   # On success, MemcachedProtocolParser sets res='' and val=the new val.
199                                                   # On failure, res=the result and val=''.
200                                                   sub handle_incr_decr_cmd {
201   ***      0                    0      0             my ( $event ) = @_;
202   ***      0                                         return $event;
203                                                   }
204                                                   
205                                                   sub _d {
206   ***      0                    0                    my ($package, undef, $line) = caller 0;
207   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
208   ***      0                                              map { defined $_ ? $_ : 'undef' }
209                                                           @_;
210   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
211                                                   }
212                                                   
213                                                   1;
214                                                   
215                                                   # ###########################################################################
216                                                   # End MemcachedEvent package
217                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
78    ***     50      0     17   unless $event
80           100      3     14   if (not $$event{'cmd'} or not $$event{'key'})
85           100      1     13   if (not $cmds{$$event{'cmd'}})
105          100     11      2   if ($$event{'res'}) { }
106          100      4      7   if $$event{'res'} eq 'NOT_FOUND'
115          100      7      6   if ($cmd_handler_for{$$event{'cmd'}})
146   ***     50      0      2   if (not $$event{'res'})
151   ***     50      0      2   $$event{'res'} eq 'NOT_STORED' ? :
152   ***     50      0      2   $$event{'res'} eq 'EXISTS' ? :
170   ***     50      0      5   if (not $$event{'res'})
175          100      1      4   $$event{'res'} eq 'INTERRUPTED' ? :
207   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
39    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
80           100      2      1     14   not $$event{'cmd'} or not $$event{'key'}


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                             
-------------------- ----- --- -----------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/MemcachedEvent.pm:30 
BEGIN                    1     /home/daniel/dev/maatkit/common/MemcachedEvent.pm:31 
BEGIN                    1     /home/daniel/dev/maatkit/common/MemcachedEvent.pm:32 
BEGIN                    1     /home/daniel/dev/maatkit/common/MemcachedEvent.pm:34 
BEGIN                    1     /home/daniel/dev/maatkit/common/MemcachedEvent.pm:39 
fingerprint             26   0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:124
handle_retr_cmd          5   0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:167
handle_storage_cmd       2   0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:143
new                      1   0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:68 
parse_event             17   0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:76 

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                             
-------------------- ----- --- -----------------------------------------------------
_d                       0     /home/daniel/dev/maatkit/common/MemcachedEvent.pm:206
handle_delete            0   0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:189
handle_incr_decr_cmd     0   0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:201


MemcachedEvent.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 15;
               1                                  4   
               1                                  9   
13                                                    
14             1                    1            11   use MemcachedEvent;
               1                                  3   
               1                                 10   
15             1                    1            12   use MaatkitTest;
               1                                  4   
               1                                 38   
16                                                    
17             1                                  9   my $memce = new MemcachedEvent();
18             1                                 10   isa_ok($memce, 'MemcachedEvent');
19                                                    
20                                                    sub make_events {
21            14                   14            75      my ( @memc_events ) = @_;
22            14                                 37      my @events;
23            14                                 56      push @events, map { $memce->parse_event(event=>$_) } @memc_events;
              17                                 97   
24            14                                 69      return \@events;
25                                                    }
26                                                    
27                                                    # #############################################################################
28                                                    # Sanity tests.
29                                                    # #############################################################################
30             1                                 14   my $events = make_events(
31                                                       {
32                                                          key           => 'my_key',
33                                                          val           => 'Some value',
34                                                          res           => 'STORED',
35                                                          Query_time    => 1,
36                                                       },
37                                                    );
38             1                                 11   is_deeply(
39                                                       $events,
40                                                       [],
41                                                       "Doesn't die when there's no cmd"
42                                                    );
43                                                    
44             1                                 13   $events = make_events(
45                                                       {
46                                                          cmd           => 'unknown_cmd',
47                                                          val           => 'Some value',
48                                                          res           => 'STORED',
49                                                          Query_time    => 1,
50                                                       },
51                                                    );
52             1                                  7   is_deeply(
53                                                       $events,
54                                                       [],
55                                                       "Doesn't die when there's no key"
56                                                    );
57                                                    
58             1                                 11   $events = make_events(
59                                                       {
60                                                          val           => 'Some value',
61                                                          res           => 'STORED',
62                                                          Query_time    => 1,
63                                                       },
64                                                    );
65             1                                  7   is_deeply(
66                                                       $events,
67                                                       [],
68                                                       "Doesn't die when there's no cmd or key"
69                                                    );
70                                                    
71             1                                 12   $events = make_events(
72                                                       {
73                                                          cmd           => 'unknown_cmd',
74                                                          key           => 'my_key',
75                                                          val           => 'Some value',
76                                                          res           => 'STORED',
77                                                          Query_time    => 1,
78                                                       },
79                                                    );
80             1                                  6   is_deeply(
81                                                       $events,
82                                                       [],
83                                                       "Doesn't handle unknown cmd"
84                                                    );
85                                                    
86                                                    # #############################################################################
87                                                    # These events are copied straight from the expected results in
88                                                    # MemcachedProtocolParser.t.
89                                                    # #############################################################################
90                                                    
91                                                    # A session with a simple set().
92             1                                 42   $events = make_events(
93                                                       {  ts            => '2009-07-04 21:33:39.229179',
94                                                          host          => '127.0.0.1',
95                                                          cmd           => 'set',
96                                                          key           => 'my_key',
97                                                          val           => 'Some value',
98                                                          flags         => '0',
99                                                          exptime       => '0',
100                                                         bytes         => '10',
101                                                         res           => 'STORED',
102                                                         Query_time    => sprintf('%.6f', .229299 - .229179),
103                                                         pos_in_log    => 0,
104                                                      },
105                                                   );
106            1                                 28   is_deeply(
107                                                      $events,
108                                                      [
109                                                         {
110                                                            arg         => 'set my_key',
111                                                            fingerprint => 'set my_key',
112                                                            key_print   => 'my_key',
113                                                            cmd         => 'set',
114                                                            key         => 'my_key',
115                                                            res         => 'STORED',
116                                                            Memc_add => 'No',
117                                                            Memc_append => 'No',
118                                                            Memc_cas => 'No',
119                                                            Memc_decr => 'No',
120                                                            Memc_delete => 'No',
121                                                            Memc_error => 'No',
122                                                            Memc_get => 'No',
123                                                            Memc_gets => 'No',
124                                                            Memc_incr => 'No',
125                                                            Memc_miss => 'No',
126                                                            Memc_prepend => 'No',
127                                                            Memc_replace => 'No',
128                                                            Memc_set => 'Yes',
129                                                            Memc_miss   => 'No',
130                                                            Memc_error  => 'No',
131                                                            Memc_Not_Stored => 'No',
132                                                            Memc_Exists     => 'No',
133                                                            Query_time => '0.000120',
134                                                            bytes => '10',
135                                                            exptime => '0',
136                                                            fingerprint => 'set my_key',
137                                                            flags => '0',
138                                                            host => '127.0.0.1',
139                                                            pos_in_log => 0,
140                                                            ts => '2009-07-04 21:33:39.229179',
141                                                            val => 'Some value'
142                                                         },
143                                                      ],
144                                                      'samples/memc_tcpdump001.txt: simple set'
145                                                   );
146                                                   
147                                                   # A session with a simple get().
148            1                                 43   $events = make_events(
149                                                      {  Query_time => '0.000067',
150                                                         cmd        => 'get',
151                                                         key        => 'my_key',
152                                                         val        => 'Some value',
153                                                         bytes      => 10,
154                                                         exptime    => undef,
155                                                         flags      => 0,
156                                                         host       => '127.0.0.1',
157                                                         pos_in_log => '0',
158                                                         res        => 'VALUE',
159                                                         ts         => '2009-07-04 22:12:06.174390'
160                                                      }
161                                                   );
162            1                                 30   is_deeply(
163                                                      $events,
164                                                      [
165                                                         {
166                                                            arg         => 'get my_key',
167                                                            fingerprint => 'get my_key',
168                                                            key_print   => 'my_key',
169                                                            cmd         => 'get',
170                                                            key         => 'my_key',
171                                                            res         => 'VALUE',
172                                                            Memc_add => 'No',
173                                                            Memc_append => 'No',
174                                                            Memc_cas => 'No',
175                                                            Memc_decr => 'No',
176                                                            Memc_delete => 'No',
177                                                            Memc_error => 'No',
178                                                            Memc_get => 'Yes',
179                                                            Memc_gets => 'No',
180                                                            Memc_incr => 'No',
181                                                            Memc_miss => 'No',
182                                                            Memc_prepend => 'No',
183                                                            Memc_replace => 'No',
184                                                            Memc_set => 'No',
185                                                            Memc_miss   => 'No',
186                                                            Memc_error  => 'No',
187                                                            Query_time => '0.000067',
188                                                            val        => 'Some value',
189                                                            bytes      => 10,
190                                                            exptime    => undef,
191                                                            flags      => 0,
192                                                            host       => '127.0.0.1',
193                                                            pos_in_log => '0',
194                                                            ts         => '2009-07-04 22:12:06.174390'
195                                                         },
196                                                      ],
197                                                      'samples/memc_tcpdump002.txt: simple get',
198                                                   );
199                                                   
200                                                   # A session with a simple incr() and decr().
201            1                                 30   $events = make_events(
202                                                      {  Query_time => '0.000073',
203                                                         cmd        => 'incr',
204                                                         key        => 'key',
205                                                         val        => '8',
206                                                         bytes      => undef,
207                                                         exptime    => undef,
208                                                         flags      => undef,
209                                                         host       => '127.0.0.1',
210                                                         pos_in_log => '0',
211                                                         res        => '',
212                                                         ts         => '2009-07-04 22:12:06.175734',
213                                                      },
214                                                      {  Query_time => '0.000068',
215                                                         cmd        => 'decr',
216                                                         bytes      => undef,
217                                                         exptime    => undef,
218                                                         flags      => undef,
219                                                         host       => '127.0.0.1',
220                                                         key        => 'key',
221                                                         pos_in_log => 522,
222                                                         res        => '',
223                                                         ts         => '2009-07-04 22:12:06.176181',
224                                                         val        => '7',
225                                                      },
226                                                   );
227            1                                 52   is_deeply(
228                                                      $events,
229                                                      [
230                                                         {
231                                                            arg         => 'incr key',
232                                                            fingerprint => 'incr key',
233                                                            key_print   => 'key',
234                                                            cmd         => 'incr',
235                                                            key         => 'key',
236                                                            res         => '',
237                                                            Memc_add => 'No',
238                                                            Memc_append => 'No',
239                                                            Memc_cas => 'No',
240                                                            Memc_decr => 'No',
241                                                            Memc_delete => 'No',
242                                                            Memc_error => 'No',
243                                                            Memc_get => 'No',
244                                                            Memc_gets => 'No',
245                                                            Memc_incr => 'Yes',
246                                                            Memc_miss => 'No',
247                                                            Memc_prepend => 'No',
248                                                            Memc_replace => 'No',
249                                                            Memc_set => 'No',
250                                                            Memc_miss   => 'No',
251                                                            Memc_error  => 'No',
252                                                            Query_time => '0.000073',
253                                                            val        => '8',
254                                                            bytes      => undef,
255                                                            exptime    => undef,
256                                                            flags      => undef,
257                                                            host       => '127.0.0.1',
258                                                            pos_in_log => '0',
259                                                            ts         => '2009-07-04 22:12:06.175734',
260                                                         },
261                                                         {  
262                                                            arg         => 'decr key',
263                                                            fingerprint => 'decr key',
264                                                            key_print   => 'key',
265                                                            cmd         => 'decr',
266                                                            key         => 'key',
267                                                            res         => '',
268                                                            Memc_add => 'No',
269                                                            Memc_append => 'No',
270                                                            Memc_cas => 'No',
271                                                            Memc_decr => 'Yes',
272                                                            Memc_delete => 'No',
273                                                            Memc_error => 'No',
274                                                            Memc_get => 'No',
275                                                            Memc_gets => 'No',
276                                                            Memc_incr => 'No',
277                                                            Memc_miss => 'No',
278                                                            Memc_prepend => 'No',
279                                                            Memc_replace => 'No',
280                                                            Memc_set => 'No',
281                                                            Memc_miss   => 'No',
282                                                            Memc_error  => 'No',
283                                                            Query_time => '0.000068',
284                                                            bytes      => undef,
285                                                            exptime    => undef,
286                                                            flags      => undef,
287                                                            host       => '127.0.0.1',
288                                                            pos_in_log => 522,
289                                                            ts         => '2009-07-04 22:12:06.176181',
290                                                            val        => '7',
291                                                         },
292                                                      ],
293                                                      'samples/memc_tcpdump003.txt: incr and decr'
294                                                   );
295                                                   
296                                                   # A session with a simple incr() and decr(), but the value doesn't exist.
297            1                                 30   $events = make_events(
298                                                      {  Query_time => '0.000131',
299                                                         bytes      => undef,
300                                                         cmd        => 'incr',
301                                                         exptime    => undef,
302                                                         flags      => undef,
303                                                         host       => '127.0.0.1',
304                                                         key        => 'key',
305                                                         pos_in_log => 764,
306                                                         res        => 'NOT_FOUND',
307                                                         ts         => '2009-07-06 10:37:21.668469',
308                                                         val        => '',
309                                                      },
310                                                      {
311                                                         Query_time => '0.000055',
312                                                         bytes      => undef,
313                                                         cmd        => 'decr',
314                                                         exptime    => undef,
315                                                         flags      => undef,
316                                                         host       => '127.0.0.1',
317                                                         key        => 'key',
318                                                         pos_in_log => 1788,
319                                                         res        => 'NOT_FOUND',
320                                                         ts         => '2009-07-06 10:37:21.668851',
321                                                         val        => '',
322                                                      },
323                                                   );
324            1                                 43   is_deeply(
325                                                      $events,
326                                                      [
327                                                         {  
328                                                            arg         => 'incr key',
329                                                            fingerprint => 'incr key',
330                                                            key_print   => 'key',
331                                                            cmd         => 'incr',
332                                                            key         => 'key',
333                                                            res         => 'NOT_FOUND',
334                                                            Memc_add => 'No',
335                                                            Memc_append => 'No',
336                                                            Memc_cas => 'No',
337                                                            Memc_decr => 'No',
338                                                            Memc_delete => 'No',
339                                                            Memc_error => 'No',
340                                                            Memc_get => 'No',
341                                                            Memc_gets => 'No',
342                                                            Memc_incr => 'Yes',
343                                                            Memc_miss => 'No',
344                                                            Memc_prepend => 'No',
345                                                            Memc_replace => 'No',
346                                                            Memc_set => 'No',
347                                                            Memc_miss   => 'Yes',
348                                                            Memc_error  => 'No',
349                                                            Query_time => '0.000131',
350                                                            bytes      => undef,
351                                                            exptime    => undef,
352                                                            flags      => undef,
353                                                            host       => '127.0.0.1',
354                                                            pos_in_log => 764,
355                                                            ts         => '2009-07-06 10:37:21.668469',
356                                                            val        => '',
357                                                         },
358                                                         {
359                                                            arg         => 'decr key',
360                                                            fingerprint => 'decr key',
361                                                            key_print   => 'key',
362                                                            cmd         => 'decr',
363                                                            key         => 'key',
364                                                            res         => 'NOT_FOUND',
365                                                            Memc_add => 'No',
366                                                            Memc_append => 'No',
367                                                            Memc_cas => 'No',
368                                                            Memc_decr => 'Yes',
369                                                            Memc_delete => 'No',
370                                                            Memc_error => 'No',
371                                                            Memc_get => 'No',
372                                                            Memc_gets => 'No',
373                                                            Memc_incr => 'No',
374                                                            Memc_miss => 'No',
375                                                            Memc_prepend => 'No',
376                                                            Memc_replace => 'No',
377                                                            Memc_set => 'No',
378                                                            Memc_miss   => 'Yes',
379                                                            Memc_error  => 'No',
380                                                            Query_time => '0.000055',
381                                                            bytes      => undef,
382                                                            exptime    => undef,
383                                                            flags      => undef,
384                                                            host       => '127.0.0.1',
385                                                            pos_in_log => 1788,
386                                                            ts         => '2009-07-06 10:37:21.668851',
387                                                            val        => '',
388                                                         },
389                                                      ],
390                                                      'samples/memc_tcpdump004.txt: incr and decr nonexistent key'
391                                                   );
392                                                   
393                                                   # A session with a huge set() that will not fit into a single TCP packet.
394            1                                 87   $events = make_events(
395                                                      {  Query_time => '0.003928',
396                                                         bytes      => 17946,
397                                                         cmd        => 'set',
398                                                         exptime    => 0,
399                                                         flags      => 0,
400                                                         host       => '127.0.0.1',
401                                                         key        => 'my_key',
402                                                         pos_in_log => 764,
403                                                         res        => 'STORED',
404                                                         ts         => '2009-07-06 22:07:14.406827',
405                                                         val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
406                                                      },
407                                                   );
408            1                                105   is_deeply(
409                                                      $events,
410                                                      [
411                                                         {  
412                                                            arg         => 'set my_key',
413                                                            fingerprint => 'set my_key',
414                                                            key_print   => 'my_key',
415                                                            cmd         => 'set',
416                                                            key         => 'my_key',
417                                                            res         => 'STORED',
418                                                            Memc_add => 'No',
419                                                            Memc_append => 'No',
420                                                            Memc_cas => 'No',
421                                                            Memc_decr => 'No',
422                                                            Memc_delete => 'No',
423                                                            Memc_error => 'No',
424                                                            Memc_get => 'No',
425                                                            Memc_gets => 'No',
426                                                            Memc_incr => 'No',
427                                                            Memc_miss => 'No',
428                                                            Memc_prepend => 'No',
429                                                            Memc_replace => 'No',
430                                                            Memc_set => 'Yes',
431                                                            Memc_miss  => 'No',
432                                                            Memc_error => 'No',
433                                                            Memc_Not_Stored => 'No',
434                                                            Memc_Exists     => 'No',
435                                                            Query_time => '0.003928',
436                                                            bytes      => 17946,
437                                                            exptime    => 0,
438                                                            flags      => 0,
439                                                            host       => '127.0.0.1',
440                                                            pos_in_log => 764,
441                                                            ts         => '2009-07-06 22:07:14.406827',
442                                                            val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
443                                                         },
444                                                      ],
445                                                      'samples/memc_tcpdump005.txt: huge set'
446                                                   );
447                                                   
448                                                   # A session with a huge get() that will not fit into a single TCP packet.
449            1                                 62   $events = make_events(
450                                                      {
451                                                         Query_time => '0.000196',
452                                                         bytes      => 17946,
453                                                         cmd        => 'get',
454                                                         exptime    => undef,
455                                                         flags      => 0,
456                                                         host       => '127.0.0.1',
457                                                         key        => 'my_key',
458                                                         pos_in_log => 0,
459                                                         res        => 'VALUE',
460                                                         ts         => '2009-07-06 22:07:14.411331',
461                                                         val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
462                                                      },
463                                                   );
464            1                                 63   is_deeply(
465                                                      $events,
466                                                      [
467                                                         {
468                                                            arg         => 'get my_key',
469                                                            fingerprint => 'get my_key',
470                                                            key_print   => 'my_key',
471                                                            cmd         => 'get',
472                                                            key         => 'my_key',
473                                                            res         => 'VALUE',
474                                                            Memc_add => 'No',
475                                                            Memc_append => 'No',
476                                                            Memc_cas => 'No',
477                                                            Memc_decr => 'No',
478                                                            Memc_delete => 'No',
479                                                            Memc_error => 'No',
480                                                            Memc_get => 'Yes',
481                                                            Memc_gets => 'No',
482                                                            Memc_incr => 'No',
483                                                            Memc_miss => 'No',
484                                                            Memc_prepend => 'No',
485                                                            Memc_replace => 'No',
486                                                            Memc_set => 'No',
487                                                            Memc_miss   => 'No',
488                                                            Memc_error  => 'No',
489                                                            Query_time => '0.000196',
490                                                            bytes      => 17946,
491                                                            exptime    => undef,
492                                                            flags      => 0,
493                                                            host       => '127.0.0.1',
494                                                            pos_in_log => 0,
495                                                            ts         => '2009-07-06 22:07:14.411331',
496                                                            val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
497                                                         },
498                                                      ],
499                                                      'samples/memc_tcpdump006.txt: huge get'
500                                                   );
501                                                   
502                                                   # A session with a get() that doesn't exist.
503            1                                 28   $events = make_events(
504                                                      {
505                                                         Query_time => '0.000016',
506                                                         bytes      => undef,
507                                                         cmd        => 'get',
508                                                         exptime    => undef,
509                                                         flags      => undef,
510                                                         host       => '127.0.0.1',
511                                                         key        => 'comment_v3_482685',
512                                                         pos_in_log => 0,
513                                                         res        => 'NOT_FOUND',
514                                                         ts         => '2009-06-11 21:54:49.059144',
515                                                         val        => '',
516                                                      },
517                                                   );
518            1                                 33   is_deeply(
519                                                      $events,
520                                                      [
521                                                         {
522                                                            arg         => 'get comment_v3_482685',
523                                                            fingerprint => 'get comment_v?_?',
524                                                            key_print   => 'comment_v?_?',
525                                                            cmd         => 'get',
526                                                            key         => 'comment_v3_482685',
527                                                            res         => 'NOT_FOUND',
528                                                            Memc_add => 'No',
529                                                            Memc_append => 'No',
530                                                            Memc_cas => 'No',
531                                                            Memc_decr => 'No',
532                                                            Memc_delete => 'No',
533                                                            Memc_error => 'No',
534                                                            Memc_get => 'Yes',
535                                                            Memc_gets => 'No',
536                                                            Memc_incr => 'No',
537                                                            Memc_miss => 'No',
538                                                            Memc_prepend => 'No',
539                                                            Memc_replace => 'No',
540                                                            Memc_set => 'No',
541                                                            Memc_miss   => 'Yes',
542                                                            Memc_error  => 'No',
543                                                            Query_time => '0.000016',
544                                                            bytes      => undef,
545                                                            exptime    => undef,
546                                                            flags      => undef,
547                                                            host       => '127.0.0.1',
548                                                            pos_in_log => 0,
549                                                            ts         => '2009-06-11 21:54:49.059144',
550                                                            val        => '',
551                                                         },
552                                                      ],
553                                                      'samples/memc_tcpdump007.txt: get nonexistent key'
554                                                   );
555                                                   
556                                                   # A session with a huge get() that will not fit into a single TCP packet, but
557                                                   # the connection seems to be broken in the middle of the receive and then the
558                                                   # new client picks up and asks for something different.
559            1                                 35   $events = make_events(
560                                                      {
561                                                         Query_time => '0.000003',
562                                                         bytes      => 17946,
563                                                         cmd        => 'get',
564                                                         exptime    => undef,
565                                                         flags      => 0,
566                                                         host       => '127.0.0.1',
567                                                         key        => 'my_key',
568                                                         pos_in_log => 0,
569                                                         res        => 'INTERRUPTED',
570                                                         ts         => '2009-07-06 22:07:14.411331',
571                                                         val        => '',
572                                                      },
573                                                      {  Query_time => '0.000001',
574                                                         cmd        => 'get',
575                                                         key        => 'my_key',
576                                                         val        => 'Some value',
577                                                         bytes      => 10,
578                                                         exptime    => undef,
579                                                         flags      => 0,
580                                                         host       => '127.0.0.1',
581                                                         pos_in_log => 5382,
582                                                         res        => 'VALUE',
583                                                         ts         => '2009-07-06 22:07:14.411334',
584                                                      },
585                                                   );
586            1                                 43   is_deeply(
587                                                      $events,
588                                                      [
589                                                         {
590                                                            arg         => 'get my_key',
591                                                            fingerprint => 'get my_key',
592                                                            key_print   => 'my_key',
593                                                            cmd         => 'get',
594                                                            key         => 'my_key',
595                                                            res         => 'INTERRUPTED',
596                                                            Memc_add => 'No',
597                                                            Memc_append => 'No',
598                                                            Memc_cas => 'No',
599                                                            Memc_decr => 'No',
600                                                            Memc_delete => 'No',
601                                                            Memc_error => 'No',
602                                                            Memc_get => 'Yes',
603                                                            Memc_gets => 'No',
604                                                            Memc_incr => 'No',
605                                                            Memc_miss => 'No',
606                                                            Memc_prepend => 'No',
607                                                            Memc_replace => 'No',
608                                                            Memc_set => 'No',
609                                                            Memc_miss   => 'No',
610                                                            Memc_error  => 'Yes',
611                                                            Query_time => '0.000003',
612                                                            bytes      => 17946,
613                                                            exptime    => undef,
614                                                            flags      => 0,
615                                                            host       => '127.0.0.1',
616                                                            pos_in_log => 0,
617                                                            ts         => '2009-07-06 22:07:14.411331',
618                                                            val        => '',
619                                                         },
620                                                         {
621                                                            arg         => 'get my_key',
622                                                            fingerprint => 'get my_key',
623                                                            key_print   => 'my_key',
624                                                            cmd         => 'get',
625                                                            key         => 'my_key',
626                                                            res         => 'VALUE',
627                                                            Memc_add => 'No',
628                                                            Memc_append => 'No',
629                                                            Memc_cas => 'No',
630                                                            Memc_decr => 'No',
631                                                            Memc_delete => 'No',
632                                                            Memc_error => 'No',
633                                                            Memc_get => 'Yes',
634                                                            Memc_gets => 'No',
635                                                            Memc_incr => 'No',
636                                                            Memc_miss => 'No',
637                                                            Memc_prepend => 'No',
638                                                            Memc_replace => 'No',
639                                                            Memc_set => 'No',
640                                                            Memc_miss   => 'No',
641                                                            Memc_error  => 'No',
642                                                            Query_time => '0.000001',
643                                                            val        => 'Some value',
644                                                            bytes      => 10,
645                                                            exptime    => undef,
646                                                            flags      => 0,
647                                                            host       => '127.0.0.1',
648                                                            pos_in_log => 5382,
649                                                            ts         => '2009-07-06 22:07:14.411334',
650                                                         },
651                                                      ],
652                                                      'samples/memc_tcpdump008.txt: interrupted huge get'
653                                                   );
654                                                   
655                                                   # A session with a delete() that doesn't exist. TODO: delete takes a queue_time.
656            1                                 23   $events = make_events(
657                                                      {
658                                                         Query_time => '0.000022',
659                                                         bytes      => undef,
660                                                         cmd        => 'delete',
661                                                         exptime    => undef,
662                                                         flags      => undef,
663                                                         host       => '127.0.0.1',
664                                                         key        => 'comment_1873527',
665                                                         pos_in_log => 0,
666                                                         res        => 'NOT_FOUND',
667                                                         ts         => '2009-06-11 21:54:52.244534',
668                                                         val        => '',
669                                                      },
670                                                   );
671            1                                 28   is_deeply(
672                                                      $events,
673                                                      [
674                                                         {
675                                                            arg         => 'delete comment_1873527',
676                                                            fingerprint => 'delete comment_?',
677                                                            key_print   => 'comment_?',
678                                                            cmd         => 'delete',
679                                                            key         => 'comment_1873527',
680                                                            res         => 'NOT_FOUND',
681                                                            Memc_add => 'No',
682                                                            Memc_append => 'No',
683                                                            Memc_cas => 'No',
684                                                            Memc_decr => 'No',
685                                                            Memc_delete => 'Yes',
686                                                            Memc_error => 'No',
687                                                            Memc_get => 'No',
688                                                            Memc_gets => 'No',
689                                                            Memc_incr => 'No',
690                                                            Memc_miss => 'No',
691                                                            Memc_prepend => 'No',
692                                                            Memc_replace => 'No',
693                                                            Memc_set => 'No',
694                                                            Memc_miss   => 'Yes',
695                                                            Memc_error  => 'No',
696                                                            Query_time => '0.000022',
697                                                            bytes      => undef,
698                                                            exptime    => undef,
699                                                            flags      => undef,
700                                                            host       => '127.0.0.1',
701                                                            pos_in_log => 0,
702                                                            ts         => '2009-06-11 21:54:52.244534',
703                                                            val        => '',
704                                                         },
705                                                      ],
706                                                      'samples/memc_tcpdump009.txt: delete nonexistent key'
707                                                   );
708                                                   
709                                                   # A session with a delete() that does exist.
710            1                                 28   $events = make_events(
711                                                      {
712                                                         Query_time => '0.000120',
713                                                         bytes      => undef,
714                                                         cmd        => 'delete',
715                                                         exptime    => undef,
716                                                         flags      => undef,
717                                                         host       => '127.0.0.1',
718                                                         key        => 'my_key',
719                                                         pos_in_log => 0,
720                                                         res        => 'DELETED',
721                                                         ts         => '2009-07-09 22:00:29.066476',
722                                                         val        => '',
723                                                      },
724                                                   );
725            1                                 27   is_deeply(
726                                                      $events,
727                                                      [
728                                                         {
729                                                            arg         => 'delete my_key',
730                                                            fingerprint => 'delete my_key',
731                                                            key_print   => 'my_key',
732                                                            cmd         => 'delete',
733                                                            key         => 'my_key',
734                                                            res         => 'DELETED',
735                                                            Memc_add => 'No',
736                                                            Memc_append => 'No',
737                                                            Memc_cas => 'No',
738                                                            Memc_decr => 'No',
739                                                            Memc_delete => 'Yes',
740                                                            Memc_error => 'No',
741                                                            Memc_get => 'No',
742                                                            Memc_gets => 'No',
743                                                            Memc_incr => 'No',
744                                                            Memc_miss => 'No',
745                                                            Memc_prepend => 'No',
746                                                            Memc_replace => 'No',
747                                                            Memc_set => 'No',
748                                                            Memc_miss   => 'No',
749                                                            Memc_error  => 'No',
750                                                            Query_time => '0.000120',
751                                                            bytes      => undef,
752                                                            exptime    => undef,
753                                                            flags      => undef,
754                                                            host       => '127.0.0.1',
755                                                            pos_in_log => 0,
756                                                            ts         => '2009-07-09 22:00:29.066476',
757                                                            val        => '',
758                                                         },
759                                                      ],
760                                                      'samples/memc_tcpdump010.txt: simple delete'
761                                                   );
762                                                   
763                                                   # #############################################################################
764                                                   # Done.
765                                                   # #############################################################################
766            1                                  3   exit;


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

Subroutine  Count Location           
----------- ----- -------------------
BEGIN           1 MemcachedEvent.t:10
BEGIN           1 MemcachedEvent.t:11
BEGIN           1 MemcachedEvent.t:12
BEGIN           1 MemcachedEvent.t:14
BEGIN           1 MemcachedEvent.t:15
BEGIN           1 MemcachedEvent.t:4 
BEGIN           1 MemcachedEvent.t:9 
make_events    14 MemcachedEvent.t:21


