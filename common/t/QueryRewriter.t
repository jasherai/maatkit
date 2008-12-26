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

use Test::More tests => 51;
use English qw(-no_match_vars);

require "../QueryRewriter.pm";

my $q = new QueryRewriter();

is(
   $q->strip_comments("select \n--bar\n foo"),
   "select foo",
   'Removes one-line comments',
);

is(
   $q->strip_comments("select foo -- bar"),
   "select foo",
   'Removes one-line comments at end of line',
);

is(
   $q->fingerprint("use `foo`"),
   "use ?",
   'Removes identifier from USE',
);

is(
   $q->fingerprint("select \n--bar\n foo"),
   "select foo",
   'Removes one-line comments in fingerprints',
);

is(
   $q->fingerprint("select foo -- bar\n"),
   "select foo",
   'Removes one-line comments in fingerprints',
);

is(
   $q->fingerprint("select 5.001, 5001. from foo"),
   "select ?, ? from foo",
   "Handles bug from perlmonks thread 728718",
);

is(
   $q->fingerprint("select 'hello', \"hello\", '\\'' from foo"),
   "select ?, ?, ? from foo",
   "Handles quoted strings",
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
   $q->fingerprint('insert into foo(a, b, c) values(2, 4, 5)'),
   'insert into foo(a, b, c) values(?+)',
   'VALUES lists',
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
   $q->convert_to_select(
      'update foo inner join bar using(baz) set big=little',
   ),
   'select  big=little from foo inner join bar using(baz) ',
   'delete inner join',
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

is (
   $q->convert_to_select(q{
REPLACE DELAYED INTO
`db1`.`tbl2`(`col1`,col2)
VALUES ('617653','2007-09-11')}),
   qq{select * from \n`db1`.`tbl2` where `col1`='617653' and col2='2007-09-11'},
   'replace delayed',
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

is(
   $q->convert_to_select("UPDATE tbl SET col='wherex'WHERE crazy=1"),
   "select  col='wherex' from tbl where  crazy=1",
   "update with SET col='wherex'WHERE"
);

