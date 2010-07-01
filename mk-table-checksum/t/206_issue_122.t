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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf 127.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_122.sql');

# #############################################################################
# Issue 122: mk-table-checksum doesn't --save-since correctly on empty tables
# #############################################################################

`$cmd --arg-table test.argtable --save-since -t test.issue_122 --chunk-size 2`;
is_deeply(
   $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'"),
   [[undef]],
   'Numeric since is not saved when table is empty'
);

$master_dbh->do("INSERT INTO test.issue_122 VALUES (null,'a'),(null,'b')");
`$cmd --arg-table test.argtable --save-since -t test.issue_122 --chunk-size 2`;
is_deeply(
   $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'"),
   [[2]],
   'Numeric since is saved when table is not empty'
);

# Test non-empty table that is chunkable with a temporal --since and
# --save-since to make sure that the current ts gets saved and not the maxval.
$master_dbh->do('UPDATE test.argtable SET since = "current_date - interval 3 day" WHERE db = "test" AND tbl = "issue_122"');
`$cmd --arg-table test.argtable --save-since -t test.issue_122 --chunk-size 2`;
$output = $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'")->[0]->[0];
like(
   $output,
   qr/^\d{4}-\d{2}-\d{2}(?:.[0-9:]+)?/,
   'Temporal since is saved when temporal since is given'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
