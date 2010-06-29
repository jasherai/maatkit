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
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 6;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

$sb->create_dbs($dbh, ['test']);
diag(`rm -rf $basedir`);

# #############################################################################
# Issue 30: Add resume functionality to mk-parallel-restore
# #############################################################################
$sb->load_file('master', 'mk-parallel-restore/t/samples/issue_30.sql');

`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25 --no-gzip --no-zero-chunk`;
# The above makes the following chunks:
#
# #   WHERE                         SIZE  FILE
# -----------------------------------------------------------
# 0:  `id` < 254                    790   issue_30.000000.sql
# 1:  `id` >= 254 AND `id` < 502    619   issue_30.000001.sql
# 2:  `id` >= 502 AND `id` < 750    661   issue_30.000002.sql
# 3:  `id` >= 750                   601   issue_30.000003.sql


# Now we fake like a resume operation died on an edge case:
# after restoring the first row of chunk 2. We should resume
# from chunk 1 to be sure that all of 2 is restored.
my $done_size = (-s "$basedir/test/issue_30.000000.sql")
              + (-s "$basedir/test/issue_30.000001.sql");
`$mysql -D test -e 'DELETE FROM issue_30 WHERE id > 502'`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test $basedir/test/ 2>&1 | grep 'Resuming'`;
like(
   $output,
   qr/Resuming restore of `test`.`issue_30` from chunk 2 with $done_size bytes/,
   'Reports non-atomic resume from chunk 2 (issue 30)'
);

$output = 'foo';
$output = `$mysql -e 'SELECT * FROM test.issue_30' | diff $trunk/mk-parallel-restore/t/samples/issue_30_all_rows.txt -`;
ok(
   !$output,
   'Resume restored all 100 rows exactly (issue 30)'
);

# Now re-do the operation with atomic-resume.  Since chunk 2 has a row,
# id = 502, it will be considered fully restored and the resume will start
# from chunk 3.  Chunk 2 will be left in a partial state.  This is why
# atomic-resume should not be used with non-transactionally-safe tables.
$done_size += (-s "$basedir/test/issue_30.000002.sql");
`$mysql -D test -e 'DELETE FROM issue_30 WHERE id > 502'`;
$output = `MKDEBUG=1 $cmd -D test $basedir/test/ 2>&1 | grep 'Resuming'`;
like(
   $output,
   qr/Resuming restore of `test`.`issue_30` from chunk 3 with $done_size bytes/,
   'Reports atomic resume from chunk 3 (issue 30)'
);

$output = 'foo';
$output = `$mysql -e 'SELECT * FROM test.issue_30' | diff $trunk/mk-parallel-restore/t/samples/issue_30_partial_chunk_2.txt -`;
ok(
   !$output,
   'Resume restored atomic chunks (issue 30)'
);

`rm -rf $basedir`;

# Test that resume doesn't do anything on a tab dump because there's
# no chunks file
`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --tab --no-gzip --no-zero-chunk`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test --local --tab $basedir/test/ 2>&1`;
like($output, qr/Cannot resume restore: no chunks file/, 'Does not resume --tab dump (issue 30)');

`rm -rf $basedir/`;

# Test that resume doesn't do anything on non-chunked dump because
# there's only 1 chunk: where 1=1
`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 10000 --no-gzip --no-zero-chunk`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test $basedir/test/ 2>&1`;
like(
   $output,
   qr/Cannot resume restore: only 1 chunk \(1=1\)/,
   'Does not resume single chunk where 1=1 (issue 30)'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
