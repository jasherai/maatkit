#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 30;
use DBI;

my $output;
my $dbh;
(my $cnf=`realpath $0`) =~ s/mk-table-sync\.t.*$/cnf/s;

sub query {
   $dbh->selectall_arrayref(@_, {Slice => {}});
}

sub run {
   my ($src, $dst, $other) = @_;
   my $cmd = "perl ../mk-table-sync -px F=$cnf,D=test,t=$src t=$dst $other 2>&1";
   chomp(my $output=`$cmd`);
   return $output;
}

# Set up the sandbox (master-master pair)
print `./make_repl_sandbox`;

# Open a connection to MySQL, or skip the rest of the tests.
$dbh = DBI->connect(
   "DBI:mysql:;host=127.0.0.1;port=12345", 'msandbox', 'msandbox',
   { PrintError => 0, RaiseError => 1 });

`/tmp/12345/use < samples/before.sql`;

$output = run('test1', 'test2', '');
like($output, qr/Can't make changes/, 'It dislikes changing a slave');

$output = run('test1', 'test2', '--skipbinlog');

is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'No alg sync');

is_deeply(
   query('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with no alg'
);

`/tmp/12345/use < samples/before.sql`;

$output = run('test1', 'test2', '-a Stream --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Stream sync');

is_deeply(
   query('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Stream'
);

`/tmp/12345/use < samples/before.sql`;

$output = run('test1', 'test2', '-a GroupBy --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic GroupBy sync');

is_deeply(
   query('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with GroupBy'
);

`/tmp/12345/use < samples/before.sql`;

$output = run('test1', 'test2', '-a Chunk --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Chunk sync');

is_deeply(
   query('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Chunk'
);

`/tmp/12345/use < samples/before.sql`;

$output = run('test1', 'test2', '-a Nibble --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Nibble sync');

is_deeply(
   query('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Nibble'
);

`/tmp/12345/use < samples/before.sql`;

$ENV{MKDEBUG} = 1;
$output = run('test1', 'test2', '-a Nibble --skipbinlog --chunksize 1 --transaction -k 1');
delete $ENV{MKDEBUG};
like(
   $output,
   qr/Executing statement on source/,
   'Nibble with transactions and locking'
);

is_deeply(
   query('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Nibble'
);

# Sync tables that have values with leading zeroes
$ENV{MKDEBUG} = 1;
$output = run('test3', 'test4', '--print --skipbinlog --verbose -f MD5');
delete $ENV{MKDEBUG};
like(
   $output,
   qr/UPDATE `test`.`test4`.*51707/,
   'Found the first row',
);
like(
   $output,
   qr/UPDATE `test`.`test4`.*'001'/,
   'Found the second row',
);
like(
   $output,
   qr/2 Chunk *test.test3/,
   'Right number of rows to update',
);

# Sync a table with Nibble and a chunksize in data size, not number of rows
$output = run('test3', 'test4', '--algorithm Nibble --chunksize 1k --print --verbose -f MD5');
# If it lived, it's OK.
ok($output, 'Synced with Nibble and data-size chunksize');

# Ensure that syncing master-master works OK
`/tmp/12345/use < samples/before.sql`;
# Make slave different from master
`/tmp/12346/use -e 'set sql_log_bin=0;update test.test1 set b=2 where a = 1'`;
# This will make 12345's data match the changed data on 12346 (that is not a
# typo).
print `perl ../mk-table-sync --synctomaster -px F=$cnf,D=test,t=test1`;
is_deeply(query('select * from test.test1'),
   [
      { a => 1, b => 2 },
      { a => 2, b => 'ca' },
   ],
   'Master-master sync worked'
);

# Issue 37: mk-table-sync should warn about triggers
`/tmp/12345/use < samples/issue_37.sql`;
`/tmp/12345/use -e 'SET SQL_LOG_BIN=0; INSERT INTO test.issue_37 VALUES (1), (2);'`;
`/tmp/12345/use < samples/checksum_tbl.sql`;
`../../mk-table-checksum/mk-table-checksum h=127.0.0.1,P=12345 --replicate test.checksum 2>&1 > /dev/null`;


$output = `../mk-table-sync --skipslavecheck --execute u=msandbox,p=msandbox,h=127.0.0.1,P=12345,D=test,t=issue_37 h=127.1,P=12346 2>&1`;
like($output, qr/Cannot write to table with triggers/, 'Die on trigger tbl write with one table (1/4, issue 37)');
$output = `../mk-table-sync -R test.checksum --synctomaster --execute h=127.1,P=12346 2>&1`;
like($output, qr/Cannot write to table with triggers/, 'Die on trigger tbl write with --replicate --synctomaster (2/4, issue 37)');
$output = `../mk-table-sync -R test.checksum --execute h=127.1,P=12345 2>&1`;
like($output, qr/Cannot write to table with triggers/, 'Die on trigger tbl write with --replicate (3/4, issue 37)');
$output = `../mk-table-sync --execute -g mysql h=127.0.0.1,P=12345 h=127.1,P=12346 2>&1`;
like($output, qr/Cannot write to table with triggers/, 'Die on trigger tbl write with no opts (4/4, issue 37)');


$output = `/tmp/12346/use -D test -e 'SELECT * FROM issue_37'`;
ok(!$output, 'Table with trigger was not written');

$output = `../mk-table-sync --skipslavecheck --execute u=msandbox,p=msandbox,h=127.0.0.1,P=12345,D=test,t=issue_37 h=127.1,P=12346 --ignore-triggers 2>&1`;
unlike($output, qr/Cannot write to table with triggers/, 'Writes to tbl with trigger with --ignore-triggers (issue 37)');

$output = `/tmp/12346/use -D test -e 'SELECT * FROM issue_37'`;
like($output, qr/a.+1.+2/ms, 'Table with trigger was written');

# #############################################################################
# Issue 8: Add --force-index parameter to mk-table-checksum and mk-table-sync
# #############################################################################
`/tmp/12345/use -e 'INSERT INTO test.issue_37 VALUES (5), (6), (7), (8), (9);'`;
$output = `MKDEBUG=1 ../mk-table-sync h=127.0.0.1,P=12345 P=12346 -d test -t issue_37 -a Chunk --chunksize 3 --ignore-triggers 2>&1 | grep 'src: '`;
like($output, qr/FROM `test`\.`issue_37` USE INDEX \(`idx_a`\) WHERE/, 'Injects USE INDEX hint by default');

$output = `MKDEBUG=1 ../mk-table-sync h=127.0.0.1,P=12345 P=12346 -d test -t issue_37 -a Chunk --chunksize 3 --ignore-triggers --no-use-index 2>&1 | grep 'src: '`;
like($output, qr/FROM `test`\.`issue_37`  WHERE/, 'No USE INDEX hint with --no-use-index');

# #############################################################################
# Issue 22: mk-table-sync fails with uninitialized value at line 2330
# #############################################################################
diag(`/tmp/12345/use -D test  < samples/issue_22.sql`);
diag(`/tmp/12345/use -D test -e "SET SQL_LOG_BIN=0; INSERT INTO test.messages VALUES (1,2,'author','2008-09-12 00:00:00','1','0','headers','msg');"`);
diag(`/tmp/12345/use -e 'CREATE DATABASE test2'`);
diag(`/tmp/12345/use -D test2 < samples/issue_22.sql`);

$output = 'foo'; # To make explicitly sure that the following command
                 # returns blank because there are no rows and not just that
                 # $output was blank from a previous test
$output = `/tmp/12345/use -D test2 -e 'SELECT * FROM messages'`;
ok(!$output, 'test2.messages is empty before sync (issue 22)');

$output = `../mk-table-sync --skipslavecheck -x u=msandbox,p=msandbox,P=12345,h=127.1,D=test,t=messages u=msandbox,p=msandbox,P=12345,h=127.1,D=test2,t=messages`;
ok(!$output, 'Synced test.messages to test2.messages on same host (issue 22)');

$output     = `/tmp/12345/use -D test  -e 'SELECT * FROM messages'`;
my $output2 = `/tmp/12345/use -D test2 -e 'SELECT * FROM messages'`;
is($output, $output2, 'test2.messages matches test.messages (issue 22)');

diag(`../../sandbox/stop_all`);
exit;

