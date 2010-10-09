#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
# See http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-index-usage/mk-index-usage";

use Sandbox;
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
if ( !@{ $dbh->selectall_arrayref('show databases like "sakila"') } ) {
   plan skip_all => "Sakila database is not loaded";
}
else {
   plan tests => 12;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my @args    = ('-F', $cnf, '--save-results-database', 'D=mk');
my $samples = "mk-index-usage/t/samples/";
my $output;

$sb->wipe_clean($dbh);

mk_index_usage::main(@args, "$trunk/common/t/samples/empty",
   qw(--empty-save-results --create-save-results-database --no-report),
   '-t', 'sakila.actor,sakila.address');

$dbh->do("use mk");

my $rows = $dbh->selectcol_arrayref("show databases");
my $ok   = grep { $_ eq "mk" } @$rows;
ok(
   $ok,
   "--create-save-results-databse"
);

$rows = $dbh->selectcol_arrayref("show tables from `mk`");
is_deeply(
   $rows,
   [qw(index_alternatives index_usage indexes queries tables)],
   "Create tables"
);

$rows = $dbh->selectall_arrayref("select * from mk.tables order by db, tbl");
is_deeply(
   $rows,
   [
      [qw( sakila actor         0 )],
      [qw( sakila address       0 )],
   ],
   "Populate tables table (filtered)"
);


$rows = $dbh->selectall_arrayref("select * from mk.indexes order by db, tbl");
is_deeply(
   $rows,
   [
      [qw(sakila  actor   idx_actor_last_name 0)],
      [qw(sakila  actor   PRIMARY             0)],
      [qw(sakila  address idx_fk_city_id      0)],
      [qw(sakila  address PRIMARY             0)],
   ],
   "Populate indexes table (filtered)"
);

$rows = $dbh->selectall_arrayref("select * from mk.queries");
is_deeply(
   $rows,
   [],
   "No queries yet"
);

$rows = $dbh->selectall_arrayref("select * from mk.index_usage");
is_deeply(
   $rows,
   [],
   "No index usage counts yet"
);

$rows = $dbh->selectall_arrayref("select * from mk.index_alternatives");
is_deeply(
   $rows,
   [],
   "No index alternatives yet"
);

# Now for the real test.
mk_index_usage::main(@args, "$trunk/mk-index-usage/t/samples/slow007.txt",
   qw(--empty-save-results --no-report), '-t', 'sakila.actor,sakila.address');

$rows = $dbh->selectall_arrayref("select * from mk.tables order by db, tbl");
is_deeply(
   $rows,
   [
      [qw( sakila actor         4 )],
      [qw( sakila address       0 )],
   ],
   "Table access counts"
);

# EXPLAIN results differ a little between 5.0 and 5.1.  5.1 is smarter.
my $res = $sandbox_version ge '5.1' ?
   # v5.1 and newer
   [
      [qw(sakila  actor   idx_actor_last_name 1)],
      [qw(sakila  actor   PRIMARY             3)],
      [qw(sakila  address idx_fk_city_id      0)],
      [qw(sakila  address PRIMARY             0)],
   ]
   : # v5.0 and older
   [
      [qw(sakila  actor   idx_actor_last_name 2)],
      [qw(sakila  actor   PRIMARY             2)],
      [qw(sakila  address idx_fk_city_id      0)],
      [qw(sakila  address PRIMARY             0)],
   ];

$rows = $dbh->selectall_arrayref("select * from mk.indexes order by db, tbl");
is_deeply(
   $rows,
   $res,
   "Index usage counts"
);

$rows = $dbh->selectall_arrayref("select * from mk.queries order by query_id");
is_deeply(
   $rows,
   [
      [  4950186562421969363,
         "select * from sakila.actor where last_name like ?",
         "select * from sakila.actor where last_name like 'A%'",
      ],
      [  10334408417593890092,
         "select * from sakila.actor where last_name like ? order by actor_id",
         "select * from sakila.actor where last_name like 'A%' order by actor_id",
      ],
      [  10891801448710051322,
         "select * from sakila.actor where actor_id>?",
         "select * from sakila.actor where actor_id>10",
      ],
   ],
   "Queries added"
);

$rows = $dbh->selectall_arrayref("select query_id, db, tbl, idx, sample from index_usage iu left join queries q using (query_id) order by db, tbl, idx");
$res = $sandbox_version ge '5.1' ?
   # v5.1 and newer
   [
      [
         4950186562421969363,
         qw(sakila  actor  idx_actor_last_name),
         "select * from sakila.actor where last_name like 'A%'",
      ], 
      [
         10891801448710051322,
         qw(sakila  actor  PRIMARY),
         "select * from sakila.actor where actor_id>10",
      ],
      [
         10334408417593890092,
         qw(sakila  actor  PRIMARY),
         "select * from sakila.actor where last_name like 'A%' order by actor_id",
      ],
   ]
   :
   # v5.0 and older
   [
      [
         4950186562421969363,
         qw(sakila  actor  idx_actor_last_name),
         "select * from sakila.actor where last_name like 'A%'",
      ], 
      [
         10334408417593890092,
         qw(sakila  actor  idx_actor_last_name),
         "select * from sakila.actor where last_name like 'A%' order by actor_id",
      ],
      [
         10891801448710051322,
         qw(sakila  actor  PRIMARY),
         "select * from sakila.actor where actor_id>10",
      ],
   ];
is_deeply(
   $rows,
   $res,
   "Index usage",
);

$rows = $dbh->selectall_arrayref("select db,tbl,idx,alt_idx,sample from index_alternatives a left join queries q using (query_id)");
$res = $sandbox_version ge '5.1' ?
   [[qw(sakila actor PRIMARY idx_actor_last_name),
    "select * from sakila.actor where last_name like 'A%' order by actor_id"]]
   : [];
is_deeply(
   $rows,
   $res,
   "Index alternatives"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
