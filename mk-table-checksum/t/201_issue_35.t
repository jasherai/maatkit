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
   plan tests => 3;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# #############################################################################
# Issue 35: mk-table-checksum dies when one server is missing a table
# #############################################################################

# This var is used later in another test.
my $create_missing_slave_tbl_cmd
   = "/tmp/12345/use -D mysql -e 'SET SQL_LOG_BIN=0;CREATE TABLE test.only_on_master(a int);'";
diag(`$create_missing_slave_tbl_cmd`);

$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345,u=msandbox,p=msandbox P=12346 -t test.only_on_master 2>&1`;
like($output, qr/MyISAM\s+NULL\s+0/, 'Table on master checksummed');
like($output, qr/MyISAM\s+NULL\s+NULL/, 'Missing table on slave checksummed');
like(
   $output,
   qr/test\.only_on_master does not exist on slave 127.0.0.1:12346/,
   'Warns about missing slave table'
);

# This var is used later in another test.
my $rm_missing_slave_tbl_cmd
   = "/tmp/12345/use -D mysql -e 'SET SQL_LOG_BIN=0;DROP TABLE test.only_on_master;'";
diag(`$rm_missing_slave_tbl_cmd`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
