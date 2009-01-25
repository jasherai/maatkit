#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 19;
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
      db            => 'test3',
   },
   {  ts   => '071015 21:43:52',
      cmd  => 'Query',
      user => 'root',
      host => 'localhost',
      ip   => '',
      arg =>
         "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
      Query_time    => '0.001943',
      Lock_time     => '0.000145',
      Rows_sent     => 0,
      Rows_examined => 0,
      pos_in_log    => 1,
      db            => 'test1',
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
      db            => 'test1',
   }
];

$expected = <<EOF;
# Overall: 3 total, 2 unique, 0 QPS ______________________________________
#                    total     min     max     avg     95%  stddev  median
# Exec time            3ms   652us     2ms     1ms     2ms   645us   657us
# Lock time          455us   109us   201us   151us   204us    46us   108us
# Rows sent              2       0       1    0.67    1.04    0.50       0
# Rows exam              3       0       2       1    2.06    0.59    1.04
# Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:52
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
   groupby => 'fingerprint',
);

is($result, $expected, 'Global report');
