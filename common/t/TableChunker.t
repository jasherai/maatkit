#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
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

}
