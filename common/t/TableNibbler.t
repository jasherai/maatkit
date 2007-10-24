#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 15;
use English qw(-no_match_vars);

require "../TableParser.pm";
require "../TableNibbler.pm";
require "../Quoter.pm";

my $p = new TableParser();
my $n = new TableNibbler();
my $q = new Quoter();
my $t;

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub throws_ok {
   my ( $code, $pat, $msg ) = @_;
   eval { $code->(); };
   like ( $EVAL_ERROR, $pat, $msg );
}

$t = $p->parse( load_file('samples/sakila.film.sql') );

is_deeply(
   $n->generate_asc_stmt (
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
   ),
   {
      cols  => [qw(film_id title description release_year language_id
                  original_language_id rental_duration rental_rate
                  length replacement_cost rating special_features
                  last_update)],
      index => 'PRIMARY',
      where => '((`film_id` >= ?))',
      slice => [0],
      scols => [qw(film_id)],
   },
   'asc stmt on sakila.film',
);

throws_ok(
   sub {
      $n->generate_asc_stmt (
         tbl    => $t,
         cols   => $t->{cols},
         quoter => $q,
         index  => 'title',
      )
   },
   qr/Index 'title' does not exist in table/,
   'Error on nonexistent index',
);

is_deeply(
   $n->generate_asc_stmt (
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'idx_title',
   ),
   {
      cols  => [qw(film_id title description release_year language_id
                  original_language_id rental_duration rental_rate
                  length replacement_cost rating special_features
                  last_update)],
      index => 'idx_title',
      where => '((`title` >= ?))',
      slice => [1],
      scols => [qw(title)],
   },
   'asc stmt on sakila.film with different index',
);

is_deeply(
   $n->generate_asc_stmt (
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'IDX_TITLE',
   ),
   {
      cols  => [qw(film_id title description release_year language_id
                  original_language_id rental_duration rental_rate
                  length replacement_cost rating special_features
                  last_update)],
      index => 'idx_title',
      where => '((`title` >= ?))',
      slice => [1],
      scols => [qw(title)],
   },
   'Index returned in correct lettercase',
);

is_deeply(
   $n->generate_asc_stmt (
      tbl    => $t,
      cols   => [qw(title)],
      quoter => $q,
   ),
   {
      cols  => [qw(title film_id)],
      index => 'PRIMARY',
      where => '((`film_id` >= ?))',
      slice => [1],
      scols => [qw(film_id)],
   },
   'Required columns added to SELECT list',
);

# ##########################################################################
# Switch to the rental table
# ##########################################################################
$t = $p->parse( load_file('samples/sakila.rental.sql') );

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
   ),
   {
      cols  => [qw(rental_id rental_date inventory_id customer_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
         . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` >= ?))',
      slice => [1, 1, 2, 1, 2, 3],
      scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
   },
   'Alternate index on sakila.rental',
);

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
      ascfirst => 1,
   ),
   {
      cols  => [qw(rental_id rental_date inventory_id customer_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` >= ?))',
      slice => [1],
      scols => [qw(rental_date)],
   },
   'Alternate index with ascfirst on sakila.rental',
);

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
      asconly => 1,
   ),
   {
      cols  => [qw(rental_id rental_date inventory_id customer_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
         . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` > ?))',
      slice => [1, 1, 2, 1, 2, 3],
      scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
   },
   'Alternate index on sakila.rental with strict ascending',
);

# ##########################################################################
# Switch to the rental table with customer_id nullable
# ##########################################################################
$t = $p->parse( load_file('samples/sakila.rental.null.sql') );

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
   ),
   {
      cols  => [qw(rental_id rental_date inventory_id customer_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
         . ' OR (`rental_date` = ? AND `inventory_id` = ? AND '
         . '(? IS NULL OR `customer_id` >= ?)))',
      slice => [1, 1, 2, 1, 2, 3, 3],
      scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id customer_id)],
   },
   'Alternate index on sakila.rental with nullable customer_id',
);

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
      asconly => 1,
   ),
   {
      cols  => [qw(rental_id rental_date inventory_id customer_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
         . ' OR (`rental_date` = ? AND `inventory_id` = ? AND '
         . '((? IS NULL AND `customer_id` IS NOT NULL) OR (`customer_id` > ?))))',
      slice => [1, 1, 2, 1, 2, 3, 3],
      scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id customer_id)],
   },
   'Alternate index on sakila.rental with nullable customer_id and strict ascending',
);

# ##########################################################################
# Switch to the rental table with inventory_id nullable
# ##########################################################################
$t = $p->parse( load_file('samples/sakila.rental.null2.sql') );

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
   ),
   {
      cols  => [qw(rental_id rental_date inventory_id customer_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` > ?) OR '
         . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NOT NULL) OR (`inventory_id` > ?)))'
         . ' OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
         . 'OR (`inventory_id` = ?)) AND `customer_id` >= ?))',
      slice => [1, 1, 2, 2, 1, 2, 2, 3],
      scols => [qw(rental_date rental_date inventory_id inventory_id
                   rental_date inventory_id inventory_id customer_id)],
   },
   'Alternate index on sakila.rental with nullable inventory_id',
);

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
      asconly => 1,
   ),
   {
      cols  => [qw(rental_id rental_date inventory_id customer_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` > ?) OR '
         . '(`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NOT NULL) OR (`inventory_id` > ?)))'
         . ' OR (`rental_date` = ? AND ((? IS NULL AND `inventory_id` IS NULL) '
         . 'OR (`inventory_id` = ?)) AND `customer_id` > ?))',
      slice => [1, 1, 2, 2, 1, 2, 2, 3],
      scols => [qw(rental_date rental_date inventory_id inventory_id
                   rental_date inventory_id inventory_id customer_id)],
   },
   'Alternate index on sakila.rental with nullable inventory_id and strict ascending',
);

