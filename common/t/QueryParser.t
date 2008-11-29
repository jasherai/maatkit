#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 15;
use English qw(-no_match_vars);

require '../QueryParser.pm';

my $qp = new QueryParser;

isa_ok($qp, 'QueryParser');

sub test_query {
   my ( $query, $expected_ref, $expected_aliases, $msg ) = @_;
   my $tr = $qp->get_table_ref($query);
   is(
      $tr,
      $expected_ref,
      "table ref: $msg"
   );
   is_deeply(
      $qp->parse_table_aliases($tr),
      $expected_aliases,
      "table aliases: $msg",
   );
   return;
}

test_query(
   'SELECT * FROM tbl WHERE id = 1',
   'tbl ',
   {
      'tbl' => 'tbl',
   },
   'basic single table'
);

test_query(
   'SELECT * FROM tbl1, tbl2 WHERE id = 1',
   'tbl1, tbl2 ',
   {
      'tbl1' => 'tbl1',
      'tbl2' => 'tbl2',
   },
   'basic two table'
);

test_query(
   'SELECT * FROM tbl AS tbl_alias WHERE id = 1',
   'tbl AS tbl_alias ',
   {
      'tbl_alias' => 'tbl',
   },
   'basic single AS-aliased'
);

test_query(
   'SELECT * FROM tbl tbl_alias WHERE id = 1',
   'tbl tbl_alias ',
   {
      'tbl_alias' => 'tbl',
   },
   'basic single implicitly aliased'
);

test_query(
   'SELECT * FROM tbl1 AS a1, tbl2 a2 WHERE id = 1',
   'tbl1 AS a1, tbl2 a2 ',
   {
      'a1' => 'tbl1',
      'a2' => 'tbl2',
   },
   'mixed two table'
);

test_query(
   'SELECT * FROM tbl1 AS a1 LEFT JOIN tbl2 as a2 ON a1.id = a2.id',
   'tbl1 AS a1 LEFT JOIN tbl2 as a2 ON a1.id = a2.id',
   {
      'a1' => 'tbl1',
      'a2' => 'tbl2',
   },
   'two table LEFT JOIN'
);

test_query(
   'SELECT * FROM db.tbl1 AS a1 WHERE id = 1',
   'db.tbl1 AS a1 ',
   {
      'a1'       => 'tbl1',
      'DATABASE' => {
         'tbl1' => 'db',
      },
   },
   'single fully-qualified and aliased table'
);

exit;
