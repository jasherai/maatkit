#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 24;
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 0;

require '../QueryRewriter.pm';
require '../EventAggregator.pm';
require '../QueryParser.pm';

my $qr = new QueryRewriter();
my $qp = new QueryParser();
my ( $result, $events, $ea, $expected );

$ea = new EventAggregator(
   groupby    => 'fingerprint',
   worst      => 'Query_time',
   attributes => {
      Query_time => [qw(Query_time)],
      user       => [qw(user)],
      ts         => [qw(ts)],
      Rows_sent  => [qw(Rows_sent)],
   },
);

isa_ok( $ea, 'EventAggregator' );

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
      arg =>
         "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
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
   'select id from users where name=?' => {
      Query_time => {
         min => '0.000652',
         max => '0.000682',
         all =>
            [ ( map {0} ( 0 .. 132 ) ), 1, 1, ( map {0} ( 135 .. 999 ) ) ],
         sum => '0.001334',
         cnt => 2,
         sample =>
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
            fingerprint   => 'select id from users where name=?',
         },
      },
      user => {
         unq => {
            bob  => 1,
            root => 1
         },
         min => 'bob',
         max => 'root',
         cnt => 2,
      },
      ts => {
         min => '071015 21:43:52',
         max => '071015 21:43:52',
         unq => { '071015 21:43:52' => 1, },
         cnt => 1,
      },
      Rows_sent => {
         min => 1,
         max => 1,
         all =>
            [ ( map {0} ( 0 .. 283 ) ), 2, ( map {0} ( 285 .. 999 ) ) ],
         sum => 2,
         cnt => 2,
      }
   },
   'insert ignore into articles (id, body,)values(?+)' => {
      Query_time => {
         min => '0.001943',
         max => '0.001943',
         all =>
            [ ( map {0} ( 0 .. 155 ) ), 1, ( map {0} ( 157 .. 999 ) ) ],
         sum => '0.001943',
         cnt => 1,
         sample =>
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
            fingerprint   => 'insert ignore into articles (id, body,)values(?+)',
         },
      },
      user => {
         unq => { root => 1 },
         min => 'root',
         max => 'root',
         cnt => 1,
      },
      ts => {
         min => '071015 21:43:52',
         max => '071015 21:43:52',
         unq => { '071015 21:43:52' => 1, },
         cnt => 1,
      },
      Rows_sent => {
         min => 0,
         max => 0,
         all =>
            [ ( map {0} ( 0 .. 283 ) ), 1, ( map {0} ( 285 .. 999 ) ) ],
         sum => 0,
         cnt => 1,
      }
   }
};

foreach my $event (@$events) {
   $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
   $ea->aggregate($event);
}

is_deeply( $ea->results->{classes},
   $result, 'Simple fingerprint aggregation' );

is_deeply(
   $ea->attributes,
   {  Query_time => 'num',
      user       => 'string',
      ts         => 'string',
      Rows_sent  => 'num',
   },
   'Found attribute types',
);

$result = {
   Query_time => {
      min => '0.000652',
      max => '0.001943',
      sum => '0.003277',
      cnt => 3,
      all => [
         ( map {0} ( 0 .. 132 ) ),
         1, 1, ( map {0} ( 135 .. 155 ) ),
         1, ( map {0} ( 157 .. 999 ) ),
      ],
   },
   user => {
      min => 'bob',
      max => 'root',
      cnt => 3,
   },
   ts => {
      min => '071015 21:43:52',
      max => '071015 21:43:52',
      cnt => 2,
   },
   Rows_sent => {
      min => 0,
      max => 1,
      sum => 2,
      cnt => 3,
      all => [ ( map {0} ( 0 .. 283 ) ), 3, ( map {0} ( 285 .. 999 ) ), ],
   },
};

is_deeply( $ea->results->{globals},
   $result, 'Simple fingerprint aggregation all' );

# #############################################################################
# Test grouping on user
# #############################################################################
$ea = new EventAggregator(
   groupby    => 'user',
   worst      => 'Query_time',
   attributes => {
      Query_time => [qw(Query_time)],
      user       => [qw(user)], # It should ignore the groupby attribute
      ts         => [qw(ts)],
      Rows_sent  => [qw(Rows_sent)],
   },
);

$result = {
   classes => {
      bob => {
         ts => {
            min => '071015 21:43:52',
            max => '071015 21:43:52',
            unq => { '071015 21:43:52' => 1 },
            cnt => 1
         },
         Query_time => {
            min    => '0.000682',
            max    => '0.000682',
            sample => {
               cmd           => 'Query',
               arg           => 'SELECT id FROM users WHERE name=\'bar\'',
               ip            => '',
               ts            => '071015 21:43:52',
               fingerprint   => 'select id from users where name=?',
               host          => 'localhost',
               pos_in_log    => 5,
               Rows_examined => 2,
               user          => 'bob',
               Query_time    => '0.000682',
               Lock_time     => '0.000201',
               Rows_sent     => 1
            },
            all => [ ( map {0} ( 0 .. 133 ) ), 1, ( map {0} ( 135 .. 999 ) ) ],
            sum => '0.000682',
            cnt => 1
         },
         Rows_sent => {
            min => 1,
            max => 1,
            all => [ ( map {0} ( 0 .. 283 ) ), 1, ( map {0} ( 285 .. 999 ) ) ],
            sum => 1,
            cnt => 1
         }
      },
      root => {
         ts => {
            min => '071015 21:43:52',
            max => '071015 21:43:52',
            unq => { '071015 21:43:52' => 1 },
            cnt => 1
         },
         Query_time => {
            min    => '0.000652',
            max    => '0.001943',
            sample => {
               cmd => 'Query',
               arg =>
                  'INSERT IGNORE INTO articles (id, body,)VALUES(3558268,\'sample text\')',
               ip => '',
               ts => '071015 21:43:52',
               fingerprint =>
                  'insert ignore into articles (id, body,)values(?+)',
               host          => 'localhost',
               pos_in_log    => 1,
               Rows_examined => 0,
               user          => 'root',
               Query_time    => '0.001943',
               Lock_time     => '0.000145',
               Rows_sent     => 0
            },
            all => [
               ( map {0} ( 0 .. 132 ) ), 1,
               ( map {0} ( 134 .. 155 ) ), 1,
               ( map {0} ( 157 .. 999 ) )
            ],
            sum => '0.002595',
            cnt => 2
         },
         Rows_sent => {
            min => 0,
            max => 1,
            all => [ ( map {0} ( 0 .. 283 ) ), 2, ( map {0} ( 285 .. 999 ) ) ],
            sum => 1,
            cnt => 2
         }
      }
   },
   globals => {
      ts => {
         min => '071015 21:43:52',
         max => '071015 21:43:52',
         cnt => 2
      },
      Query_time => {
         min => '0.000652',
         max => '0.001943',
         all => [
            ( map {0} ( 0 .. 132 ) ), 1, 1,
            ( map {0} ( 135 .. 155 ) ), 1,
            ( map {0} ( 157 .. 999 ) )
         ],
         sum => '0.003277',
         cnt => 3
      },
      Rows_sent => {
         min => 0,
         max => 1,
         all => [ ( map {0} ( 0 .. 283 ) ), 3, ( map {0} ( 285 .. 999 ) ) ],
         sum => 2,
         cnt => 3
      }
   }
};

foreach my $event (@$events) {
   $ea->aggregate($event);
}

is_deeply( $ea->results, $result, 'user aggregation' );

# #############################################################################
# Test bucketizing a straightforward list.
# #############################################################################
is_deeply(
   [ $ea->bucketize( [ 2, 3, 6, 4, 8, 9, 1, 1, 1, 5, 4, 3, 1 ] ) ],
   [  [  ( map {0} ( 0 .. 283 ) ),
         4,
         ( map {0} ( 285 .. 297 ) ),
         1,
         ( map {0} ( 299 .. 305 ) ),
         2,
         ( map {0} ( 307 .. 311 ) ),
         2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1,
         ( map {0} ( 330 .. 999 ) ),
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
   [  $ea->unbucketize(
         $ea->bucketize( [ 2, 3, 6, 4, 8, 9, 1, 1, 1, 5, 4, 3, 1 ] )
      )
   ],

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

# #############################################################################
# Test statistical metrics: 95%, stddev, and median
# #############################################################################

$result = $ea->calculate_statistical_metrics(
   $ea->bucketize( [ 2, 3, 6, 4, 8, 9, 1, 1, 1, 5, 4, 3, 1 ] ) );
is_deeply(
   $result,
   {  stddev => 2.26493026699131,
      median => 3.04737229873823,
      cutoff => 12,
      pct_95 => 8.08558592696284,
   },
   'Calculates statistical metrics'
);

$result = $ea->calculate_statistical_metrics(
   $ea->bucketize( [ 1, 1, 1, 1, 2, 3, 4, 4, 4, 4, 6, 8, 9 ] ) );

# 95th pct: --------------------------^
# median:------------------^ = 3.5
is_deeply(
   $result,
   {  stddev => 2.23248737175256,
      median => 3.56557131581936,
      cutoff => 12,
      pct_95 => 8.08558592696284,
   },
   'Calculates median when it is halfway between two elements',
);

# This is a special case: only two values, widely separated.  The median should
# be exact (because we pass in min/max) and the stdev should never be bigger
# than half the difference between min/max.
$result = $ea->calculate_statistical_metrics(
   $ea->bucketize( [ 0.000002, 0.018799 ] ) );
is_deeply(
   $result,
   {  stddev => 0.0132914861659635,
      median => 0.0094005,
      cutoff => 2,
      pct_95 => 0.018799,
   },
   'Calculates stats for two-element special case',
);

$result = $ea->calculate_statistical_metrics(undef);
is_deeply(
   $result,
   {  stddev => 0,
      median => 0,
      cutoff => undef,
      pct_95 => 0,
   },
   'Calculates statistical metrics for undef array'
);

$result = $ea->calculate_statistical_metrics( [] );
is_deeply(
   $result,
   {  stddev => 0,
      median => 0,
      cutoff => undef,
      pct_95 => 0,
   },
   'Calculates statistical metrics for empty array'
);

$result = $ea->calculate_statistical_metrics( [ 1, 2 ], {} );
is_deeply(
   $result,
   {  stddev => 0,
      median => 0,
      cutoff => undef,
      pct_95 => 0,
   },
   'Calculates statistical metrics for when $stats missing'
);

$result = $ea->calculate_statistical_metrics( $ea->bucketize( [0.9] ) );
is_deeply(
   $result,
   {  stddev => 0,
      median => 0.9,
      cutoff => 1,
      pct_95 => 0.9,
   },
   'Calculates statistical metrics for 1 value'
);

# #############################################################################
# Make sure it doesn't die when I try to parse an event that doesn't have an
# expected attribute.
# #############################################################################
eval { $ea->aggregate( { fingerprint => 'foo' } ); };
is( $EVAL_ERROR, '', "Handles an undef attrib OK" );

# #############################################################################
# Issue 184: db OR Schema
# #############################################################################
$ea = new EventAggregator(
   groupby => 'arg',
   attributes => {
      db => [qw(db Schema)],
   },
   worst => 'foo',
);

$events = [
   {  arg    => "foo1",
      Schema => 'db1',
   },
   {  arg => "foo2",
      db  => 'db1',
   },
];
foreach my $event (@$events) {
   $ea->aggregate($event);
}

is( $ea->results->{classes}->{foo1}->{db}->{min},
   'db1', 'Gets Schema for db|Schema (issue 184)' );

is( $ea->results->{classes}->{foo2}->{db}->{min},
   'db1', 'Gets db for db|Schema (issue 184)' );

# #############################################################################
# Make sure large values are kept reasonable.
# #############################################################################
$ea = new EventAggregator(
   attributes   => { Rows_read => [qw(Rows_read)], },
   attrib_limit => 1000,
   worst        => 'foo',
   groupby      => 'arg',
);

$events = [
   {  arg       => "arg1",
      Rows_read => 4,
   },
   {  arg       => "arg2",
      Rows_read => 4124524590823728995,
   },
   {  arg       => "arg1",
      Rows_read => 4124524590823728995,
   },
];

foreach my $event (@$events) {
   $ea->aggregate($event);
}

$result = {
   classes => {
      'arg1' => {
         Rows_read => {
            min => 4,
            max => 4,
            all =>
               [ ( map {0} ( 0 .. 311 ) ), 2, ( map {0} ( 313 .. 999 ) ) ],
            sum    => 8,
            cnt    => 2,
            'last' => 4,
         }
      },
      'arg2' => {
         Rows_read => {
            min => 0,
            max => 0,
            all =>
               [ ( map {0} ( 0 .. 283 ) ), 1, ( map {0} ( 285 .. 999 ) ) ],
            sum    => 0,
            cnt    => 1,
            'last' => 0,
         }
      },
   },
   globals => {
      Rows_read => {
         min => 0, # Because 'last' is only kept at the class level
         max => 4,
         all => [
            ( map {0} ( 0 .. 283 ) ), 1,
            ( map {0} ( 285 .. 311 ) ),
            2,
            ( map {0} ( 313 .. 999 ) ),
         ],
         sum => 8,
         cnt => 3,
      },
   },
};

is_deeply( $ea->results, $result, 'Limited attribute values', );

# #############################################################################
# For issue 171, the enhanced --top syntax, we need to pick events by complex
# criteria.  It's too messy to do with a log file, so we'll do it with an event
# generator function.
# #############################################################################
{
   my $i = 0;
   my @event_specs = (
      # fingerprint, time, count; 1350 seconds total
      [ 'event0', 10, 1   ], # An outlier, but happens once
      [ 'event1', 10, 5   ], # An outlier, but not in top 95%
      [ 'event2', 2,  500 ], # 1000 seconds total
      [ 'event3', 1,  500 ], # 500  seconds total
      [ 'event4', 1,  300 ], # 300  seconds total
   );
   sub generate_event {
      START:
      if ( $i >= $event_specs[0]->[2] ) {
         shift @event_specs;
         $i = 0;
      }
      $i++;
      return undef unless @event_specs;
      return {
         fingerprint => $event_specs[0]->[0],
         Query_time  => $event_specs[0]->[1],
      };
   }
}

$ea = new EventAggregator(
   groupby    => 'fingerprint',
   worst      => 'foo',
   attributes => {
      Query_time => [qw(Query_time)],
   },
);

while ( my $event = generate_event() ) {
   $ea->aggregate($event);
}

my @chosen;

@chosen = $ea->top_events(
   groupby => 'fingerprint',
   attrib  => 'Query_time',
   orderby => 'sum',
   total   => 1300,
   count   => 2,               # Get event2/3 but not event4
   # Or outlier events that usually take > 5s to execute and happened > 3 times
   ol_attrib => 'Query_time',
   ol_limit  => 5,
   ol_freq   => 3,
);

is_deeply(
   \@chosen,
   [
      [qw(event2 top)],
      [qw(event3 top)],
      [qw(event1 outlier)],
   ],
   'Got top events' );

@chosen = $ea->top_events(
   groupby => 'fingerprint',
   attrib  => 'Query_time',
   orderby => 'sum',
   total   => 1300,
   count   => 2,               # Get event2/3 but not event4
   # Or outlier events that usually take > 5s to execute
   ol_attrib => 'Query_time',
   ol_limit  => 5,
   ol_freq   => undef,
);

is_deeply(
   \@chosen,
   [
      [qw(event2 top)],
      [qw(event3 top)],
      [qw(event1 outlier)],
      [qw(event0 outlier)],
   ],
   'Got top events with outlier' );

# Try to make it fail
eval {
   $ea->aggregate({foo         => 'FAIL'});
   $ea->aggregate({fingerprint => 'FAIL'});
   # but not this one -- the caller should eval to catch this.
   # $ea->aggregate({fingerprint => 'FAIL2', Query_time => 'FAIL' });
   @chosen = $ea->top_events(
      groupby => 'fingerprint',
      attrib  => 'Query_time',
      orderby => 'sum',
      count   => 2,
   );
};
is($EVAL_ERROR, '', 'It handles incomplete/malformed events');

$events = [
   {  Query_time    => '0.000652',
      arg           => 'select * from sakila.actor join sakila.film_actor using(actor_id)',
   },
   {  Query_time    => '1.000652',
      arg           => 'select * from sakila.actor',
   },
   {  Query_time    => '2.000652',
      arg           => 'select * from sakila.actor join sakila.film_actor using(actor_id)',
   },
   {  Query_time    => '0.000652',
      arg           => 'select * from sakila.actor',
   },
];

$ea = new EventAggregator(
   groupby    => 'tables',
   worst      => 'foo',
   attributes => {
      Query_time => [qw(Query_time)],
   },
);

foreach my $event ( @$events ) {
   $event->{tables} = [ $qp->get_tables($event->{arg}) ];
   $ea->aggregate($event);
}

is_deeply(
   $ea->results,
   {
      classes => {
         'sakila.actor' => {
            Query_time => {
               min => '0.000652',
               max => '2.000652',
               all =>
                  [ 
                     ( map {0} ( 1 .. 133 ) ), 2,
                     ( map {0} ( 134 .. 283 ) ), 1,
                     ( map {0} ( 285 .. 297 ) ), 1,
                     ( map {0} ( 299 .. 999 ) )
                  ],
               sum => '3.002608',
               cnt => 4,
            },
         },
         'sakila.film_actor' => {
            Query_time => {
               min => '0.000652',
               max => '2.000652',
               all =>
                  [ 
                     ( map {0} ( 1 .. 133 ) ), 1,
                     ( map {0} ( 134 .. 297 ) ), 1,
                     ( map {0} ( 299 .. 999 ) )
                  ],
               sum => '2.001304',
               cnt => 2,
            },
         },
      },
      globals => {
         Query_time => {
            min => '0.000652',
            max => '2.000652',
            all =>
               [ 
                  ( map {0} ( 1 .. 133 ) ), 3,
                  ( map {0} ( 134 .. 283 ) ), 1,
                  ( map {0} ( 285 .. 297 ) ), 2,
                  ( map {0} ( 299 .. 999 ) )
               ],
            sum => '5.003912',
            cnt => 6,
         },
      },
   },
   'Aggregation by tables',
);

# Event attribute with space in name.
$ea = new EventAggregator(
   groupby    => 'fingerprint',
   worst      => 'Query time',
   attributes => {
      'Query time' => ['Query time'],
   },
);
$events = {
   fingerprint  => 'foo',
   'Query time' => 123,
};
$ea->aggregate($events);
is(
   $ea->results->{classes}->{foo}->{'Query time'}->{min},
   123,
   'Aggregates attributes with spaces in their names'
);

# #############################################################################
# Issue 323: mk-query-digest does not properly handle logs with an empty Schema:
# #############################################################################
$ea = new EventAggregator(
   groupby    => 'fingerprint',
   worst      => 'Query time',
   attributes => {
      'Query time' => ['Query time'],
      'Schema'     => ['Schema'],
   },
);
$events = {
   fingerprint  => 'foo',
   'Query time' => 123,
   'Schema'     => '',
};
$ea->aggregate($events);
is(
   $ea->{type_for}->{Schema},
   'string',
   'Empty Schema: (issue 323)'
);

exit;
