#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';

use Test::More tests => 83;
use English qw(-no_match_vars);

use MaatkitTest;
use SQLParser;

my $sp = new SQLParser();

# #############################################################################
# Whitespace and comments.
# #############################################################################
is(
   $sp->clean_query(' /* leading comment */select *
      from tbl where /* comment */ id=1  /*trailing comment*/ '
   ),
   'select * from tbl where  id=1',
   'Remove extra whitespace and comment blocks'
);

is(
   $sp->clean_query('/*
      leading comment
      on multiple lines
*/ select * from tbl where /* another
silly comment */ id=1
/*trailing comment
also on mutiple lines*/ '
   ),
   'select * from tbl where  id=1',
   'Remove multi-line comment blocks'
);

is(
   $sp->clean_query('-- SQL style      
   -- comments
   --

  
select now()
'
   ),
   'select now()',
   'Remove multiple -- comment lines and blank lines'
);


# #############################################################################
# Add space between key tokens.
# #############################################################################
is(
   $sp->clean_query('insert into t value(1)'),
   'insert into t value (1)',
   'Add space VALUE (cols)'
);

is(
   $sp->clean_query('insert into t values(1)'),
   'insert into t values (1)',
   'Add space VALUES (cols)'
);

is(
   $sp->clean_query('select * from a join b on(foo)'),
   'select * from a join b on (foo)',
   'Add space ON (conditions)'
);

is(
   $sp->clean_query('select * from a join b on(foo) join c on(bar)'),
   'select * from a join b on (foo) join c on (bar)',
   'Add space multiple ON (conditions)'
);

is(
   $sp->clean_query('select * from a join b using(foo)'),
   'select * from a join b using (foo)',
   'Add space using (conditions)'
);

is(
   $sp->clean_query('select * from a join b using(foo) join c using(bar)'),
   'select * from a join b using (foo) join c using (bar)',
   'Add space multiple USING (conditions)'
);

is(
   $sp->clean_query('select * from a join b using(foo) join c on(bar)'),
   'select * from a join b using (foo) join c on (bar)',
   'Add space USING and ON'
);

# ###########################################################################
# ORDER BY
# ###########################################################################
is_deeply(
   $sp->parse_order_by('foo'),
   [qw(foo)],
   'ORDER BY foo'
);
is_deeply(
   $sp->parse_order_by('foo'),
   [qw(foo)],
   'order by foo'
);
is_deeply(
   $sp->parse_order_by('foo, bar'),
   [qw(foo bar)],
   'order by foo, bar'
);
is_deeply(
   $sp->parse_order_by('foo asc, bar'),
   ['foo asc', 'bar'],
   'order by foo asc, bar'
);
is_deeply(
   $sp->parse_order_by('1'),
   [qw(1)],
   'ORDER BY 1'
);
is_deeply(
   $sp->parse_order_by('RAND()'),
   ['RAND()'],
   'ORDER BY RAND()'
);

# ###########################################################################
# LIMIT
# ###########################################################################
is_deeply(
   $sp->parse_limit('1'),
   { row_count => 1, },
   'LIMIT 1'
);
is_deeply(
   $sp->parse_limit('1, 2'),
   { row_count => 2,
     offset    => 1,
   },
   'LIMIT 1, 2'
);
is_deeply(
   $sp->parse_limit('5 OFFSET 10'),
   { row_count       => 5,
     offset          => 10,
     explicit_offset => 1,
   },
   'LIMIT 5 OFFSET 10'
);


# ###########################################################################
# FROM table_references
# ###########################################################################
sub test_from {
   my ( $from, $struct ) = @_;
   is_deeply(
      $sp->parse_from($from),
      $struct,
      "FROM $from"
   );
};

test_from(
   'tbl',
   [ { name => 'tbl', } ],
);

test_from(
   'tbl ta',
   [ { name  => 'tbl', alias => 'ta', }  ],
);

test_from(
   'tbl AS ta',
   [ { name           => 'tbl',
       alias          => 'ta',
       explicit_alias => 1,
   } ],
);

test_from(
   't1, t2',
   [
      { name => 't1', },
      {
         name => 't2',
         join => {
            to    => 't1',
            type  => 'inner',
            ansi  => 0,
         },
      }
   ],
);

test_from(
   't1 a, t2 as b',
   [
      { name  => 't1',
        alias => 'a',
      },
      {
        name           => 't2',
        alias          => 'b',
        explicit_alias => 1,
        join           => {
            to   => 't1',
            type => 'inner',
            ansi => 0,
         },
      }
   ],
);


test_from(
   't1 JOIN t2 ON t1.id=t2.id',
   [
      {
         name => 't1',
      },
      {
         name => 't2',
         join => {
            to         => 't1',
            type       => '',
            condition  => 'on',
            predicates => 't1.id=t2.id ',
            ansi       => 1,
         },
      }
   ],
);

test_from(
   't1 a JOIN t2 as b USING (id)',
   [
      {
         name  => 't1',
         alias => 'a',
      },
      {
         name  => 't2',
         alias => 'b',
         explicit_alias => 1,
         join  => {
            to         => 't1',
            type       => '',
            condition  => 'using',
            predicates => '(id) ',
            ansi       => 1,
         },
      },
   ],
);

test_from(
   't1 JOIN t2 ON t1.id=t2.id JOIN t3 ON t1.id=t3.id',
   [
      {
         name  => 't1',
      },
      {
         name  => 't2',
         join  => {
            to         => 't1',
            type       => '',
            condition  => 'on',
            predicates => 't1.id=t2.id ',
            ansi       => 1,
         },
      },
      {
         name  => 't3',
         join  => {
            to         => 't2',
            type       => '',
            condition  => 'on',
            predicates => 't1.id=t3.id ',
            ansi       => 1,
         },
      },
   ],
);

test_from(
   't1 AS a LEFT JOIN t2 b ON a.id = b.id',
   [
      {
         name  => 't1',
         alias => 'a',
         explicit_alias => 1,
      },
      {
         name  => 't2',
         alias => 'b',
         join  => {
            to         => 't1',
            type       => 'left',
            condition  => 'on',
            predicates => 'a.id = b.id ',
            ansi       => 1,
         },
      },
   ],
);

test_from(
   't1 a NATURAL RIGHT OUTER JOIN t2 b',
   [
      {
         name  => 't1',
         alias => 'a',
      },
      {
         name  => 't2',
         alias => 'b',
         join  => {
            to   => 't1',
            type => 'natural right outer',
            ansi => 1,
         },
      },
   ],
);

# http://pento.net/2009/04/03/join-and-comma-precedence/
test_from(
   'a, b LEFT JOIN c ON c.c = a.a',
   [
      {
         name  => 'a',
      },
      {
         name  => 'b',
         join  => {
            to   => 'a',
            type => 'inner',
            ansi => 0,
         },
      },
      {
         name  => 'c',
         join  => {
            to         => 'b',
            type       => 'left',
            condition  => 'on',
            predicates => 'c.c = a.a ',
            ansi       => 1, 
         },
      },
   ],
);

test_from(
   'a, b, c CROSS JOIN d USING (id)',
   [
      {
         name  => 'a',
      },
      {
         name  => 'b',
         join  => {
            to   => 'a',
            type => 'inner',
            ansi => 0,
         },
      },
      {
         name  => 'c',
         join  => {
            to   => 'b',
            type => 'inner',
            ansi => 0,
         },
      },
      {
         name  => 'd',
         join  => {
            to         => 'c',
            type       => 'cross',
            condition  => 'using',
            predicates => '(id) ',
            ansi       => 1, 
         },
      },
   ],
);

# Index hints.
test_from(
   'tbl FORCE INDEX (foo)',
   [
      {
         name       => 'tbl',
         index_hint => 'FORCE INDEX (foo)',
      }
   ]
);

test_from(
   'tbl USE INDEX(foo)',
   [
      {
         name       => 'tbl',
         index_hint => 'USE INDEX(foo)',
      }
   ]
);

test_from(
   'tbl FORCE KEY(foo)',
   [
      {
         name       => 'tbl',
         index_hint => 'FORCE KEY(foo)',
      }
   ]
);

test_from(
   'tbl t FORCE KEY(foo)',
   [
      {
         name       => 'tbl',
         alias      => 't',
         index_hint => 'FORCE KEY(foo)',
      }
   ]
);

test_from(
   'tbl AS t FORCE KEY(foo)',
   [
      {
         name           => 'tbl',
         alias          => 't',
         explicit_alias => 1,
         index_hint     => 'FORCE KEY(foo)',
      }
   ]
);

# #############################################################################
# parse_identifier()
# #############################################################################
sub test_parse_identifier {
   my ( $tbl, $struct ) = @_;
   my %s = $sp->parse_identifier($tbl);
   is_deeply(
      \%s,
      $struct,
      $tbl
   );
   return;
}

test_parse_identifier('tbl',
   { name => 'tbl', }
);

test_parse_identifier('tbl a',
   { name => 'tbl', alias => 'a', }
);

test_parse_identifier('tbl as a',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_identifier('tbl AS a',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_identifier('db.tbl',
   { name => 'tbl', db => 'db', }
);

test_parse_identifier('db.tbl a',
   { name => 'tbl', db => 'db', alias => 'a', }
);

test_parse_identifier('db.tbl AS a',
   { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
);


test_parse_identifier('`tbl`',
   { name => 'tbl', }
);

test_parse_identifier('`tbl` `a`',
   { name => 'tbl', alias => 'a', }
);

test_parse_identifier('`tbl` as `a`',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_identifier('`tbl` AS `a`',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_identifier('`db`.`tbl`',
   { name => 'tbl', db => 'db', }
);

test_parse_identifier('`db`.`tbl` `a`',
   { name => 'tbl', db => 'db', alias => 'a', }
);

test_parse_identifier('`db`.`tbl` AS `a`',
   { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
);

test_parse_identifier('db.* foo',
   { name => '*', db => 'db', alias => 'foo' }
);

# #############################################################################
# Subqueries.
# #############################################################################

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $query = "DELETE FROM t1
WHERE s11 > ANY
(SELECT COUNT(*) /* no hint */ FROM t2 WHERE NOT EXISTS
   (SELECT * FROM t3 WHERE ROW(5*t2.s1,77)=
      (SELECT 50,11*s1 FROM
         (SELECT * FROM t5) AS t5
      )
   )
)";
my @subqueries = $sp->remove_subqueries($sp->clean_query($query));
is_deeply(
   \@subqueries,
   [
      'DELETE FROM t1 WHERE s11 > ANY (__SQ3__)',
      {
         alias   => 't5',
         query   => 'SELECT * FROM t5',
         context => 'identifier',
         nested  => 1,
      },
      {
         query   => 'SELECT 50,11*s1 FROM __SQ0__',
         context => 'scalar',
         nested  => 2,
      },
      {
         query   => 'SELECT * FROM t3 WHERE ROW(5*t2.s1,77)= __SQ1__',
         context => 'list',
         nested  => 3,
      },
      {
         query   => 'SELECT COUNT(*)  FROM t2 WHERE NOT EXISTS (__SQ2__)',
         context => 'list',
      }
   ],
   'DELETE with nested subqueries'
);

$query = "select col from tbl
          where id=(select max(id) from tbl2 where foo='bar') limit 1";
@subqueries = $sp->remove_subqueries($sp->clean_query($query));
is_deeply(
   \@subqueries,
   [
      'select col from tbl where id=__SQ0__ limit 1',
      {
         query   => "select max(id) from tbl2 where foo='bar'",
         context => 'scalar',
      },
   ],
   'Subquery as scalar'
);

$query = "select col from tbl
          where id=(select max(id) from tbl2 where foo='bar') and col in(select foo from tbl3) limit 1";
@subqueries = $sp->remove_subqueries($sp->clean_query($query));
is_deeply(
   \@subqueries,
   [
      'select col from tbl where id=__SQ1__ and col in(__SQ0__) limit 1',
      {
         query   => "select foo from tbl3",
         context => 'list',
      },
      {
         query   => "select max(id) from tbl2 where foo='bar'",
         context => 'scalar',
      },
   ],
   'Subquery as scalar and IN()'
);

$query = "SELECT NOW() AS a1, (SELECT f1(5)) AS a2";
@subqueries = $sp->remove_subqueries($sp->clean_query($query));
is_deeply(
   \@subqueries,
   [
      'SELECT NOW() AS a1, __SQ0__ ',
      {
         query   => "SELECT f1(5)",
         alias   => 'a2',
         context => 'identifier',
      },
   ],
   'Subquery as SELECT column'
);

$query = "SELECT DISTINCT store_type FROM stores s1
WHERE NOT EXISTS (
SELECT * FROM cities WHERE NOT EXISTS (
SELECT * FROM cities_stores
WHERE cities_stores.city = cities.city
AND cities_stores.store_type = stores.store_type))";
@subqueries = $sp->remove_subqueries($sp->clean_query($query));
is_deeply(
   \@subqueries,
   [
      'SELECT DISTINCT store_type FROM stores s1 WHERE NOT EXISTS (__SQ1__)',
      {
         query   => "SELECT * FROM cities_stores WHERE cities_stores.city = cities.city AND cities_stores.store_type = stores.store_type",
         context => 'list',
         nested  => 1,
      },
      {
         query   => "SELECT * FROM cities WHERE NOT EXISTS (__SQ0__)",
         context => 'list',
      },
   ],
   'Two nested NOT EXISTS subqueries'
);

$query = "select col from tbl
          where id=(select max(id) from tbl2 where foo='bar')
          and col in(select foo from
            (select b from fn where id=1
               and b > any(select a from a)
            )
         ) limit 1";
@subqueries = $sp->remove_subqueries($sp->clean_query($query));
is_deeply(
   \@subqueries,
   [
      'select col from tbl where id=__SQ1__ and col in(__SQ0__) limit 1',
      {
         query    => 'select a from a',
         context  => 'list',
         nested   => 1,
      },
      {
         query    => 'select b from fn where id=1 and b > any(__SQ0__)',
         context  => 'identifier',
         nested   => 2,
      },
   ],
   'Subquery as scalar and IN()'
);

# #############################################################################
# Test parsing full queries.
# #############################################################################

my @cases = (

   # ########################################################################
   # DELETE
   # ########################################################################
   {  name   => 'DELETE FROM',
      query  => 'DELETE FROM tbl',
      struct => {
         type    => 'delete',
         clauses => { from => 'tbl', },
         from    => [ { name => 'tbl', } ],
         unknown => undef,
      },
   },
   {  name   => 'DELETE FROM WHERE',
      query  => 'DELETE FROM tbl WHERE id=1',
      struct => {
         type    => 'delete',
         clauses => { 
            from  => 'tbl ',
            where => 'id=1',
         },
         from    => [ { name => 'tbl', } ],
         where   => 'id=1',
         unknown => undef,
      },
   },
   {  name   => 'DELETE FROM LIMIT',
      query  => 'DELETE FROM tbl LIMIT 5',
      struct => {
         type    => 'delete',
         clauses => {
            from  => 'tbl ',
            limit => '5',
         },
         from    => [ { name => 'tbl', } ],
         limit   => {
            row_count => 5,
         },
         unknown => undef,
      },
   },
   {  name   => 'DELETE FROM ORDER BY',
      query  => 'DELETE FROM tbl ORDER BY foo',
      struct => {
         type    => 'delete',
         clauses => {
            from     => 'tbl ',
            order_by => 'foo',
         },
         from     => [ { name => 'tbl', } ],
         order_by => [qw(foo)],
         unknown  => undef,
      },
   },
   {  name   => 'DELETE FROM WHERE LIMIT',
      query  => 'DELETE FROM tbl WHERE id=1 LIMIT 3',
      struct => {
         type    => 'delete',
         clauses => { 
            from  => 'tbl ',
            where => 'id=1 ',
            limit => '3',
         },
         from    => [ { name => 'tbl', } ],
         where   => 'id=1 ',
         limit   => {
            row_count => 3,
         },
         unknown => undef,
      },
   },
   {  name   => 'DELETE FROM WHERE ORDER BY',
      query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id',
      struct => {
         type    => 'delete',
         clauses => { 
            from     => 'tbl ',
            where    => 'id=1 ',
            order_by => 'id',
         },
         from     => [ { name => 'tbl', } ],
         where    => 'id=1 ',
         order_by => [qw(id)],
         unknown  => undef,
      },
   },
   {  name   => 'DELETE FROM WHERE ORDER BY LIMIT',
      query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id ASC LIMIT 1 OFFSET 3',
      struct => {
         type    => 'delete',
         clauses => { 
            from     => 'tbl ',
            where    => 'id=1 ',
            order_by => 'id ASC ',
            limit    => '1 OFFSET 3',
         },
         from    => [ { name => 'tbl', } ],
         where   => 'id=1 ',
         order_by=> ['id ASC'],
         limit   => {
            row_count       => 1,
            offset          => 3,
            explicit_offset => 1,
         },
         unknown => undef,
      },
   },

   # ########################################################################
   # INSERT
   # ########################################################################
   {  name   => 'INSERT INTO VALUES',
      query  => 'INSERT INTO tbl VALUES (1,"foo")',
      struct => {
         type    => 'insert',
         clauses => { 
            into   => 'tbl',
            values => '(1,"foo")',
         },
         into   => [ { name => 'tbl', } ],
         values => [ '(1,"foo")', ],
         unknown => undef,
      },
   },
   {  name   => 'INSERT VALUE',
      query  => 'INSERT tbl VALUE (1,"foo")',
      struct => {
         type    => 'insert',
         clauses => { 
            into   => 'tbl',
            values => '(1,"foo")',
         },
         into   => [ { name => 'tbl', } ],
         values => [ '(1,"foo")', ],
         unknown => undef,
      },
   },
   {  name   => 'INSERT INTO cols VALUES',
      query  => 'INSERT INTO db.tbl (id, name) VALUE (2,"bob")',
      struct => {
         type    => 'insert',
         clauses => { 
            into    => 'db.tbl',
            columns => 'id, name ',
            values  => '(2,"bob")',
         },
         into    => [ { name => 'tbl', db => 'db' } ],
         columns => [ { name => 'id' }, { name => 'name' } ],
         values  => [ '(2,"bob")', ],
         unknown => undef,
      },
   },
   {  name   => 'INSERT INTO VALUES ON DUPLICATE',
      query  => 'INSERT INTO tbl VALUE (3,"bob") ON DUPLICATE KEY UPDATE col1=9',
      struct => {
         type    => 'insert',
         clauses => { 
            into         => 'tbl',
            values       => '(3,"bob") ',
            on_duplicate => 'col1=9',
         },
         into         => [ { name => 'tbl', } ],
         values       => [ '(3,"bob")', ],
         on_duplicate => ['col1=9',],
         unknown      => undef,
      },
   },
   {  name   => 'INSERT INTO SET',
      query  => 'INSERT INTO tbl SET id=1, foo=NULL',
      struct => {
         type    => 'insert',
         clauses => { 
            into => 'tbl',
            set  => 'id=1, foo=NULL',
         },
         into    => [ { name => 'tbl', } ],
         set     => ['id=1', 'foo=NULL',],
         unknown => undef,
      },
   },
   {  name   => 'INSERT INTO SET ON DUPLICATE',
      query  => 'INSERT INTO tbl SET i=3 ON DUPLICATE KEY UPDATE col1=9',
      struct => {
         type    => 'insert',
         clauses => { 
            into         => 'tbl',
            set          => 'i=3 ',
            on_duplicate => 'col1=9',
         },
         into         => [ { name => 'tbl', } ],
         set          => ['i=3',],
         on_duplicate => ['col1=9',],
         unknown      => undef,
      },
   },
   {  name   => 'INSERT ... SELECT',
      query  => 'INSERT INTO tbl (col) SELECT id FROM tbl2 WHERE id > 100',
      struct => {
         type    => 'insert',
         clauses => { 
            into    => 'tbl',
            columns => 'col ',
            select  => 'id FROM tbl2 WHERE id > 100',
         },
         into         => [ { name => 'tbl', } ],
         columns      => [ { name => 'col' } ],
         select       => {
            clauses => { 
               columns => 'id ',
               from    => 'tbl2 ',
               where   => 'id > 100',
            },
            columns => [ { name => 'id' } ],
            from    => [ { name => 'tbl2', } ],
            where   => 'id > 100',
            unknown => undef,
         },
         unknown      => undef,
      },
   },
   {  name   => 'INSERT INTO VALUES()',
      query  => 'INSERT INTO db.tbl (id, name) VALUES(2,"bob")',
      struct => {
         type    => 'insert',
         clauses => { 
            into    => 'db.tbl',
            columns => 'id, name ',
            values  => '(2,"bob")',
         },
         into    => [ { name => 'tbl', db => 'db' } ],
         columns => [ { name => 'id' }, { name => 'name' } ],
         values  => [ '(2,"bob")', ],
         unknown => undef,
      },
   },

   # ########################################################################
   # REPLACE
   # ########################################################################
   # REPLACE are parsed by parse_insert() so if INSERT is well-tested we
   # shouldn't need to test REPLACE much.
   {  name   => 'REPLACE INTO VALUES',
      query  => 'REPLACE INTO tbl VALUES (1,"foo")',
      struct => {
         type    => 'replace',
         clauses => { 
            into   => 'tbl',
            values => '(1,"foo")',
         },
         into   => [ { name => 'tbl', } ],
         values => [ '(1,"foo")', ],
         unknown => undef,
      },
   },
   {  name   => 'REPLACE VALUE',
      query  => 'REPLACE tbl VALUE (1,"foo")',
      struct => {
         type    => 'replace',
         clauses => { 
            into   => 'tbl',
            values => '(1,"foo")',
         },
         into   => [ { name => 'tbl', } ],
         values => [ '(1,"foo")', ],
         unknown => undef,
      },
   },
   {  name   => 'REPLACE INTO cols VALUES',
      query  => 'REPLACE INTO db.tbl (id, name) VALUE (2,"bob")',
      struct => {
         type    => 'replace',
         clauses => { 
            into    => 'db.tbl',
            columns => 'id, name ',
            values  => '(2,"bob")',
         },
         into    => [ { name => 'tbl', db => 'db' } ],
         columns => [ { name => 'id' }, { name => 'name' } ],
         values  => [ '(2,"bob")', ],
         unknown => undef,
      },
   },

   # ########################################################################
   # SELECT
   # ########################################################################
   {  name   => 'SELECT',
      query  => 'SELECT NOW()',
      struct => {
         type    => 'select',
         clauses => { 
            columns => 'NOW()',
         },
         columns => [ { name => 'NOW()' } ],
         unknown => undef,
      },
   },
   {  name   => 'SELECT FROM',
      query  => 'SELECT col1, col2 FROM tbl',
      struct => {
         type    => 'select',
         clauses => { 
            columns => 'col1, col2 ',
            from    => 'tbl',
         },
         columns => [ { name => 'col1' }, { name => 'col2' } ],
         from    => [ { name => 'tbl', } ],
         unknown => undef,
      },
   },
   {  name   => 'SELECT FROM JOIN WHERE GROUP BY ORDER BY LIMIT',
      query  => '/* nonsensical but covers all the basic clauses */
         SELECT t1.col1 a, t1.col2 as b
         FROM tbl1 t1
            LEFT JOIN tbl2 AS t2 ON t1.id = t2.id
         WHERE
            t2.col IS NOT NULL
            AND t2.name = "bob"
         GROUP BY a, b
         ORDER BY t2.name ASC
         LIMIT 100, 10
      ',
      struct => {
         type    => 'select',
         clauses => { 
            columns  => 't1.col1 a, t1.col2 as b ',
            from     => 'tbl1 t1 LEFT JOIN tbl2 AS t2 ON t1.id = t2.id ',
            where    => 't2.col IS NOT NULL AND t2.name = "bob" ',
            group_by => 'a, b ',
            order_by => 't2.name ASC ',
            limit    => '100, 10',
         },
         columns => [ { name => 'col1', db => 't1', alias => 'a' },
                      { name => 'col2', db => 't1', alias => 'b',
                        explicit_alias => 1 } ],
         from    => [
            {
               name  => 'tbl1',
               alias => 't1',
            },
            {
               name  => 'tbl2',
               alias => 't2',
               explicit_alias => 1,
               join  => {
                  to        => 'tbl1',
                  type      => 'left',
                  condition => 'on',
                  predicates=> 't1.id = t2.id  ',
                  ansi      => 1,
               },
            },
         ],
         where    => 't2.col IS NOT NULL AND t2.name = "bob" ',
         group_by => { columns => [qw(a b)], },
         order_by => ['t2.name ASC'],
         limit    => {
            row_count => 10,
            offset    => 100,
         },
         unknown => undef,
      },
   },
   {  name   => 'SELECT FROM JOIN ON() JOIN USING() WHERE',
      query  => 'SELECT t1.col1 a, t1.col2 as b

         FROM tbl1 t1

            JOIN tbl2 AS t2 ON(t1.id = t2.id)

            JOIN tbl3 t3 USING(id) 

         WHERE
            t2.col IS NOT NULL',
      struct => {
         type    => 'select',
         clauses => { 
            columns  => 't1.col1 a, t1.col2 as b ',
            from     => 'tbl1 t1 JOIN tbl2 AS t2 on (t1.id = t2.id) JOIN tbl3 t3 using (id) ',
            where    => 't2.col IS NOT NULL',
         },
         columns => [ { name => 'col1', db => 't1', alias => 'a' },
                      { name => 'col2', db => 't1', alias => 'b',
                        explicit_alias => 1 } ],
         from    => [
            {
               name  => 'tbl1',
               alias => 't1',
            },
            {
               name  => 'tbl2',
               alias => 't2',
               explicit_alias => 1,
               join  => {
                  to        => 'tbl1',
                  type      => '',
                  condition => 'on',
                  predicates=> '(t1.id = t2.id) ',
                  ansi      => 1,
               },
            },
            {
               name  => 'tbl3',
               alias => 't3',
               join  => {
                  to        => 'tbl2',
                  type      => '',
                  condition => 'using',
                  predicates=> '(id)  ',
                  ansi      => 1,
               },
            },
         ],
         where    => 't2.col IS NOT NULL',
         unknown => undef,
      },
   },
   {  name   => 'SELECT keywords',
      query  => 'SELECT all high_priority SQL_CALC_FOUND_ROWS NOW() LOCK IN SHARE MODE',
      struct => {
         type     => 'select',
         clauses  => { 
            columns => 'NOW()',
         },
         columns  => [ { name => 'NOW()' } ],
         keywords => {
            all                 => 1,
            high_priority       => 1,
            sql_calc_found_rows => 1,
            lock_in_share_mode  => 1,
         },
         unknown  => undef,
      },
   },
   { name   => 'SELECT * FROM WHERE',
     query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
     struct => {
         type     => 'select',
         clauses  => { 
            columns => '* ',
            from    => 'tbl ',
            where   => 'ip="127.0.0.1"',
         },
         columns  => [ { name => '*' } ],
         from     => [ { name => 'tbl' } ],
         where    => 'ip="127.0.0.1"',
         unknown  => undef,
      },
   },

   # ########################################################################
   # UPDATE
   # ########################################################################
   {  name   => 'UPDATE SET',
      query  => 'UPDATE tbl SET col=1',
      struct => {
         type    => 'update',
         clauses => { 
            tables => 'tbl ',
            set    => 'col=1',
         },
         tables  => [ { name => 'tbl', } ],
         set     => ['col=1'],
         unknown => undef,
      },
   },
   {  name   => 'UPDATE SET WHERE ORDER BY LIMIT',
      query  => 'UPDATE tbl AS t SET foo=NULL WHERE foo IS NOT NULL ORDER BY id LIMIT 10',
      struct => {
         type    => 'update',
         clauses => { 
            tables   => 'tbl AS t ',
            set      => 'foo=NULL ',
            where    => 'foo IS NOT NULL ',
            order_by => 'id ',
            limit    => '10',
         },
         tables   => [ { name => 'tbl', alias => 't', explicit_alias => 1, } ],
         set      => ['foo=NULL'],
         where    => 'foo IS NOT NULL ',
         order_by => ['id'],
         limit    => { row_count => 10 },
         unknown => undef,
      },
   },
);

foreach my $test ( @cases ) {
   my $struct = $sp->parse($test->{query});
   is_deeply(
      $struct,
      $test->{struct},
      $test->{name},
   );
}

# #############################################################################
# Done.
# #############################################################################
exit;
