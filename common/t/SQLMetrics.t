#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 10;
use English qw(-no_match_vars);
use Data::Dumper;

require '../QueryRewriter.pm';
require '../SQLMetrics.pm';

my $qr = new QueryRewriter();

my $sm  = new SQLMetrics(
   group_by        => 'fingerprint',
   attributes      => [qw(Query_time user)],
);

isa_ok($sm, 'SQLMetrics');

my $events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
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
   {
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

my $metrics = {
   unique => {
      'select id from users where name=?' => {
         Query_time => {
            min => '0.000652',
            max => '0.000682',
            all => [ '0.000652', '0.000682' ],
            sum => '0.001334',
            cnt => 2
         },
         user => {
            unq => {
               bob  => 1,
               root => 1
            },
         },
      },
      'insert ignore into articles (id, body,)values(?+)' => {
         Query_time => {
            min => '0.001943',
            max => '0.001943',
            all => [ '0.001943' ],
            sum => '0.001943',
            cnt => 1
         },
         user => {
            unq => { root => 1 },
         },
      }
   },
   all => {
      Query_time => {
         min => '0.000652',
         max => '0.001943',
         sum => '0.003277',
         cnt => 3
      },
      user => {
      }
   }
};

foreach my $event ( @$events ) {
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $sm->calc_event_metrics($event);
}
is_deeply($sm->{metrics}, $metrics, 'Calcs metrics');

# #############################################################################
# Test that the sample of the worst occurrence is saved.
# #############################################################################

$sm  = new SQLMetrics(
   group_by        => 'fingerprint',
   attributes      => [qw(Query_time user)],
   worst_attrib    => 'Query_time',
);

$events = [
   {
      cmd         => 'Query',
      user        => 'bob',
      arg         => "foo 1",
      Query_time  => '1',
   },
   {
      cmd         => 'Query',
      user        => 'bob',
      arg         => "foo 2",
      Query_time  => '2',
   },
   {
      cmd           => 'Query',
      user          => 'root',
      arg           => "foo 3",
      Query_time    => '1',
   }
];

foreach my $event ( @$events ) {
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $sm->calc_event_metrics($event);
}
is($sm->{metrics}->{unique}->{'foo ?'}->{Query_time}->{sample},
   'foo 2', 'Keeps worst sample for Query_time');

# #############################################################################
# Test statistical metrics: 95% avg, stddev and median
# #############################################################################
my $expected_stats = {
   avg       => 3.25,
   stddev    => 2.26133508433323,
   median    => 3,
   distro    => [qw(0 0 0 0 0 0 13 0)],
   cutoff    => 12,
   max       => 8,
};
my $stats = $sm->calculate_statistical_metrics([2,3,6,4,8,9,1,1,1,5,4,3,1],
                                              distro => 1);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics'
);

$expected_stats = {
   avg       => 0,
   stddev    => 0,
   median    => 0,
   distro    => [qw(0 0 0 0 0 0 0 0)],
   cutoff    => undef,
   max       => 0,
};
$stats = $sm->calculate_statistical_metrics(undef, distro=>1);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics for undef array'
);

$stats = $sm->calculate_statistical_metrics([], distro=>1);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics for empty array'
);
 
$expected_stats = {
   avg       => 0.9,
   stddev    => 0,
   median    => 0.9,
   distro    => [qw(0 0 0 0 0 1 0 0)],
   cutoff    => 1,
   max       => 0.9,
};
$stats = $sm->calculate_statistical_metrics([0.9], distro=>1);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics for 1 value'
);

my $handler = SQLMetrics::make_handler('foo', 0);
is(ref $handler, 'CODE', 'make_handler with 0 as sample value');

# #############################################################################
# Issue 184:
# #############################################################################
$sm  = new SQLMetrics(
   group_by        => 'fingerprint',
   attributes      => [qw(db|Schema)],
   worst_attrib    => 'Query_time',
);

$events = [
   {
      arg         => "foo 1",
      Query_time  => '1',
      Schema      => 'db1',
   },
   {
      arg         => "foo 2",
      Query_time  => '2',
      Schema      => 'db1',
   },
];
foreach my $event ( @$events ) {
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $sm->calc_event_metrics($event);
}
ok(exists $sm->{metrics}->{unique}->{'foo ?'}->{db}->{unq}->{db1},
   'Gets Schema for db|Schema (issue 184)');

$sm  = new SQLMetrics(
   group_by        => 'fingerprint',
   attributes      => [qw(Schema|db)],
   worst_attrib    => 'Query_time',
);

$events = [
   {
      arg         => "foo 1",
      Query_time  => '1',
      db          => 'db1',
   },
   {
      arg         => "foo 2",
      Query_time  => '2',
      db          => 'db1',
   },
];
foreach my $event ( @$events ) {
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $sm->calc_event_metrics($event);
}
ok(exists $sm->{metrics}->{unique}->{'foo ?'}->{Schema}->{unq}->{db1},
   'Gets db for Schema|db (issue 184)');
exit;
