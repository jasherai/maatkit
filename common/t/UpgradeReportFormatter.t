#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

require '../Transformers.pm';
require '../EventAggregator.pm';
require '../QueryRewriter.pm';
require '../ReportFormatter.pm';
require '../UpgradeReportFormatter.pm';

my $result;
my $expected;
my ($meta_events, $events1, $events2, $meta_ea, $ea1, $ea2);

my $qr  = new QueryRewriter();
my $urf = new UpgradeReportFormatter();

sub aggregate {
   foreach my $event (@$meta_events) {
      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
      $meta_ea->aggregate($event);
   }
   foreach my $event (@$events1) {
      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
      $ea1->aggregate($event);
   }
   foreach my $event (@$events2) {
      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
      $ea2->aggregate($event);
   }
}

$meta_ea = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'differences',
);
$ea1 = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
);
$ea2 = new EventAggregator(
   groupby => 'fingerprint',
   worst   => 'Query_time',
);

isa_ok($urf, 'UpgradeReportFormatter');

$events1 = [
   {
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '8.000652',
      pos_in_log    => 1,
      db            => 'test1',
   },
   {
      cmd  => 'Query',
      arg           => "SELECT id FROM users WHERE name='foo'",
      Query_time    => '1.001943',
      pos_in_log    => 2,
      db            => 'test1',
   },
   {
      cmd           => 'Query',
      arg           => "SELECT id FROM users WHERE name='bar'",
      Query_time    => '1.000682',
      pos_in_log    => 5,
      db            => 'test1',
   },
];
$events2 = $events1;
$meta_events = [
   {
      arg => "SELECT id FROM users WHERE name='bar'",
      differences          => 0,
      different_row_counts => 0,
      different_checksums  => 0,
   },
   {
      arg => "SELECT id FROM users WHERE name='bar'",
      differences          => 0,
      different_row_counts => 0,
      different_checksums  => 0,
   },
   {
      arg => "SELECT id FROM users WHERE name='bar'",
      differences          => 1,
      different_row_counts => 1,
      different_checksums  => 0,
   },
];

$expected = <<EOF;
# Query 1: ID 0x82860EDA9A88FCC5 at byte 0 _______________________________
Found 1 differences in 3 samples:
  checksums     0
  row counts    1
EOF

aggregate();

$result = $urf->event_report(
   meta_ea  => $meta_ea,
   host_eas => [$ea1, $ea2],
   where   => 'select id from users where name=?',
   rank    => 1,
   worst   => 'differences',
);

is($result, $expected, 'Event report');

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $urf->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
