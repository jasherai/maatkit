#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

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
# Test online stuff, e.g. get_cols_and_struct().
# #############################################################################
require '../DSNParser.pm';
require '../Sandbox.pm';
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

SKIP: {
   skip 'Cannot connect to sandbox mater', 1
      unless $dbh;

   diag(`/tmp/12345/use -e 'CREATE DATABASE test'`);
   diag(`/tmp/12345/use < samples/col_types.sql`);

   my $sth = $dbh->prepare('SELECT * FROM test.col_types_1');
   $sth->execute();
   my ($cols, $struct) = MockSyncStream::get_cols_and_struct($dbh, $sth);
   $sth->finish();

   is_deeply(
      $cols,
      [
         'id',
         'i',
         'f',
         'd',
         'dt',
         'ts',
         'c',
         'v',
         't',
      ],
      'Gets column names from sth'
   );
   is_deeply(
      $struct,
      {
         is_numeric => {
            id => 1,
            i  => 1,
            f  => 1,
            d  => 1,
            dt => 0,
            ts => 0,
            c  => 0,
            v  => 0,
            t  => 0,
         },
      },
      'Gets table struct from sth'
   );

   $sb->wipe_clean($dbh);
   $dbh->disconnect();
};

# #############################################################################
# Done.
# #############################################################################
exit;
