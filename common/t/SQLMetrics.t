#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 16;
use English qw(-no_match_vars);
use Data::Dumper;

require '../QueryRewriter.pm';
require '../SQLMetrics.pm';

my $qr = new QueryRewriter();

my $sm  = new SQLMetrics(
   group_by        => 'fingerprint',
   attributes      => [qw(Query_time user ts Rows_sent)],
);

isa_ok($sm, 'SQLMetrics');

my $events = [
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
            min => 'bob',
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
            min => 1,
            max => 1,
            all => [1, 1],
            sum => 2,
            cnt => 2,
         }
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
            all => [0],
            sum => 0,
            cnt => 1,
         }
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
      },
   }
};

foreach my $event ( @$events ) {
   $event->{fingerprint} = $qr->fingerprint($event->{arg});
   $sm->calc_event_metrics($event);
}
is_deeply($sm->{metrics}, $metrics, 'Calcs metrics');
is($sm->{n_events}, 3, 'Got 3 events');
is($sm->{n_queries}, 3, 'Got 3 queries');

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
is($sm->{metrics}->{unique}->{'foo ?'}->{Query_time}->{sample}->{arg},
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

my $handler = $sm->make_handler('foo', {foo => 0});
is(ref $handler, 'CODE', 'make_handler with 0 as sample value');

# #############################################################################
# Make sure it doesn't die when I try to parse an event that doesn't have an
# expected attribute.
# #############################################################################
$sm  = new SQLMetrics(
   group_by        => 'fingerprint',
   attributes      => [qw(foobar)],
);
eval {
   $sm->calc_event_metrics({ fingerprint => 'foo' });
};
is($EVAL_ERROR, '', "Handles an undef attrib OK");

# And, make sure it didn't create a "fast" version of the subroutine yet --
# there should not have been enough information to do so.
is($sm->{unrolled_loops}, undef, 'Waits till all samples to unroll loops');

# After a while, it should give up and unroll the loops.
$sm->calc_event_metrics({ fingerprint => 'foo' }) for (0 .. 55);
like($sm->{unrolled_loops}, qr/CODE/, 'Gives up, unrolls loops');

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

$sm  = new SQLMetrics(
   group_by        => 'arg',
   attributes      => [qw(Rows_read)],
   worst_attrib    => 'Rows_read',
   attrib_limit    => 1000,
);
$events = [
   {
      arg         => "SELECT template FROM template WHERE title='options'",
      Rows_read   => 4,
   },
   {
      arg         => "# administrator command: Init DB;",
      Rows_read   => 4124524590823728995,
   },
   {
      arg         => "SELECT template FROM template WHERE title='options'",
      Rows_read   => 4124524590823728995,
   },
];
foreach my $event ( @$events ) {
   $sm->calc_event_metrics($event);
}
is_deeply(
   $sm->{metrics},
   {  'unique' => {
         '# administrator command: Init DB;' => {
            'Rows_read' => {
               'min'    => 0,
               'max'    => 0,
               'sample' => {
                  'Rows_read' => '4.12452459082373e+18',
                  'arg'       => '# administrator command: Init DB;'
               },
               'all' => [ '0' ],
               'sum' => 0,
               'cnt' => 1
            }
         },
         'SELECT template FROM template WHERE title=\'options\'' => {
            'Rows_read' => {
               'min'    => 4,
               'max'    => 4,
               'sample' => {
                  'Rows_read' => '4.12452459082373e+18',
                  'arg' =>
                     'SELECT template FROM template WHERE title=\'options\''
               },
               'all' => [ 4, 4 ],
               'sum' => 8,
               'cnt' => 2
            }
         }
      },
      'all' => {
         'Rows_read' => {
            'min' => 0,
            'max' => 4,
            'sum' => 8,
            'cnt' => 3
         }
      }
   },
   'attrib_limit prevents big values',
);
