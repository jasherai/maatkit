#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 21;

require "../mysql-explain-tree";

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}
my $e = new ExplainTree;
my $t;

$t = $e->parse( load_file('samples/full_scan_sakila_film.sql') );
is_deeply(
   $t,
   {  type     => 'Table scan',
      id       => 1,
      rowid    => 0,
      rows     => 935,
      children => [
         {  type          => 'Table',
            table         => 'film',
            possible_keys => undef,
         }
      ]
   },
   'Simple scan',
);

$t = $e->parse( load_file('samples/actor_join_film_ref.sql') );
is_deeply(
   $t,
   {  type     => 'JOIN',
      children => [
         {  type     => 'Table scan',
            rows     => 952,
            id       => 1,
            rowid    => 0,
            children => [
               {  type          => 'Table',
                  table         => 'film',
                  possible_keys => 'PRIMARY',
               }
            ],
         },
         {  type     => 'Index lookup',
            key      => 'film_actor->idx_fk_film_id',
            key_len  => 2,
            'ref'    => 'sakila.film.film_id',
            rows     => 2,
            id       => 1,
            rowid    => 1,
            children => [
               {  type          => 'Table',
                  table         => 'film_actor',
                  possible_keys => 'idx_fk_film_id',
               },
            ]
         },
      ]
   },
   'Simple join',
);

$t = $e->parse( load_file('samples/simple_join_three_tables.sql') );
is_deeply(
   $t,
   {  type     => 'JOIN',
      children => [
         {  type     => 'JOIN',
            children => [
               {  type     => 'Index scan',
                  key      => 'actor_1->PRIMARY',
                  key_len  => 2,
                  'ref'    => undef,
                  rows     => 200,
                  id       => 1,
                  rowid    => 0,
               },
               {  type     => 'Unique index lookup',
                  key      => 'actor_2->PRIMARY',
                  key_len  => 2,
                  'ref'    => 'sakila.actor_1.actor_id',
                  rows     => 1,
                  id       => 1,
                  rowid    => 1,
               },
            ],
         },
         {  type     => 'Unique index lookup',
            key      => 'actor_3->PRIMARY',
            key_len  => 2,
            'ref'    => 'sakila.actor_1.actor_id',
            rows     => 1,
            id       => 1,
            rowid    => 2,
         },
      ],
   },
   'Simple join over three tables',
);

$t = $e->parse( load_file('samples/film_join_actor_eq_ref.sql') );
is_deeply(
   $t,
   {  type     => 'JOIN',
      children => [
         {  type     => 'Table scan',
            rows     => 5143,
            id       => 1,
            rowid    => 0,
            children => [
               {  type          => 'Table',
                  table         => 'film_actor',
                  possible_keys => 'idx_fk_film_id',
               },
            ]
         },
         {  type     => 'Unique index lookup',
            key      => 'film->PRIMARY',
            key_len  => 2,
            'ref'    => 'sakila.film_actor.film_id',
            rows     => 1,
            id       => 1,
            rowid    => 1,
            children => [
               {  type          => 'Table',
                  table         => 'film',
                  possible_keys => 'PRIMARY',
               },
            ]
         },
      ]
   },
   'Straight join',
);

$t = $e->parse( load_file('samples/full_row_pk_lookup_sakila_film.sql') );
is_deeply(
   $t,
   {  type     => 'Constant index lookup',
      key      => 'film->PRIMARY',
      key_len  => 2,
      'ref'    => 'const',
      rows     => 1,
      id       => 1,
      rowid    => 0,
      children => [
         {  type          => 'Table',
            table         => 'film',
            possible_keys => 'PRIMARY',
         },
      ]
   },
   'Constant lookup',
);

$t = $e->parse( load_file('samples/index_scan_sakila_film.sql') );
is_deeply(
   $t,
   {  type     => 'Index scan',
      key      => 'film->idx_title',
      key_len  => 767,
      'ref'    => undef,
      rows     => 952,
      id       => 1,
      rowid    => 0,
      children => [
         {  type          => 'Table',
            table         => 'film',
            possible_keys => undef,
         },
      ]
   },
   'Index scan',
);

$t = $e->parse( load_file('samples/index_scan_sakila_film_using_where.sql') );
is_deeply(
   $t,
   {  type     => 'Filter with WHERE',
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'Index scan',
            key      => 'film->idx_title',
            key_len  => 767,
            'ref'    => undef,
            rows     => 952,
            children => [
               {  type          => 'Table',
                  table         => 'film',
                  possible_keys => undef,
               },
            ]
         },
      ]
   },
   'Index scan with WHERE clause',
);

$t = $e->parse( load_file('samples/pk_lookup_sakila_film.sql') );
is_deeply(
   $t,
   {  type    => 'Constant index lookup',
      key     => 'film->PRIMARY',
      key_len => 2,
      'ref'   => 'const',
      rows    => 1,
      id      => 1,
      rowid   => 0,
   },
   'PK lookup with covering index',
);

$t = $e->parse( load_file('samples/film_join_actor_const.sql') );
is_deeply(
   $t,
   {  type     => 'JOIN',
      children => [
         {  type     => 'Constant index lookup',
            key      => 'film->PRIMARY',
            key_len  => 2,
            'ref'    => 'const',
            rows     => 1,
            id       => 1,
            rowid    => 0,
            children => [
               {  type          => 'Table',
                  table         => 'film',
                  possible_keys => 'PRIMARY',
               },
            ],
         },
         {  type     => 'Index lookup',
            key      => 'film_actor->idx_fk_film_id',
            key_len  => 2,
            'ref'    => 'const',
            rows     => 10,
            id       => 1,
            rowid    => 1,
            children => [
               {  type          => 'Table',
                  table         => 'film_actor',
                  possible_keys => 'idx_fk_film_id',
               },
            ],
         },
      ],
   },
   'Join from constant lookup in film to const ref in film_actor',
);

$t = $e->parse( load_file('samples/film_join_actor_const_using_index.sql') );
is_deeply(
   $t,
   {  type     => 'JOIN',
      children => [
         {  type    => 'Constant index lookup',
            key     => 'film->PRIMARY',
            key_len => 2,
            'ref'   => 'const',
            rows    => 1,
            id      => 1,
            rowid   => 0,
         },
         {  type    => 'Index lookup',
            key     => 'film_actor->idx_fk_film_id',
            key_len => 2,
            'ref'   => 'const',
            rows    => 10,
            id      => 1,
            rowid   => 1,
         },
      ],
   },
   'Join from const film to const ref film_actor with covering index',
);

$t = $e->parse( load_file('samples/film_range_on_pk.sql') );
is_deeply(
   $t,
   {  type     => 'Filter with WHERE',
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'Index range scan',
            key      => 'film->PRIMARY',
            key_len  => 2,
            'ref'    => undef,
            rows     => 20,
            children => [
               {  type          => 'Table',
                  table         => 'film',
                  possible_keys => 'PRIMARY',
               },
            ],
         },
      ],
   },
   'Index range scan with WHERE clause',
);

$t = $e->parse( load_file('samples/film_ref_or_null_on_original_language_id.sql') );
is_deeply(
   $t,
   {  type     => 'Filter with WHERE',
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'Index lookup with extra null lookup',
            key      => 'film->idx_fk_original_language_id',
            key_len  => 2,
            'ref'    => 'const',
            rows     => 512,
            children => [
               {  type          => 'Table',
                  table         => 'film',
                  possible_keys => 'idx_fk_original_language_id',
               },
            ],
         },
      ],
   },
   'Index ref_or_null scan',
);

$t = $e->parse( load_file('samples/rental_index_merge_intersect.sql') );
is_deeply(
   $t,
   {  type     => 'Filter with WHERE',
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'Bookmark lookup',
            rows     => 1,
            children => [
               {  type     => 'Index merge',
                  method   => 'intersect',
                  rows     => 1,
                  children => [
                     {  type    => 'Index range scan',
                        key     => 'rental->idx_fk_inventory_id',
                        key_len => 3,
                        'ref'   => undef,
                        rows    => 1,
                     },
                     {  type    => 'Index range scan',
                        key     => 'rental->idx_fk_customer_id',
                        key_len => 2,
                        'ref'   => undef,
                        rows    => 1,
                     },
                  ],
               },
               {  type          => 'Table',
                  table         => 'rental',
                  possible_keys => 'idx_fk_inventory_id,idx_fk_customer_id',
               },
            ],
         },
      ],
   },
   'Index intersection merge',
);

$t = $e->parse( load_file('samples/index_merge_three_keys.sql') );
is_deeply(
   $t,
   {  type     => 'Filter with WHERE',
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'Index merge',
            method   => 'intersect',
            rows     => 2,
            children => [
               {  type    => 'Index range scan',
                  key     => 't1->key1',
                  key_len => 5,
                  'ref'   => undef,
                  rows    => 2,
               },
               {  type    => 'Index range scan',
                  key     => 't1->key2',
                  key_len => 5,
                  'ref'   => undef,
                  rows    => 2,
               },
               {  type    => 'Index range scan',
                  key     => 't1->key3',
                  key_len => 5,
                  'ref'   => undef,
                  rows    => 2,
               },
            ],
         },
      ],
   },
   'Index intersection merge with three keys and covering index',
);

$t = $e->parse( load_file('samples/index_merge_union_intersect.sql') );
is_deeply(
   $t,
   {  type     => 'Filter with WHERE',
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'Bookmark lookup',
            rows     => 154,
            children => [
               {  type     => 'Index merge',
                  method   => 'union',
                  rows     => 154,
                  children => [

                     {  type     => 'Index merge',
                        method   => 'intersect',
                        rows     => 154,
                        children => [
                           {  type    => 'Index range scan',
                              key     => 't1->key1',
                              key_len => 5,
                              'ref'   => undef,
                              rows    => 154,
                           },
                           {  type    => 'Index range scan',
                              key     => 't1->key2',
                              key_len => 5,
                              'ref'   => undef,
                              rows    => 154,
                           },
                        ],
                     },

                     {  type     => 'Index merge',
                        method   => 'intersect',
                        rows     => 154,
                        children => [
                           {  type    => 'Index range scan',
                              key     => 't1->key3',
                              key_len => 5,
                              'ref'   => undef,
                              rows    => 154,
                           },
                           {  type    => 'Index range scan',
                              key     => 't1->key4',
                              key_len => 5,
                              'ref'   => undef,
                              rows    => 154,
                           },
                        ],
                     },

                  ],
               },

               {  type          => 'Table',
                  table         => 't1',
                  possible_keys => 'key1,key2,key3,key4',
               },
            ],
         },
      ],
   },
   'Index merge union-intersection',
);

$t = $e->parse( load_file('samples/index_merge_sort_union.sql') );
is_deeply(
   $t,
   {  type     => 'Filter with WHERE',
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'Bookmark lookup',
            rows     => 45,
            children => [
               {  type     => 'Index merge',
                  method   => 'sort_union',
                  rows     => 45,
                  children => [

                     {  type    => 'Index range scan',
                        key     => 't0->i1',
                        key_len => 4,
                        'ref'   => undef,
                        rows    => 45,
                     },
                     {  type    => 'Index range scan',
                        key     => 't0->i2',
                        key_len => 4,
                        'ref'   => undef,
                        rows    => 45,
                     },

                  ],
               },

               {  type          => 'Table',
                  table         => 't0',
                  possible_keys => 'i1,i2',
               },
            ],
         },
      ],
   },
   'Index merge sort_union',
);

$t = $e->parse( load_file('samples/no_from.sql') );
is_deeply(
   $t,
   {  type  => 'DUAL',
      id    => 1,
      rowid => 0,
   },
   'No tables used',
);

$t = $e->parse( load_file('samples/simple_union.sql') );
is_deeply(
   $t,
   {  type     => 'Table scan',
      rows     => undef,
      id       => '',
      rowid    => 2,
      children => [
         {  type    => 'UNION',
            possible_keys => undef,
            table => '<union1,2>',
            children => [
               {  type    => 'Index scan',
                  key     => 'actor_1->PRIMARY',
                  key_len => 2,
                  'ref'   => undef,
                  rows    => 200,
                  id      => 1,
                  rowid   => 0,
               },
               {  type    => 'Index scan',
                  key     => 'actor_2->PRIMARY',
                  key_len => 2,
                  'ref'   => undef,
                  rows    => 200,
                  id      => 2,
                  rowid   => 1,
               },
            ],
         },
      ],
   },
   'Simple union',
);

$t = $e->parse( load_file('samples/simple_derived.sql') );
is_deeply(
   $t,
   {  type     => 'Table scan',
      rows     => 200,
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'DERIVED',
            table    => '<derived2>',
            possible_keys => undef,
            children => [
               {  type    => 'Index scan',
                  key     => 'actor->PRIMARY',
                  key_len => 2,
                  'ref'   => undef,
                  rows    => 200,
                  id      => 2,
                  rowid   => 1,
               },
            ],
         },
      ],
   },
   'Simple derived table',
);

$t = $e->parse( load_file('samples/derived_over_join.sql') );
is_deeply(
   $t,
   {  type     => 'Table scan',
      rows     => 40000,
      id       => 1,
      rowid    => 0,
      children => [
         {  type     => 'DERIVED',
            table    => '<derived2>',
            possible_keys => undef,
            children => [
               {  type     => 'JOIN',
                  children => [
                     {  type    => 'Index scan',
                        key     => 'actor_1->PRIMARY',
                        key_len => 2,
                        'ref'   => undef,
                        rows    => 200,
                        id      => 2,
                        rowid   => 1,
                     },
                     {  type    => 'Index scan',
                        key     => 'actor_2->PRIMARY',
                        key_len => 2,
                        'ref'   => undef,
                        rows    => 200,
                        id      => 2,
                        rowid   => 2,
                     },
                  ],
               },
            ],
         },
      ],
   },
   'Simple derived table over a simple join',
);

$t = $e->parse( load_file('samples/join_two_derived_tables_of_joins.sql') );
is_deeply(
   $t,
   {  type     => 'JOIN',
      children => [
         {  type     => 'Table scan',
            rows     => 40000,
            id       => 1,
            rowid    => 0,
            children => [
               {  type     => 'DERIVED',
                  table    => '<derived2>',
                  possible_keys => undef,
                  children => [
                     {  type     => 'JOIN',
                        children => [
                           {  type    => 'Index scan',
                              key     => 'actor_1->PRIMARY',
                              key_len => 2,
                              'ref'   => undef,
                              rows    => 200,
                              id      => 2,
                              rowid   => 4,
                           },
                           {  type    => 'Index scan',
                              key     => 'actor_2->PRIMARY',
                              key_len => 2,
                              'ref'   => undef,
                              rows    => 200,
                              id      => 2,
                              rowid   => 5,
                           },
                        ],
                     },
                  ],
               },
            ],
         },
         {  type     => 'Filter with WHERE',
            id       => 1,
            rowid    => 1,
            children => [
               {  type     => 'Table scan',
                  rows     => 40000,
                  children => [
                     {  type     => 'DERIVED',
                        table    => '<derived3>',
                        possible_keys => undef,
                        children => [
                           {  type     => 'JOIN',
                              children => [
                                 {  type    => 'Index scan',
                                    key     => 'actor_3->PRIMARY',
                                    key_len => 2,
                                    'ref'   => undef,
                                    rows    => 200,
                                    id      => 3,
                                    rowid   => 2,
                                 },
                                 {  type    => 'Index scan',
                                    key     => 'actor_4->PRIMARY',
                                    key_len => 2,
                                    'ref'   => undef,
                                    rows    => 200,
                                    id      => 3,
                                    rowid   => 3,
                                 },
                              ],
                           },
                        ],
                     },
                  ],
               },
            ],
         },
      ],
   },
   'Join two derived tables which each contain a join',
);
