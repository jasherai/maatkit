#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';

use Test::More tests => 113;
use English qw(-no_match_vars);

use MaatkitTest;
use SQLParser;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $sp = new SQLParser();

# ############################################################################
# Should throw some errors for stuff it can't do.
# ############################################################################
throws_ok(
   sub { $sp->parse('drop table foo'); },
   qr/Cannot parse DROP queries/,
   "Dies if statement type cannot be parsed"
);

# #############################################################################
# WHERE where_condition
# #############################################################################
sub test_where {
   my ( $where, $struct ) = @_;
   is_deeply(
      $sp->parse_where($where),
      $struct,
      "WHERE $where"
   );
};

test_where(
   'i=1',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '1',
      },
   ],
);

test_where(
   'i=1 or j<10 or k>100 or l != 0',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '1',
      },
      {
         predicate => 'or',
         column    => 'j',
         operator  => '<',
         value     => '10',
      },
      {
         predicate => 'or',
         column    => 'k',
         operator  => '>',
         value     => '100',
      },
      {
         predicate => 'or',
         column    => 'l',
         operator  => '!=',
         value     => '0',
      },
   ],
);

test_where(
   'i=1 and foo="bar"',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '1',
      },
      {
         predicate => 'and',
         column    => 'foo',
         operator  => '=',
         value     => '"bar"',
      },
   ],
);

test_where(
   '(i=1 and foo="bar")',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '1',
      },
      {
         predicate => 'and',
         column    => 'foo',
         operator  => '=',
         value     => '"bar"',
      },
   ],
);

test_where(
   '(i=1) and (foo="bar")',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '1',
      },
      {
         predicate => 'and',
         column    => 'foo',
         operator  => '=',
         value     => '"bar"',
      },
   ],
);

test_where(
   'i= 1 and foo ="bar" or j = 2',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '1',
      },
      {
         predicate => 'and',
         column    => 'foo',
         operator  => '=',
         value     => '"bar"',
      },
      {
         predicate => 'or',
         column    => 'j',
         operator  => '=',
         value     => '2',
      },
   ],
);

test_where(
   'i=1 and foo="i have spaces and a keyword!"',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '1',
      },
      {
         predicate => 'and',
         column    => 'foo',
         operator  => '=',
         value     => '"i have spaces and a keyword!"',
      },
   ],
);

test_where(
   'i="this and this" or j<>"that and that" and k="and or and" and z=1',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '"this and this"',
      },
      {
         predicate => 'or',
         column    => 'j',
         operator  => '<>',
         value     => '"that and that"',
      },
      {
         predicate => 'and',
         column    => 'k',
         operator  => '=',
         value     => '"and or and"',
      },
      {
         predicate => 'and',
         column    => 'z',
         operator  => '=',
         value     => '1',
      },
   ],
);

test_where(
   'i="this and this" or j in ("and", "or") and x is not null or a between 1 and 10 and sz="the keyword \'and\' is in the middle or elsewhere hidden"',
   [
      {
         predicate => undef,
         column    => 'i',
         operator  => '=',
         value     => '"this and this"',
      },
      {
         predicate => 'or',
         column    => 'j',
         operator  => 'in',
         value     => '("and", "or")',
      },
      {
         predicate => 'and',
         column    => 'x',
         operator  => 'is not',
         value     => 'null',
      },
      {
         predicate => 'or',
         column    => 'a',
         operator  => 'between',
         value     => '1 and 10',
      },
      {
         predicate => 'and',
         column    => 'sz',
         operator  => '=',
         value     => '"the keyword \'and\' is in the middle or elsewhere hidden"',
      },
   ],
);

test_where(
   "(`ga_announcement`.`disabled` = 0)",
   [
      {
         predicate => undef,
         column    => '`ga_announcement`.`disabled`',
         operator  => '=',
         value     => '0',
      },
   ]
);

test_where(
   "1",
   [
      {
         predicate => undef,
         column    => undef,
         operator  => undef,
         value     => '1',
      },
   ]
);

test_where(
   "1 and foo not like '%bar%'",
   [
      {
         predicate => undef,
         column    => undef,
         operator  => undef,
         value     => '1',
      },
      {
         predicate => 'and',
         column    => 'foo',
         operator  => 'not like',
         value     => '\'%bar%\'',
      },
   ]
);

test_where(
   "TRUE or FALSE",
   [
      {
         predicate => undef,
         column    => undef,
         operator  => undef,
         value     => 'true',
      },
      {
         predicate => 'or',
         column    => undef,
         operator  => undef,
         value     => 'false',
      },
   ]
);

test_where(
   "TO_DAYS(column) < TO_DAYS(NOW()) - 5",
   [
      {
         predicate => undef,
         column    => "TO_DAYS(column)",
         operator  => '<',
         value     => 'TO_DAYS(NOW()) - 5',
      },
   ]
);

test_where(
   "id <> CONV(ff, 16, 10)",
   [
      {
         predicate => undef,
         column    => 'id',
         operator  => '<>',
         value     => 'CONV(ff, 16, 10)',
      },
   ]
);

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
# Normalize space around certain SQL keywords.  (This makes parsing easier.)
# #############################################################################
is(
   $sp->normalize_keyword_spaces('insert into t value(1)'),
   'insert into t value (1)',
   'Add space VALUE (cols)'
);

is(
   $sp->normalize_keyword_spaces('insert into t values(1)'),
   'insert into t values (1)',
   'Add space VALUES (cols)'
);

is(
   $sp->normalize_keyword_spaces('select * from a join b on(foo)'),
   'select * from a join b on (foo)',
   'Add space ON (conditions)'
);

is(
   $sp->normalize_keyword_spaces('select * from a join b on(foo) join c on(bar)'),
   'select * from a join b on (foo) join c on (bar)',
   'Add space multiple ON (conditions)'
);

is(
   $sp->normalize_keyword_spaces('select * from a join b using(foo)'),
   'select * from a join b using (foo)',
   'Add space using (conditions)'
);

is(
   $sp->normalize_keyword_spaces('select * from a join b using(foo) join c using(bar)'),
   'select * from a join b using (foo) join c using (bar)',
   'Add space multiple USING (conditions)'
);

is(
   $sp->normalize_keyword_spaces('select * from a join b using(foo) join c on(bar)'),
   'select * from a join b using (foo) join c on (bar)',
   'Add space USING and ON'
);

# ###########################################################################
# GROUP BY
# ###########################################################################
is_deeply(
   $sp->parse_group_by('col, tbl.bar, 4, col2 ASC, MIN(bar)'),
   [
      { column => 'col', },
      { table => 'tbl', column => 'bar', },
      { position => '4', },
      { column => 'col2', sort => 'ASC', },
      { function => 'MIN', expression => 'bar' },
   ],
   "GROUP BY col, tbl.bar, 4, col2 ASC, MIN(bar)"
);

# ###########################################################################
# ORDER BY
# ###########################################################################
is_deeply(
   $sp->parse_order_by('foo'),
   [{column=>'foo'}],
   'ORDER BY foo'
);
is_deeply(
   $sp->parse_order_by('foo'),
   [{column=>'foo'}],
   'order by foo'
);
is_deeply(
   $sp->parse_order_by('foo, bar'),
   [
      {column => 'foo'},
      {column => 'bar'},
   ],
   'order by foo, bar'
);
is_deeply(
   $sp->parse_order_by('foo asc, bar'),
   [
      {column => 'foo', sort => 'ASC'},
      {column => 'bar'},
   ],
   'order by foo asc, bar'
);
is_deeply(
   $sp->parse_order_by('1'),
   [{position => '1'}],
   'ORDER BY 1'
);
is_deeply(
   $sp->parse_order_by('RAND()'),
   [{function => 'RAND'}],
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
   my $got = $sp->parse_from($from);
   is_deeply(
      $got,
      $struct,
      "FROM $from"
   ) or print Dumper($got);
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
            type       => 'inner',
            condition  => 'on',
            where      => [
               {
                  predicate => undef,
                  column    => 't1.id',
                  operator  => '=',
                  value     => 't2.id',
               },
            ],
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
            type       => 'inner',
            condition  => 'using',
            columns    => ['id'],
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
            type       => 'inner',
            condition  => 'on',
            where      => [
               {
                  predicate => undef,
                  column    => 't1.id',
                  operator  => '=',
                  value     => 't2.id',
               },
            ],
            ansi       => 1,
         },
      },
      {
         name  => 't3',
         join  => {
            to         => 't2',
            type       => 'inner',
            condition  => 'on',
            where      => [
               {
                  predicate => undef,
                  column    => 't1.id',
                  operator  => '=',
                  value     => 't3.id',
               },
            ],
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
            where      => [
               {
                  predicate => undef,
                  column    => 'a.id',
                  operator  => '=',
                  value     => 'b.id',
               },
            ],
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
            where      => [
               {
                  predicate => undef,
                  column    => 'c.c',
                  operator  => '=',
                  value     => 'a.a',
               },
            ],
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
            columns    => ['id'],
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

# Database-qualified tables.
test_from(
   'db.tbl',
   [{
      db   => 'db',
      name => 'tbl',
   }],
);

test_from(
   '`db`.`tbl`',
   [{
      db   => 'db',
      name => 'tbl',
   }],
);

test_from(
   '`ryan likes`.`to break stuff`',
   [{
      db   => 'ryan likes',
      name => 'to break stuff',
   }],
);

test_from(
   '`db`.`tbl` LEFT JOIN `foo`.`bar` USING (glue)',
   [
      {  db   => 'db',
         name => 'tbl',
      },
      {  db   => 'foo',
         name => 'bar',
         join => {
            to        => 'tbl',
            type      => 'left',
            ansi      => 1,
            condition => 'using',
            columns   => ['glue'],
         },
      },
   ],
);

test_from(
   'tblB AS dates LEFT JOIN dbF.tblC AS scraped ON dates.dt = scraped.dt AND dates.version = scraped.version',
   [
      {
        name           => 'tblB',
        alias          => 'dates',
        explicit_alias => 1,
      },
      {
        name           => 'tblC',
        alias          => 'scraped',
        explicit_alias => 1,
        db             => 'dbF',
        join           => {
          condition  => 'on',
          ansi       => 1,
          to         => 'tblB',
          type       => 'left',
          where      => [
            {
              predicate => undef,
              column    => 'dates.dt',
              operator  => '=',
              value     => 'scraped.dt',
            },
            {
              predicate => 'and',
              column    => 'dates.version',
              operator  => '=',
              value     => 'scraped.version',
            },
          ],
        },
      },
   ],
);

# #############################################################################
# parse_table_reference()
# #############################################################################
sub test_parse_table_reference {
   my ( $tbl, $struct ) = @_;
   my $s = $sp->parse_table_reference($tbl);
   is_deeply(
      $s,
      $struct,
      $tbl
   );
   return;
}

test_parse_table_reference('tbl',
   { name => 'tbl', }
);

test_parse_table_reference('tbl a',
   { name => 'tbl', alias => 'a', }
);

test_parse_table_reference('tbl as a',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_table_reference('tbl AS a',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_table_reference('db.tbl',
   { name => 'tbl', db => 'db', }
);

test_parse_table_reference('db.tbl a',
   { name => 'tbl', db => 'db', alias => 'a', }
);

test_parse_table_reference('db.tbl AS a',
   { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
);


test_parse_table_reference('`tbl`',
   { name => 'tbl', }
);

test_parse_table_reference('`tbl` `a`',
   { name => 'tbl', alias => 'a', }
);

test_parse_table_reference('`tbl` as `a`',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_table_reference('`tbl` AS `a`',
   { name => 'tbl', alias => 'a', explicit_alias => 1, }
);

test_parse_table_reference('`db`.`tbl`',
   { name => 'tbl', db => 'db', }
);

test_parse_table_reference('`db`.`tbl` `a`',
   { name => 'tbl', db => 'db', alias => 'a', }
);

test_parse_table_reference('`db`.`tbl` AS `a`',
   { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
);

# #############################################################################
# parse_columns()
# #############################################################################
sub test_parse_columns {
   my ( $cols, $struct ) = @_;
   my $s = $sp->parse_columns($cols);
   is_deeply(
      $s,
      $struct,
      $cols,
   );
   return;
}

test_parse_columns('tbl.* foo',
   [ { name => '*', tbl => 'tbl', alias => 'foo' } ],
);

# #############################################################################
# parse_set()
# #############################################################################
sub test_parse_set {
   my ( $set, $struct ) = @_;
   my $got = $sp->parse_set($set);
   is_deeply(
      $got,
      $struct,
      "parse_set($set)"
   ) or print Dumper($got);
}

test_parse_set(
   "col='val'",
   [{column=>"col", value=>"val"}],
);

test_parse_set(
   'a.foo="bar", b.foo="bat"',
   [
      {tbl=>"a", column=>"foo", value=>"bar"},
      {tbl=>"b", column=>"foo", value=>"bat"},
   ],
);

# #############################################################################
# Subqueries.
# #############################################################################

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
         query   => 'SELECT * FROM t5',
         context => 'identifier',
         nested  => 1,
      },
      {
         query   => 'SELECT 50,11*s1 FROM __SQ0__ AS t5',
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
      'SELECT NOW() AS a1, __SQ0__ AS a2',
      {
         query   => "SELECT f1(5)",
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
@subqueries = $sp->remove_subqueries(
   $sp->clean_query($sp->normalize_keyword_spaces($query)));
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
      'select col from tbl where id=__SQ3__ and col in(__SQ2__) limit 1',
      {
         query   => 'select a from a',
         context => 'list',
         nested  => 1,
      },
      {
         query   => 'select b from fn where id=1 and b > any(__SQ0__)',
         context => 'identifier',
         nested  => 2,
      },
      {
         query   => 'select foo from __SQ1__',
         context => 'list',
      },
      {
         query   => 'select max(id) from tbl2 where foo=\'bar\'',
         context => 'scalar',
      },
   ],
   'Mutiple and nested subqueries'
);

$query = "select (select now()) from universe";
@subqueries = $sp->remove_subqueries($sp->clean_query($query));
is_deeply(
   \@subqueries,
   [
      'select __SQ0__ from universe',
      {
         query   => 'select now()',
         context => 'identifier',
      },
   ],
   'Subquery as non-aliased column identifier'
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
         where   => [
            {
               predicate => undef,
               column    => 'id',
               operator  => '=',
               value     => '1',
            },
         ],
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
         order_by => [{column=>'foo'}],
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
         where   => [
            {
               predicate => undef,
               column    => 'id',
               operator  => '=',
               value     => '1',
            },
         ],
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
         where   => [
            {
               predicate => undef,
               column    => 'id',
               operator  => '=',
               value     => '1',
            },
         ],
         order_by => [{column=>'id'}],
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
         where   => [
            {
               predicate => undef,
               column    => 'id',
               operator  => '=',
               value     => '1',
            },
         ],
         order_by=> [{column=>'id', sort=>'ASC'}],
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
            values       => '(3,"bob")',
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
         set     => [
            { column => 'id',  value => '1',    },
            { column => 'foo', value => 'NULL', },
         ],
         unknown => undef,
      },
   },
   {  name   => 'INSERT INTO SET ON DUPLICATE',
      query  => 'INSERT INTO tbl SET i=3 ON DUPLICATE KEY UPDATE col1=9',
      struct => {
         type    => 'insert',
         clauses => { 
            into         => 'tbl',
            set          => 'i=3',
            on_duplicate => 'col1=9',
         },
         into         => [ { name => 'tbl', } ],
         set          => [{column=>'i', value=>'3'}],
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
            type    => 'select',
            clauses => { 
               columns => 'id ',
               from    => 'tbl2 ',
               where   => 'id > 100',
            },
            columns => [ { name => 'id' } ],
            from    => [ { name => 'tbl2', } ],
            where   => [
               {
                  predicate => undef,
                  column    => 'id',
                  operator  => '>',
                  value     => '100',
               },
            ],
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
   {
      name  => 'REPLACE SELECT JOIN ON',
      query => 'REPLACE INTO db.tblA (dt, ncpc) SELECT dates.dt, scraped.total_r FROM tblB AS dates LEFT JOIN dbF.tblC AS scraped ON dates.dt = scraped.dt AND dates.version = scraped.version',
      struct => {
         type    => 'replace',
         clauses => {
            columns => 'dt, ncpc ',
            into    => 'db.tblA',
            select  => 'dates.dt, scraped.total_r FROM tblB AS dates LEFT JOIN dbF.tblC AS scraped ON dates.dt = scraped.dt AND dates.version = scraped.version',
         },
         columns => [ { name => 'dt' }, { name => 'ncpc' } ],
         into    => [ { db => 'db', name => 'tblA' } ],
         select  => {
            type    => 'select',
            clauses => {
               columns => 'dates.dt, scraped.total_r ',
               from    => 'tblB AS dates LEFT JOIN dbF.tblC AS scraped ON dates.dt = scraped.dt AND dates.version = scraped.version',
            },
            columns => [
               { tbl => 'dates',   name => 'dt'      },
               { tbl => 'scraped', name => 'total_r' },
            ],
            from    => [
               {
                 name           => 'tblB',
                 alias          => 'dates',
                 explicit_alias => 1,
               },
               {
                 name           => 'tblC',
                 alias          => 'scraped',
                 explicit_alias => 1,
                 db             => 'dbF',
                 join           => {
                   condition => 'on',
                   ansi  => 1,
                   to    => 'tblB',
                   type  => 'left',
                   where => [
                     {
                       predicate => undef,
                       column    => 'dates.dt',
                       operator  => '=',
                       value     => 'scraped.dt',
                     },
                     {
                       predicate => 'and',
                       column    => 'dates.version',
                       operator  => '=',
                       value     => 'scraped.version',
                     },
                   ],
                 },
               },
            ],
            unknown => undef,
         },
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
         columns => [ { name => 'col1', tbl => 't1', alias => 'a' },
                      { name => 'col2', tbl => 't1', alias => 'b',
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
                  where      => [
                     {
                        predicate => undef,
                        column    => 't1.id',
                        operator  => '=',
                        value     => 't2.id',
                     },
                  ],
                  ansi      => 1,
               },
            },
         ],
         where    => [
            {
               predicate => undef,
               column    => 't2.col',
               operator  => 'is not',
               value     => 'null',
            },
            {
               predicate => 'and',
               column    => 't2.name',
               operator  => '=',
               value     => '"bob"',
            },
         ],
         group_by => [
            { column => 'a' },
            { column => 'b' },
         ],
         order_by => [{table=>'t2', column=>'name', sort=>'ASC'}],
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
         columns => [ { name => 'col1', tbl => 't1', alias => 'a' },
                      { name => 'col2', tbl => 't1', alias => 'b',
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
                  type      => 'inner',
                  condition => 'on',
                  where      => [
                     {
                        predicate => undef,
                        column    => 't1.id',
                        operator  => '=',
                        value     => 't2.id',
                     },
                  ],
                  ansi      => 1,
               },
            },
            {
               name  => 'tbl3',
               alias => 't3',
               join  => {
                  to        => 'tbl2',
                  type      => 'inner',
                  condition => 'using',
                  columns   => ['id'],
                  ansi      => 1,
               },
            },
         ],
         where    => [
            {
               predicate => undef,
               column    => 't2.col',
               operator  => 'is not',
               value     => 'null',
            },
         ],
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
         where    => [
            {
               predicate => undef,
               column    => 'ip',
               operator  => '=',
               value     => '"127.0.0.1"',
            },
         ],
         unknown  => undef,
      },
   },
   { name    => 'SELECT with simple subquery',
     query   => 'select * from t where id in(select col from t2)',
     struct  => {
         type    => 'select',
         clauses => { 
            columns => '* ',
            from    => 't ',
            where   => 'id in(__SQ0__)',
         },
         columns    => [ { name => '*' } ],
         from       => [ { name => 't' } ],
         where      => [
            {
               predicate => undef,
               column    => 'id',
               operator  => 'in',
               value     => '(__SQ0__)',
            },
         ],
         unknown    => undef,
         subqueries => [
            {
               query   => 'select col from t2',
               context => 'list',
               type    => 'select',
               clauses => { 
                  columns => 'col ',
                  from    => 't2',
               },
               columns    => [ { name => 'col' } ],
               from       => [ { name => 't2' } ],
               unknown    => undef,
            },
         ],
      },
   },
   { name    => 'Complex SELECT, multiple JOIN and subqueries',
     query   => 'select now(), (select foo from bar where id=1)
                 from t1, t2 join (select * from sqt1) as t3 using (`select`)
                 join t4 on t4.id=t3.id 
                 where c1 > any(select col2 as z from sqt2 zz
                    where sqtc<(select max(col) from l where col<100))
                 and s in ("select", "tricky") or s <> "select"
                 group by 1 limit 10',
      struct => {
         type       => 'select',
         clauses    => { 
            columns  => 'now(), __SQ3__ ',
            from     => 't1, t2 join __SQ2__ as t3 using (`select`) join t4 on t4.id=t3.id ',
            where    => 'c1 > any(__SQ1__) and s in ("select", "tricky") or s <> "select" ',
            group_by => '1 ',
            limit    => '10',
         },
         columns    => [ { name => 'now()' }, { name => '__SQ3__' } ],
         from       => [
            {
               name => 't1',
            },
            {
               name => 't2',
               join => {
                  to   => 't1',
                  ansi => 0,
                  type => 'inner',
               },
            },
            {
               name  => '__SQ2__',
               alias => 't3',
               explicit_alias => 1,
               join  => {
                  to   => 't2',
                  ansi => 1,
                  type => 'inner',
                  columns    => ['`select`'],
                  condition  => 'using',
               },
            },
            {
               name => 't4',
               join => {
                  to   => '__SQ2__',
                  ansi => 1,
                  type => 'inner',
                  where      => [
                     {
                        predicate => undef,
                        column    => 't4.id',
                        operator  => '=',
                        value     => 't3.id',
                     },
                  ],
                  condition  => 'on',
               },
            },
         ],
         where      => [
            {
               predicate => undef,
               column    => 'c1',
               operator  => '>',
               value     => 'any(__SQ1__)',
            },
            {
               predicate => 'and',
               column    => 's',
               operator  => 'in',
               value     => '("select", "tricky")',
            },
            {
               predicate => 'or',
               column    => 's',
               operator  => '<>',
               value     => '"select"',
            },
         ],
         limit      => { row_count => 10 },
         group_by   => [ { position => '1' } ],
         unknown    => undef,
         subqueries => [
            {
               clauses => {
                  columns => 'max(col) ',
                  from    => 'l ',
                  where   => 'col<100'
               },
               columns => [ { name => 'max(col)' } ],
               context => 'scalar',
               from    => [ { name => 'l' } ],
               nested  => 1,
               query   => 'select max(col) from l where col<100',
               type    => 'select',
               unknown => undef,
               where   => [
                  {
                     predicate => undef,
                     column    => 'col',
                     operator  => '<',
                     value     => '100',
                  },
               ],
            },
            {
               clauses  => {
                  columns => 'col2 as z ',
                  from    => 'sqt2 zz ',
                  where   => 'sqtc<__SQ0__'
               },
               columns => [
                  { alias => 'z', explicit_alias => 1, name => 'col2' }
               ],
               context  => 'list',
               from     => [ { alias => 'zz', name => 'sqt2' } ],
               query    => 'select col2 as z from sqt2 zz where sqtc<__SQ0__',
               type     => 'select',
               unknown  => undef,
               where    => [
                  {
                     predicate => undef,
                     column    => 'sqtc',
                     operator  => '<',
                     value     => '__SQ0__',
                  },
               ],
            },
            {
               clauses  => {
                  columns => '* ',
                  from    => 'sqt1'
               },
               columns  => [ { name => '*' } ],
               context  => 'identifier',
               from     => [ { name => 'sqt1' } ],
               query    => 'select * from sqt1',
               type     => 'select',
               unknown  => undef
            },
            {
               clauses  => {
               columns  => 'foo ',
                  from  => 'bar ',
                  where => 'id=1'
               },
               columns  => [ { name => 'foo' } ],
               context  => 'identifier',
               from     => [ { name => 'bar' } ],
               query    => 'select foo from bar where id=1',
               type     => 'select',
               unknown  => undef,
               where    => [
                  {
                     predicate => undef,
                     column    => 'id',
                     operator  => '=',
                     value     => '1',
                  },
               ],
            },
         ],
      },
   },
   {  name   => 'Table joined twice',
      query  => "SELECT *
                 FROM   `w_chapter`
                 INNER JOIN `w_series` AS `w_chapter__series`
                 ON `w_chapter`.`series_id` = `w_chapter__series`.`id`,
                 `w_series`,
                 `auth_user`
                 WHERE `w_chapter`.`status` = 1",
      struct => {
         type    => 'select',
         clauses => { 
            columns => "* ",
            from    => "`w_chapter` INNER JOIN `w_series` AS `w_chapter__series` ON `w_chapter`.`series_id` = `w_chapter__series`.`id`, `w_series`, `auth_user` ",
            where   => "`w_chapter`.`status` = 1",
         },
         columns => [{name => '*'}],
         from    => [
          {
            name => 'w_chapter'
          },
          {
            alias => 'w_chapter__series',
            explicit_alias => 1,
            join => {
              ansi => 1,
              condition => 'on',
               where      => [
                  {
                     predicate => undef,
                     column    => '`w_chapter`.`series_id`',
                     operator  => '=',
                     value     => '`w_chapter__series`.`id`',
                  },
               ],
              to => 'w_chapter',
              type => 'inner'
            },
            name => 'w_series'
          },
          {
            join => {
              ansi => 0,
              to => 'w_series',
              type => 'inner'
            },
            name => 'w_series'
          },
          {
            join => {
              ansi => 0,
              to => 'w_series',
              type => 'inner'
            },
            name => 'auth_user'
          }
         ],
         where   => [
            {
               predicate => undef,
               column    => '`w_chapter`.`status`',
               operator  => '=',
               value     => '1',
            },
         ],
         unknown => undef,
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
         set     => [ { column =>'col', value => '1' } ],
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
         set      => [ { column => 'foo', value => 'NULL' } ],
         where    => [
            {
               predicate => undef,
               column    => 'foo',
               operator  => 'is not',
               value     => 'null',
            },
         ],
         order_by => [{column=>'id'}],
         limit    => { row_count => 10 },
         unknown => undef,
      },
   },

   # ########################################################################
   # EXPLAIN EXTENDED fully-qualified queries.
   # ########################################################################
   {  name   => 'EXPLAIN EXTENDED SELECT',
      query  => 'select `sakila`.`city`.`country_id` AS `country_id` from `sakila`.`city` where (`sakila`.`city`.`country_id` = 1)',
      struct => {
         type    => 'select',
         clauses => { 
            columns => '`sakila`.`city`.`country_id` AS `country_id` ',
            from    => '`sakila`.`city` ',
            where   => '(`sakila`.`city`.`country_id` = 1)',
         },
         columns => [
            { db    => 'sakila',
              tbl   => 'city',
              name  => 'country_id',
              alias => 'country_id',
              explicit_alias => 1,
            },
         ],
         from    => [ { db=>'sakila', name=>'city' } ],
         where   => [ {
            predicate => undef,
            column    => '`sakila`.`city`.`country_id`',
            operator  => '=',
            value     => '1',
         } ],
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
   ) or print Dumper($struct);
   die if $test->{stop};
}

# #############################################################################
# Done.
# #############################################################################
exit;
