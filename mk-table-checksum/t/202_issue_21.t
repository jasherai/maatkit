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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser();
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
      plan tests => 5;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $ret_val;
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# #############################################################################
# Issue 21: --empty-replicate-table doesn't empty if previous runs leave info
# #############################################################################

# This test requires that the test db has only the table created by
# issue_21.sql. If there are other tables, the first test below
# will fail because samples/basic_replicate_output will differ.
$sb->wipe_clean($master_dbh);
$sb->create_dbs($master_dbh, ['test']);

$sb->load_file('master', 'mk-table-checksum/t/samples/checksum_tbl.sql');
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_21.sql');

# Run --replication once to populate test.checksum
$cmd = 'perl ../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox -d test --replicate test.checksum | diff ./samples/basic_replicate_output -';
$ret_val = system($cmd);
# Might as well test this while we're at it
cmp_ok($ret_val >> 8, '==', 0, 'Basic --replicate works');

# Insert a bogus row into test.checksum
my $repl_row = "INSERT INTO test.checksum VALUES ('foo', 'bar', 0, 'a', 'b', 0, 'c', 0,  NOW())";
diag(`/tmp/12345/use -e "$repl_row"`);
# Run --replicate again which should completely clear test.checksum,
# including our bogus row
`perl ../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox --replicate test.checksum -d test --empty-replicate-table 2>&1 > /dev/null`;
# Make sure bogus row is actually gone
$cmd = "/tmp/12345/use -e \"SELECT db FROM test.checksum WHERE db = 'foo';\"";
$output = `$cmd`;
unlike($output, qr/foo/, '--empty-replicate-table completely empties the table (fixes issue 21)');

# While we're at it, let's test what the doc says about --empty-replicate-table:
# "Ignored if L<"--replicate"> is not specified."
$repl_row = "INSERT INTO test.checksum VALUES ('foo', 'bar', 0, 'a', 'b', 0, 'c', 0,  NOW())";
diag(`/tmp/12345/use -e "$repl_row"`);
`perl ../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox P=12346 --empty-replicate-table 2>&1 > /dev/null`;
# Now make sure bogus row is still present
$cmd = "/tmp/12345/use -e \"SELECT db FROM test.checksum WHERE db = 'foo';\"";
$output = `$cmd`;
like($output, qr/foo/, '--empty-replicate-table is ignored if --replicate is not specified');
diag(`/tmp/12345/use -D test -e "DELETE FROM checksum WHERE db = 'foo'"`);

# Screw up the data on the slave and make sure --replicate-check works
$slave_dbh->do("update test.checksum set this_crc='' where test.checksum.tbl = 'issue_21'");
$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox -d test --replicate test.checksum --replicate-check 1 2>&1`;
like($output, qr/issue_21/, '--replicate-check works');
cmp_ok($CHILD_ERROR>>8, '==', 1, 'Exit status is correct with --replicate-check failure');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
