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

my $dp = new DSNParser(opts=>$dsn_opts);
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
   plan tests => 10;
}

$sb->load_file('master', 'mk-upgrade/t/samples/001/tables.sql');
$sb->load_file('slave2', 'mk-upgrade/t/samples/001/tables.sql');

my $cmd    = "$trunk/mk-upgrade/mk-upgrade h=127.1,P=12345,u=msandbox,p=msandbox P=12347 --compare results,warnings --zero-query-times";
my @args   = ('--compare', 'results,warnings', '--zero-query-times');
my $sample = "$trunk/mk-upgrade/t/samples/";

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
# Issue 951: mk-upgrade "I need a db argument" error with
# compare-results-method=rows
# #############################################################################
$sb->load_file('master', 'mk-upgrade/t/samples/002/tables.sql');
$sb->load_file('slave2', 'mk-upgrade/t/samples/002/tables.sql');

# Make a difference so diff_rows() is called.
$dbh1->do('insert into test.t values (5)');

ok(
   no_diff(
      sub { mk_upgrade::main(@args,
         'h=127.1,P=12345,u=msandbox,p=msandbox,D=test', 'P=12347,D=test',
         "$sample/002/no-db.log",
         qw(--compare-results-method rows --temp-database test)) },
      'mk-upgrade/t/samples/002/report-01.txt',
   ),
   'No db, compare results row, DSN D, --temp-database (issue 951)'
);

$sb->load_file('master', 'mk-upgrade/t/samples/002/tables.sql');
$sb->load_file('slave2', 'mk-upgrade/t/samples/002/tables.sql');
$dbh1->do('insert into test.t values (5)');

ok(
   no_diff(
      sub { mk_upgrade::main(@args,
         'h=127.1,P=12345,u=msandbox,p=msandbox,D=test', 'P=12347,D=test',
         "$sample/002/no-db.log",
         qw(--compare-results-method rows --temp-database tmp_db)) },
      'mk-upgrade/t/samples/002/report-01.txt',
   ),
   'No db, compare results row, DSN D'
);

is_deeply(
   $dbh1->selectall_arrayref('show tables from `test`'),
   [['t']],
   "Didn't create temp table in event's db"
);

is_deeply(
   $dbh1->selectall_arrayref('show tables from `tmp_db`'),
   [['mk_upgrade_left']],
   "Createed temp table in --temp-database"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
