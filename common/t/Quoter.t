#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 21;

require "../Quoter.pm";

my $q = new Quoter;

is(
   $q->quote('a'),
   '`a`',
   'Simple quote OK',
);

is(
   $q->quote('a','b'),
   '`a`.`b`',
   'multi value',
);

is(
   $q->quote('`a`'),
   '```a```',
   'already quoted',
);

is(
   $q->quote('a`b'),
   '`a``b`',
   'internal quote',
);

is(
   $q->quote('my db', 'my tbl'),
   '`my db`.`my tbl`',
   'quotes db with space and tbl with space'
);

is( $q->quote_val(1), "1", 'number' );
is( $q->quote_val('001'), "'001'", 'number with leading zero' );
is( $q->quote_val(qw(1 2 3)), '1, 2, 3', 'three numbers');
is( $q->quote_val(qw(a)), "'a'", 'letter');
is( $q->quote_val("a'"), "'a\\''", 'letter with quotes');
is( $q->quote_val(undef), 'NULL', 'NULL');
is( $q->quote_val(''), "''", 'Empty string');
is( $q->quote_val('\\\''), "'\\\\\\\''", 'embedded backslash');

# Splitting DB and tbl apart
is_deeply(
   [$q->split_unquote("`db`.`tbl`")],
   [qw(db tbl)],
   'splits with a quoted db.tbl',
);

is_deeply(
   [$q->split_unquote("db.tbl")],
   [qw(db tbl)],
   'splits with a db.tbl',
);

is_deeply(
   [$q->split_unquote("tbl")],
   [undef, 'tbl'],
   'splits without a db',
);

is_deeply(
   [$q->split_unquote("tbl", "db")],
   [qw(db tbl)],
   'splits with a db',
);

is( $q->literal_like('foo'), 'foo', 'LIKE foo');
is( $q->literal_like('foo_bar'), 'foo\_bar', 'LIKE foo_bar');
is( $q->literal_like('foo%bar'), 'foo\%bar', 'LIKE foo%bar');
is( $q->literal_like('v_b%a c_'), 'v\_b\%a c\_', 'LIKE v_b%a c_');

exit;
