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
require "$trunk/mk-upgrade/mk-upgrade";

# This runs immediately if the server is already running, else it starts it.
diag(`$trunk/sandbox/start-sandbox master 12347 >/dev/null`);

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master');
my $dbh2 = $sb->get_dbh_for('slave2');

if ( !$dbh1 ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$dbh2 ) {
   plan skip_all => 'Cannot connect to second sandbox master';
}
else {
   plan tests => 6;
}

$sb->load_file('master', 'mk-upgrade/t/samples/001/tables.sql');
$sb->load_file('slave2', 'mk-upgrade/t/samples/001/tables.sql');

my $cmd = "$trunk/mk-upgrade/mk-upgrade h=127.1,P=12345,u=msandbox,p=msandbox P=12347 --compare results,warnings --zero-query-times";

ok(
   no_diff(
      "$cmd $trunk/mk-upgrade/t/samples/001/select-one.log",
      'mk-upgrade/t/samples/001/select-one.txt'
   ),
   'Report for a single query (checksum method)'
);

ok(
   no_diff(
      "$cmd $trunk/mk-upgrade/t/samples/001/select-everyone.log",
      'mk-upgrade/t/samples/001/select-everyone.txt'
   ),
   'Report for multiple queries (checksum method)'
);

ok(
   no_diff(
      "$cmd $trunk/mk-upgrade/t/samples/001/select-one.log --compare-results-method rows",
      'mk-upgrade/t/samples/001/select-one-rows.txt'
   ),
   'Report for a single query (rows method)'
);

ok(
   no_diff(
      "$cmd $trunk/mk-upgrade/t/samples/001/select-everyone.log --compare-results-method rows",
      'mk-upgrade/t/samples/001/select-everyone-rows.txt'
   ),
   'Report for multiple queries (rows method)'
);

ok(
   no_diff(
      "$cmd --reports queries,differences,errors $trunk/mk-upgrade/t/samples/001/select-everyone.log",
      'mk-upgrade/t/samples/001/select-everyone-no-stats.txt'
   ),
   'Report without statistics'
);

ok(
   no_diff(
      "$cmd --reports differences,errors,statistics $trunk/mk-upgrade/t/samples/001/select-everyone.log",
      'mk-upgrade/t/samples/001/select-everyone-no-queries.txt'
   ),
   'Report without per-query reports'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
