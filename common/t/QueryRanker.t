#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 25;

require '../QueryRanker.pm';

my $qr = new QueryRanker();
isa_ok($qr, 'QueryRanker');

# #############################################################################
# Test query time comparison.
# #############################################################################
sub test_compare_query_times {
   my ( $t1, $t2, $rank, $comment ) = @_;
   is(
      $qr->compare_query_times($t1, $t2),
      $rank,
      "compare_query_times($t1, $t2)" . ($comment ? ": $comment" : '')
   );
}

test_compare_query_times(0, 0, 0);
test_compare_query_times(0, 0.000001, 1, 'increase from zero');
test_compare_query_times(0.000001, 0.000005, 0);
test_compare_query_times(0.000001, 0.000010, 2, '1 bucket diff on edge');
test_compare_query_times(0.000008, 0.000018, 2, '1 bucket diff');
test_compare_query_times(0.000001, 10, 14, 'full bucket range diff on edges');
test_compare_query_times(0.000008, 1000000, 14, 'huge diff');

# Thresholds
test_compare_query_times(0.000001, 0.000006, 1, '1us threshold');
test_compare_query_times(0.000010, 0.000020, 1, '10us threshold');
test_compare_query_times(0.000100, 0.000200, 1, '100us threshold');
test_compare_query_times(0.001000, 0.006000, 1, '1ms threshold');
test_compare_query_times(0.010000, 0.015000, 1, '10ms threshold');
test_compare_query_times(0.100000, 0.150000, 1, '100ms threshold');
test_compare_query_times(1.000000, 1.200000, 1, '1s threshold');
test_compare_query_times(10.0,     10.1,     1, '10s threshold');

# #############################################################################
# Test ranking.
# #############################################################################
my $results = {
   host1 => {
      Query_time    => 0.001020,
      warning_count => 0,
      warnings      => {},
   },
   host2 => {
      Query_time    => 0.001100,
      warning_count => 0,
      warnings      => {},
   },
};
is(
   $qr->rank($results),
   0,
   'No warnings, no time diff (0)'
);

$results = {
   host1 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => {
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         }
      },
   },
   host2 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => { 
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         }
      },
   },
};
is(
   $qr->rank($results),
   1,
   'Same warning, no time diff (1)'
);

$results = {
   host1 => {
      Query_time    => 0.003020,
      warning_count => 0,
      warnings      => {},
   },
   host2 => {
      Query_time    => 0.000100,
      warning_count => 0,
      warnings      => {},
   },
};
is(
   $qr->rank($results),
   2,
   'No warnings, time diff (2)'
);

$results = {
   host1 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => {
            Level   => 'Error',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         }
      },
   },
   host2 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => {
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         }
      },
   },
};
is(
   $qr->rank($results),
   3,
   'Same warning, different level (3)'
);

$results = {
   host1 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => {
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         }
      },
   },
   host2 => {
      Query_time    => 0.1,
      warning_count => 0,
      warnings      => {},
   },
};
is(
   $qr->rank($results),
   5,
   'Warning on host1 but not host2 (5)'
);

$results = {
   host1 => {
      Query_time    => 0.1,
      warning_count => 0,
      warnings      => {},
   },
   host2 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => {
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         }
      },
   },
};
is(
   $qr->rank($results),
   5,
   'Warning on host2 but not host1 (5)'
);

$results = {
   host1 => {
      Query_time    => 0.1,
      warning_count => 2,
      warnings      => {
         1264 => {
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         },
         1062 => {
            Level   => 'Error',
            Code    => '1062',
            Message => "Duplicate entry '1' for key 1",
         },
      },
   },
   host2 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => {
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         },
      },
   },
};
is(
   $qr->rank($results),
   5,
   'One new warning, one old warning (5)'
);

$results = {
   host1 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1062 => {
            Level   => 'Error',
            Code    => '1062',
            Message => "Duplicate entry '1' for key 1",
         }
      },
   },
   host2 => {
      Query_time    => 0.1,
      warning_count => 1,
      warnings      => {
         1264 => {
            Level   => 'Warning',
            Code    => '1264',
            Message => "Out of range value adjusted for column 'userid' at row 1",
         }
      },
   },
};
is(
   $qr->rank($results),
   7,
   'Same number of differents warnings (7)'
);

# #############################################################################
# Done.
# #############################################################################
my $output;
{
   local *STDERR;
   open STDERR, '>', \$output;
   $qr->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
