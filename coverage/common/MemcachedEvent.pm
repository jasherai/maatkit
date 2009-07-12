---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/MemcachedEvent.pm   75.4   61.5   33.3   92.3    n/a  100.0   72.9
Total                          75.4   61.5   33.3   92.3    n/a  100.0   72.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MemcachedEvent.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sun Jul 12 15:07:05 2009
Finish:       Sun Jul 12 15:07:05 2009

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
18                                                    # MemcachedEvent package $Revision: 4148 $
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
               1                                  9   
32             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
33                                                    
34             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                 12   
35                                                    $Data::Dumper::Indent    = 1;
36                                                    $Data::Dumper::Sortkeys  = 1;
37                                                    $Data::Dumper::Quotekeys = 0;
38                                                    
39             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
40                                                    
41                                                    my %cmd_handler_for = (
42                                                       set      => \&handle_storage_cmd,
43                                                       add      => \&handle_storage_cmd,
44                                                       replace  => \&handle_storage_cmd,
45                                                       append   => \&handle_storage_cmd,
46                                                       prepend  => \&handle_storage_cmd,
47                                                       cas      => \&handle_storage_cmd,
48                                                       get      => \&handle_retr_cmd,
49                                                       gets     => \&handle_retr_cmd,
50                                                       'delete' => \&handle_delete,
51                                                       incr     => \&handle_incr_decr_cmd,
52                                                       decr     => \&handle_incr_decr_cmd,
53                                                    );
54                                                    
55                                                    sub new {
56             1                    1            16      my ( $class, %args ) = @_;
57             1                                  3      my $self = {
58                                                       };
59             1                                 12      return bless $self, $class;
60                                                    }
61                                                    
62                                                    # Given an event from MemcachedProtocolParser, returns an event
63                                                    # more suitable for mk-query-digest.
64                                                    sub make_event {
65            13                   13           583      my ( $self, $event ) = @_;
66    ***     13     50                          48      return unless $event;
67                                                    
68    ***     13     50     33                  121      if ( !$event->{cmd} || !$event->{key} ) {
69    ***      0                                  0         MKDEBUG && _d('Event has no cmd or key:', Dumper($event));
70    ***      0                                  0         return;
71                                                       }
72                                                    
73    ***     13     50                          55      if ( !exists $cmd_handler_for{$event->{cmd}} ) {
74    ***      0                                  0         MKDEBUG && _d('No cmd handler exists for', $event->{cmd});
75    ***      0                                  0         return;
76                                                       }
77                                                    
78                                                       # For a normal event, arg is the query.  For memcached, the "query" is
79                                                       # essentially the cmd and key, so this becomes arg.  E.g.: "set mk_key".
80            13                                 69      $event->{arg}         = "$event->{cmd} $event->{key}";
81            13                                 53      $event->{fingerprint} = $self->fingerprint($event->{arg});
82            13                                 52      $event->{key_print}   = $self->fingerprint($event->{key});
83                                                    
84            13                                 57      $event->{"Memc_$event->{cmd}"} = 'Yes';  # Got this type of cmd.
85                                                    
86                                                       # Handle different cmd results to determine errors, misses, etc.
87                                                       # A cmd handler should return the event on success, or nothing on failure.
88            13                                 56      return $cmd_handler_for{$event->{cmd}}->($event);
89                                                    }
90                                                    
91                                                    # Replace things that look like placeholders with a ?
92                                                    sub fingerprint {
93            26                   26            94      my ( $self, $val ) = @_;
94            26                                149      $val =~ s/[0-9A-Fa-f]{16,}|\d+/?/g;
95            26                                106      return $val;
96                                                    }
97                                                    
98                                                    # Possible results for storage cmds:
99                                                    # - "STORED\r\n", to indicate success.
100                                                   #
101                                                   # - "NOT_STORED\r\n" to indicate the data was not stored, but not
102                                                   #   because of an error. This normally means that either that the
103                                                   #   condition for an "add" or a "replace" command wasn't met, or that the
104                                                   #   item is in a delete queue (see the "delete" command below).
105                                                   #
106                                                   # - "EXISTS\r\n" to indicate that the item you are trying to store with
107                                                   #   a "cas" command has been modified since you last fetched it.
108                                                   #
109                                                   # - "NOT_FOUND\r\n" to indicate that the item you are trying to store
110                                                   #   with a "cas" command did not exist or has been deleted.
111                                                   sub handle_storage_cmd {
112            2                    2             6      my ( $event ) = @_;
113                                                   
114                                                      # There should be a result for any storage cmd.   
115   ***      2     50                           9      if ( !$event->{res} ) {
116   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
117   ***      0                                  0         return;
118                                                      }
119                                                   
120                                                      # Technically NOT_STORED is not an error, but we treat it as one.
121   ***      2     50                          11      $event->{'Memc_error'} = $event->{res} eq 'STORED'    ? 'No'  : 'Yes';
122   ***      2     50                          13      $event->{'Memc_miss'}  = $event->{res} eq 'NOT_FOUND' ? 'Yes' : 'No';
123                                                   
124            2                                 10      return $event;
125                                                   }
126                                                   
127                                                   # Technically, the only results for a retrieval cmd are the values requested.
128                                                   #  "If some of the keys appearing in a retrieval request are not sent back
129                                                   #   by the server in the item list this means that the server does not
130                                                   #   hold items with such keys (because they were never stored, or stored
131                                                   #   but deleted to make space for more items, or expired, or explicitly
132                                                   #   deleted by a client)."
133                                                   # Contrary to this, MemcacedProtocolParser will set res='VALUE' on
134                                                   # success, res='NOT_FOUND' on failure, or res='INTERRUPTED' if the get
135                                                   # didn't finish.
136                                                   sub handle_retr_cmd {
137            5                    5            17      my ( $event ) = @_;
138                                                   
139                                                      # There should be a result for any retr cmd.   
140   ***      5     50                          21      if ( !$event->{res} ) {
141   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
142   ***      0                                  0         return;
143                                                      }
144                                                   
145            5    100                          26      $event->{'Memc_error'} = $event->{res} eq 'INTERRUPTED' ? 'Yes' : 'No';
146            5    100                          28      $event->{'Memc_miss'}  = $event->{res} eq 'NOT_FOUND'   ? 'Yes' : 'No';
147                                                   
148            5                                 27      return $event;
149                                                   }
150                                                   
151                                                   # Possible results for a delete cmd:
152                                                   # - "DELETED\r\n" to indicate success
153                                                   #
154                                                   # - "NOT_FOUND\r\n" to indicate that the item with this key was not
155                                                   #   found.
156                                                   sub handle_delete {
157            2                    2             7      my ( $event ) = @_;
158                                                   
159                                                      # There should be a result for any delete cmd.   
160   ***      2     50                          10      if ( !$event->{res} ) {
161   ***      0                                  0         MKDEBUG && _d('No result for event:', Dumper($event));
162   ***      0                                  0         return;
163                                                      }
164                                                   
165            2                                  7      $event->{'Memc_error'} = 'No';
166            2    100                          13      $event->{'Memc_miss'}  = $event->{res} eq 'NOT_FOUND' ? 'Yes' : 'No';
167                                                   
168            2                                 10      return $event;
169                                                   }
170                                                   
171                                                   # Possible results for an incr or decr cmd:
172                                                   # - "NOT_FOUND\r\n" to indicate the item with this value was not found
173                                                   #
174                                                   # - <value>\r\n , where <value> is the new value of the item's data,
175                                                   #   after the increment/decrement operation was carried out.
176                                                   # On success, MemcachedProtocolParser sets res='' and val=the new val.
177                                                   # On failure, res=the result and val=''.
178                                                   sub handle_incr_decr_cmd {
179            4                    4            13      my ( $event ) = @_;
180                                                   
181            4                                 13      $event->{'Memc_error'} = 'No';
182            4    100                          24      $event->{'Memc_miss'}  = $event->{res} eq 'NOT_FOUND' ? 'Yes' : 'No';
183                                                   
184            4                                 18      return $event;
185                                                   }
186                                                   
187                                                   sub _d {
188   ***      0                    0                    my ($package, undef, $line) = caller 0;
189   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
190   ***      0                                              map { defined $_ ? $_ : 'undef' }
191                                                           @_;
192   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
193                                                   }
194                                                   
195                                                   1;
196                                                   
197                                                   # ###########################################################################
198                                                   # End MemcachedEvent package
199                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
66    ***     50      0     13   unless $event
68    ***     50      0     13   if (not $$event{'cmd'} or not $$event{'key'})
73    ***     50      0     13   if (not exists $cmd_handler_for{$$event{'cmd'}})
115   ***     50      0      2   if (not $$event{'res'})
121   ***     50      2      0   $$event{'res'} eq 'STORED' ? :
122   ***     50      0      2   $$event{'res'} eq 'NOT_FOUND' ? :
140   ***     50      0      5   if (not $$event{'res'})
145          100      1      4   $$event{'res'} eq 'INTERRUPTED' ? :
146          100      1      4   $$event{'res'} eq 'NOT_FOUND' ? :
160   ***     50      0      2   if (not $$event{'res'})
166          100      1      1   $$event{'res'} eq 'NOT_FOUND' ? :
182          100      2      2   $$event{'res'} eq 'NOT_FOUND' ? :
189   ***      0      0      0   defined $_ ? :


Conditions
----------

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
68    ***     33      0      0     13   not $$event{'cmd'} or not $$event{'key'}


Covered Subroutines
-------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:30 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:31 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:32 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:34 
BEGIN                    1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:39 
fingerprint             26 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:93 
handle_delete            2 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:157
handle_incr_decr_cmd     4 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:179
handle_retr_cmd          5 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:137
handle_storage_cmd       2 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:112
make_event              13 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:65 
new                      1 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:56 

Uncovered Subroutines
---------------------

Subroutine           Count Location                                             
-------------------- ----- -----------------------------------------------------
_d                       0 /home/daniel/dev/maatkit/common/MemcachedEvent.pm:188


