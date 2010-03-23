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
else {
   plan tests => 17;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->wipe_clean($dbh);
$sb->create_dbs($dbh, ['test']);

# Test ascending index; it should ascend the primary key
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --dry-run --where 1=1 --source D=test,t=table_3,F=$cnf --purge 2>&1`;
like($output, qr/FORCE INDEX\(`PRIMARY`\)/, 'Uses PRIMARY index');
$output = `$cmd --where 1=1 --source D=test,t=table_3,F=$cnf --purge 2>&1`;
is($output, '', 'Does not die with ascending index');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended key OK');

# Test specifying a wrong index.
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --where 1=1 --source i=foo,D=test,t=table_3,F=$cnf --purge 2>&1`;
like($output, qr/Index 'foo' does not exist in table/, 'Got bad-index error OK');

# Test specifying a NULLable index.
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --where 1=1 --source i=b,D=test,t=table_1,F=$cnf --purge 2>&1`;
is($output, "", 'Got no error with a NULLable index');

# Test table without a primary key
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --where 1=1 --source D=test,t=table_4,F=$cnf --purge 2>&1`;
like($output, qr/Cannot find an ascendable index/, 'Got need-PK-error OK');

# Test ascending index explicitly
$sb->load_file('master', 'mk-archiver/t/samples/tables1-4.sql');
$output = `$cmd --where 1=1 --source D=test,t=table_3,F=$cnf,i=PRIMARY --purge 2>&1`;
is($output, '', 'No output for ascending index explicitly');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_3"`;
is($output + 0, 0, 'Ascended explicit key OK');

# Test that mk-archiver gets column ordinals and such right when building the
# ascending-index queries.
$sb->load_file('master', 'mk-archiver/t/samples/table11.sql');
$output = `$cmd --limit 2 --where 1=1 --source D=test,t=table_11,F=$cnf --purge 2>&1`;
is($output, '', 'No output while dealing with out-of-order PK');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_11"`;
is($output + 0, 0, 'Ascended out-of-order PK OK');

#####################
# Test that ascending index check WHERE clause can't be hijacked
$sb->load_file('master', 'mk-archiver/t/samples/table6.sql');
$output = `$cmd --source D=test,t=table_6,F=$cnf --purge --limit 2 --where 'c=1'`;
is($output, '', 'No errors purging table_6');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_6"`;
is($output + 0, 1, 'Did not purge last row');

# Test that ascending index check doesn't leave any holes
$sb->load_file('master', 'mk-archiver/t/samples/table5.sql');
$output = `$cmd --source D=test,t=table_5,F=$cnf --purge --limit 50 --where 'a<current_date - interval 1 day' 2>&1`;
is($output, '', 'No errors in larger table');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_5"`;
is($output + 0, 0, 'Purged completely on multi-column ascending index');

# Make sure ascending index check can be disabled
$output = `$cmd --where 1=1 --dry-run --no-ascend --source D=test,t=table_5,F=$cnf --purge --limit 50 2>&1`;
like ( $output, qr/(^SELECT .*$)\n\1/m, '--no-ascend makes fetch-first and fetch-next identical' );
$sb->load_file('master', 'mk-archiver/t/samples/table5.sql');
$output = `$cmd --where 1=1 --no-ascend --source D=test,t=table_5,F=$cnf --purge --limit 1 2>&1`;
is($output, '', "No output when --no-ascend");

# Check ascending only first column
$output = `$cmd --where 1=1 --dry-run --ascend-first --source D=test,t=table_5,F=$cnf --purge --limit 50 2>&1`;
like ( $output, qr/WHERE \(1=1\) AND \(\(`a` >= \?\)\) LIMIT/, 'Can ascend just first column');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
