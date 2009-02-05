#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 29;
use English qw(-no_match_vars);

require '../QueryRewriter.pm';
require '../QueryParser.pm';

my $qr = new QueryRewriter;
my $qp = new QueryParser;

isa_ok($qp, 'QueryParser');

sub test_query {
   my ( $query, $aliases, $tables, $msg ) = @_;
   is_deeply(
      $qp->get_table_aliases($query),
      $aliases,
      "get_table_aliases: $msg",
   );
   is_deeply(
      [$qp->get_tables($query)],
      $tables,
      "get_tables: $msg",
   );
   return;
}

sub test_get_tbl_refs {
   my ( $query, $tbl_ref, $msg ) = @_;
   my @table_refs = $qp->_get_table_refs($query);
   is_deeply(
      \@table_refs,
      $tbl_ref,
      "_get_tbl_refs: $msg",
   );
   return;
}

test_get_tbl_refs(
   'SELECT * FROM tbl tbl_alias WHERE id = 1',
   ['tbl tbl_alias '],
   'one implicit alias'
);

test_get_tbl_refs(
   'SELECT * FROM tbl AS tbl_alias WHERE id = 1',
   ['tbl AS tbl_alias '],
   'one AS alias'
);

test_get_tbl_refs(
   'SELECT * FROM t1 AS a, t2 WHERE id = 1',
   ['t1 AS a, t2 '],
   'one AS alias, one not aliased'
);
test_get_tbl_refs(
   'SELECT * FROM t1 AS a, t2, t3 c WHERE id = 1',
   ['t1 AS a, t2, t3 c '],
   'one AS alias, one not aliased, one implicit alias'
);

test_get_tbl_refs(
   'SELECT * FROM t1',
   ['t1'],
   'one not aliased, no following clauses',
);

test_get_tbl_refs(
   'SELECT * FROM t1 a JOIN t2 b ON a.id=b.id WHERE foo = "bar"',
   ['t1 a', 't2 b'],
   'two tables implicitly aliased and JOIN',
);

test_get_tbl_refs(
   'UPDATE foo AS bar SET value = 1 WHERE 1',
   ['foo AS bar '],
   'update with one AS alias',
);

test_get_tbl_refs(
   'INSERT INTO foo VALUES (1)',
   ['foo '],
   'insert with one not aliased',
);

exit;

test_query(
   'SELECT * FROM tbl WHERE id = 1',
   {
      'tbl' => 'tbl',
   },
   [ qw(tbl) ],
   'basic single table'
);

test_query(
   'SELECT * FROM tbl1, tbl2 WHERE id = 1',
   {
      'tbl1' => 'tbl1',
      'tbl2' => 'tbl2',
   },
   [qw(tbl1 tbl2)],
   'basic two table'
);

test_query(
   'SELECT * FROM tbl AS tbl_alias WHERE id = 1',
   {
      'tbl_alias' => 'tbl',
   },
   [qw(tbl)],
   'basic single AS-aliased'
);

test_query(
   'SELECT * FROM tbl tbl_alias WHERE id = 1',
   {
      'tbl_alias' => 'tbl',
   },
   [qw(tbl)],
   'basic single implicitly aliased'
);

test_query(
   'SELECT * FROM tbl1 AS a1, tbl2 a2 WHERE id = 1',
   {
      'a1' => 'tbl1',
      'a2' => 'tbl2',
   },
   [qw(tbl1 tbl2)],
   'mixed two table'
);

test_query(
   'SELECT * FROM tbl1 AS a1 LEFT JOIN tbl2 as a2 ON a1.id = a2.id',
   {
      'a1' => 'tbl1',
      'a2' => 'tbl2',
   },
   [qw(tbl1 tbl2)],
   'two table LEFT JOIN'
);

test_query(
   'SELECT * FROM db.tbl1 AS a1 WHERE id = 1',
   {
      'a1'       => 'tbl1',
      'DATABASE' => {
         'tbl1' => 'db',
      },
   },
   [qw(db.tbl1)],
   'single fully-qualified and aliased table'
);

test_query(
   q{SELECT a FROM store_orders_line_items JOIN store_orders},
   {
      store_orders_line_items => 'store_orders_line_items',
      store_orders            => 'store_orders',
   },
   [qw(store_orders_line_items store_orders)],
   'Embedded ORDER keyword',
);

# #############################################################################
# Issue 185: QueryParser fails to parse table ref for a JOIN ... ON
# #############################################################################
test_query(
    'select  n.column1 = a.column1, n.word3 = a.word3 from db2.tuningdetail_21_265507 n inner join db1.gonzo a using(gonzo)', 
   {
      'n' => 'tuningdetail_21_265507',
      'a' => 'gonzo',
      'DATABASE' => {
         'tuningdetail_21_265507' => 'db2',
         'gonzo' => 'db1',
      },
   },
   [qw(db2.tuningdetail_21_265507 db1.gonzo)],
   'SELECT with JOIN ON and no WHERE (issue 185)'
);

# #############################################################################
test_query(
   'select 12_13_foo from (select 12foo from 123_bar) as 123baz',
   {
      '123_bar' => '123_bar',
   },
   [qw(123_bar)],
   'Subquery in the FROM clause'
);

test_query(
   q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
   . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
   . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
   . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
   . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
   . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
   . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )},
   {
      PL => 'GARDEN_CLUPL',
      GC => 'GARDENJOB',
      ABU => 'APLTRACT_GARDENPLANT',
   },
   [qw(GARDEN_CLUPL GARDENJOB APLTRACT_GARDENPLANT)],
   'Gets tables from query with aliases and comma-join',
);

is_deeply(
   [
   $qp->get_tables(
   q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
      .q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
      .q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
      .q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
      .q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
      .q{`account_name`, `provider_account_id`, `campaign_name`, }
      .q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
      .q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
      .q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
      .q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
      .q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
      .q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
      .q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
      .q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
      .q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
      .q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
      .q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
      .q{(`id` >= 2166633); })
   ],
   [qw(checksum.checksum `foo`.`bar`)],
   'gets tables from nasty checksum query',
);

is_deeply(
   [ $qp->get_tables(q{SELECT STRAIGHT_JOIN distinct foo, bar FROM A, B, C}) ],
   [qw(A B C)],
   'gets tables from STRAIGHT_JOIN',
);

is_deeply(
   [ $qp->get_tables(
      'replace into checksum.checksum select `last_update`, `foo` from foo.foo')
   ],
   [qw(checksum.checksum foo.foo)],
   'gets tables with reserved words');

exit;
