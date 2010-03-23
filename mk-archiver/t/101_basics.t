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

my $dp  = new DSNParser(opts=>$dsn_opts);
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

my @args = qw(--dry-run --where 1=1);

# ###########################################################################
# These are dry-run tests of various options to test that the correct
# SQL statements are generated.
# ###########################################################################

# Test --for-update
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--for-update --purge)) });
like($output, qr/SELECT .*? FOR UPDATE/, '--for-update');

# Test --share-lock
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--share-lock --purge)) });
like($output, qr/SELECT .*? LOCK IN SHARE MODE/, '--share-lock');

# Test --quick-delete
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--quick-delete --purge)) });
like($output, qr/DELETE QUICK/, '--quick-delete');

# Test --low-priority-delete
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--low-priority-delete --purge)) });
like($output, qr/DELETE LOW_PRIORITY/, '--low-priority-delete');

# Test --low-priority-insert
$output = output(sub {mk_archiver::main(@args, qw(--dest t=table_2), '--source', "D=test,t=table_1,F=$cnf", qw(--low-priority-insert)) });
like($output, qr/INSERT LOW_PRIORITY/, '--low-priority-insert');

# Test --delayed-insert
$output = output(sub {mk_archiver::main(@args, qw(--dest t=table_2), '--source', "D=test,t=table_1,F=$cnf", qw(--delayed-insert)) });
like($output, qr/INSERT DELAYED/, '--delay-insert');

# Test --replace
$output = output(sub {mk_archiver::main(@args, qw(--dest t=table_2), '--source', "D=test,t=table_1,F=$cnf", qw(--replace)) });
like($output, qr/REPLACE/, '--replace');

# Test --high-priority-select
$output = output(sub {mk_archiver::main(@args, qw(--high-priority-select --dest t=table_2 --source), "D=test,t=table_1,F=$cnf", qw(--replace)) });
like($output, qr/SELECT HIGH_PRIORITY/, '--high-priority-select');

# Test --columns
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", '--columns', 'a,b', qw(--purge)) });
like($output, qr{SELECT /\*!40001 SQL_NO_CACHE \*/ `a`,`b` FROM}, 'Only got specified columns');

# Test --primary-key-only
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--primary-key-only --purge)) });
like($output, qr{SELECT /\*!40001 SQL_NO_CACHE \*/ `a` FROM}, '--primary-key-only works');

# Test that tables must have same columns
$output = output(sub {mk_archiver::main(@args, qw(--dest t=table_4 --source), "D=test,t=table_1,F=$cnf", qw(--purge)) }, undef, stderr=>1, dont_die=>1);
like($output, qr/The following columns exist in --source /, 'Column check throws error');
$output = output(sub {mk_archiver::main(@args, qw(--no-check-columns --dest t=table_4 --source), "D=test,t=table_1,F=$cnf", qw(--purge)) });
like($output, qr/SELECT/, 'I can disable the check OK');

# ###########################################################################
# These are online tests that check various options.
# ###########################################################################

shift @args;  # remove --dry-run

# Test --why-quit and --statistics output
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--purge --why-quit --statistics)) });
like($output, qr/Started at \d/, 'Start timestamp');
like($output, qr/Source:/, 'source');
like($output, qr/SELECT 4\nINSERT 0\nDELETE 4\n/, 'row counts');
like($output, qr/Exiting because there are no more rows/, 'Exit reason');

# Test basic functionality with OPTIMIZE
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = output(sub {mk_archiver::main(@args, qw(--optimize ds --source), "D=test,t=table_1,F=$cnf", qw(--purge)) });
is($output, '', 'OPTIMIZE did not fail');

# Test an empty table
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `mysql --defaults-file=$cnf -N -e "delete from test.table_1"`;
$output = output(sub {mk_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--purge)) });
is($output, "", 'Empty table OK');

# Test the output
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$trunk/mk-archiver/mk-archiver --where 1=1 --source D=test,t=table_1,F=$cnf --purge --progress 2 2>&1 | awk '{print \$3}'`;
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
$output = output(sub {mk_archiver::main(@args, qw(--statistics --source), "D=test,t=table_1,F=$cnf", qw(--dest t=table_2)) });
like($output, qr/commit *10/, 'Stats print OK');

# Test --no-delete.
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = output(sub {mk_archiver::main(@args, qw(--no-delete --purge --source), "D=test,t=table_1,F=$cnf", qw(--dry-run)) });
like($output, qr/> /, '--no-delete implies strict ascending');
unlike($output, qr/>=/, '--no-delete implies strict ascending');
$output = output(sub {mk_archiver::main(@args, qw(--no-delete --purge --source), "D=test,t=table_1,F=$cnf") });
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_1"`;
is($output + 0, 4, 'All 4 rows are still there');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
