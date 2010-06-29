#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

# #############################################################################
# chunk_tables()
# #############################################################################

# Make sure that it sets first_tbl_in_db and last_chunk_in_tbl correctly.
my $q = new Quoter();
my $o = new OptionParser(
   description => 'mk-parallel-dump',
);
$o->get_specs("$trunk/mk-parallel-dump/mk-parallel-dump");
@ARGV = qw(--no-resume --dry-run);
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
    L => '',
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
    L => '',
    N => 't2',
    W => '1=1',
    Z => '1234',
    last_chunk_in_tbl => 1
   },
   {
    C => 0,
    D => 'd1',
    E => undef,
    L => '',
    N => 't3',
    W => '1=1',
    Z => '123',
    last_chunk_in_tbl => 1,
   },
];

# The S key is for the chunk's table struct.  It's big and we
# don't need to check it here.
my @got_chunks = map { delete $_->{S}; $_ } mk_parallel_dump::chunk_tables(%args);
is_deeply(
   \@got_chunks,
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
    L => '',
    N => 't1',
    W => '1=1',
    Z => '120',
    last_chunk_in_tbl => 1,
    first_tbl_in_db   => 1,
};
@got_chunks = map { delete $_->{S}; $_ } mk_parallel_dump::chunk_tables(%args);
is_deeply(
   \@got_chunks,
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
    L => '',
    N => 't4',
    W => '1=1',
    Z => '100',
    last_chunk_in_tbl => 1,
};
@got_chunks = map { delete $_->{S}; $_ } mk_parallel_dump::chunk_tables(%args);
is_deeply(
   \@got_chunks,
   $chunks,
   'chunk_tables(), 2 dbs mixed'
);

SKIP: {
   skip 'sakila db not loaded', 1
      unless $dbh && @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   my $tp = new TableParser(Quoter => $q);
   my $du = new MySQLDump(cache => 0);
   my $tc = new TableChunker(Quoter => $q, MySQLDump => $du);

   $args{dbh}          = $dbh;
   $args{TableChunker} = $tc;

   my $tbl_struct = $tp->parse(
      $du->get_create_table($dbh, $q, 'sakila', 'actor'));

   # Actually chunk a table (i.e. W => some range).
   @ARGV = qw(--no-resume --chunk-size 50 --base-dir /tmp/mpr);
   $o->get_opts();

   @tbls = (
      {
         tbl        => 'actor',  # has 200 rows
         db         => 'sakila',
         tbl_struct => $tbl_struct,
         size       => '100',
      },
   );

   $chunks = [
     {
       C => 0,
       D => 'sakila',
       E => 'InnoDB',
       L => '`actor_id`,`first_name`,`last_name`,`last_update`',
       N => 'actor',
       W => "`actor_id` = 0",
       Z => 4050,
       first_tbl_in_db => 1
     },
     {
       C => 1,
       D => 'sakila',
       E => 'InnoDB',
       L => '`actor_id`,`first_name`,`last_name`,`last_update`',
       N => 'actor',
       W => "`actor_id` > 0 AND `actor_id` < '51'",
       Z => 4050,
     },
     {
       C => 2,
       D => 'sakila',
       E => 'InnoDB',
       L => '`actor_id`,`first_name`,`last_name`,`last_update`',
       N => 'actor',
       W => "`actor_id` >= '51' AND `actor_id` < '101'",
       Z => 4050
     },
     {
       C => 3,
       D => 'sakila',
       E => 'InnoDB',
       L => '`actor_id`,`first_name`,`last_name`,`last_update`',
       N => 'actor',
       W => "`actor_id` >= '101' AND `actor_id` < '151'",
       Z => 4050
     },
     {
       C => 4,
       D => 'sakila',
       E => 'InnoDB',
       L => '`actor_id`,`first_name`,`last_name`,`last_update`',
       N => 'actor',
       W => "`actor_id` >= '151'",
       Z => 4050,
       last_chunk_in_tbl => 1
     }
   ];
   @got_chunks = map { delete $_->{S}; $_ } mk_parallel_dump::chunk_tables(%args);
   is_deeply(
      \@got_chunks,
      $chunks,
      'sakila.actor'
   );
}

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf /tmp/mpr`);
exit;
