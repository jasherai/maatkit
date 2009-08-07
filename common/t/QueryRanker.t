#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 32;

require '../QueryRanker.pm';

my $qr = new QueryRanker();
isa_ok($qr, 'QueryRanker');

# #############################################################################
# Test query time comparison.
# #############################################################################
sub test_compare_query_times {
   my ( $t1, $t2, $expected_rank, $comment ) = @_;
   # We don't look at the reason here, just the rank.
   my @res = $qr->compare_query_times($t1, $t2);
   my $got_rank = shift @res;
   is(
      $got_rank,
      $expected_rank,
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
# Test execution ranking.
# #############################################################################
my @results = (
   {
      Query_time => {
         Query_time  => 0.001020,
         error       => undef
      },
      warnings   => {
         count => 0,
         codes => {},
      },
   },
   {
      Query_time => {
         Query_time  => 0.001100,
         error       => undef,
      },
      warnings    => {
         count => 0,
         codes => {},
         error       => undef,
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 0 ],
   'No warnings, no time diff (0)'
);

@results = (
   {
      Query_time  => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => {
               Level   => 'Warning',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            }
         },
         error   => undef,
      }
   },
   {
      Query_time  => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => { 
               Level   => 'Warning',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            }
         },
         error => undef,
      },
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 1,
     'Query has warnings (rank+1)'
   ],
   'Same warning, no time diff (1)'
);

@results = (
   {
      Query_time  => {
         Query_time  => 0.003020,
         error       => undef,
      },
      warnings    => {
         count => 0,
         codes => {},
         error => undef,
      }
   },
   {
      Query_time  => {
         Query_time  => 0.000100,
         error       => undef,
      },
      warnings    => {
         count => 0,
         codes => {},
         error => undef,
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 2,
     'Query times differ significantly: host1 in 1ms range, host2 in 100us range (rank+2)',
   ],
   'No warnings, time diff (2)'
);

@results = (
   {
      Query_time  => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => {
               Level   => 'Error',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            }
         },
         error       => undef,
      }
   },
   {
      Query_time  => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => {
               Level   => 'Warning',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            }
         },
         error       => undef,
      },
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 3,
     'Query has warnings (rank+1)',
     'Error 1264 changes level: Error on host1, Warning on host2 (rank+2)',
   ],
   'Same warning, different level (3)'
);

@results = (
   {
      Query_time  => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => {
               Level   => 'Warning',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            }
         },
         error       => undef,
      }
   },
   {
      Query_time    => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 0,
         codes => {},
         error => undef,
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 5,
     'Query has warnings (rank+1)',
     'Warning counts differ by 1 (rank+1)',
     'Error 1264 on host1 is new (rank+3)',
   ],
   'Warning on host1 but not host2 (5)'
);

@results = (
   {
      Query_time    => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 0,
         codes => {},
         error       => undef,
      }
   },
   {
      Query_time    => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => {
               Level   => 'Warning',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            }
         },
         error       => undef,
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 5,
     'Query has warnings (rank+1)',
     'Warning counts differ by 1 (rank+1)',
     'Error 1264 on host2 is new (rank+3)',
   ],
   'Warning on host2 but not host1 (5)'
);

@results = (
   {
      Query_time    => {
         Query_time  => 0.1,
         error       => undef,,
      },
      warnings    => {
         count => 2,
         codes => {
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
         error       => undef,
      }
   },
   {
      Query_time    => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => {
               Level   => 'Warning',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            },
         },
         error       => undef,
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 5,
     'Query has warnings (rank+1)',
     'Warning counts differ by 1 (rank+1)',
     'Error 1062 on host1 is new (rank+3)',
   ],
   'One new warning, one old warning (5)'
);

@results = (
   {
      Query_time    => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1062 => {
               Level   => 'Error',
               Code    => '1062',
               Message => "Duplicate entry '1' for key 1",
            }
         },
         error       => undef,
      }
   },
   {
      Query_time    => {
         Query_time  => 0.1,
         error       => undef,
      },
      warnings    => {
         count => 1,
         codes => {
            1264 => {
               Level   => 'Warning',
               Code    => '1264',
               Message => "Out of range value adjusted for column 'userid' at row 1",
            }
         },
         error       => undef,
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 7,
     'Query has warnings (rank+1)',
     'Error 1062 on host1 is new (rank+3)',
     'Error 1264 on host2 is new (rank+3)',
   ],
   'Same number of different warnings (7)'
);

@results = (
   {
      Query_time    => {
         Query_time  => -1,
         error       => 'something terrible happened',
      },
   },
   {
      Query_time    => {
         Query_time  => -1,
         error       => 'query caused an error',
      },
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 200,
     'Query failed to execute on host1: something terrible happened (rank+100)',
     'Query failed to execute on host2: query caused an error (rank+100)',
   ],
   'Query failed to execute for Query_time (200)'
);

# #############################################################################
# Test result ranking.
# #############################################################################
@results = (
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '123',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'int',
               b => 'char',
            },
         },
      }
   },
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '123',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'int',
               b => 'char',
            },
         },
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 0 ],
   'No checksum, row or col diffs (0)'
);

@results = (
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '123',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'int',
               b => 'char',
            },
         },
      }
   },
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'int',
               b => 'char',
            },
         },
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 50,
     'Table checksums do not match (rank+50)'
   ],
   'Only table checksums differ (50)'
);

@results = (
   {
      checksum_results => {
         error    => undef,
         n_rows   => 11,
         checksum => '123',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'int',
               b => 'char',
            },
         },
      }
   },
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'int',
               b => 'char',
            },
         },
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 100,
     'Table checksums do not match (rank+50)',
     'Number of rows do not match (rank+50)',
   ],
   'Table checksums and rows differ (100)'
);

@results = (
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'int',
               b => 'char',
            },
         },
      }
   },
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'bigint',
               b => 'char',
            },
         },
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 3,
     "Types for a column differ: 'int' on host1, 'bigint' on host2 (rank+3)",
   ],
   'Column type differs (3)'
);

@results = (
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'bigint',
            },
         },
      }
   },
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'bigint',
               b => 'char',
            },
         },
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 5,
     "Column b exists on host2 but not on host1 (rank+5)",
   ],
   'host1 missing a column (5)'
);

@results = (
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'bigint',
               b => 'char',
            },
         },
      }
   },
   {
      checksum_results => {
         error    => undef,
         n_rows   => 10,
         checksum => '124',
         table_struct   => {
            cols     => [qw(a b)],
            type_for => {
               a => 'bigint',
            },
         },
      }
   },
);
is_deeply(
   [ $qr->rank_results(@results) ],
   [ 5,
     "Column b exists on host1 but not on host2 (rank+5)",
   ],
   'host2 missing a column (5)'
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
