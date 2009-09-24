#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

require "../TableSyncStream.pm";
require "../Quoter.pm";
require "../MockSth.pm";
require "../RowDiff.pm";
require "../ChangeHandler.pm";

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like( $EVAL_ERROR, $pat, $msg );
}

my $q = new Quoter();
my @rows;

throws_ok(
   sub { new TableSyncStream() },
   qr/I need a Quoter/,
   'Quoter required'
);
my $t = new TableSyncStream(
   Quoter => $q,
);

my $ch = new ChangeHandler(
   Quoter  => $q,
   dst_db  => 'test',
   dst_tbl => 'foo',
   src_db  => 'test',
   src_tbl => 'foo',
   replace => 0,
   actions => [ sub { push @rows, @_ }, ],
   queue   => 0,
);

$t->prepare_to_sync(
   ChangeHandler   => $ch,
   cols            => [qw(a b c)],
   buffer_in_mysql => 1,
);
is(
   $t->get_sql(
      where    => 'foo=1',
      database => 'test',
      table    => 'foo',
   ),
   'SELECT SQL_BUFFER_RESULT `a`, `b`, `c` FROM `test`.`foo` WHERE foo=1',
   'Got SQL with SQL_BUFFER_RESULT OK',
);


$t->prepare_to_sync(
   ChangeHandler   => $ch,
   cols            => [qw(a b c)],
);
is(
   $t->get_sql(
      where    => 'foo=1',
      database => 'test',
      table    => 'foo',
   ),
   'SELECT `a`, `b`, `c` FROM `test`.`foo` WHERE foo=1',
   'Got SQL OK',
);

is( $t->done, undef, 'Not done yet' );

my $d = new RowDiff( dbh => 1 );
$d->compare_sets(
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
   syncer => $t,
   tbl    => {},
);

is_deeply(
   \@rows,
   [
   'INSERT INTO `test`.`foo`(`a`, `b`, `c`) VALUES (1, 2, 3)',
   'DELETE FROM `test`.`foo` WHERE `a`=4 AND `b`=2 AND `c`=3 LIMIT 1',
   ],
   'rows from handler',
);
