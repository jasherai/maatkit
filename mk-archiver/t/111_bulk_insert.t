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
   plan tests => 7;
}

my $output;
my $rows;
my $cnf = "/tmp/12345/my.sandbox.cnf";
my $cmd = "$trunk/mk-archiver/mk-archiver";

$sb->wipe_clean($dbh);
$sb->create_dbs($dbh, ['test']);

# Test --bulk-insert
$sb->load_file('master', 'mk-archiver/t/samples/table5.sql');
$dbh->do('INSERT INTO `test`.`table_5_copy` SELECT * FROM `test`.`table_5`');

$output = `$cmd --no-ascend --limit 50 --bulk-insert --bulk-delete --where 1=1 --source D=test,t=table_5,F=$cnf --statistics --dest t=table_5_dest 2>&1`;
like($output, qr/SELECT 105/, 'Fetched 105 rows');
like($output, qr/DELETE 105/, 'Deleted 105 rows');
like($output, qr/INSERT 105/, 'Inserted 105 rows');
like($output, qr/bulk_deleting *3 /, 'Issued only 3 DELETE statements');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_5"`;
is($output + 0, 0, 'Bulk delete removed all rows');
$output = `mysql --defaults-file=$cnf -N -e "select count(*) from test.table_5_dest"`;
is($output + 0, 105, 'Bulk insert works');

# Check that the destination table has the same data as the source
$output = `mysql --defaults-file=$cnf -N -e "checksum table test.table_5_dest, test.table_5_copy"`;
my ( $chks ) = $output =~ m/dest\s+(\d+)/;
like($output, qr/copy\s+$chks/, 'copy checksum');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
