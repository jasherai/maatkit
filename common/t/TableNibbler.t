#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 21;
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

is_deeply (
   [$n->sort_indexes($t)],
   [qw(PRIMARY idx_fk_language_id idx_title idx_fk_original_language_id)],
   'Sorted indexes OK'
);

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

is_deeply(
   $n->generate_del_stmt (
      tbl    => $t,
      quoter => $q,
   ),
   {
      cols  => [qw(film_id)],
      index => 'PRIMARY',
      where => '(`film_id` = ?)',
      slice => [0],
      scols => [qw(film_id)],
   },
   'del stmt on sakila.film',
);

is_deeply(
   $n->generate_asc_stmt (
      tbl    => $t,
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
   'defaults to all columns',
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
   $n->generate_del_stmt (
      tbl    => $t,
      quoter => $q,
      index  => 'idx_title',
      cols   => [qw(film_id)],
   ),
   {
      cols  => [qw(film_id title)],
      index => 'idx_title',
      where => '(`title` = ?)',
      slice => [1],
      scols => [qw(title)],
   },
   'del stmt on sakila.film with different index and extra column',
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
   $n->generate_del_stmt (
      tbl    => $t,
      quoter => $q,
      index  => 'rental_date',
   ),
   {
      cols  => [qw(rental_date inventory_id customer_id)],
      index => 'rental_date',
      where => '(`rental_date` = ? AND `inventory_id` = ? AND `customer_id` = ?)',
      slice => [0, 1, 2],
      scols => [qw(rental_date inventory_id customer_id)],
   },
   'Alternate index on sakila.rental delete statement',
);

# Check that I can select from one table and insert into another OK
my $f = $p->parse( load_file('samples/sakila.film.sql') );
is_deeply(
   $n->generate_ins_stmt (
      tbl    => $f,
      cols   => $t->{cols},
   ),
   {
      cols  => [qw(last_update)],
      slice => [12],
   },
   'Generated an INSERT statement from film into rental',
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
   $n->generate_del_stmt (
      tbl    => $t,
      quoter => $q,
      index  => 'rental_date',
   ),
   {
      cols  => [qw(rental_date inventory_id customer_id)],
      index => 'rental_date',
      where => '(`rental_date` = ? AND `inventory_id` = ? AND '
               . '((? IS NULL AND `customer_id` IS NULL) OR (`customer_id` = ?)))',
      slice => [0, 1, 2, 2],
      scols => [qw(rental_date inventory_id customer_id customer_id)],
   },
   'Alternate index on sakila.rental delete statement with nullable customer_id',
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

# ##########################################################################
# Switch to the rental table with cols in a different order.
# ##########################################################################
$t = $p->parse( load_file('samples/sakila.rental.remix.sql') );

is_deeply(
   $n->generate_asc_stmt(
      tbl    => $t,
      quoter => $q,
      index  => 'rental_date',
   ),
   {
      cols  => [qw(rental_id rental_date customer_id inventory_id
                  return_date staff_id last_update)],
      index => 'rental_date',
      where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
         . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` >= ?))',
      slice => [1, 1, 3, 1, 3, 2],
      scols => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
   },
   'Out-of-order index on sakila.rental',
);

# ##########################################################################
# Switch to table without any indexes
# ##########################################################################
$t = $p->parse( load_file('samples/t1.sql') );

throws_ok(
   sub {
      $n->generate_asc_stmt (
         tbl    => $t,
         quoter => $q,
      )
   },
   qr/Cannot find an ascendable index in table/,
   'Error when no good index',
);

