#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;
use English qw(-no_match_vars);

require '../QueryRewriter.pm';
require '../SQLMetrics.pm';

my $qr = new QueryRewriter();

use Data::Dumper;
$Data::Dumper::Indent = 1;

my $handlers = [
   SQLMetrics::make_handler_for('Query_time', 'number'),
   SQLMetrics::make_handler_for('user', 'string'),
];

my $m  = new SQLMetrics(
   key_metric      => 'arg',
   fingerprint     => sub { return $qr->fingerprint(@_); },
   handlers        => $handlers,
   buffer_n_events => -1,
);

isa_ok($m, 'SQLMetrics');

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
      NR            => 5,
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
      NR            => 8,
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
      NR            => 11,
   }
];

my $metrics = {
   'unique' => {
      'insert ignore into articles (id, body,)values(N+)' => {
         'count' => 1,
         'Query_time' => {
            'avg' => '0.001943',
            'min' => '0.001943',
            'max' => '0.001943',
            'all_vals' => [
            '0.001943'
            ],
            'total' => '0.001943',
            last => '0.001943',
         },
         'user' => {
            'root' => 1,
         },
         'sample' => 'INSERT IGNORE INTO articles (id, body,)VALUES(3558268,\'sample text\')'
      },
      'select id from users where name=S' => {
         'count' => 2,
         'Query_time' => {
            'avg' => '0.000667',
            'min' => '0.000652',
            'max' => '0.000682',
            'all_vals' => [
               '0.000652',
               '0.000682'
            ],
            total    => '0.001334',
            last     => '0.000682',
         },
         'user' => {
            bob   => 1,
            root  => 1,
         },
         'sample' => 'SELECT id FROM users WHERE name=\'foo\''
      }
   },
   all => {
      'Query_time' => {
         'avg' => '0.00109233333333333',
         'min' => '0.000652',
         'max' => '0.001943',
         'total' => '0.003277',
      },
      'user' => {
         'bob'  => 1,
         'root' => 2,
      },
   },
};

foreach my $event ( @$events ) {
   $m->record_event($event);
}
$m->calc_metrics();
is_deeply($m->{metrics}, $metrics, 'Calcs buffered metrics');

$m->reset_metrics();
$m->{buffer_n_events} = 1;
foreach my $event ( @$events ) {
   $m->record_event($event);
}
is_deeply($m->{metrics}, $metrics, 'Calcs metrics one-by-one');

# #############################################################################
# Test that the sample of the worst occurrence is saved.
# #############################################################################

$m  = new SQLMetrics(
   key_metric      => 'arg',
   fingerprint     => sub { return $qr->fingerprint(@_); },
   handlers        => $handlers,
   worst_metric    => 'Query_time',
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

$metrics = {
   'unique' => {
      'foo N' => {
         'count' => 3,
         'Query_time' => {
            'avg' => '1.33333333333333',
            'min' => '1',
            'max' => '2',
            'all_vals' => [
               '1', '2', '1',
            ],
            'total' => '4',
            last => 1,
         },
         'user' => {
            'bob' => 2,
            'root' => 1,
         },
         'sample' => 'foo 2'
      },
   },
   all => {
      'Query_time' => {
         'avg' => '1.33333333333333',
         'min' => '1',
         'max' => '2',
         'total' => '4',
      },
      'user' => {
         'bob'  => 2,
         'root' => 1,
      },
   },
};

foreach my $event ( @$events ) {
   $m->calc_event_metrics($event);
}
is_deeply($m->{metrics}, $metrics, 'Keeps worst sample');

# #############################################################################
# Test statistical metrics: 95% avg, stddev and median
# #############################################################################
my $expected_stats = {
   avg       => 3.25,
   stddev    => 2.2,
   median    => 3,
   distro    => [],
   cutoff    => 12,
};
my $stats = $m->calculate_statistical_metrics([2,3,6,4,8,9,1,1,1,5,4,3,1]);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics'
);

$expected_stats = {
   avg       => 0,
   stddev    => 0,
   median    => 0,
   distro    => [],
   cutoff    => undef,
};
$stats = $m->calculate_statistical_metrics(undef);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics for undef array'
);

$stats = $m->calculate_statistical_metrics([]);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics for empty array'
);
 
$expected_stats = {
   avg       => 9,
   stddev    => 0,
   median    => 9,
   distro    => [],
   cutoff    => undef,
};
$stats = $m->calculate_statistical_metrics([9]);
is_deeply(
   $stats,
   $expected_stats,
   'Calculates statistical metrics for 1 value'
);

exit;
