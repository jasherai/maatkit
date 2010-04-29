#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 21;

use Processlist;
use MaatkitTest;
use TextResultSetParser;
use Transformers;
use MasterSlave;
use MaatkitTest;

my $ms  = new MasterSlave();
my $pl  = new Processlist(MasterSlave=>$ms);
my $rsp = new TextResultSetParser();

my @events;
my $procs;

sub parse_n_times {
   my ( $n, %args ) = @_;
   my @events;
   for ( 1..$n ) {
      my $event = $pl->parse_event(misc => \%args);
      push @events, $event if $event;
   }
   return @events;
}

# An unfinished query doesn't crash anything.
$procs = [
   [ [1, 'unauthenticated user', 'localhost', undef, 'Connect', undef,
    'Reading from net', undef] ],
],
parse_n_times(
   3,
   code  => sub {
      return shift @$procs;
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:00'),
);
is_deeply($pl->_get_rows()->{prev_rows}, [], 'Prev does not know about undef query');
is(scalar @events, 0, 'No events fired from connection in process');

# Make a new one to replicate a bug with certainty...
$pl = Processlist->new(MasterSlave=>$ms);

# An existing sleeping query that goes away doesn't crash anything.
parse_n_times(
   1,
   code  => sub {
      return [
         [1, 'root', 'localhost', undef, 'Sleep', 7, '', undef],
      ],
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:00'),
);

# And now the connection goes away...
parse_n_times(
   1,
   code  => sub {
      return [
      ],
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:01'),
);

is_deeply($pl->_get_rows()->{prev_rows}, [], 'everything went away');
is(scalar @events, 0, 'No events fired from sleeping connection that left');

# Make sure there's a fresh start...
$pl = Processlist->new(MasterSlave=>$ms);

# The initial processlist shows a query in progress.
parse_n_times(
   1,
   code  => sub {
      return [
         [1, 'root', 'localhost', 'test', 'Query', 2, 'executing', 'query1_1'],
      ],
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:00'),
   etime => .05,
);

# The $prev array should now show that the query started at time 2 seconds ago
is_deeply(
   $pl->_get_rows()->{prev_rows},
   [
      [1, 'root', 'localhost', 'test', 'Query', 2,
         'executing', 'query1_1',
         Transformers::unix_timestamp('2001-01-01 00:04:58'), .05,
         Transformers::unix_timestamp('2001-01-01 00:05:00') ],
   ],
   'Prev knows about the query',
);

is(scalar @events, 0, 'No events fired');

# The next processlist shows a new query in progress and the other one is not
# there anymore at all.
$procs = [
   [ [2, 'root', 'localhost', 'test', 'Query', 1, 'executing', 'query2_1'] ],
];
@events = parse_n_times(
   2, 
   code  => sub {
      return shift @$procs,
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:01'),
   etime => .03,
);

# The $prev array should not have the first one anymore, just the second one.
is_deeply(
   $pl->_get_rows()->{prev_rows},
   [
      [2, 'root', 'localhost', 'test', 'Query', 1,
         'executing', 'query2_1',
         Transformers::unix_timestamp('2001-01-01 00:05:00'), .03,
         Transformers::unix_timestamp('2001-01-01 00:05:01')],
   ],
   'Prev forgot disconnected cxn 1, knows about cxn 2',
);

# And the first query has fired an event.
is_deeply(
   \@events,
   [  {  db         => 'test',
         user       => 'root',
         host       => 'localhost',
         arg        => 'query1_1',
         bytes      => 8,
         ts         => '2001-01-01T00:05:00',
         Query_time => 2,
         Lock_time  => 0,
         id         => 1,
      },
   ],
   'query1_1 fired',
);

# In this sample, the query on cxn 2 is finished, but the connection is still
# open.
@events = parse_n_times(
   1,
   code  => sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Sleep', 0, '', undef],
      ],
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:02'),
);

# And so as a result, query2_1 has fired and the prev array is empty.
is_deeply(
   $pl->_get_rows()->{prev_rows},
   [],
   'Prev says no queries are active',
);

# And the first query on cxn 2 has fired an event.
is_deeply(
   \@events,
   [  {  db         => 'test',
         user       => 'root',
         host       => 'localhost',
         arg        => 'query2_1',
         bytes      => 8,
         ts         => '2001-01-01T00:05:01',
         Query_time => 1,
         Lock_time  => 0,
         id         => 2,
      },
   ],
   'query2_1 fired',
);

# In this sample, cxn 2 is running a query, with a start time at the current
# time of 3 secs later
@events = parse_n_times(
   1,
   code  => sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
      ],
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:03'),
   etime => 3.14159,
);

is_deeply(
   $pl->_get_rows()->{prev_rows},
   [
      [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
      Transformers::unix_timestamp('2001-01-01 00:05:03'), 3.14159,
      Transformers::unix_timestamp('2001-01-01 00:05:03') ],
   ],
   'Prev says query2_2 just started',
);

# And there is no event on cxn 2.
is_deeply(
   \@events,
   [],
   'query2_2 is not fired yet',
);

# In this sample, the "same" query is running one second later and this time it
# seems to have a start time of 5 secs later, which is not enough to be a new
# query.
@events = parse_n_times(
   1,
   code  => sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
      ],
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:05'),
   etime => 2.718,
);

# And so as a result, query2_2 has NOT fired, but the prev array contains the
# query2_2 still.
is_deeply(
   $pl->_get_rows()->{prev_rows},
   [
      [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
      Transformers::unix_timestamp('2001-01-01 00:05:03'), 3.14159,
      Transformers::unix_timestamp('2001-01-01 00:05:03') ],
   ],
   'After query2_2 fired, the prev array has the one starting at 05:03',
);

is(scalar(@events), 0, 'It did not fire yet');

# But wait!  There's another!  And this time we catch it!
@events = parse_n_times(
   1,
   code  => sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
      ],
   },
   time  => Transformers::unix_timestamp('2001-01-01 00:05:08.500'),
   etime => 0.123,
);

# And so as a result, query2_2 has fired and the prev array contains the "new"
# query2_2.
is_deeply(
   $pl->_get_rows()->{prev_rows},
   [
      [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
      Transformers::unix_timestamp('2001-01-01 00:05:08'), 0.123,
      Transformers::unix_timestamp('2001-01-01 00:05:08.500') ],
   ],
   'After query2_2 fired, the prev array has the one starting at 05:08',
);

# And the query has fired an event.
is_deeply(
   \@events,
   [  {  db         => 'test',
         user       => 'root',
         host       => 'localhost',
         arg        => 'query2_2',
         bytes      => 8,
         ts         => '2001-01-01T00:05:03',
         Query_time => 5.5,
         Lock_time  => 0,
         id         => 2,
      },
   ],
   'query2_2 fired',
);

# #########################################################################
# Tests for "find" functionality.
# #########################################################################

my %find_spec = (
   only_oldest  => 1,
   busy_time    => 60,
   idle_time    => 0,
   ignore => {
      Id       => 5,
      User     => qr/^system.user$/,
      State    => qr/Locked/,
      Command  => qr/Binlog Dump/,
   },
   match => {
      Command  => qr/Query/,
      Info     => qr/^(?i:select)/,
   },
);

my @queries = $pl->find(
   [  {  'Time'    => '488',
         'Command' => 'Connect',
         'db'      => undef,
         'Id'      => '4',
         'Info'    => undef,
         'User'    => 'system user',
         'State'   => 'Waiting for master to send event',
         'Host'    => ''
      },
      {  'Time'    => '488',
         'Command' => 'Connect',
         'db'      => undef,
         'Id'      => '5',
         'Info'    => undef,
         'User'    => 'system user',
         'State' =>
            'Has read all relay log; waiting for the slave I/O thread to update it',
         'Host' => ''
      },
      {  'Time'    => '416',
         'Command' => 'Sleep',
         'db'      => undef,
         'Id'      => '7',
         'Info'    => undef,
         'User'    => 'msandbox',
         'State'   => '',
         'Host'    => 'localhost'
      },
      {  'Time'    => '0',
         'Command' => 'Query',
         'db'      => undef,
         'Id'      => '8',
         'Info'    => 'show full processlist',
         'User'    => 'msandbox',
         'State'   => undef,
         'Host'    => 'localhost:41655'
      },
      {  'Time'    => '467',
         'Command' => 'Binlog Dump',
         'db'      => undef,
         'Id'      => '2',
         'Info'    => undef,
         'User'    => 'msandbox',
         'State' =>
            'Has sent all binlog to slave; waiting for binlog to be updated',
         'Host' => 'localhost:56246'
      },
      {  'Time'    => '91',
         'Command' => 'Sleep',
         'db'      => undef,
         'Id'      => '40',
         'Info'    => undef,
         'User'    => 'msandbox',
         'State'   => '',
         'Host'    => 'localhost'
      },
      {  'Time'    => '91',
         'Command' => 'Query',
         'db'      => undef,
         'Id'      => '41',
         'Info'    => 'optimize table foo',
         'User'    => 'msandbox',
         'State'   => 'Query',
         'Host'    => 'localhost'
      },
      {  'Time'    => '91',
         'Command' => 'Query',
         'db'      => undef,
         'Id'      => '42',
         'Info'    => 'select * from foo',
         'User'    => 'msandbox',
         'State'   => 'Locked',
         'Host'    => 'localhost'
      },
      {  'Time'    => '91',
         'Command' => 'Query',
         'db'      => undef,
         'Id'      => '43',
         'Info'    => 'select * from foo',
         'User'    => 'msandbox',
         'State'   => 'executing',
         'Host'    => 'localhost'
      },
   ],
   %find_spec,
);

my $expected = [
      {  'Time'    => '91',
         'Command' => 'Query',
         'db'      => undef,
         'Id'      => '43',
         'Info'    => 'select * from foo',
         'User'    => 'msandbox',
         'State'   => 'executing',
         'Host'    => 'localhost'
      },
   ];

is_deeply(\@queries, $expected, 'Basic find()');

%find_spec = (
   only_oldest  => 1,
   busy_time    => 1,
   ignore => {
      User     => qr/^system.user$/,
      State    => qr/Locked/,
      Command  => qr/Binlog Dump/,
   },
   match => {
   },
);

@queries = $pl->find(
   [  {  'Time'    => '488',
         'Command' => 'Sleep',
         'db'      => undef,
         'Id'      => '7',
         'Info'    => undef,
         'User'    => 'msandbox',
         'State'   => '',
         'Host'    => 'localhost'
      },
   ],
   %find_spec,
);

is(scalar(@queries), 0, 'Did not find any query');

%find_spec = (
   only_oldest  => 1,
   busy_time    => undef,
   idle_time    => 15,
   ignore => {
   },
   match => {
   },
);
is_deeply(
   [
      $pl->find(
         $rsp->parse(load_file('common/t/samples/pl/recset003.txt')),
         %find_spec,
      )
   ],
   [
      {
         Id    => '29392005',
         User  => 'remote',
         Host  => '1.2.3.148:49718',
         db    => 'happy',
         Command => 'Sleep',
         Time  => '17',
         State => undef,
         Info  => 'NULL',
      }
   ],
   'idle_time'
);

# #########################################################################
# Tests for "find" functionality.
# #########################################################################
%find_spec = (
   match => { User => 'msandbox' },
);
@queries = $pl->find(
   $rsp->parse(load_file('common/t/samples/pl/recset008.txt')),
   %find_spec,
);
ok(
   @queries == 0,
   "Doesn't match replication thread by default"
);

%find_spec = (
   replication_threads => 1,
   match => { User => 'msandbox' },
);
@queries = $pl->find(
   $rsp->parse(load_file('common/t/samples/pl/recset008.txt')),
   %find_spec,
);
ok(
   @queries == 1,
   "Matches replication thread"
);

# #############################################################################
# Done.
# #############################################################################
exit;
