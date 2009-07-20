#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 19;

require '../Processlist.pm';
require '../MaatkitTest.pm';
require '../TextResultSetParser.pm';

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

my $pl  = new Processlist();
my $rsp = new TextResultSetParser();

MaatkitTest->import(qw(load_file));

my @events;
my $callback = sub { push @events, @_ };
my $prev     = [];

# An unfinished query doesn't crash anything.
@events = ();
$pl->parse_event(
   sub {
      return [
         [1, 'unauthenticated user', 'localhost', undef, 'Connect', undef,
         'Reading from net', undef],
      ],
   },
   {
      prev => $prev,
      time => 1000,
   },
   $callback,
);
is_deeply($prev, [], 'Prev does not know about undef query');
is(scalar @events, 0, 'No events fired from connection in process');

# Make a new one to replicate a bug with certainty...
$pl = Processlist->new();

# An existing sleeping query that goes away doesn't crash anything.
@events = ();
$pl->parse_event(
   sub {
      return [
         [1, 'root', 'localhost', undef, 'Sleep', 7, '', undef],
      ],
   },
   {
      prev => $prev,
      time => 1000,
   },
   $callback,
);

# And now the connection goes away...
$pl->parse_event(
   sub {
      return [
      ],
   },
   {
      prev => $prev,
      time => 1001,
   },
   $callback,
);

is_deeply($prev, [], 'everything went away');
is(scalar @events, 0, 'No events fired from sleeping connection that left');

# Make sure there's a fresh start...
$pl = Processlist->new();

# The initial processlist shows a query in progress.
@events = ();
$pl->parse_event(
   sub {
      return [
         [1, 'root', 'localhost', 'test', 'Query', 2, 'executing', 'query1_1'],
      ],
   },
   {
      prev => $prev,
      time => 1000,
      etime => .05,
   },
   $callback,
);

# The $prev array should now show that the query started at time 998.
is_deeply(
   $prev,
   [
      [1, 'root', 'localhost', 'test', 'Query', 2,
         'executing', 'query1_1', 998, .05, 1000 ],
   ],
   'Prev knows about the query',
);

is(scalar @events, 0, 'No events fired');

# The next processlist shows a new query in progress and the other one is not
# there anymore at all.
@events = ();
$pl->parse_event(
   sub {
      return [
         [2, 'root', 'localhost', 'test', 'Query', 1, 'executing', 'query2_1'],
      ],
   },
   {
      prev => $prev,
      time => 1001,
      etime => .03,
   },
   $callback,
);

# The $prev array should not have the first one anymore, just the second one.
is_deeply(
   $prev,
   [
      [2, 'root', 'localhost', 'test', 'Query', 1,
         'executing', 'query2_1', 1000, .03, 1001],
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
         ts         => 1000,
         Query_time => 2,
         Lock_time  => 0,
         id         => 1,
      },
   ],
   'query1_1 fired',
);

# In this sample, the query on cxn 2 is finished, but the connection is still
# open.
@events = ();
$pl->parse_event(
   sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Sleep', 0, '', undef],
      ],
   },
   {
      prev => $prev,
      time => 1002,
   },
   $callback,
);

# And so as a result, query2_1 has fired and the prev array is empty.
is_deeply(
   $prev,
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
         ts         => 1001,
         Query_time => 1,
         Lock_time  => 0,
         id         => 2,
      },
   ],
   'query2_1 fired',
);

# In this sample, cxn 2 is running a query, with a start time at the current
# time of 1003.
@events = ();
$pl->parse_event(
   sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
      ],
   },
   {
      prev => $prev,
      time => 1003,
      etime => 3.14159,
   },
   $callback,
);

is_deeply(
   $prev,
   [
      [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
      1003, 3.14159, 1003 ],
   ],
   'Prev says query2_2 just started',
);

# And there is no event on cxn 2.
is_deeply(
   \@events,
   [],
   'query2_2 is not fired yet',
);

# In this sample, the "same" query is running one second later and this time
# it seems to have a start time of 1005, which is not enough to be a new query.
@events = ();
$pl->parse_event(
   sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
      ],
   },
   {
      prev => $prev,
      time => 1005,
      etime => 2.718,
   },
   $callback,
);

# And so as a result, query2_2 has NOT fired, but the prev array contains the
# query2_2 still.
is_deeply(
   $prev,
   [
      [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
      1003, 3.14159, 1003 ],
   ],
   'After query2_2 fired, the prev array has the one starting at 1003',
);

is(scalar(@events), 0, 'It did not fire yet');

# But wait!  There's another!  And this time we catch it!
@events = ();
$pl->parse_event(
   sub {
      return [
         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
      ],
   },
   {
      prev => $prev,
      time => 1008.5,
      etime => 0.123,
   },
   $callback,
);

# And so as a result, query2_2 has fired and the prev array contains the "new"
# query2_2.
is_deeply(
   $prev,
   [
      [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
      1008, 0.123, 1008.5 ],
   ],
   'After query2_2 fired, the prev array has the one starting at 1008',
);

# And the query has fired an event.
is_deeply(
   \@events,
   [  {  db         => 'test',
         user       => 'root',
         host       => 'localhost',
         arg        => 'query2_2',
         bytes      => 8,
         ts         => 1003,
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
         $rsp->parse(load_file('samples/recset003.txt')),
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

# #############################################################################
# Done.
# #############################################################################
exit;
