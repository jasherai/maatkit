#!/usr/bin/perl

BEGIN {
   die
      "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
}

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use IndexUsage;
use MaatkitTest;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

my $iu = new IndexUsage();

# These are mock TableParser::get_keys() structs.
my $actor_idx = {
   PRIMARY             => { name => 'PRIMARY', },
   idx_actor_last_name => { name => 'idx_actor_last_name', }
};
my $film_actor_idx = {
   PRIMARY        => { name => 'PRIMARY', },
   idx_fk_film_id => { name => 'idx_fk_film_id', },
};
my $film_idx = {
   PRIMARY => { name => 'PRIMARY', },
};
my $othertbl_idx = {
   PRIMARY => { name => 'PRIMARY', },
};

# This is more of an integration test than a unit test.
# First we explore all the databases/tables/indexes in the server.
$iu->add_indexes(db=>'sakila', tbl=>'actor',      indexes=>$actor_idx);
$iu->add_indexes(db=>'sakila', tbl=>'film_actor', indexes=>$film_actor_idx );
$iu->add_indexes(db=>'sakila', tbl=>'film',       indexes=>$film_idx );
$iu->add_indexes(db=>'sakila', tbl=>'othertbl',   indexes=>$othertbl_idx);

# Now, we see some queries that use some tables, but not all of them.
$iu->add_table_usage(qw(sakila      actor));
$iu->add_table_usage(qw(sakila film_actor));
$iu->add_table_usage(qw(sakila   othertbl));    # But not sakila.film!

# Some of those queries also use indexes.
$iu->add_index_usage(
   usage      => [
      {  db  => 'sakila',
         tbl => 'film_actor',
         idx => [qw(PRIMARY idx_fk_film_id)],
         alt => [],
      },
      {  db  => 'sakila',
         tbl => 'actor',
         idx => [qw(PRIMARY)],
         alt => [qw(idx_actor_last_name)],
      },
   ],
);

# Now let's find out which indexes were never used.
my @unused;
$iu->find_unused_indexes(
   sub {
      my ($thing) = @_;
      push @unused, $thing;
   }
);

is_deeply(
   \@unused,
   [
      {
         db  => 'sakila',
         tbl => 'actor',
         idx => [ { name=>'idx_actor_last_name', cnt=>0 } ],
      },
      {
         db  => 'sakila',
         tbl => 'othertbl',
         idx => [ { name=>'PRIMARY', cnt=>0 } ],
      },
   ],
   'Got unused indexes for sakila.actor and film_actor',
);

# #############################################################################
# Done.
# #############################################################################
exit;
