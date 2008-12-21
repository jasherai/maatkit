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

use Test::More tests => 52;
use English qw(-no_match_vars);
use DBI;

require "../TableParser.pm";
require "../Quoter.pm";

my $p = new TableParser();
my $q = new Quoter();
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

eval {
   $p->parse( load_file('samples/noquotes.sql') );
};
like($EVAL_ERROR, qr/quoting/, 'No quoting');

eval {
   $p->parse( load_file('samples/ansi_quotes.sql') );
};
like($EVAL_ERROR, qr/quoting/, 'ANSI quoting');

$t = $p->parse( load_file('samples/t1.sql') );
is_deeply(
   $t,
   {  cols         => [qw(a)],
      col_posn     => { a => 0 },
      is_col       => { a => 1 },
      is_autoinc   => { a => 0 },
      null_cols    => [qw(a)],
      is_nullable  => { a => 1 },
      keys         => {},
      defs         => { a => '  `a` int(11) default NULL' },
      numeric_cols => [qw(a)],
      is_numeric   => { a => 1 },
      engine       => 'MyISAM',
      type_for     => { a => 'int' },
   },
   'Basic table is OK',
);

$t = $p->parse( load_file('samples/TableParser-prefix_idx.sql') );
is_deeply(
   $t,
   {
      cols           => [ 'a', 'b' ],
      col_posn       => { a => 0, b => 1 },
      is_col         => { a => 1, b => 1 },
      is_autoinc     => { 'a' => 0, 'b' => 0 },
      null_cols      => [ 'a', 'b' ],
      is_nullable    => { 'a' => 1, 'b' => 1 },
      keys           => {
         prefix_idx => {
            unique => 0,
            is_col => {
               a => 1,
               b => 1,
            },
            name => 'prefix_idx',
            type => 'BTREE',
            is_nullable => 2,
            colnames => '`a`(10),`b`(20)',
            cols => [ 'a', 'b' ],
            col_prefixes => [ 10, 20 ],
         },
         mix_idx => {
            unique => 0,
            is_col => {
               a => 1,
               b => 1,
            },
            name => 'mix_idx',
            type => 'BTREE',
            is_nullable => 2,
            colnames => '`a`,`b`(20)',
            cols => [ 'a', 'b' ],
            col_prefixes => [ undef, 20 ],
         },
      },
      defs           => {
         a => '  `a` varchar(64) default NULL',
         b => '  `b` varchar(64) default NULL'
      },
      numeric_cols   => [],
      is_numeric     => {},
      engine         => 'MyISAM',
      type_for       => { a => 'varchar', b => 'varchar' },
   },
   'Indexes with prefixes parse OK (fixes issue 1)'
);

$t = $p->parse( load_file('samples/sakila.film.sql') );
is_deeply(
   $t,
   {  cols => [
         qw(film_id title description release_year language_id
            original_language_id rental_duration rental_rate
            length replacement_cost rating special_features
            last_update)
      ],
      col_posn => {
         film_id              => 0,
         title                => 1,
         description          => 2,
         release_year         => 3,
         language_id          => 4,
         original_language_id => 5,
         rental_duration      => 6,
         rental_rate          => 7,
         length               => 8,
         replacement_cost     => 9,
         rating               => 10,
         special_features     => 11,
         last_update          => 12,
      },
      is_autoinc => {
         film_id              => 1,
         title                => 0,
         description          => 0,
         release_year         => 0,
         language_id          => 0,
         original_language_id => 0,
         rental_duration      => 0,
         rental_rate          => 0,
         length               => 0,
         replacement_cost     => 0,
         rating               => 0,
         special_features     => 0,
         last_update          => 0,
      },
      is_col => {
         film_id              => 1,
         title                => 1,
         description          => 1,
         release_year         => 1,
         language_id          => 1,
         original_language_id => 1,
         rental_duration      => 1,
         rental_rate          => 1,
         length               => 1,
         replacement_cost     => 1,
         rating               => 1,
         special_features     => 1,
         last_update          => 1,
      },
      null_cols   => [qw(description release_year original_language_id length rating special_features )],
      is_nullable => {
         description          => 1,
         release_year         => 1,
         original_language_id => 1,
         length               => 1,
         special_features     => 1,
         rating               => 1,
      },
      keys => {
         PRIMARY => {
            colnames     => '`film_id`',
            cols         => [qw(film_id)],
            col_prefixes => [undef],
            is_col       => { film_id => 1 },
            is_nullable  => 0,
            unique       => 1,
            type         => 'BTREE',
            name         => 'PRIMARY',
         },
         idx_title => {
            colnames     => '`title`',
            cols         => [qw(title)],
            col_prefixes => [undef],
            is_col       => { title => 1, },
            is_nullable  => 0,
            unique       => 0,
            type         => 'BTREE',
            name         => 'idx_title',
         },
         idx_fk_language_id => {
            colnames     => '`language_id`',
            cols         => [qw(language_id)],
            col_prefixes => [undef],
            unique       => 0,
            is_col       => { language_id => 1 },
            is_nullable  => 0,
            type         => 'BTREE',
            name         => 'idx_fk_language_id',
         },
         idx_fk_original_language_id => {
            colnames     => '`original_language_id`',
            cols         => [qw(original_language_id)],
            col_prefixes => [undef],
            unique       => 0,
            is_col       => { original_language_id => 1 },
            is_nullable  => 1,
            type         => 'BTREE',
            name         => 'idx_fk_original_language_id',
         },
      },
      defs => {
         film_id      => "  `film_id` smallint(5) unsigned NOT NULL auto_increment",
         title        => "  `title` varchar(255) NOT NULL",
         description  => "  `description` text",
         release_year => "  `release_year` year(4) default NULL",
         language_id  => "  `language_id` tinyint(3) unsigned NOT NULL",
         original_language_id =>
            "  `original_language_id` tinyint(3) unsigned default NULL",
         rental_duration =>
            "  `rental_duration` tinyint(3) unsigned NOT NULL default '3'",
         rental_rate      => "  `rental_rate` decimal(4,2) NOT NULL default '4.99'",
         length           => "  `length` smallint(5) unsigned default NULL",
         replacement_cost => "  `replacement_cost` decimal(5,2) NOT NULL default '19.99'",
         rating           => "  `rating` enum('G','PG','PG-13','R','NC-17') default 'G'",
         special_features =>
            "  `special_features` set('Trailers','Commentaries','Deleted Scenes','Behind the Scenes') default NULL",
         last_update =>
            "  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP",
      },
      numeric_cols => [
         qw(film_id release_year language_id original_language_id rental_duration
            rental_rate length replacement_cost)
      ],
      is_numeric => {
         film_id              => 1,
         release_year         => 1,
         language_id          => 1,
         original_language_id => 1,
         rental_duration      => 1,
         rental_rate          => 1,
         length               => 1,
         replacement_cost     => 1,
      },
      engine   => 'InnoDB',
      type_for => {
         film_id              => 'smallint',
         title                => 'varchar',
         description          => 'text',
         release_year         => 'year',
         language_id          => 'tinyint',
         original_language_id => 'tinyint',
         rental_duration      => 'tinyint',
         rental_rate          => 'decimal',
         length               => 'smallint',
         replacement_cost     => 'decimal',
         rating               => 'enum',
         special_features     => 'set',
         last_update          => 'timestamp',
      },
   },
   'sakila.film',
);

is_deeply (
   [$p->sort_indexes($t)],
   [qw(PRIMARY idx_fk_language_id idx_title idx_fk_original_language_id)],
   'Sorted indexes OK'
);

is( $p->find_best_index($t), 'PRIMARY', 'Primary key is best');
is( $p->find_best_index($t, 'idx_title'), 'idx_title', 'Specified key is best');
throws_ok (
   sub { $p->find_best_index($t, 'foo') },
   qr/does not exist/,
   'Index does not exist',
);

$t = $p->parse( load_file('samples/temporary_table.sql') );
is_deeply(
   $t,
   {  cols         => [qw(a)],
      col_posn     => { a => 0 },
      is_col       => { a => 1 },
      is_autoinc   => { a => 0 },
      null_cols    => [qw(a)],
      is_nullable  => { a => 1 },
      keys         => {},
      defs         => { a => '  `a` int(11) default NULL' },
      numeric_cols => [qw(a)],
      is_numeric   => { a => 1 },
      engine       => 'MyISAM',
      type_for     => { a => 'int' },
   },
   'Temporary table',
);

$t = $p->parse( load_file('samples/hyphentest.sql') );
is_deeply(
   $t,
   {  'is_autoinc' => {
         'sort_order'                => 0,
         'pfk-source_instrument_id'  => 0,
         'pfk-related_instrument_id' => 0
      },
      'null_cols'    => [],
      'numeric_cols' => [
         'pfk-source_instrument_id', 'pfk-related_instrument_id',
         'sort_order'
      ],
      'cols' => [
         'pfk-source_instrument_id', 'pfk-related_instrument_id',
         'sort_order'
      ],
      'col_posn' => {
         'sort_order'                => 2,
         'pfk-source_instrument_id'  => 0,
         'pfk-related_instrument_id' => 1
      },
      'keys' => {
         'sort_order' => {
            'unique'       => 0,
            'is_col'       => { 'sort_order' => 1 },
            'name'         => 'sort_order',
            'type'         => 'BTREE',
            'col_prefixes' => [ undef ],
            'is_nullable'  => 0,
            'colnames'     => '`sort_order`',
            'cols'         => [ 'sort_order' ]
         },
         'PRIMARY' => {
            'unique' => 1,
            'is_col' => {
               'pfk-source_instrument_id'  => 1,
               'pfk-related_instrument_id' => 1
            },
            'name'         => 'PRIMARY',
            'type'         => 'BTREE',
            'col_prefixes' => [ undef, undef ],
            'is_nullable'  => 0,
            'colnames' =>
               '`pfk-source_instrument_id`,`pfk-related_instrument_id`',
            'cols' =>
               [ 'pfk-source_instrument_id', 'pfk-related_instrument_id' ]
         }
      },
      'defs' => {
         'sort_order' => '  `sort_order` int(11) NOT NULL',
         'pfk-source_instrument_id' =>
            '  `pfk-source_instrument_id` int(10) unsigned NOT NULL',
         'pfk-related_instrument_id' =>
            '  `pfk-related_instrument_id` int(10) unsigned NOT NULL'
      },
      'engine' => 'InnoDB',
      'is_col' => {
         'sort_order'                => 1,
         'pfk-source_instrument_id'  => 1,
         'pfk-related_instrument_id' => 1
      },
      'is_numeric' => {
         'sort_order'                => 1,
         'pfk-source_instrument_id'  => 1,
         'pfk-related_instrument_id' => 1
      },
      'type_for' => {
         'sort_order'                => 'int',
         'pfk-source_instrument_id'  => 'int',
         'pfk-related_instrument_id' => 'int'
      },
      'is_nullable' => {}
   },
   'Hyphens in indexed columns',
);

$t = $p->parse( load_file('samples/ndb_table.sql') );
is_deeply(
   $t,
   {  cols        => [qw(id)],
      col_posn    => { id => 0 },
      is_col      => { id => 1 },
      is_autoinc  => { id => 1 },
      null_cols   => [],
      is_nullable => {},
      keys        => {
         PRIMARY => {
            cols         => [qw(id)],
            unique       => 1,
            is_col       => { id => 1 },
            name         => 'PRIMARY',
            type         => 'BTREE',
            col_prefixes => [undef],
            is_nullable  => 0,
            colnames     => '`id`',
         }
      },
      defs => { id => '  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT' },
      numeric_cols => [qw(id)],
      is_numeric   => { id => 1 },
      engine       => 'ndbcluster',
      type_for     => { id => 'bigint' },
   },
   'NDB table',
);

$t = $p->parse( load_file('samples/mixed-case.sql') );
is_deeply(
   $t,
   {  cols         => [qw(a b mixedcol)],
      col_posn     => { a => 0, b => 1, mixedcol => 2 },
      is_col       => { a => 1, b => 1, mixedcol => 1 },
      is_autoinc   => { a => 0, b => 0, mixedcol => 0 },
      null_cols    => [qw(a b mixedcol)],
      is_nullable  => { a => 1, b => 1, mixedcol => 1 },
      keys         => {
         mykey => {
            colnames     => '`a`,`b`,`mixedcol`',
            cols         => [qw(a b mixedcol)],
            col_prefixes => [undef, undef, undef],
            is_col       => { a => 1, b => 1, mixedcol => 1 },
            is_nullable  => 3,
            unique       => 0,
            type         => 'BTREE',
            name         => 'mykey',
         },
      },
      defs         => {
         a => '  `a` int(11) default NULL',
         b => '  `b` int(11) default NULL',
         mixedcol => '  `mixedcol` int(11) default NULL',
      },
      numeric_cols => [qw(a b mixedcol)],
      is_numeric   => { a => 1, b => 1, mixedcol => 1 },
      engine       => 'MyISAM',
      type_for     => { a => 'int', b => 'int', mixedcol => 'int' },
   },
   'Mixed-case identifiers',
);

# #############################################################################
# Tests from the former IndexChecker package in mk-duplicate-key-checker
# #############################################################################
my $ddl;
my $opt = { version => '004001000' };

$ddl = load_file('samples/no_keys.sql');
is($p->get_engine($ddl), 'MyISAM', 'Right engine');
is_deeply($p->get_keys($ddl, $opt),   [],       'No keys');
is_deeply($p->get_fks($ddl),    [],       'No foreign keys');

$ddl = load_file('samples/one_key.sql');
is_deeply($p->get_fks($ddl),    [],       'No foreign keys, again');
is_deeply(
   $p->get_keys($ddl, $opt),
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
   $p->get_keys($ddl, $opt),
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
   $p->get_fks($ddl, { database => 'test' } ),
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
   $p->get_keys($ddl, $opt),
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
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
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
   $p->get_keys($ddl, $opt),
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
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
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
   $p->get_keys($ddl, $opt),
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
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
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
   $p->get_keys($ddl, $opt),
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
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
   [
   ],
   'No dupe keys b/c of fulltext'
);
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt),
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

$ddl = load_file('samples/nondupe_fulltext_not_exact.sql');
is_deeply(
   $p->get_keys($ddl, $opt),
   [
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a_b',
         cols   => '`a`,`b`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_b',
         cols   => '`b`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a',
         cols   => '`a`',
      },
   ],
   'Fulltext keys on table ft_not_dupe_key (for issue 10)'
);
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
   [
   ],
   'No dupe keys b/c fulltext requires exact match (issue 10)'
);

$ddl = load_file('samples/dupe_fulltext_exact.sql');
is_deeply(
   $p->get_keys($ddl, $opt),
   [
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a_b_1',
         cols   => '`a`,`b`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a_b_2',
         cols   => '`a`,`b`',
      },
   ],
   'Fulltext keys on table ft_dupe_key_exact (issue 10)'
);
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
   [
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a_b_1',
         cols   => '`a`,`b`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a_b_2',
         cols   => '`a`,`b`',
      },
   ],
   'Dupe exact fulltext keys (issue 10)'
);

$ddl = load_file('samples/dupe_fulltext_reverse_order.sql');
is_deeply(
   $p->get_keys($ddl, $opt),
   [
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a_b',
         cols   => '`a`,`b`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_b_a',
         cols   => '`b`,`a`',
      },
   ],
   'Fulltext keys on table ft_dupe_key_reverse_order (issue 10)'
);
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
   [
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_a_b',
         cols   => '`a`,`b`',
      },
      {
         struct => 'FULLTEXT',
         name   => 'ft_idx_b_a',
         cols   => '`b`,`a`',
      },
   ],
   'Dupe reverse order fulltext keys (issue 10)'
);

$ddl = load_file('samples/dupe_key_unordered.sql');
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
   [
   ],
   'No dupe keys because of order'
);
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt),
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
   $p->get_fks($ddl, { database => 'test' } ),
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
   $p->get_duplicate_fks($p->get_fks($ddl, { database => 'test' } )),
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
   $p->get_fks($ddl, { database => 'sakila' } ),
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
   $p->get_duplicate_fks($p->get_fks($ddl, { database => 'sakila' } )),
   [
   ],
   'No duplicate foreign keys'
);

$ddl = load_file('samples/innodb_dupe.sql');
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt)),
   [],
   'No duplicate keys with ordinary options'
);
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt), { clustered => 1, engine => 'InnoDB' }),
   [
      {
         struct => 'BTREE',
         name   => 'PRIMARY',
         cols   => '`a`',
      },
      {
         struct => 'BTREE',
         name   => 'b',
         cols   => '`b`,`a`',
      },
   ],
   'Duplicate keys with cluster options'
);

$ddl = load_file('samples/dupe_if_it_were_innodb.sql');
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt), { clustered => 1, engine => 'MyISAM' }),
   [ ],
   'No cluster-duplicate keys because not InnoDB'
);

# This table is a test case for an infinite loop I ran into while writing the
# cluster stuff
$ddl = load_file('samples/mysql_db.sql');
is_deeply(
   $p->get_duplicate_keys($p->get_keys($ddl, $opt), { clustered => 1, engine => 'InnoDB' }),
   [],
   'No cluster-duplicate keys in mysql.db'
);

# #############################################################################
# Sandbox tests
# #############################################################################

my $dbh;
eval {
   $dbh = DBI->connect(
   "DBI:mysql:;mysql_read_default_group=mysql", undef, undef,
   { PrintError => 0, RaiseError => 1 })
};
SKIP: {
   skip 'Cannot connect to MySQL', 4
      unless $dbh;
   skip 'Sakila is not installed', 4
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   is_deeply(
      [$p->find_possible_keys(
         $dbh, 'sakila', 'film_actor', $q, 'film_id > 990  and actor_id > 1')],
      [qw(idx_fk_film_id PRIMARY)],
      'Best index for WHERE clause'
   );

   is_deeply(
      [$p->find_possible_keys(
         $dbh, 'sakila', 'film_actor', $q, 'film_id > 990 or actor_id > 1')],
      [qw(idx_fk_film_id PRIMARY)],
      'Best index for WHERE clause with sort_union'
   );

   is($p->table_exists($dbh, 'sakila', 'film_actor', $q), '1', 'table_exists returns true when the table exists');
   is($p->table_exists($dbh, 'sakila', 'foo', $q), '0', 'table_exists returns false when the table does not exist');
}

# TODO: use Sandbox
my $sb_dbh = DBI->connect(
   "DBI:mysql:host=127.0.0.1;port=12345", 'root', 'msandbox',
   { PrintError => 0, RaiseError => 1 });
$sb_dbh->do("DROP DATABASE IF EXISTS foo");
$sb_dbh->do("CREATE DATABASE foo");
$sb_dbh->do("GRANT SELECT ON test.* TO 'user'\@'\%'");
$sb_dbh->do('FLUSH PRIVILEGES');

my $sb_dbh2 = DBI->connect(
   "DBI:mysql:host=127.0.0.1;port=12345", 'user', undef,
   { PrintError => 0, RaiseError => 1 });
is($p->table_exists($sb_dbh2, 'mysql', 'db', $q, 1), '0', 'table_exists but no insert privs');
$sb_dbh2->disconnect();

$sb_dbh->do('DROP DATABASE foo');
$sb_dbh->do("DROP USER 'user'");
$sb_dbh->disconnect();

# #############################################################################
# Issue 109: Test schema changes in 5.1
# #############################################################################
sub cmp_ddls {
   my ( $desc, $v1, $v2 ) = @_;

   $t = $p->parse( load_file($v1) );
   my $t2 = $p->parse( load_file($v2) );

   # The defs for each will differ due to string case: 'default' vs. 'DEFAULT'.
   # Everything else should be identical, though. So we'll chop out the defs,
   # compare them later, and check the rest first.
   my %defs  = %{$t->{defs}};
   my %defs2 = %{$t2->{defs}};
   $t->{defs}  = ();
   $t2->{defs} = ();
   is_deeply($t, $t2, "$desc SHOW CREATE parse identically");

   my $defstr  = '';
   my $defstr2 = '';
   foreach my $col ( keys %defs ) {
      $defstr  .= lc $defs{$col};
      $defstr2 .= lc $defs2{$col};
   }
   is($defstr, $defstr2, "$desc defs are identical (except for case)");

   return;
}

cmp_ddls('v5.0 vs. v5.1', 'samples/issue_109-01-v50.sql', 'samples/issue_109-01-v51.sql');

exit;
