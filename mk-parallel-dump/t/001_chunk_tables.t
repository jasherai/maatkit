#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

require '../mk-parallel-dump';

# #############################################################################
# chunk_tables()
# #############################################################################

# Make sure that it sets first_tbl_in_db and last_chunk_in_tbl correctly.
my $q = new Quoter();
my $o = new OptionParser(
   description => 'mk-parallel-dump',
);
$o->get_specs('../mk-parallel-dump');
@ARGV = qw(--no-resume);
$o->get_opts();

my @tbls = (
   {
      tbl        => 't1',
      db         => 'd1',
      tbl_struct => {},
      size       => '12345',
   },
   {
      tbl        => 't2',
      db         => 'd1',
      tbl_struct => {},
      size       => '1234',
   },
   {
      tbl        => 't3',
      db         => 'd1',
      tbl_struct => {},
      size       => '123',
   },
);

my %args = (
   dbh          => 1,  # not needed
   tbls         => \@tbls,
   stat_totals  => {},
   stats_for    => {},
   OptionParser => $o,
   Quoter       => $q,
   TableChunker => 1,  # not needed
);

my $chunks = [
   {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't1',
    W => '1=1',
    Z => '12345',
    first_tbl_in_db => 1,
    last_chunk_in_tbl => 1
   },
   {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't2',
    W => '1=1',
    Z => '1234',
    last_chunk_in_tbl => 1
   },
   {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't3',
    W => '1=1',
    Z => '123',
    last_chunk_in_tbl => 1,
   },
];

is_deeply(
   [ mk_parallel_dump::chunk_tables(%args) ],
   $chunks,
   'chunk_tables(), 1 db with 3 tables'
);

# Add another db to the tables.
push @tbls, {
   tbl        => 't1',
   db         => 'd2',
   tbl_struct => {},
   size       => '120',
};
push @$chunks, {
    C => 0,
    D => 'd2',
    E => undef,
    L => '*',
    N => 't1',
    W => '1=1',
    Z => '120',
    last_chunk_in_tbl => 1,
    first_tbl_in_db   => 1,
};

is_deeply(
   [ mk_parallel_dump::chunk_tables(%args) ],
   $chunks,
   'chunk_tables(), 2 dbs'
);

# Now confuse it by adding another table, t4, from db1.  This can happen if
# t4 is smaller than db2.t1 because the tables are sorted by size.
push @tbls, {
   tbl        => 't4',
   db         => 'd1',
   tbl_struct => {},
   size       => '100',
};
push @$chunks, {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't4',
    W => '1=1',
    Z => '100',
    last_chunk_in_tbl => 1,
};

is_deeply(
   [ mk_parallel_dump::chunk_tables(%args) ],
   $chunks,
   'chunk_tables(), 2 dbs mixed'
);

# #############################################################################
# Done.
# #############################################################################
exit;
