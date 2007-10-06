#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;
use English qw(-no_match_vars);

require "../TableParser.pm";

my $p = new TableParser();
my $t;

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

$t = $p->parse( load_file('samples/t1.sql') );
is_deeply(
   $t,
   {  cols         => [qw(a)],
      is_col       => { a => 1 },
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

$t = $p->parse( load_file('samples/sakila.film.sql') );
is_deeply(
   $t,
   {  cols => [
         qw(film_id title description release_year language_id
            original_language_id rental_duration rental_rate
            length replacement_cost rating special_features
            last_update)
      ],
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
      null_cols   => [qw( release_year original_language_id length rating special_features )],
      is_nullable => {
         release_year         => 1,
         original_language_id => 1,
         length               => 1,
         special_features     => 1,
         rating               => 1,
      },
      keys => {
         PRIMARY => {
            colnames    => '`film_id`',
            cols        => [qw(film_id)],
            is_col      => { film_id => 1 },
            is_nullable => 0,
            unique      => 1,
            type        => 'BTREE',
         },
         idx_title => {
            colnames    => '`title`',
            cols        => [qw(title)],
            is_col      => { title => 1, },
            is_nullable => 0,
            unique      => 0,
            type        => 'BTREE',
         },
         idx_fk_language_id => {
            colnames    => '`language_id`',
            cols        => [qw(language_id)],
            unique      => 0,
            is_col      => { language_id => 1 },
            is_nullable => 0,
            type        => 'BTREE',
         },
         idx_fk_original_language_id => {
            colnames    => '`original_language_id`',
            cols        => [qw(original_language_id)],
            unique      => 0,
            is_col      => { original_language_id => 1 },
            is_nullable => 1,
            type        => 'BTREE',
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
   'sakila.film is OK',
);
