#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 5;
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

require '../Transformers.pm';
require '../QueryReportFormatter.pm';
require '../EventAggregator.pm';
require '../QueryRewriter.pm';

my ( $qrf, $result, $events, $expected, $qr, $ea );

$qr  = new QueryRewriter();
$qrf = new QueryReportFormatter();
$ea  = new EventAggregator(
   save    => 'Query_time',
   classes => {
      fingerprint => {
         Query_time    => [qw(Query_time)],
         Lock_time     => [qw(Lock_time)],
         user          => [qw(user)],
         ts            => [qw(ts)],
         Rows_sent     => [qw(Rows_sent)],
         Rows_examined => [qw(Rows_examined)],
         db            => [qw(db)],
      },
   },
   globals => {
      Query_time    => [qw(Query_time)],
      Lock_time     => [qw(Lock_time)],
      user          => [qw(user)],
      ts            => [qw(ts)],
      Rows_sent     => [qw(Rows_sent)],
      Rows_examined => [qw(Rows_examined)],
      db            => [qw(db)],
   }
);

isa_ok( $qrf, 'QueryReportFormatter' );

$result = $qrf->header();
like($result,
   qr/^# \S+ user time, \S+ system time, \S+ rss, \S+ vsz/s,
   'Header looks ok');

$events = [
   {  ts            => '071015 21:43:52',
      cmd           => 'Query',
      user          => 'root',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '8.000652',
      Lock_time     => '0.000109',
      Rows_sent     => 1,
      Rows_examined => 1,
      pos_in_log    => 1,
      db            => 'test3',
   },
   {  ts   => '071015 21:43:52',
      cmd  => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg =>
         "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      Query_time    => '1.001943',
      Lock_time     => '0.000145',
      Rows_sent     => 0,
      Rows_examined => 0,
      pos_in_log    => 2,
      db            => 'test1',
   },
   {  ts            => '071015 21:43:53',
      cmd           => 'Query',
      user          => 'bob',
      host          => 'localhost',
      ip            => '',
      arg           => "SELECT id FROM users WHERE name='bar'",
      Query_time    => '1.000682',
      Lock_time     => '0.000201',
      Rows_sent     => 1,
      Rows_examined => 2,
      pos_in_log    => 5,
      db            => 'test1',
   }
];

$expected = <<EOF;
# Overall: 3 total, 2 unique, 3 QPS, 10.00x concurrency __________________
#                    total     min     max     avg     95%  stddev  median
# Exec time            10s      1s      8s      3s      8s      3s      1s
# Lock time          455us   109us   201us   151us   204us    46us   108us
# Rows sent              2       0       1    0.67    1.04    0.50       0
# Rows exam              3       0       2       1    2.06    0.59    1.04
# Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:53
EOF

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

$result = $qrf->global_report(
   $ea,
   attributes => [
      qw(Query_time Lock_time Rows_sent Rows_examined ts)
   ],
   worst   => 'Query_time',
   groupby => 'fingerprint',
);

is($result, $expected, 'Global report');

$expected = <<EOF;
# Query 1: 3 QPS, 9.00x concurrency, ID 0x82860EDA9A88FCC5 at byte 1 _____
#              pct   total     min     max     avg     95%  stddev  median
# Count         66       2
# Exec time     89      9s      1s      8s      5s      8s      5s      5s
# Lock time     68   310us   109us   201us   155us   201us    65us   155us
# Rows sent    100       2       1       1       1       1       0       1
# Rows exam    100       3       1       2    1.50       2    0.71    1.50
# Time range 2007-10-15 21:43:52 to 2007-10-15 21:43:53
# Databases      2  test1:1 test3:1
# Users          2  bob:1 root:1
EOF

$result = $qrf->event_report(
   $ea,
   attributes => [
      qw(Query_time Lock_time Rows_sent Rows_examined ts db user)
   ],
   groupby => 'fingerprint',
   which   => 'select id from users where name=?',
   rank    => 1,
   worst   => 'Query_time',
);

is($result, $expected, 'Event report');

$expected = <<EOF;
# Query_time distribution
#   1us
#  10us
# 100us
#   1ms
#  10ms
# 100ms
#    1s  ################################################################
#  10s+
EOF

$result = $qrf->chart_distro(
   $ea,
   attribute => 'Query_time',
   groupby   => 'fingerprint',
   which     => 'select id from users where name=?',
);

is($result, $expected, 'Query_time distro');
