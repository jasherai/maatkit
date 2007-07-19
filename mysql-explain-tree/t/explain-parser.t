#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;

require "../mysql-explain-tree";

# Test that I can load 'explain' files and get an array of hashrefs from them.
my $p = new ExplainParser;

is_deeply(
   $p->parse( load_file('samples/full_scan_sakila_film.sql') ),
   [  {  id            => 1,
         select_type   => 'SIMPLE',
         table         => 'film',
         type          => 'ALL',
         possible_keys => undef,
         key           => undef,
         key_len       => undef,
         'ref'         => undef,
         rows          => 935,
         Extra         => '',
      }
   ],
   'One line horizontal',
);

is_deeply(
   $p->parse( load_file('samples/actor_join_film_ref.sql') ),
   [  {  id            => 1,
         select_type   => 'SIMPLE',
         table         => 'film',
         type          => 'ALL',
         possible_keys => 'PRIMARY',
         key           => undef,
         key_len       => undef,
         'ref'         => undef,
         rows          => 952,
         Extra         => '',
      },
      {  id            => 1,
         select_type   => 'SIMPLE',
         table         => 'film_actor',
         type          => 'ref',
         possible_keys => 'idx_fk_film_id',
         key           => 'idx_fk_film_id',
         key_len       => 2,
         'ref'         => 'sakila.film.film_id',
         rows          => 2,
         Extra         => '',
      },
   ],
   'Simple join',
);

is_deeply(
   $p->parse( load_file('samples/rental_index_merge_intersect.sql') ),
   [  {  id            => 1,
         select_type   => 'SIMPLE',
         table         => 'rental',
         type          => 'index_merge',
         possible_keys => 'idx_fk_inventory_id,idx_fk_customer_id',
         key           => 'idx_fk_inventory_id,idx_fk_customer_id',
         key_len       => '3,2',
         'ref'         => undef,
         rows          => 1,
         Extra         =>
            'Using intersect(idx_fk_inventory_id,idx_fk_customer_id); Using where',
      }
   ],
   'Vertical output',
);

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}
