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
# Issue 122: mk-table-checksum doesn't --save-since correctly on empty tables
# #############################################################################

$sb->load_file('master', 'mk-table-checksum/t/samples/issue_122.sql');
$output = `../mk-table-checksum --arg-table test.argtable --save-since h=127.1,P=12345,u=msandbox,p=msandbox -t test.issue_122 --chunk-size 2`;
my $res = $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'");
is_deeply($res, [[undef]], 'Numeric since is not saved when table is empty');

$master_dbh->do("INSERT INTO test.issue_122 VALUES (null,'a'),(null,'b')");
$output = `../mk-table-checksum --arg-table test.argtable --save-since h=127.1,P=12345,u=msandbox,p=msandbox -t test.issue_122 --chunk-size 2`;
$res = $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'");
is_deeply($res, [[2]], 'Numeric since is saved when table is not empty');

# Test non-empty table that is chunkable with a temporal --since and
# --save-since to make sure that the current ts gets saved and not the maxval.
$master_dbh->do('UPDATE test.argtable SET since = "current_date - interval 3 day" WHERE db = "test" AND tbl = "issue_122"');
$output = `../mk-table-checksum --arg-table test.argtable --save-since h=127.1,P=12345,u=msandbox,p=msandbox -t test.issue_122 --chunk-size 2`;
$res = $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'");
like($res->[0]->[0], qr/^\d{4}-\d{2}-\d{2}(?:.[0-9:]+)?/, 'Temporal since is saved when temporal since is given');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
