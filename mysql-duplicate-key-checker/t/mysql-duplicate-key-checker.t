#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use Test::More tests => 22;

require "../mysql-duplicate-key-checker";

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}
my $c = new IndexChecker;
my $ddl;
my $opt = { version => '004001000' };

$ddl = load_file('samples/no_keys.sql');
is($c->find_engine($ddl), 'MyISAM', 'Right engine');
is_deeply($c->find_keys($ddl, $opt),   [],       'No keys');
is_deeply($c->find_fks($ddl),    [],       'No foreign keys');

$ddl = load_file('samples/one_key.sql');
is_deeply($c->find_fks($ddl),    [],       'No foreign keys, again');
is_deeply(
   $c->find_keys($ddl, $opt),
   [
      {
         struct => 'BTREE',
         name   => 'PRIMARY',
         cols   => '`a`',
      },
   ],
   'One key'
);

$ddl = load_file('samples/one_fk.sql');
is_deeply(
   $c->find_keys($ddl, $opt),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
   ],
   'One key with one FK'
);
is_deeply(
   $c->find_fks($ddl, { database => 'test' } ),
   [
      {
         parent => '`test`.`t2`',
         name   => 't1_ibfk_1',
         cols   => '`a`',
         fkcols => '`a`',
      },
   ],
   'One foreign key'
);

$ddl = load_file('samples/dupe_key.sql');
is_deeply(
   $c->find_keys($ddl, $opt),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
      {
         struct => 'BTREE',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
   ],
   'Two keys on table dupe_key'
);
is_deeply(
   $c->find_duplicate_keys($c->find_keys($ddl, $opt)),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
      {
         struct => 'BTREE',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
   ],
   'Two dupe keys on table dupe_key'
);

$ddl = load_file('samples/dupe_key_reversed.sql');
is_deeply(
   $c->find_keys($ddl, $opt),
   [
      {
         struct => 'BTREE',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
   ],
   'Two keys on table dupe_key in reverse'
);
is_deeply(
   $c->find_duplicate_keys($c->find_keys($ddl, $opt)),
   [
      {
         struct => 'BTREE',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
   ],
   'Two dupe keys on table dupe_key in reverse'
);

$ddl = load_file('samples/dupe_keys_thrice.sql');
is_deeply(
   $c->find_keys($ddl, $opt),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
      {
         struct => 'BTREE',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
      {
         struct => 'BTREE',
         name   => 'a_3',
         cols   => '`a`,`b`',
      },
   ],
   'Three keys on table dupe_key'
);
is_deeply(
   $c->find_duplicate_keys($c->find_keys($ddl, $opt)),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
      {
         struct => 'BTREE',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
      {
         struct => 'BTREE',
         name   => 'a_3',
         cols   => '`a`,`b`',
      },
   ],
   'Dupe keys only output once'
);

$ddl = load_file('samples/nondupe_fulltext.sql');
is_deeply(
   $c->find_keys($ddl, $opt),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
   ],
   'Fulltext keys on table dupe_key'
);
is_deeply(
   $c->find_duplicate_keys($c->find_keys($ddl, $opt)),
   [
   ],
   'No dupe keys b/c of fulltext'
);
is_deeply(
   $c->find_duplicate_keys($c->find_keys($ddl, $opt),
      { ignore_type => 1 }),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`a`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
   ],
   'Dupe keys when ignoring type'
);

$ddl = load_file('samples/dupe_key_unordered.sql');
is_deeply(
   $c->find_duplicate_keys($c->find_keys($ddl, $opt)),
   [
   ],
   'No dupe keys because of order'
);
is_deeply(
   $c->find_duplicate_keys($c->find_keys($ddl, $opt),
      { ignore_order => 1 }),
   [
      {
         struct => 'BTREE',
         name   => 'a',
         cols   => '`b`,`a`',
      },
      {
         struct => 'BTREE',
         name   => 'a_2',
         cols   => '`a`,`b`',
      },
   ],
   'Two dupe keys when ignoring order'
);

$ddl = load_file('samples/dupe_fk_one.sql');
is_deeply(
   $c->find_fks($ddl, { database => 'test' } ),
   [
      {
         parent => '`test`.`t2`',
         name   => 't1_ibfk_1',
         cols   => '`a`, `b`',
         fkcols   => '`a`, `b`',
      },
      {
         parent => '`test`.`t2`',
         name   => 't1_ibfk_2',
         cols   => '`b`, `a`',
         fkcols   => '`b`, `a`',
      },
   ],
   'Two foreign keys'
);
is_deeply(
   $c->find_duplicate_fks($c->find_fks($ddl, { database => 'test' } )),
   [
      {
         parent => '`test`.`t2`',
         name   => 't1_ibfk_1',
         cols   => '`a`, `b`',
         fkcols   => '`a`, `b`',
      },
      {
         parent => '`test`.`t2`',
         name   => 't1_ibfk_2',
         cols   => '`b`, `a`',
         fkcols   => '`b`, `a`',
      },
   ],
   'Two duplicate foreign keys'
);

$ddl = load_file('samples/sakila_film.sql');
is_deeply(
   $c->find_fks($ddl, { database => 'sakila' } ),
   [
      {
         parent => '`sakila`.`language`',
         name   => 'fk_film_language',
         cols   => '`language_id`',
         fkcols => '`language_id`',
      },
      {
         parent => '`sakila`.`language`',
         name   => 'fk_film_language_original',
         fkcols   => '`original_language_id`',
         cols => '`language_id`',
      },
   ],
   'Two foreign keys'
);
is_deeply(
   $c->find_duplicate_fks($c->find_fks($ddl, { database => 'sakila' } )),
   [
   ],
   'No duplicate foreign keys'
);
