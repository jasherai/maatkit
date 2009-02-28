#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 38;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh   = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

$sb->create_dbs($master_dbh, [qw(test)]);

sub query_slave {
   return $slave_dbh->selectall_arrayref(@_, {Slice => {}});
}

sub run {
   my ($src, $dst, $other) = @_;
   my $output;
   my $cmd = "../mk-table-sync -px h=127.1,P=12345,D=test,t=$src h=127.1,P=12346,D=test,t=$dst $other 2>&1";
   chomp($output=`$cmd`);
   return $output;
}

# #############################################################################
# Test basic master-slave syncing
# #############################################################################
$sb->load_file('master', 'samples/before.sql');
my $output = run('test1', 'test2', '');
like($output, qr/Can't make changes/, 'It dislikes changing a slave');

$output = run('test1', 'test2', '--skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'No alg sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with no alg'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '-a Stream --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Stream sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Stream'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '-a GroupBy --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic GroupBy sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with GroupBy'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '-a Chunk --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Chunk sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Chunk'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '-a Nibble --skipbinlog');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Nibble sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Nibble'
);

$sb->load_file('master', 'samples/before.sql');
$ENV{MKDEBUG} = 1;
$output = run('test1', 'test2', '-a Nibble --skipbinlog --chunksize 1 --transaction -k 1');
delete $ENV{MKDEBUG};
like(
   $output,
   qr/Executing statement on source/,
   'Nibble with transactions and locking'
);
is_deeply(
   query_slave('select * from test.test2'),
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

# #############################################################################
# Ensure that syncing master-master works OK
# #############################################################################
diag(`../../sandbox/make_master-master`);
diag(`/tmp/12348/use -e 'CREATE DATABASE test'`);
diag(`/tmp/12348/use < samples/before.sql`);
# Make master2 different from master1
diag(`/tmp/12349/use -e 'set sql_log_bin=0;update test.test1 set b="mm" where a=1'`);
# This will make master1's data match the changed data on master2 (that is not
# a typo).
`perl ../mk-table-sync --synctomaster -px h=127.0.0.1,P=12348,D=test,t=test1`;
$output = `/tmp/12348/use -e 'select b from test.test1 where a=1' -N`;
like($output, qr/mm/, 'Master-master sync worked');
diag(`../../sandbox/stop_master-master`);

# #############################################################################
# Issue 37: mk-table-sync should warn about triggers
# #############################################################################
$sb->load_file('master', 'samples/issue_37.sql');
$sb->use('master', '-e "SET SQL_LOG_BIN=0; INSERT INTO test.issue_37 VALUES (1), (2);"');
$sb->load_file('master', 'samples/checksum_tbl.sql');
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
$sb->use('master', '-e \'INSERT INTO test.issue_37 VALUES (5), (6), (7), (8), (9);\'');

$output = `MKDEBUG=1 ../mk-table-sync h=127.0.0.1,P=12345 P=12346 -d test -t issue_37 -a Chunk --chunksize 3 --ignore-triggers --print 2>&1 | grep 'src: '`;
like($output, qr/FROM `test`\.`issue_37` USE INDEX \(`idx_a`\) WHERE/, 'Injects USE INDEX hint by default');

$output = `MKDEBUG=1 ../mk-table-sync h=127.0.0.1,P=12345 P=12346 -d test -t issue_37 -a Chunk --chunksize 3 --ignore-triggers --nouseindex --print 2>&1 | grep 'src: '`;
like($output, qr/FROM `test`\.`issue_37`  WHERE/, 'No USE INDEX hint with --nouseindex');

# #############################################################################
# Issue 22: mk-table-sync fails with uninitialized value at line 2330
# #############################################################################
$sb->use('master', '-D test < samples/issue_22.sql');
$sb->use('master', "-D test -e \"SET SQL_LOG_BIN=0; INSERT INTO test.messages VALUES (1,2,'author','2008-09-12 00:00:00','1','0','headers','msg');\"");
$sb->create_dbs($master_dbh, [qw(test2)]);
$sb->use('master', '-D test2 < samples/issue_22.sql');

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

# #############################################################################
# Issue 79: mk-table-sync with --replicate doesn't honor --tables
# #############################################################################

# The previous test should have left test.messages on the slave (12346)
# out of sync. Now we also unsync test2 on the slave and then re-sync only
# it. If --tables is honored, only test2 on the slave will be synced.
$sb->use('master', "-D test -e \"SET SQL_LOG_BIN=0; INSERT INTO test2 VALUES (1,'a'),(2,'b')\"");
diag(`../../mk-table-checksum/mk-table-checksum --replicate=test.checksum h=127.1,P=12345 -d test > /dev/null`);

# Test that what the doc says about --tables is true:
# "Table names may be qualified with the database name."
# In the code, a qualified db.tbl name is used.
# So we'll test first an unqualified tbl name.
$output = `../mk-table-sync h=127.1,P=12345 -R test.checksum -x -d test -t test2 -v`;
unlike($output, qr/messages/, '--replicate honors --tables (1/4)');
like($output,   qr/test2/,    '--replicate honors --tables (2/4)');

# Now we'll test with a qualified db.tbl name.
$sb->use('slave1', '-D test -e "TRUNCATE TABLE test2; TRUNCATE TABLE messages"');
diag(`../../mk-table-checksum/mk-table-checksum --replicate=test.checksum h=127.1,P=12345 -d test > /dev/null`);

$output = `../mk-table-sync h=127.1,P=12345 -R test.checksum -x -d test -t test.test2 -v`;
unlike($output, qr/messages/, '--replicate honors --tables (3/4)');
like($output,   qr/test2/,    '--replicate honors --tables (4/4)');

# #############################################################################
# Issue 96: mk-table-sync: Nibbler infinite loop
# #############################################################################
# This is a work in progress.
# diag(`/tmp/12345/use -D test < samples/issue_96.sql`);
# sleep 1;
# diag(`/tmp/12345/use -D test -e "DELETE FROM issue_96 WHERE 1 LIMIT 5"`);
# $output = `../mk-table-sync h=127.1,P=12345 P=12346 -a Nibble --chunksize 2 -x`;

# #############################################################################
# Issue 111: Make mk-table-sync require --print or --execute or --test
# #############################################################################

# This test reuses the test.message table created above for issue 22.
$output = `../mk-table-sync h=127.1,P=12345,D=test,t=messages P=12346`;
like($output, qr/Specify at least one of --print, --execute or --test/,
   'Requires --print, --execute or --test');

# #############################################################################
# Issue 262
# #############################################################################
$sb->create_dbs($master_dbh, ['foo']);
$sb->use('master', '-e "create table foo.t1 (i int)"');
$sb->use('master', '-e "SET SQL_LOG_BIN=0; insert into foo.t1 values (1)"');
$sb->use('slave1', '-e "truncate table foo.t1"');
$output = `perl ../mk-table-sync --print h=127.1,P=12345 -d mysql,foo h=127.1,P=12346 2>&1`;
like(
   $output,
   qr/INSERT INTO `foo`\.`t1`\(`i`\) VALUES \(1\)/,
   'Does not die checking tables for triggers (issue 262)'
);

# #############################################################################
# Don't let people try to restrict syncing with D=foo
# #############################################################################
$output = `perl ../mk-table-sync h=localhost,D=test 2>&1`;
like($output, qr/Are you trying to sync/, 'Throws error on D=');

# #############################################################################
# Test --explainhosts (issue 293).
# #############################################################################
$output = `perl ../mk-table-sync --explainhosts localhost,D=foo,t=bar t=baz`;
is($output,
<<EOF
# DSN: A=utf8,D=foo,h=localhost,t=bar
# DSN: A=utf8,D=foo,h=localhost,t=baz
EOF
, '--explainhosts');

# #############################################################################
# Done
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
