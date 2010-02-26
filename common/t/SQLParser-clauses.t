#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';

use Test::More tests => 41;
use English qw(-no_match_vars);

use MaatkitTest;
use SQLParser;

my $sp = new SQLParser();

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
# Done.
# #############################################################################
exit;
