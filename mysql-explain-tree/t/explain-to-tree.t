#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;

require "../mysql-explain-tree";

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}
my $e = new ExplainTree;

is_deeply(
   $e->parse( load_file('samples/full_scan_sakila_film.sql') ),
   {  type  => 'Table scan',
      rows  => 935,
      table => {
         type          => 'Table',
         table         => 'film',
         possible_keys => undef,
      }
   },
   'simple scan worked OK',
);

is_deeply(
   $e->parse( load_file('samples/actor_join_film_ref.sql') ),
   {  type => 'JOIN',
      left => {
         type  => 'Table scan',
         rows  => 952,
         table => {
            type          => 'Table',
            table         => 'film',
            possible_keys => 'PRIMARY',
         },
      },
      right => {
         type     => 'Index lookup',
         key      => 'idx_fk_film_id',
         key_len  => 2,
         'ref'    => 'sakila.film.film_id',
         rows     => 2,
         table    => {
            type          => 'Table',
            table         => 'film_actor',
            possible_keys => 'idx_fk_film_id',
         },
      },
   },
   'simple join worked OK',
);
