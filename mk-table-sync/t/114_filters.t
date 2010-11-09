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
use Sandbox;
require "$trunk/mk-table-sync/mk-table-sync";


my $vp = new VersionParser();
my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 4;
}

my $output;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-table-sync/mk-table-sync -F $cnf"; 

$sb->wipe_clean($master_dbh);
$sb->load_file('master', 'mk-table-sync/t/samples/filter_tables.sql');

$output = `$cmd h=127.1,P=12345 P=12346 --no-check-slave --dry-run -t issue_806_1.t2 | tail -n 2`;
is(
   $output,
"# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
#      0       0      0      0 Chunk     0    issue_806_1.t2
",
   "db-qualified --tables (issue 806)"
);

# #############################################################################
# Issue 820: Make mk-table-sync honor schema filters with --replicate
# #############################################################################
$master_dbh->do('DROP DATABASE IF EXISTS test');
$master_dbh->do('CREATE DATABASE test');
$sb->load_file('master', 'mk-table-sync/t/samples/checksum_tbl.sql', 'test');

$slave_dbh->do('insert into issue_806_1.t1 values (41)');
$slave_dbh->do('insert into issue_806_2.t2 values (42)');

my $mk_table_checksum = "$trunk/mk-table-checksum/mk-table-checksum";

`$mk_table_checksum -F $cnf --replicate test.checksum h=127.1,P=12345 -d issue_806_1,issue_806_2 --quiet`;
`$mk_table_checksum -F $cnf --replicate test.checksum h=127.1,P=12345 -d issue_806_1,issue_806_2 --replicate-check 1 --quiet`;

$output = `$cmd h=127.1,P=12345 --replicate test.checksum --dry-run | tail -n 2`;
is(
   $output,
"#      0       0      0      0 Chunk     0    issue_806_2.t2
#      0       0      0      0 Chunk     0    issue_806_1.t1
",
   "--replicate with no filters"
);

$output = `$cmd h=127.1,P=12345 --replicate test.checksum --dry-run -t t1 | tail -n 2`;
is(
   $output,
"# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
#      0       0      0      0 Chunk     0    issue_806_1.t1
",
   "--replicate with --tables"
);

$output = `$cmd h=127.1,P=12345 --replicate test.checksum --dry-run -d issue_806_2 | tail -n 2`;
is(
   $output,
"# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
#      0       0      0      0 Chunk     0    issue_806_2.t2
",
   "--replicate with --databases"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
