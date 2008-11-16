#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use English qw(-no_match_vars);

require '../SQLMetrics.pm';
require '../LogMetricsSlow.pm';

use Data::Dumper;
$Data::Dumper::Indent = 1;

my $slow_metrics = new LogMetricsSlow;
isa_ok($slow_metrics, 'LogMetricsSlow');

my $h = { $slow_metrics->get_handlers_for(qw(Query_time Lock_time)) };
is_deeply(
   $h,
   {
      'Query_time' => {
      'all_all_vals' => 0,
      'min' => '1',
      'avg' => 1,
      'max' => '1',
      'all_vals' => 1,
      'total' => 1,
      'transformer' => undef,
      'all_events' => 1,
      'type' => 1
      },
      'Lock_time' => {
      'all_all_vals' => 0,
      'min' => '1',
      'avg' => 1,
      'max' => '1',
      'all_vals' => 1,
      'total' => 1,
      'transformer' => undef,
      'type' => 1,
      'all_events' => 1
      },
   },
   'Gets basic handlers',
);

exit;
