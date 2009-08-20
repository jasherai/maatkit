#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

require "../MockSyncStream.pm";
require "../Quoter.pm";
require "../MockSth.pm";
require "../RowDiff.pm";

my $rd = new RowDiff( dbh => 1 );
my @rows;

sub same_row {
   push @rows, 'same';
}

sub diff_row {
   push @rows, 'diff';
}

my $mss = new MockSyncStream(
   query         => 'SELECT a, b, c FROM foo WHERE id = 1',
   cols          => [qw(a b c)],
   same_callback => \&same_row,
   diff_callback => \&diff_row,
);

is(
   $mss->get_sql(),
   'SELECT a, b, c FROM foo WHERE id = 1',
   'get_sql()',
);

is( $mss->done(), undef, 'Not done yet' );

@rows = ();
$rd->compare_sets(
   left => new MockSth(
      { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      # { a => 4, b => 2, c => 3 },
   ),
   right => new MockSth(
      # { a => 1, b => 2, c => 3 },
      { a => 2, b => 2, c => 3 },
      { a => 3, b => 2, c => 3 },
      { a => 4, b => 2, c => 3 },
   ),
   syncer => $mss,
   tbl    => {},
);
is_deeply(
   \@rows,
   [
      'diff',
      'same',
      'same',
      'diff',
   ],
   'rows from handler',
);

# #############################################################################
# Done.
# #############################################################################
exit;
