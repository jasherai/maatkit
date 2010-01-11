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
      plan tests => 2;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# #############################################################################
# Issue 69: mk-table-checksum should be able to re-checksum things that differ
# #############################################################################

$sb->load_file('master', 'mk-table-checksum/t/samples/checksum_tbl.sql');
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_21.sql');
 `../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox -d test --replicate test.checksum`;

$slave_dbh->do("update test.checksum set this_crc='' where test.checksum.tbl = 'issue_21'");
$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox -d test --replicate test.checksum --replicate-check 1 2>&1`;

# This test relies on the previous test which checked that --replicate-check works
# and left an inconsistent checksum on columns_priv.
$output = `../mk-table-checksum h=127.1,P=12345,u=msandbox,p=msandbox -d test --replicate test.checksum --replicate-check 1 --recheck | diff samples/issue_69.txt -`;
ok(!$output, '--recheck reports inconsistent table like --replicate');

# Now check that --recheck actually caused the inconsistent table to be
# re-checksummed on the master.
$output = 'foo';
$output = `../mk-table-checksum h=127.1,P=12345,u=msandbox,p=msandbox --replicate test.checksum --replicate-check 1`;
ok(!$output, '--recheck re-checksummed inconsistent table; it is now consistent');

$master_dbh->do('DROP TABLE test.issue_21');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
