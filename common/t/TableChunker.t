#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
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
   [qw(film_id language_id original_language_id)],
   'Found chunkable columns on sakila.film',
);

is_deeply(
   [ $c->find_chunk_columns($t, { exact => 1 }) ],
   [qw(film_id)],
   'Found exact chunkable columns on sakila.film',
);
