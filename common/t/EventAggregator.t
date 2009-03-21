#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 51;

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
            [ 1, ( map {0} (1..999) ) ],
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
      all => [ 1, ( map {0} (1..283 ) ), 2, ( map {0} (285..999) ), ],
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
            all => [ 1, ( map {0} (1..283) ), 1, ( map {0} (285..999) ) ],
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
         all => [ 1, ( map {0} (1..283) ), 2, ( map {0} (285..999) ) ],
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
# Test buckets.
# #############################################################################

# Given an arrayref of vals, returns an arrayref and hashref of those
# vals suitable for passing to calculate_statistical_metrics().
sub bucketize {
   my ( $vals ) = @_;
   my @bucketed = map { 0 } (0..999); # TODO: shouldn't hard code this
   my ($sum, $max, $min);
   $max = $min = $vals->[0];
   foreach my $val ( @$vals ) {
      $bucketed[ EventAggregator::bucket_idx($val) ]++;
      $max = $max > $val ? $max : $val;
      $min = $min < $val ? $min : $val;
      $sum += $val;
   }
   return (\@bucketed, { sum => $sum, max => $max, min => $min, cnt => scalar @$vals});
}

sub test_bucket_val {
   my ( $bucket, $val ) = @_;
   my $msg = sprintf 'bucket %d equals %.9f', $bucket, $val;
   cmp_ok(
      sprintf('%.9f', EventAggregator::bucket_value($bucket)),
      '==',
      $val,
      $msg
   );
   return;
}

sub test_bucket_idx {
   my ( $val, $bucket ) = @_;
   my $msg = sprintf 'val %.8f goes in bucket %d', $val, $bucket;
   cmp_ok(
      EventAggregator::bucket_idx($val),
      '==',
      $bucket,
      $msg
   );
   return;
}

test_bucket_idx(0, 0);
test_bucket_idx(0.0000001, 0);  # < MIN_BUCK (0.000001)
test_bucket_idx(0.000001, 1);   # = MIN_BUCK
test_bucket_idx(0.00000104, 1); # last val in bucket 1
test_bucket_idx(0.00000105, 2); # first val in bucket 2
test_bucket_idx(1, 284);
test_bucket_idx(2, 298);
test_bucket_idx(3, 306);
test_bucket_idx(4, 312);
test_bucket_idx(5, 317);
test_bucket_idx(6, 320);
test_bucket_idx(7, 324);
test_bucket_idx(8, 326);
test_bucket_idx(9, 329);
test_bucket_idx(20, 345);
test_bucket_idx(97.356678643, 378);
test_bucket_idx(100, 378);
# I don't know why this is failing on the high end of the scale. :-(
# TODO: figure it out.
test_bucket_idx(1402556844201353.5, 999); # first val in last bucket
test_bucket_idx(9000000000000000.0, 999);

# These vals are rounded to 9 decimal places, otherwise we'll have
# problems with Perl returning stuff like 1.025e-9.
test_bucket_val(0, 0);
test_bucket_val(1,   0.000001000);
test_bucket_val(2,   0.000001050);
test_bucket_val(3,   0.000001103);
test_bucket_val(10,  0.000001551);
test_bucket_val(100, 0.000125239);
test_bucket_val(999, 1402556844201353.5);

is_deeply(
   [ bucketize( [ 2, 3, 6, 4, 8, 9, 1, 1, 1, 5, 4, 3, 1 ] ) ],
   [  [  ( map {0} ( 0 .. 283 ) ),
         4, # 1 -> 284
         ( map {0} ( 285 .. 297 ) ),
         1, # 2 -> 298
         ( map {0} ( 299 .. 305 ) ),
         2, # 3 -> 306
         ( map {0} ( 307 .. 311 ) ),
         2,             # 4 -> 312
         0, 0, 0, 0,    # 313, 314, 315, 316,
         1,             # 5 -> 317
         0, 0,          # 318, 319
         1,             # 6 -> 320
         0, 0, 0, 0, 0, # 321, 322, 323, 324, 325
         1,             # 8 -> 326
         0, 0,          # 327, 328
         1,             # 9 -> 329
         ( map {0} ( 330 .. 999 ) ),
      ],
      {  sum => 48,
         max => 9,
         min => 1,
         cnt => 13,
      },
   ],
   'Bucketizes values (values -> buckets)',
);

is_deeply(
   [ EventAggregator::buckets_of() ],
   [
      ( map {0} (0..47)    ),
      ( map {1} (48..94)   ),
      ( map {2} (95..141)  ),
      ( map {3} (142..188) ),
      ( map {4} (189..235) ),
      ( map {5} (236..283) ),
      ( map {6} (284..330) ),
      ( map {7} (331..999) )
   ],
   '8 buckets of base 10'
);

# #############################################################################
# Test statistical metrics: 95%, stddev, and median
# #############################################################################

$result = $ea->calculate_statistical_metrics(
   bucketize( [ 2, 3, 6, 4, 8, 9, 1, 1, 1, 5, 4, 3, 1 ] ) );
# The above bucketize will be bucketized as:
# VALUE  BUCKET  VALUE        RANGE                       N VALS  SUM
# 1      248     0.992136979  [0.992136979, 1.041743827)  4       3.968547916
# 2      298     1.964363355  [1.964363355, 2.062581523)  1       1.964363355
# 3      306     2.902259332  [2.902259332, 3.047372299)  2       5.804518664
# 4      312     3.889305079  [3.889305079, 4.083770333)  2       7.778610158
# 5      317     4.963848363  [4.963848363, 5.212040781)  1       4.963848363
# 6      320     5.746274961  [5.746274961, 6.033588710)  1       5.746274961
# 8      326     7.700558026  [7.700558026, 8.085585927)  1       7.700558026
# 9      329     8.914358484  [8.914358484, 9.360076409)  1       8.914358484
#                                                                 -----------
#                                                                 46.841079927
# I have hand-checked these values and they are correct.
is_deeply(
   $result,
   {
      stddev => 2.51982318221967,
      median => 2.90225933213165,
      cutoff => 12,
      pct_95 => 7.70055802567889,
   },
   'Calculates statistical metrics'
);

$result = $ea->calculate_statistical_metrics(
   bucketize( [ 1, 1, 1, 1, 2, 3, 4, 4, 4, 4, 6, 8, 9 ] ) );
# The above bucketize will be bucketized as:
# VALUE  BUCKET  VALUE        RANGE                       N VALS
# 1      248     0.992136979  [0.992136979, 1.041743827)  4
# 2      298     1.964363355  [1.964363355, 2.062581523)  1
# 3      306     2.902259332  [2.902259332, 3.047372299)  1
# 4      312     3.889305079  [3.889305079, 4.083770333)  4
# 6      320     5.746274961  [5.746274961, 6.033588710)  1
# 8      326     7.700558026  [7.700558026, 8.085585927)  1
# 9      329     8.914358484  [8.914358484, 9.360076409)  1
#
# I have hand-checked these values and they are correct.
is_deeply(
   $result,
   {
      stddev => 2.48633263817885,
      median => 3.88930507895285,
      cutoff => 12,
      pct_95 => 7.70055802567889,
   },
   'Calculates median when it is halfway between two elements',
);

# This is a special case: only two values, widely separated.  The median should
# be exact (because we pass in min/max) and the stdev should never be bigger
# than half the difference between min/max.
$result = $ea->calculate_statistical_metrics(
   bucketize( [ 0.000002, 0.018799 ] ) );
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

$result = $ea->calculate_statistical_metrics( bucketize( [0.9] ) );
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
               [ 1, ( map {0} (1..999) ) ],
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
         all => [ 1, ( map {0} (1..311) ), 2, ( map {0} (313..999) ) ],
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

# #############################################################################
# Issue 321: mk-query-digest stuck in infinite loop while processing log
# #############################################################################

my $bad_vals = [580,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,25,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

my $bad_event = {
   min => 0,
   max => 1,
   last => 1,
   sum => 25,
   cnt => 605
};

$result = $ea->calculate_statistical_metrics($bad_vals, $bad_event);
is_deeply(
   $result,
   {
      stddev => 0.1974696076416,
      median => 0,
      pct_95 => 0,
      cutoff => 574,
   },
   'statistical metrics with mostly zero values'
);

exit;
