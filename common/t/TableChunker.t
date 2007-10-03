#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 6;
use DBI;
use English qw(-no_match_vars);

require "../TableParser.pm";
require "../TableChunker.pm";

my $p = new TableParser();
my $c = new TableChunker();
my $t;

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

# Open a connection to MySQL, or skip the rest of the tests.
my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef, { RaiseError => 1 })
};
SKIP: {
   skip $EVAL_ERROR, 1 if $EVAL_ERROR;
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
         '`a` < "2001-04-02"',
         '`a` >= "2001-04-02" AND `a` < "2001-07-02"',
         '`a` >= "2001-07-02" AND `a` < "2001-10-01"',
         '`a` >= "2001-10-01" AND `a` < "2001-12-31"',
         '`a` >= "2001-12-31"',
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

}
