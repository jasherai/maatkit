#!/usr/bin/perl

BEGIN {
   die
      "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
}

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 7;
use constant MKDEBUG => $ENV{MKDEBUG} || 0;

use IndexUsage;
use OptionParser;
use DSNParser;
use Transformers;
use QueryRewriter;
use Sandbox;
use MaatkitTest;

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

Transformers->import(qw(make_checksum));

my $qr  = new QueryRewriter();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

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
# Test save results.
# #############################################################################
SKIP: {
   skip "Cannot connect to sandbox master", 6 unless $dbh;
   skip "Sakila database is not loaded",    6
      unless @{ $dbh->selectall_arrayref('show databases like "sakila"') };

   # Use mk-index-usage to create all the save results tables.
   `$trunk/mk-index-usage/mk-index-usage -F /tmp/12345/my.sandbox.cnf --create-save-results-database --save-results-database D=mk_iu --empty-save-results-tables --no-report --quiet $trunk/common/t/samples/empty >/dev/null 2>&1`;

   $iu = new IndexUsage(
      dbh => $dbh,
      db  => "mk_iu",
      QueryRewriter => $qr,
   );

   $iu->add_indexes(db=>'sakila', tbl=>'actor',      indexes=>$actor_idx);
   $iu->add_indexes(db=>'sakila', tbl=>'film_actor', indexes=>$film_actor_idx );
   $iu->add_indexes(db=>'sakila', tbl=>'film',       indexes=>$film_idx );
   $iu->add_indexes(db=>'sakila', tbl=>'othertbl',   indexes=>$othertbl_idx);
   
   my $rows = $dbh->selectall_arrayref("SELECT db,tbl,idx,usage_cnt FROM mk_iu.indexes ORDER BY db,tbl,idx");
   is_deeply(
      $rows,
      [
         ['sakila', 'actor', 'idx_actor_last_name',  '0'],
         ['sakila','actor','PRIMARY','0'],
         ['sakila','film','PRIMARY','0'],
         ['sakila','film_actor','idx_fk_film_id','0'],
         ['sakila','film_actor','PRIMARY','0'],
         ['sakila','othertbl','PRIMARY','0'],
      ],
      "Add indexes to results"
   );

   $rows = $dbh->selectall_arrayref("SELECT db,tbl,usage_cnt FROM mk_iu.tables ORDER BY db,tbl");
   is_deeply(
      $rows,
      [
         [qw(sakila actor      0)],
         [qw(sakila film       0)],
         [qw(sakila film_actor 0)],
         [qw(sakila othertbl   0)],
      ],
      "Add tables to results"
   );

   $iu->add_table_usage(qw(sakila      actor));
   $iu->add_table_usage(qw(sakila film_actor));
   $iu->add_table_usage(qw(sakila   othertbl));    # But not sakila.film!
   
   $rows = $dbh->selectall_arrayref("SELECT db,tbl,usage_cnt FROM mk_iu.tables ORDER BY db,tbl");
   is_deeply(
      $rows,
      [
         [qw(sakila actor      1)],
         [qw(sakila film       0)],
         [qw(sakila film_actor 1)],
         [qw(sakila othertbl   1)],
      ],
      "Update table usage in results"
   );

   my $query    = "select * from sakila.film_actor a left join sakila.actor b using (id)";
   my $checksum = $iu->add_query($query);
   $iu->add_index_usage(
      checksum => $checksum,
      usage    => [
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

   $rows = $dbh->selectall_arrayref("SELECT db,tbl,idx,usage_cnt FROM mk_iu.indexes ORDER BY db,tbl,idx");
   is_deeply(
      $rows,
      [
         [qw(sakila actor      idx_actor_last_name         0)],
         [qw(sakila actor      PRIMARY                     1)],
         [qw(sakila film       PRIMARY                     0)],
         [qw(sakila film_actor idx_fk_film_id              1)],
         [qw(sakila film_actor PRIMARY                     1)],
         [qw(sakila othertbl   PRIMARY                     0)],
      ],
      "Updates index usage in results"
   );

   $rows = $dbh->selectall_arrayref("select db,tbl,idx,fingerprint from mk_iu.index_usage left join mk_iu.queries using (checksum) order by db,tbl,idx");
   is_deeply(
      $rows,
      [
         [qw(sakila actor PRIMARY), $query],
         [qw(sakila film_actor idx_fk_film_id), $query],
         [qw(sakila film_actor PRIMARY), $query],
      ],
      "Updates query-index usage in results"
   );

   @unused = ();
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
      'Unused indexes for sakila.actor and film_actor',
   );

   $sb->wipe_clean($dbh);
}

# #############################################################################
# Done.
# #############################################################################
exit;
