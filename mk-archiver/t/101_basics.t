#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-archiver/mk-archiver";

my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

# Make sure load works.
$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$rows = $dbh->selectrow_arrayref('select count(*) from test.table_1')->[0];
if ( ($rows || 0) != 4 ) {
   plan skip_all => 'Failed to load tables1-4.sql';
}
else {
   plan tests => 23;
}

# ###########################################################################
# These are dry-run tests of various options to test that the correct
# SQL statements are generated.
# ###########################################################################

# Test --for-update
$output = `$cmd --where 1=1 --dry-run --source D=test,t=table_1,F=$cnf --for-update --purge 2>&1`;
like($output, qr/SELECT .*? FOR UPDATE/, 'forupdate works');

# Test --share-lock
$output = `$cmd --where 1=1 --dry-run --source D=test,t=table_1,F=$cnf --share-lock --purge 2>&1`;
like($output, qr/SELECT .*? LOCK IN SHARE MODE/, 'sharelock works');

# Test --quick-delete
$output = `$cmd --where 1=1 --dry-run --source D=test,t=table_1,F=$cnf --quick-delete --purge 2>&1`;
like($output, qr/DELETE QUICK/, 'quickdel works');

# Test --low-priority-delete
$output = `$cmd --where 1=1 --dry-run --source D=test,t=table_1,F=$cnf --low-priority-delete --purge 2>&1`;
like($output, qr/DELETE LOW_PRIORITY/, 'lpdel works');

# Test --low-priority-insert
$output = `$cmd --where 1=1 --dry-run --dest t=table_2 --source D=test,t=table_1,F=$cnf --low-priority-insert 2>&1`;
like($output, qr/INSERT LOW_PRIORITY/, 'lpins works');

# Test --delayed-insert
$output = `$cmd --where 1=1 --dry-run --dest t=table_2 --source D=test,t=table_1,F=$cnf --delayed-insert 2>&1`;
like($output, qr/INSERT DELAYED/, 'delayedins works');

# Test --replace
$output = `$cmd --where 1=1 --dry-run --dest t=table_2 --source D=test,t=table_1,F=$cnf --replace 2>&1`;
like($output, qr/REPLACE/, 'replace works');

# Test --high-priority-select
$output = `$cmd --where 1=1 --high-priority-select --dry-run --dest t=table_2 --source D=test,t=table_1,F=$cnf --replace 2>&1`;
like($output, qr/SELECT HIGH_PRIORITY/, 'hpselect works');

# Test --columns
$output = `$cmd --where 1=1 --dry-run --source D=test,t=table_1,F=$cnf --columns=a,b --purge 2>&1`;
like($output, qr{SELECT /\*!40001 SQL_NO_CACHE \*/ `a`,`b` FROM}, 'Only got specified columns');

# Test --primary-key-only
$output = `$cmd --where 1=1 --dry-run --source D=test,t=table_1,F=$cnf --primary-key-only --purge 2>&1`;
like($output, qr{SELECT /\*!40001 SQL_NO_CACHE \*/ `a` FROM}, '--primary-key-only works');

# Test that tables must have same columns
$output = `$cmd --where 1=1 --dry-run --dest t=table_4 --source D=test,t=table_1,F=$cnf --purge 2>&1`;
like($output, qr/The following columns exist in --source /, 'Column check throws error');
$output = `$cmd --where 1=1 --dry-run --no-check-columns --dest t=table_4 --source D=test,t=table_1,F=$cnf --purge 2>&1`;
like($output, qr/SELECT/, 'I can disable the check OK');

# ###########################################################################
# These are online tests that check various options.
# ###########################################################################

# Test --why-quit and --statistics output
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --where 1=1 --source D=test,t=table_1,F=$cnf --purge --why-quit --statistics 2>&1`;
like($output, qr/Started at \d/, 'Start timestamp');
like($output, qr/Source:/, 'source');
like($output, qr/SELECT 4\nINSERT 0\nDELETE 4\n/, 'row counts');
like($output, qr/Exiting because there are no more rows/, 'Exit reason');

# Test basic functionality with OPTIMIZE
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --where 1=1 --optimize ds --source D=test,t=table_1,F=$cnf --purge 2>&1`;
is($output, '', 'OPTIMIZE did not fail');

# Test an empty table
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `mysql --defaults-file=$cnf -N -e "delete from test.table_1"`;
$output = `$cmd --where 1=1 --source D=test,t=table_1,F=$cnf --purge 2>&1`;
is($output, "", 'Empty table OK');

# Test the output
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --where 1=1 --source D=test,t=table_1,F=$cnf --purge --progress 2 2>&1 | awk '{print \$3}'`;
is($output, <<EOF
COUNT
0
2
4
4
EOF
,'Progress output looks okay');

# Statistics
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --statistics --where 1=1 --source D=test,t=table_1,F=$cnf --dest t=table_2 2>&1`;
like($output, qr/commit *10/, 'Stats print OK');

# Test --no-delete.
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --no-delete --purge --where 1=1 --source D=test,t=table_1,F=$cnf --dry-run 2>&1`;
like($output, qr/> /, '--no-delete implies strict ascending');
unlike($output, qr/>=/, '--no-delete implies strict ascending');
$output = `$cmd --no-delete --purge --where 1=1 --source D=test,t=table_1,F=$cnf 2>&1`;
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'All 4 rows are still there');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
