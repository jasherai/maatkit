#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 86;
use English qw(-no_match_vars);

require '../QueryRewriter.pm';
require '../QueryParser.pm';

use Data::Dumper;
$Data::Dumper::Indent=1;

my $qr = new QueryRewriter;
my $qp = new QueryParser;

isa_ok($qp, 'QueryParser');

sub test_query {
   my ( $query, $aliases, $tables, $msg ) = @_;
   is_deeply(
      $qp->get_aliases($query),
      $aliases,
      "get_aliases: $msg",
   );
   is_deeply(
      [$qp->get_tables($query)],
      $tables,
      "get_tables:  $msg",
   );
   return;
}

# #############################################################################
# All manner of "normal" SELECT queries.
# #############################################################################

# 1 table
test_query(
   'SELECT * FROM t1 WHERE id = 1',
   {
      't1' => 't1',
   },
   [qw(t1)],
   'one table no alias'
);
test_query(
   'SELECT * FROM t1 a WHERE id = 1',
   {
      'a' => 't1',
   },
   [qw(t1)],
   'one table implicit alias'
);
test_query(
   'SELECT * FROM t1 AS a WHERE id = 1',
   {
      'a' => 't1',
   },
   [qw(t1)],
   'one table AS alias'
);
test_query(
   'SELECT * FROM t1',
   {
      t1 => 't1',
   },
   [qw(t1)],
   'one table no alias and no following clauses',
);

# 2 tables
test_query(
   'SELECT * FROM t1, t2 WHERE id = 1',
   {
      't1' => 't1',
      't2' => 't2',
   },
   [qw(t1 t2)],
   'two tables no aliases'
);
test_query(
   'SELECT * FROM t1 a, t2 WHERE foo = "bar"',
   {
      a  => 't1',
      t2 => 't2',
   },
   [qw(t1 t2)],
   'two tables implicit alias and no alias',
);
test_query(
   'SELECT * FROM t1 a, t2 b WHERE id = 1',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables implicit aliases'
);
test_query(
   'SELECT * FROM t1 AS a, t2 AS b WHERE id = 1',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables AS aliases'
);
test_query(
   'SELECT * FROM t1 AS a, t2 b WHERE id = 1',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables AS alias and implicit alias'
);
test_query(
   'SELECT * FROM t1 a, t2 AS b WHERE id = 1',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables implicit alias and AS alias'
);

# ANSI JOINs
test_query(
   'SELECT * FROM t1 JOIN t2 ON a.id = b.id',
   {
      't1' => 't1',
      't2' => 't2',
   },
   [qw(t1 t2)],
   'two tables no aliases JOIN'
);
test_query(
   'SELECT * FROM t1 a JOIN t2 b ON a.id = b.id',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables implicit aliases JOIN'
);
test_query(
   'SELECT * FROM t1 AS a JOIN t2 as b ON a.id = b.id',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables AS aliases JOIN'
);
test_query(
   'SELECT * FROM t1 AS a JOIN t2 b ON a.id=b.id WHERE id = 1',
   {
      a => 't1',
      b => 't2',
   },
   [qw(t1 t2)],
   'two tables AS alias and implicit alias JOIN'
);
test_query(
   'SELECT * FROM t1 LEFT JOIN t2 ON a.id = b.id',
   {
      't1' => 't1',
      't2' => 't2',
   },
   [qw(t1 t2)],
   'two tables no aliases LEFT JOIN'
);
test_query(
   'SELECT * FROM t1 a LEFT JOIN t2 b ON a.id = b.id',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables implicit aliases LEFT JOIN'
);
test_query(
   'SELECT * FROM t1 AS a LEFT JOIN t2 as b ON a.id = b.id',
   {
      'a' => 't1',
      'b' => 't2',
   },
   [qw(t1 t2)],
   'two tables AS aliases LEFT JOIN'
);
test_query(
   'SELECT * FROM t1 AS a LEFT JOIN t2 b ON a.id=b.id WHERE id = 1',
   {
      a => 't1',
      b => 't2',
   },
   [qw(t1 t2)],
   'two tables AS alias and implicit alias LEFT JOIN'
);

# 3 tables
test_query(
   'SELECT * FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4 WHERE foo = "bar"',
   {
      t1 => 't1',
      t2 => 't2',
      t3 => 't3',
   },
   [qw(t1 t2 t3)],
   'three tables no aliases JOIN'
);
test_query(
   'SELECT * FROM t1 AS a, t2, t3 c WHERE id = 1',
   {
      a  => 't1',
      t2 => 't2',
      c  => 't3',
   },
   [qw(t1 t2 t3)],
   'three tables AS alias, no alias, implicit alias'
);
test_query(
   'SELECT * FROM t1 a, t2 b, t3 c WHERE id = 1',
   {
      a => 't1',
      b => 't2',
      c => 't3',
   },
   [qw(t1 t2 t3)],
   'three tables implicit aliases'
);

# Db-qualified tables
test_query(
   'SELECT * FROM db.t1 AS a WHERE id = 1',
   {
      'a'        => 't1',
      'DATABASE' => {
         't1' => 'db',
      },
   },
   [qw(db.t1)],
   'one db-qualified table AS alias'
);
test_query(
   'SELECT * FROM `db`.`t1` AS a WHERE id = 1',
   {
      'a'        => '`t1`',
      'DATABASE' => {
         '`t1`' => '`db`',
      },
   },
   [qw(`db`.`t1`)],
   'one db-qualified table AS alias with backticks'
);

# Other cases
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
# Non-SELECT queries.
# #############################################################################
test_query(
   'UPDATE foo AS bar SET value = 1 WHERE 1',
   {
      bar => 'foo',
   },
   [qw(foo)],
   'update with one AS alias',
);

test_query(
   'UPDATE IGNORE foo bar SET value = 1 WHERE 1',
   {
      bar => 'foo',
   },
   [qw(foo)],
   'update ignore with one implicit alias',
);

test_query(
   'UPDATE IGNORE bar SET value = 1 WHERE 1',
   {
      bar => 'bar',
   },
   [qw(bar)],
   'update ignore with one not aliased',
);

test_query(
   'UPDATE LOW_PRIORITY baz SET value = 1 WHERE 1',
   {
      baz => 'baz',
   },
   [qw(baz)],
   'update low_priority with one not aliased',
);

test_query(
   'UPDATE LOW_PRIORITY IGNORE bat SET value = 1 WHERE 1',
   {
      bat => 'bat',
   },
   [qw(bat)],
   'update low_priority ignore with one not aliased',
);

test_query(
   'INSERT INTO foo VALUES (1)',
   {
      foo => 'foo',
   },
   [qw(foo)],
   'insert with one not aliased',
);

test_query(
   'INSERT INTO foo VALUES (1) ON DUPLICATE KEY UPDATE bar = 1',
   {
      foo => 'foo',
   },
   [qw(foo)],
   'insert / on duplicate key update',
);

# #############################################################################
# Diabolical dbs and tbls with spaces in their names.
# #############################################################################

test_query(
   'select * from `my table` limit 1;',
   {
      '`my table`' => '`my table`',
   },
   ['`my table`'],
   'one table with space in name, not aliased',
);
test_query(
   'select * from `my database`.mytable limit 1;',
   {
      mytable  => 'mytable',
      DATABASE => {
         mytable => '`my database`',
      },
   },
   ['`my database`.mytable'],
   'one db.tbl with space in db, not aliased',
);
test_query(
   'select * from `my database`.`my table` limit 1; ',
   {
      '`my table`'  => '`my table`',
      DATABASE => {
         '`my table`' => '`my database`',
      },
   },
   ['`my database`.`my table`'],
   'one db.tbl with space in both db and tbl, not aliased',
);

# #############################################################################
# Issue 185: QueryParser fails to parse table ref for a JOIN ... USING
# #############################################################################
test_query(
    'select  n.column1 = a.column1, n.word3 = a.word3 from db2.tuningdetail_21_265507 n inner join db1.gonzo a using(gonzo)', 
   {
      'n'        => 'tuningdetail_21_265507',
      'a'        => 'gonzo',
      'DATABASE' => {
         'tuningdetail_21_265507' => 'db2',
         'gonzo'                  => 'db1',
      },
   },
   [qw(db2.tuningdetail_21_265507 db1.gonzo)],
   'SELECT with JOIN ON and no WHERE (issue 185)'
);

# #############################################################################
test_query(
   'select 12_13_foo from (select 12foo from 123_bar) as 123baz',
   {
      '123baz' => undef,
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

test_query(
   q{SELECT count(*) AS count_all FROM `impact_actions`  LEFT OUTER JOIN }
      . q{recommended_change_events ON (impact_actions.event_id = }
      . q{recommended_change_events.event_id) LEFT OUTER JOIN }
      . q{recommended_change_aments ON (impact_actions.ament_id = }
      . q{recommended_change_aments.ament_id) WHERE (impact_actions.user_id = 71058 }
      # An old version of the regex used to think , was the precursor to a
      # table name, so it would pull out 7,8,9,10,11 as table names.
      . q{AND (impact_actions.action_type IN (4,7,8,9,10,11) AND }
      . q{(impact_actions.change_id = 2699 OR recommended_change_events.change_id = }
      . q{2699 OR recommended_change_aments.change_id = 2699)))},
   {
      '`impact_actions`'          => '`impact_actions`',
      'recommended_change_events' => 'recommended_change_events',
      'recommended_change_aments' => 'recommended_change_aments',
   },
   [qw(`impact_actions` recommended_change_events recommended_change_aments)],
   'Does not think IN() list has table names',
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

is_deeply(
   [ $qp->get_tables(
      'SELECT * FROM (SELECT * FROM foo WHERE UserId = 577854809 ORDER BY foo DESC) q1 GROUP BY foo ORDER BY bar DESC LIMIT 3')
   ],
   [qw(foo)],
   'get_tables on simple subquery'
);

ok($qp->has_derived_table(
   'select * from ( select 1) as x'),
   'simple derived');
ok($qp->has_derived_table(
   'select * from a join ( select 1) as x'),
   'join, derived');
ok($qp->has_derived_table(
   'select * from a join b, (select 1) as x'),
   'comma join, derived');
is($qp->has_derived_table(
   'select * from foo'),
   '', 'no derived');
is($qp->has_derived_table(
   'select * from foo where a in(select a from b)'),
   '', 'no derived on correlated');

exit;
