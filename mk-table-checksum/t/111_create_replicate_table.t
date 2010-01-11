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
$sb->load_file('master', 'mk-table-checksum/t/samples/checksum_tbl.sql');

# #############################################################################
# Issue 77: mk-table-checksum should be able to create the --replicate table
# #############################################################################

# First check that, like a Klingon, it dies with honor.
`/tmp/12345/use -e 'DROP TABLE test.checksum'`;
$output = `../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox --replicate test.checksum 2>&1`;
like($output, qr/replicate table .+ does not exist/, 'Dies with honor when replication table does not exist');

$output = `../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox --ignore-databases sakila --replicate test.checksum --create-replicate-table`;
like($output, qr/DATABASE\s+TABLE\s+CHUNK/, '--create-replicate-table creates the replicate table');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
