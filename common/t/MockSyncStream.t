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
sub not_in_left {
   push @rows, 'not in left';
}
sub not_in_right {
   push @rows, 'not in right';
}

my $mss = new MockSyncStream(
   query        => 'SELECT a, b, c FROM foo WHERE id = 1',
   cols         => [qw(a b c)],
   same_row     => \&same_row,
   not_in_left  => \&not_in_left,
   not_in_right => \&not_in_right,
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
      'not in right',
      'same',
      'same',
      'not in left',
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

   diag(`/tmp/12345/use -e 'CREATE DATABASE test' 2>/dev/null`);
   diag(`/tmp/12345/use < samples/col_types.sql`);

   my $sth = $dbh->prepare('SELECT * FROM test.col_types_1');
   $sth->execute();
   is_deeply(
      MockSyncStream::get_result_set_struct($dbh, $sth),
      {
         cols => [
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
         type_for => {
            id => 'integer',
            i  => 'integer',
            f  => 'float',
            d  => 'decimal',
            dt => 'timestamp',
            ts => 'timestamp',
            c  => 'char',
            v  => 'varchar',
            t  => 'blob',
         },
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
         is_col => {
            id => 1,
            i  => 1,
            f  => 1,
            d  => 1,
            dt => 1,
            ts => 1,
            c  => 1,
            v  => 1,
            t  => 1,
         },
         col_posn => {
            id => 0,
            i  => 1,
            f  => 2,
            d  => 3,
            dt => 4,
            ts => 5,
            c  => 6,
            v  => 7,
            t  => 8,
         },
         is_nullable => {
            id => 1,
            i  => 1,
            f  => 1,
            d  => 1,
            dt => 0,
            ts => 0,
            c  => 1,
            v  => 1,
            t  => 1,
         },
      },
      'Gets result set struct from sth attribs'
   );

   $sth = $dbh->prepare('SELECT v, c, t, id, i, f, d FROM test.col_types_1');
   $sth->execute();
   my $row = $sth->fetchrow_hashref();
   is_deeply(
      MockSyncStream::as_arrayref($sth, $row),
      ['hello world','c','this is text',1,1,3.14,5.08,],
      'as_arrayref()'
   );

   $sth->finish();
   $sb->wipe_clean($dbh);
   $dbh->disconnect();
};

# #############################################################################
# Done.
# #############################################################################
exit;
