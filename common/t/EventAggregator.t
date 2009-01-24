#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;
use English qw(-no_match_vars);
use Data::Dumper;

require '../QueryRewriter.pm';
require '../EventAggregator.pm';

my $qr = new QueryRewriter();
my ($result, $events, $ea);

$ea  = new EventAggregator(
   classes => {
      fingerprint => {
         Query_time => [qw(Query_time)],
         user       => [qw(user)],
         ts         => [qw(ts)],
         Rows_sent  => [qw(Rows_sent)],
      },
   },
);

isa_ok($ea, 'EventAggregator');

$events = [
   {  cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '0.000652',
      Lock_time     => '0.000109',
      Rows_sent     => 1,
      Rows_examined => 1,
      pos_in_log    => 0,
   },
   {  ts   => '071015 21:43:52',
      cmd  => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg  => "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      Query_time    => '0.001943',
      Lock_time     => '0.000145',
      Rows_sent     => 0,
      Rows_examined => 0,
      pos_in_log    => 1,
   },
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'bob',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='bar'",
      Query_time    => '0.000682',
      Lock_time     => '0.000201',
      Rows_sent     => 1,
      Rows_examined => 2,
      pos_in_log    => 5,
   }
];

$result = {
   fingerprint => {
      'select id from users where name=?' => {
         Query_time => {
            min => '0.000652',
            max => '0.000682',
            # all => [ '0.000652', '0.000682' ] # buckets 133, 134
            all => [ (map { 0 } (0 .. 132)), 1, 1, (map{0}(135..999))],
            sum => '0.001334',
            cnt => 2
         },
         user => {
            unq => {
               bob  => 1,
               root => 1
            },
            min => 'bob',
            max => 'root',
         },
         ts => {
            min => '071015 21:43:52',
            max => '071015 21:43:52',
            unq => {
               '071015 21:43:52' => 1,
            },
         },
         Rows_sent => {
            min => 1,
            max => 1,
            # all => [1, 1],
            all => [ (map { 0 } (0 .. 283)), 2, (map{0}(285..999))],
            sum => 2,
            cnt => 2,
         }
      },
      'insert ignore into articles (id, body,)values(?+)' => {
         Query_time => {
            min => '0.001943',
            max => '0.001943',
            # all => [ '0.001943' ],
            all => [ (map { 0 } (0 .. 155)), 1, (map{0}(157..999))],
            sum => '0.001943',
            cnt => 1
         },
         user => {
            unq => { root => 1 },
            min => 'root',
            max => 'root',
         },
         ts => {
            min => '071015 21:43:52',
            max => '071015 21:43:52',
            unq => {
               '071015 21:43:52' => 1,
            }
         },
         Rows_sent => {
            min => 0,
            max => 0,
            all => [ (map { 0 } (0..283)), 1, (map {0}(285..999)) ],
            sum => 0,
            cnt => 1,
         }
      }
   },
};

foreach my $event ( @$events ) {
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $ea->aggregate($event);
}

is_deeply($ea->results->{classes}, $result, 'Simple fingerprint aggregation');

$ea  = new EventAggregator(
   classes => {},
   globals => {
      Query_time => [qw(Query_time)],
      user       => [qw(user)],
      ts         => [qw(ts)],
      Rows_sent  => [qw(Rows_sent)],
   },
);

$result = {
   Query_time => {
      min => '0.000652',
      max => '0.001943',
      sum => '0.003277',
      cnt => 3,
      all => [
         (map { 0 } (0 .. 132)),
         1, 1,
         (map{0}(135..155)),
         1,
         (map{0}(157..999)),
      ],
   },
   user => {
      min => 'bob',
      max => 'root',
   },
   ts => {
      min => '071015 21:43:52',
      max => '071015 21:43:52',
   },
   Rows_sent => {
      min => 0,
      max => 1,
      sum => 2,
      cnt => 3,
      all => [
         (map { 0 } (0 .. 283)),
         3,
         (map{0}(285..999)),
      ],
   },
};

foreach my $event ( @$events ) {
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $ea->aggregate($event);
}

is_deeply($ea->results->{globals}, $result, 'Simple fingerprint aggregation all');

# #############################################################################
# Test that the sample of the worst occurrence is saved.
# #############################################################################

$ea  = new EventAggregator(
   classes => {
      arg => {
         Query_time => [qw(Query_time)],
      },
   },
   save => 'Query_time',
);

$events = [
   {
      user        => 'bob',
      arg         => "foo 1",
      Query_time  => '1',
   },
   {
      user          => 'root',
      arg           => "foo 1",
      Query_time    => '5',
   }
];

foreach my $event ( @$events ) {
   $ea->aggregate($event);
}

is($ea->results->{classes}->{arg}->{'foo 1'}->{Query_time}->{sample}->{user}, 'root',
   "Keeps the worst sample");

# #############################################################################
# Test bucketizing a straightforward list.
# #############################################################################
is_deeply(
   [$ea->bucketize([2,3,6,4,8,9,1,1,1,5,4,3,1])],
   [
      [
         (map{0} (0..283)),
         4,
         (map{0} (285..297)),
         1,
         (map{0} (299..305)),
         2,
         (map{0} (307..311)),
         2,0,0,0,1,0,0,0,1,0,0,0,0,0,1,0,0,1,
         (map{0} (330..999)),
      ],
      {  sum => 48,
         max => 9,
         min => 1,
         cnt => 13,
      },
   ],
   'Bucketizes values right',
);

is_deeply(
   [$ea->unbucketize($ea->bucketize([2,3,6,4,8,9,1,1,1,5,4,3,1]))],
   # If there were no loss of precision, we'd get this:
   # [1, 1, 1, 1, 2, 3, 3, 4, 4, 5, 6, 8, 9]
   # But we have only 5% precision in the buckets, so...
   [  '1.04174382747661', '1.04174382747661',
      '1.04174382747661', '1.04174382747661',
      '2.06258152254188', '3.04737229873823',
      '3.04737229873823', '4.08377033290049',
      '4.08377033290049', '4.96384836320513',
      '6.03358870952811', '8.08558592696284',
      '9.36007640870036'
   ],
   "Unbucketizes okay",
);
