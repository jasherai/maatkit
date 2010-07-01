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
require "$trunk/mk-archiver/mk-archiver";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 13;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->create_dbs($dbh, ['test']);

# Test --bulk-delete deletes in chunks
$sb->load_file('master', 'mk-archiver/t/samples/table5.sql');
$output = `perl -I $trunk/mk-archiver/t/samples $cmd --plugin Plugin7 --no-ascend --limit 50 --bulk-delete --purge --where 1=1 --source D=test,t=table_5,F=$cnf --statistics 2>&1`;
like($output, qr/SELECT 105/, 'Fetched 105 rows');
like($output, qr/DELETE 105/, 'Deleted 105 rows');
like($output, qr/bulk_deleting *3 /, 'Issued only 3 DELETE statements');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_5"`;
is($output + 0, 0, 'Bulk delete removed all rows');

# Test that the generic plugin worked OK
$output = `mysql --defaults-file=$cnf -N -e "select a from test.stat_test"`;
is($output + 0, 105, 'Generic plugin worked');

# Test --bulk-delete jails the WHERE safely in parens.
$output = `$cmd --dry-run --no-ascend --limit 50 --bulk-delete --purge --where 1=1 --source D=test,t=table_5,F=$cnf --statistics 2>&1`;
like($output, qr/\(1=1\)/, 'WHERE clause is jailed');
unlike($output, qr/[^(]1=1/, 'WHERE clause is jailed');

# Test --bulk-delete works ok with a destination table
$sb->load_file('master', 'mk-archiver/t/samples/table5.sql');
$output = `$cmd --no-ascend --limit 50 --bulk-delete --where 1=1 --source D=test,t=table_5,F=$cnf --statistics --dest t=table_5_dest 2>&1`;
like($output, qr/SELECT 105/, 'Fetched 105 rows');
like($output, qr/DELETE 105/, 'Deleted 105 rows');
like($output, qr/INSERT 105/, 'Inserted 105 rows');
like($output, qr/bulk_deleting *3 /, 'Issued only 3 DELETE statements');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_5"`;
is($output + 0, 0, 'Bulk delete removed all rows');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_5_dest"`;
is($output + 0, 105, 'Bulk delete works OK with normal insert');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
