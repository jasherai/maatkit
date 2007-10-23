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

$t = $p->parse( load_file('samples/sakila.film.sql') );
is_deeply(
   $n->generate_nibble(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
   ),
   {
      asc_stmt   => {
         idx   => 'PRIMARY',
         where => '((`film_id` >= ?))',
         slice => [0],
         cols  => [qw(film_id)],
      },
      del_stmt   => {
         idx   => 'PRIMARY',
         where => '(`film_id` = ?)',
         slice => [0],
         cols  => [qw(film_id)],
      },
   },
   'Basics works OK on sakila.film',
);

__DATA__
$t = $p->parse( load_file('samples/sakila.rental.sql') );
is_deeply(
   $n->generate_nibble(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
   ),
   {
      asc_stmt   => {
         cols  => [qw(rental_id rental_date inventory_id customer_id
                     return_date staff_id last_update)],
         idx   => 'PRIMARY',
         where => '((`rental_id` >= ?))',
         slice => [0],
         cols  => [qw(rental_id)],
      },
   },
   'Basics works OK on sakila.rental',
);

$t = $p->parse( load_file('samples/sakila.rental.sql') );
is_deeply(
   $n->generate_nibble(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
   ),
   {
      asc_stmt   => {
         cols  => [qw(rental_id rental_date inventory_id customer_id
                     return_date staff_id last_update)],
         idx   => 'rental_date',
         where => '((`rental_date` >= ?) OR (`rental_date` = ? AND `inventory_id` >= ?)'
            . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` >= ?))',
         slice => [1, 1, 2, 1, 2, 3],
         cols  => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
      },
   },
   'Alternate index works OK on sakila.rental',
);

$t = $p->parse( load_file('samples/sakila.rental.sql') );
is_deeply(
   $n->generate_nibble(
      tbl    => $t,
      cols   => $t->{cols},
      quoter => $q,
      index  => 'rental_date',
      asconly => 1,
   ),
   {
      asc_stmt   => {
         cols  => [qw(rental_id rental_date inventory_id customer_id
                     return_date staff_id last_update)],
         idx   => 'rental_date',
         where => '((`rental_date` > ?) OR (`rental_date` = ? AND `inventory_id` > ?)'
            . ' OR (`rental_date` = ? AND `inventory_id` = ? AND `customer_id` > ?))',
         slice => [1, 1, 2, 1, 2, 3],
         cols  => [qw(rental_date rental_date inventory_id rental_date inventory_id customer_id)],
      },
   },
   'Alternate index works OK on sakila.rental with strict ascending',
);
