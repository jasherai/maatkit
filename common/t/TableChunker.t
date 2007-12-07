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

my $tests;
BEGIN {
   $tests = 20;
}

use Test::More tests => $tests;
use DBI;
use English qw(-no_match_vars);

require "../TableParser.pm";
require "../TableChunker.pm";
require "../Quoter.pm";

my $q = new Quoter();
my $p = new TableParser();
my $c = new TableChunker( quoter => $q );
my $t;

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

$t = $p->parse( load_file('samples/sakila.film.sql') );
is_deeply(
   [ $c->find_chunk_columns($t) ],
   [ 0, [qw(film_id language_id original_language_id)]],
   'Found chunkable columns on sakila.film',
);

is_deeply(
   [ $c->find_chunk_columns($t, { exact => 1 }) ],
   [ 1, [qw(film_id)]],
   'Found exact chunkable columns on sakila.film',
);

is_deeply(
   [ $c->find_chunk_columns($t, { possible_keys => [qw(idx_fk_language_id)] }) ],
   [ 0, [qw(language_id original_language_id film_id)]],
   'Found preferred chunkable columns on sakila.film',
);

$t = $p->parse( load_file('samples/pk_not_first.sql') );
is_deeply(
   [ $c->find_chunk_columns($t) ],
   [ 0, [qw(film_id language_id original_language_id)]],
   'PK column is first',
);

is (
   $c->inject_chunks(
      query     => 'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ FOO FROM 1/*WHERE*/',
      database  => 'sakila',
      table     => 'film',
      chunks    => [ '1=1', 'a=b' ],
      chunk_num => 1,
      where     => 'FOO=BAR',
   ),
   'SELECT /*sakila.film:2/2*/ 1 AS chunk_num, FOO FROM 1 WHERE (a=b) AND (FOO=BAR)',
   'Replaces chunk info into query',
);

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef, { RaiseError => 1 })
};
SKIP: {
   skip 'Cannot connect to MySQL', $tests - 8 if $EVAL_ERROR;
   skip 'Sakila is not installed', $tests - 8
         unless @{$dbh->selectall_arrayref('show databases like "sakila"')};

   my @chunks;

   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'film_id',
      min           => 0,
      max           => 99,
      rows_in_range => 100,
      size          => 30,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`film_id` < 30',
         '`film_id` >= 30 AND `film_id` < 60',
         '`film_id` >= 60 AND `film_id` < 90',
         '`film_id` >= 90',
      ],
      'Got the right chunks from dividing 100 rows into 30-row chunks',
   );

   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'film_id',
      min           => 0,
      max           => 99,
      rows_in_range => 100,
      size          => 300,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '1=1',
      ],
      'Got the right chunks from dividing 100 rows into 300-row chunks',
   );

   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'film_id',
      min           => 0,
      max           => 0,
      rows_in_range => 100,
      size          => 300,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '1=1',
      ],
      'No rows, so one chunk',
   );

   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'original_language_id',
      min           => 0,
      max           => 99,
      rows_in_range => 100,
      size          => 50,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`original_language_id` < 50',
         '`original_language_id` >= 50',
         '`original_language_id` IS NULL',
      ],
      'Nullable column adds IS NULL chunk',
   );

   $t = $p->parse( load_file('samples/daycol.sql') );

   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '2001-01-01',
      max           => '2002-01-01',
      rows_in_range => 365,
      size          => 90,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "2001-04-01"',
         '`a` >= "2001-04-01" AND `a` < "2001-06-30"',
         '`a` >= "2001-06-30" AND `a` < "2001-09-28"',
         '`a` >= "2001-09-28" AND `a` < "2001-12-27"',
         '`a` >= "2001-12-27"',
      ],
      'Date column chunks OK',
   );

   $t = $p->parse( load_file('samples/datetime.sql') );
   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '1922-01-14 05:18:23',
      max           => '2005-11-26 00:59:19',
      rows_in_range => 3,
      size          => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "1949-12-28 19:52:02"',
         '`a` >= "1949-12-28 19:52:02" AND `a` < "1977-12-12 10:25:41"',
         '`a` >= "1977-12-12 10:25:41"',
      ],
      'Datetime column chunks OK',
   );

   $t = $p->parse( load_file('samples/timecol.sql') );
   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '00:59:19',
      max           => '09:03:15',
      rows_in_range => 3,
      size          => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < "03:40:38"',
         '`a` >= "03:40:38" AND `a` < "06:21:57"',
         '`a` >= "06:21:57"',
      ],
      'Time column chunks OK',
   );

   $t = $p->parse( load_file('samples/doublecol.sql') );
   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '1',
      max           => '99.999',
      rows_in_range => 3,
      size          => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 33.99966',
         '`a` >= 33.99966 AND `a` < 66.99933',
         '`a` >= 66.99933',
      ],
      'Double column chunks OK',
   );

   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '1',
      max           => '2',
      rows_in_range => 5,
      size          => 3,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 1.6',
         '`a` >= 1.6',
      ],
      'Double column chunks OK with smaller-than-int values',
   );

   eval {
   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '1',
      max           => '2',
      rows_in_range => 50000000,
      size          => 3,
      dbh           => $dbh,
   );
   };
   is(
      $EVAL_ERROR,
      "Chunk size is too small: 1.00000 !> 1\n",
      'Throws OK when too many chunks',
   );

   $t = $p->parse( load_file('samples/floatcol.sql') );
   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '1',
      max           => '99.999',
      rows_in_range => 3,
      size          => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 33.99966',
         '`a` >= 33.99966 AND `a` < 66.99933',
         '`a` >= 66.99933',
      ],
      'Float column chunks OK',
   );

   $t = $p->parse( load_file('samples/decimalcol.sql') );
   @chunks = $c->calculate_chunks(
      table         => $t,
      col           => 'a',
      min           => '1',
      max           => '99.999',
      rows_in_range => 3,
      size          => 1,
      dbh           => $dbh,
   );
   is_deeply(
      \@chunks,
      [
         '`a` < 33.99966',
         '`a` >= 33.99966 AND `a` < 66.99933',
         '`a` >= 66.99933',
      ],
      'Decimal column chunks OK',
   );

   throws_ok(
      sub { $c->size_to_rows($dbh, 'sakila', 'film', 'foo') },
      qr/Invalid size spec/,
      'Rejects bad size spec',
   );
   is( $c->size_to_rows($dbh, 'sakila', 'film', '5'), 5, 'Numeric size' );
   my $size = $c->size_to_rows($dbh, 'sakila', 'film', '5k');
   ok($size >= 20 && $size <= 30, 'Convert bytes to rows');

}
