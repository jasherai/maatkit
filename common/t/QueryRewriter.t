#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
use strict;
use warnings FATAL => 'all';

use Test::More tests => 95;
use English qw(-no_match_vars);

require "../QueryRewriter.pm";

my $q = new QueryRewriter();

is(
   $q->strip_comments("select \n--bar\n foo"),
   "select \n\n foo",
   'Removes one-line comments',
);

is(
   $q->strip_comments("select foo--bar\nfoo"),
   "select foo\nfoo",
   'Removes one-line comments without running them together',
);

is(
   $q->strip_comments("select foo -- bar"),
   "select foo ",
   'Removes one-line comments at end of line',
);

is(
   $q->fingerprint(
      q{UPDATE groups_search SET  charter = '   -------3\'\' XXXXXXXXX.\n    \n    -----------------------------------------------------', show_in_list = 'Y' WHERE group_id='aaaaaaaa'}),
   'update groups_search set charter = ?, show_in_list = ? where group_id=?',
   'complex comments',
);

is(
   $q->fingerprint("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
   "mysqldump",
   'Fingerprints all mysqldump SELECTs together',
);

is(
   $q->distill("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
   "SELECT film",
   'Distills mysqldump SELECTs to selects',
);

is(
   $q->fingerprint("CALL foo(1, 2, 3)"),
   "call foo",
   'Fingerprints stored procedure calls specially',
);

is(
   $q->distill("CALL foo(1, 2, 3)"),
   "CALL foo",
   'Distills stored procedure calls specially',
);

is(
   $q->fingerprint('# administrator command: Init DB'),
   '# administrator command: Init DB',
   'Fingerprints admin commands as themselves',
);

is(
   $q->distill('# administrator command: Init DB'),
   'ADMIN',
   'Distills admin commands together',
);

is(
   $q->fingerprint(
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
      .q{(`id` >= 2166633); }),
   'maatkit',
   'Fingerprints mk-table-checksum queries together',
);

is(
   $q->distill(
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
      .q{(`id` >= 2166633); }),
   'REPLACE SELECT checksum.checksum foo.bar',
   'Distills mk-table-checksum query',
);

is(
   $q->fingerprint("use `foo`"),
   "use ?",
   'Removes identifier from USE',
);

is(
   $q->distill("use `foo`"),
   "USE",
   'distills USE',
);

is(
   $q->fingerprint("select \n--bar\n foo"),
   "select foo",
   'Removes one-line comments in fingerprints',
);

is(
   $q->distill("select \n--bar\n foo"),
   "SELECT",
   'distills queries from DUAL',
);

is(
   $q->fingerprint("select foo--bar\nfoo"),
   "select foo foo",
   'Removes one-line comments in fingerprint without mushing things together',
);

is(
   $q->fingerprint("select foo -- bar\n"),
   "select foo ",
   'Removes one-line EOL comments in fingerprints',
);

# This one is too expensive!
#is(
#   $q->fingerprint(
#      "select a,b ,c , d from tbl where a=5 or a = 5 or a=5 or a =5"),
#   "select a, b, c, d from tbl where a=? or a=? or a=? or a=?",
#   "Normalizes commas and equals",
#);

is(
   $q->fingerprint("select null, 5.001, 5001. from foo"),
   "select ?, ?, ? from foo",
   "Handles bug from perlmonks thread 728718",
);

is(
   $q->distill("select null, 5.001, 5001. from foo"),
   "SELECT foo",
   "distills simple select",
);

is(
   $q->fingerprint("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
   "select ?, ?, ?, ? from foo",
   "Handles quoted strings",
);

is(
   $q->distill("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
   "SELECT foo",
   "distills with quoted strings",
);

is(
   $q->fingerprint("select 'hello'\n"),
   "select ?",
   "Handles trailing newline",
);

# This is a known deficiency, fixes seem to be expensive though.
is(
   $q->fingerprint("select '\\\\' from foo"),
   "select '\\ from foo",
   "Does not handle all quoted strings",
);

is(
   $q->fingerprint("select   foo"),
   "select foo",
   'Collapses whitespace',
);

is(
   $q->strip_comments("select /*\nhello!*/ 1"),
   'select  1',
   'Stripped star comment',
);

is(
   $q->strip_comments('select /*!40101 hello*/ 1'),
   'select /*!40101 hello*/ 1',
   'Left version star comment',
);

is(
   $q->fingerprint('SELECT * from foo where a = 5'),
   'select * from foo where a = ?',
   'Lowercases, replaces integer',
);

is(
   $q->fingerprint('select 0e0, +6e-30, -6.00 from foo where a = 5.5 or b=0.5 or c=.5'),
   'select ?, ?, ? from foo where a = ? or b=? or c=?',
   'Floats',
);

is(
   $q->fingerprint("select 0x0, x'123', 0b1010, b'10101' from foo"),
   'select ?, ?, ?, ? from foo',
   'Hex/bit',
);

is(
   $q->fingerprint(" select  * from\nfoo where a = 5"),
   'select * from foo where a = ?',
   'Collapses whitespace',
);

is(
   $q->fingerprint("select * from foo where a in (5) and b in (5, 8,9 ,9 , 10)"),
   'select * from foo where a in(?+) and b in(?+)',
   'IN lists',
);

is(
   $q->fingerprint("select foo_1 from foo_2_3"),
   'select foo_? from foo_?_?',
   'Numeric table names',
);

is(
   $q->distill("select foo_1 from foo_2_3"),
   'SELECT foo_?_?',
   'distills numeric table names',
);

# 123f00 => ?oo because f "looks like it could be a number".
is(
   $q->fingerprint("select 123foo from 123foo", { prefixes => 1 }),
   'select ?oo from ?oo',
   'Numeric table name prefixes',
);

is(
   $q->fingerprint("select 123_foo from 123_foo", { prefixes => 1 }),
   'select ?_foo from ?_foo',
   'Numeric table name prefixes with underscores',
);

is(
   $q->fingerprint("insert into abtemp.coxed select foo.bar from foo"),
   'insert into abtemp.coxed select foo.bar from foo',
   'A string that needs no changes',
);

is(
   $q->distill("insert into abtemp.coxed select foo.bar from foo"),
   'INSERT SELECT abtemp.coxed foo',
   'distills insert/select',
);

is(
   $q->fingerprint('insert into foo(a, b, c) values(2, 4, 5)'),
   'insert into foo(a, b, c) values(?+)',
   'VALUES lists',
);

is(
   $q->distill('insert into foo(a, b, c) values(2, 4, 5)'),
   'INSERT foo',
   'distills value lists',
);

is(
   $q->fingerprint('insert into foo(a, b, c) values(2, 4, 5) , (2,4,5)'),
   'insert into foo(a, b, c) values(?+)',
   'VALUES lists with multiple ()',
);

is(
   $q->fingerprint('insert into foo(a, b, c) value(2, 4, 5)'),
   'insert into foo(a, b, c) value(?+)',
   'VALUES lists with VALUE()',
);

is(
   $q->fingerprint('select * from foo limit 5'),
   'select * from foo limit ?',
   'limit alone',
);

is(
   $q->fingerprint('select * from foo limit 5, 10'),
   'select * from foo limit ?',
   'limit with comma-offset',
);

is(
   $q->fingerprint('select * from foo limit 5 offset 10'),
   'select * from foo limit ?',
   'limit with offset',
);

is(
   $q->fingerprint('select 1 union select 2 union select 4'),
   'select ? /*repeat union*/',
   'union fingerprints together',
);

is(
   $q->distill('select 1 union select 2 union select 4'),
   'SELECT UNION',
   'union distills together',
);

is(
   $q->fingerprint('select 1 union all select 2 union all select 4'),
   'select ? /*repeat union all*/',
   'union all fingerprints together',
);

is(
   $q->fingerprint(
      q{select * from (select 1 union all select 2 union all select 4) as x }
      . q{join (select 2 union select 2 union select 3) as y}),
   q{select * from (select ? /*repeat union all*/) as x }
      . q{join (select ? /*repeat union*/) as y},
   'union all fingerprints together',
);

is($q->convert_to_select(), undef, 'No query');

is(
   $q->convert_to_select(
      'replace into foo select * from bar',
   ),
   'select * from bar',
   'replace select',
);

is(
   $q->convert_to_select(
      'replace into foo select`faz` from bar',
   ),
   'select`faz` from bar',
   'replace select',
);

is(
   $q->convert_to_select(
      'insert into foo(a, b, c) values(1, 3, 5)',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'insert',
);

is(
   $q->convert_to_select(
      'insert ignore into foo(a, b, c) values(1, 3, 5)',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'insert ignore',
);

is(
   $q->convert_to_select(
      'insert into foo(a, b, c) value(1, 3, 5)',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'insert with VALUE()',
);

is(
   $q->convert_to_select(
      'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
   ),
   'select * from  foo where a=1 and  b= 3 and  c= 5',
   'replace with ODKU',
);

is(
   $q->distill(
      'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
   ),
   'REPLACE UPDATE foo',
   'distills ODKU',
);

is(
   $q->convert_to_select(
      'replace into foo(a, b, c) values(now(), "3", 5)',
   ),
   'select * from  foo where a=now() and  b= "3" and  c= 5',
   'replace with complicated expressions',
);

is(
   $q->convert_to_select(
      'replace into foo(a, b, c) values(current_date - interval 1 day, "3", 5)',
   ),
   'select * from  foo where a=current_date - interval 1 day and  b= "3" and  c= 5',
   'replace with complicated expressions',
);

is(
   $q->convert_to_select(
      'insert into foo select * from bar join baz using (bat)',
   ),
   'select * from bar join baz using (bat)',
   'insert select',
);

is(
   $q->distill(
      'insert into foo select * from bar join baz using (bat)',
   ),
   'INSERT SELECT foo bar baz',
   'distills insert select',
);

is(
   $q->convert_to_select(
      'insert into foo select * from bar where baz=bat on duplicate key update',
   ),
   'select * from bar where baz=bat',
   'insert select on duplicate key update',
);

is(
   $q->convert_to_select(
      'update foo set bar=baz where bat=fiz',
   ),
   'select  bar=baz from foo where  bat=fiz',
   'update set',
);

is(
   $q->distill(
      'update foo set bar=baz where bat=fiz',
   ),
   'UPDATE foo',
   'distills update',
);

is(
   $q->convert_to_select(
      'update foo inner join bar using(baz) set big=little',
   ),
   'select  big=little from foo inner join bar using(baz) ',
   'delete inner join',
);

is(
   $q->distill(
      'update foo inner join bar using(baz) set big=little',
   ),
   'UPDATE foo bar',
   'distills update-multi',
);

is(
   $q->convert_to_select(
      'update foo set bar=baz limit 50',
   ),
   'select  bar=baz  from foo  limit 50 ',
   'update with limit',
);

is(
   $q->convert_to_select(
q{UPDATE foo.bar
SET    whereproblem= '3364', apple = 'fish'
WHERE  gizmo='5091'}
   ),
   q{select     whereproblem= '3364', apple = 'fish' from foo.bar where   gizmo='5091'},
   'unknown issue',
);

is(
   $q->convert_to_select(
      'delete from foo where bar = baz',
   ),
   'select * from  foo where bar = baz',
   'delete',
);

is(
   $q->distill(
      'delete from foo where bar = baz',
   ),
   'DELETE foo',
   'distills delete',
);

# Insanity...
is(
   $q->convert_to_select('
update db2.tbl1 as p
   inner join (
      select p2.col1, p2.col2
      from db2.tbl1 as p2
         inner join db2.tbl3 as ba
            on p2.col1 = ba.tbl3
      where col4 = 0
      order by priority desc, col1, col2
      limit 10
   ) as chosen on chosen.col1 = p.col1
      and chosen.col2 = p.col2
   set p.col4 = 149945'),
   'select  p.col4 = 149945 from db2.tbl1 as p
   inner join (
      select p2.col1, p2.col2
      from db2.tbl1 as p2
         inner join db2.tbl3 as ba
            on p2.col1 = ba.tbl3
      where col4 = 0
      order by priority desc, col1, col2
      limit 10
   ) as chosen on chosen.col1 = p.col1
      and chosen.col2 = p.col2 ',
   'SELECT in the FROM clause',
);

is(
   $q->distill('
update db2.tbl1 as p
   inner join (
      select p2.col1, p2.col2
      from db2.tbl1 as p2
         inner join db2.tbl3 as ba
            on p2.col1 = ba.tbl3
      where col4 = 0
      order by priority desc, col1, col2
      limit 10
   ) as chosen on chosen.col1 = p.col1
      and chosen.col2 = p.col2
   set p.col4 = 149945'),
   'UPDATE SELECT db?.tbl?',
   'distills complex subquery',
);

is(
   $q->convert_to_select(q{INSERT INTO foo.bar (col1, col2, col3)
       VALUES ('unbalanced(', 'val2', 3)}),
   q{select * from  foo.bar  where col1='unbalanced(' and  }
   . q{col2= 'val2' and  col3= 3},
   'unbalanced paren inside a string in VALUES',
);

is(
   $q->convert_to_select(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
   'select 1 from  foo.bar b left join baz.bat c on a=b where nine>eight',
   'Do not select * from a join',
);

is(
   $q->distill(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
   'DELETE foo.bar baz.bat',
   'distills and then collapses same tables',
);

is (
   $q->convert_to_select(q{
REPLACE DELAYED INTO
`db1`.`tbl2`(`col1`,col2)
VALUES ('617653','2007-09-11')}),
   qq{select * from \n`db1`.`tbl2` where `col1`='617653' and col2='2007-09-11'},
   'replace delayed',
);

is (
   $q->distill(q{
REPLACE DELAYED INTO
`db1`.`tbl2`(`col1`,col2)
VALUES ('617653','2007-09-11')}),
   'REPLACE db?.tbl?',
   'distills replace-delayed',
);

is(
   $q->convert_to_select(
      'select * from tbl where id = 1'
   ),
   'select * from tbl where id = 1',
   'Does not convert select to select',
);

is($q->wrap_in_derived(), undef, 'Cannot wrap undef');

is(
   $q->wrap_in_derived(
      'select * from foo',
   ),
   'select 1 from (select * from foo) as x limit 1',
   'wrap in derived table',
);

is(
   $q->wrap_in_derived('set timestamp=134'),
   'set timestamp=134',
   'Do not wrap non-SELECT queries',
);

is(
   $q->distill('set timestamp=134'),
   'SET',
   'distills set',
);

is(
   $q->convert_select_list('select * from tbl'),
   'select 1 from tbl',
   'Star to one',
);

is(
   $q->convert_select_list('select a, b, c from tbl'),
   'select isnull(coalesce( a, b, c )) from tbl',
   'column list to isnull/coalesce'
);

is($q->convert_to_select(
   q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
   . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
   . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
   . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
   . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
   . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
   . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
   "select  GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME='Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59' from GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU where  PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1 AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0 AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )",
   'update with no space between quoted string and where (issue 168)'
);

is($q->distill(
   q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
   . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
   . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
   . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
   . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
   . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
   . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
   'UPDATE GARDEN_CLUPL GARDENJOB APLTRACT_GARDENPLANT',
   'distills where there is alias and comma-join',
);

is(
   $q->distill(q{SELECT STRAIGHT_JOIN distinct foo, bar FROM A, B, C}),
   'SELECT A B C',
   'distill with STRAIGHT_JOIN',
);

is(
   $q->distill(
      'replace into checksum.checksum select `last_update`, `foo` from foo.foo'),
   'REPLACE SELECT checksum.checksum foo.foo',
   'distill with reserved words');

is($q->distill('SHOW STATUS'), 'SHOW', 'distill SHOW');

is($q->distill('commit'), 'COMMIT', 'distill COMMIT');

is($q->distill('FLUSH TABLES WITH READ LOCK'), 'FLUSH', 'distill FLUSH');

is($q->distill('BEGIN'), 'BEGIN', 'distill BEGIN');

is($q->distill('start'), 'START', 'distill START');

is($q->distill('ROLLBACK'), 'ROLLBACK', 'distill ROLLBACK');

is(
   $q->convert_to_select("UPDATE tbl SET col='wherex'WHERE crazy=1"),
   "select  col='wherex' from tbl where  crazy=1",
   "update with SET col='wherex'WHERE"
);
