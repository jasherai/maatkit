#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 67;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $output;
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
   my $cmd = "../mk-table-sync --print --execute h=127.1,P=12345,D=test,t=$src h=127.1,P=12346,D=test,t=$dst $other 2>&1";
   chomp($output=`$cmd`);
   return $output;
}

# Pre-create a second host while the other test are running
# so we won't have to wait for it to load when we need it.
diag(`../../sandbox/make_sandbox 12347 >/dev/null &`);

# Test DSN value inheritance.
$output = `../mk-table-sync h=127.1 h=127.2,P=12346 --port 12345 --explain-hosts`;
is(
   $output,
"# DSN: P=12345,h=127.1
# DSN: P=12346,h=127.2
",
   'DSNs inherit values from --port, etc. (issue 248)'
);

# #############################################################################
# Test basic master-slave syncing
# #############################################################################
$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '');
like($output, qr/Can't make changes/, 'It dislikes changing a slave');

$output = run('test1', 'test2', '--no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'No alg sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with no alg'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '--algorithms Stream --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Stream sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Stream'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '--algorithms GroupBy --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic GroupBy sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with GroupBy'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '--algorithms Chunk,GroupBy --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Chunk sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Chunk'
);

$sb->load_file('master', 'samples/before.sql');
$output = run('test1', 'test2', '--algorithms Nibble --no-bin-log');
is($output, "INSERT INTO `test`.`test2`(`a`, `b`) VALUES (1, 'en');
INSERT INTO `test`.`test2`(`a`, `b`) VALUES (2, 'ca');", 'Basic Nibble sync');
is_deeply(
   query_slave('select * from test.test2'),
   [ {   a => 1, b => 'en' }, { a => 2, b => 'ca' } ],
   'Synced OK with Nibble'
);

# Save original MKDEBUG env because we modify it below.
my $dbg = $ENV{MKDEBUG};

$sb->load_file('master', 'samples/before.sql');
$ENV{MKDEBUG} = 1;
$output = run('test1', 'test2', '--algorithms Nibble --no-bin-log --chunk-size 1 --transaction --lock 1');
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
$output = run('test3', 'test4', '--print --no-bin-log --verbose --function MD5');
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
   qr/2 Chunk\s+2\s+test.test3/,
   'Right number of rows to update',
);

# Sync a table with Nibble and a chunksize in data size, not number of rows
$output = run('test3', 'test4', '--algorithms Nibble --chunk-size 1k --print --verbose --function MD5');
# If it lived, it's OK.
ok($output, 'Synced with Nibble and data-size chunksize');

# Restore MKDEBUG env.
$ENV{MKDEBUG} = $dbg;

# #############################################################################
# Ensure that syncing master-master works OK
# #############################################################################
# Sometimes I skip this test if I'm running this script over and over.
SKIP: {
   skip "I'm impatient", 1 if 0;

   diag(`../../sandbox/make_master-master`);
   diag(`/tmp/12348/use -e 'CREATE DATABASE test'`);
   diag(`/tmp/12348/use < samples/before.sql`);
   # Make master2 different from master1
   diag(`/tmp/12349/use -e 'set sql_log_bin=0;update test.test1 set b="mm" where a=1'`);
   # This will make master1's data match the changed data on master2 (that is not
   # a typo).
   `perl ../mk-table-sync --no-check-slave --sync-to-master --print --execute h=127.0.0.1,P=12348,D=test,t=test1`;
   sleep 1;
   $output = `/tmp/12348/use -e 'select b from test.test1 where a=1' -N`;
   like($output, qr/mm/, 'Master-master sync worked');
   diag(`../../sandbox/stop_master-master >/dev/null &`);
};

# #############################################################################
# Issue 37: mk-table-sync should warn about triggers
# #############################################################################
$sb->load_file('master', 'samples/issue_37.sql');
$sb->use('master', '-e "SET SQL_LOG_BIN=0; INSERT INTO test.issue_37 VALUES (1), (2);"');
$sb->load_file('master', 'samples/checksum_tbl.sql');
`../../mk-table-checksum/mk-table-checksum h=127.0.0.1,P=12345 --replicate test.checksum -d test 2>&1 > /dev/null`;

$output = `../mk-table-sync --no-check-slave --execute u=msandbox,p=msandbox,h=127.0.0.1,P=12345,D=test,t=issue_37 h=127.1,P=12346 2>&1`;
like($output,
   qr/Triggers are defined/,
   'Die on trigger tbl write with one table (1/4, issue 37)'
);

$output = `../mk-table-sync --replicate test.checksum --sync-to-master --execute h=127.1,P=12346 -d test -t issue_37 2>&1`;
like($output,
   qr/Triggers are defined/,
   'Die on trigger tbl write with --replicate --sync-to-master (2/4, issue 37)'
);

$output = `../mk-table-sync --replicate test.checksum --execute h=127.1,P=12345 -d test -t issue_37 2>&1`;
like(
   $output,
   qr/Triggers are defined/,
   'Die on trigger tbl write with --replicate (3/4, issue 37)'
);

$output = `../mk-table-sync --execute --ignore-databases mysql h=127.0.0.1,P=12345 h=127.1,P=12346 2>&1`;
like(
   $output,
   qr/Triggers are defined/,
   'Die on trigger tbl write with no opts (4/4, issue 37)'
);

$output = `/tmp/12346/use -D test -e 'SELECT * FROM issue_37'`;
ok(
   !$output,
   'Table with trigger was not written'
);

$output = `../mk-table-sync --no-check-slave --execute u=msandbox,p=msandbox,h=127.0.0.1,P=12345,D=test,t=issue_37 h=127.1,P=12346 --no-check-triggers 2>&1`;
unlike(
   $output,
   qr/Triggers are defined/,
   'Writes to tbl with trigger with --no-check-triggers (issue 37)'
);

$output = `/tmp/12346/use -D test -e 'SELECT * FROM issue_37'`;
like(
   $output, qr/a.+1.+2/ms,
   'Table with trigger was written'
);

# #############################################################################
# Issue 8: Add --force-index parameter to mk-table-checksum and mk-table-sync
# #############################################################################
$sb->use('master', '-e \'INSERT INTO test.issue_37 VALUES (5), (6), (7), (8), (9);\'');

$output = `MKDEBUG=1 ../mk-table-sync h=127.0.0.1,P=12345 P=12346 -d test -t issue_37 --algorithms Chunk --chunk-size 3 --no-check-slave --no-check-triggers --print 2>&1 | grep 'src: '`;
like($output, qr/FROM `test`\.`issue_37` FORCE INDEX \(`idx_a`\) WHERE/, 'Injects USE INDEX hint by default');

$output = `MKDEBUG=1 ../mk-table-sync h=127.0.0.1,P=12345 P=12346 -d test -t issue_37 --algorithms Chunk --chunk-size 3 --no-check-slave --no-check-triggers --no-index-hint --print 2>&1 | grep 'src: '`;
like($output, qr/FROM `test`\.`issue_37`  WHERE/, 'No USE INDEX hint with --no-index-hint');

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

$output = `../mk-table-sync --no-check-slave --execute u=msandbox,p=msandbox,P=12345,h=127.1,D=test,t=messages u=msandbox,p=msandbox,P=12345,h=127.1,D=test2,t=messages 2>&1`;
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
$output = `../mk-table-sync h=127.1,P=12345 --replicate test.checksum --execute -d test -t test2 -v`;
unlike($output, qr/messages/, '--replicate honors --tables (1/4)');
like($output,   qr/test2/,    '--replicate honors --tables (2/4)');

# Now we'll test with a qualified db.tbl name.
$sb->use('slave1', '-D test -e "TRUNCATE TABLE test2; TRUNCATE TABLE messages"');
diag(`../../mk-table-checksum/mk-table-checksum --replicate=test.checksum h=127.1,P=12345 -d test > /dev/null`);

$output = `../mk-table-sync h=127.1,P=12345 --replicate test.checksum --execute -d test -t test.test2 -v`;
unlike($output, qr/messages/, '--replicate honors --tables (3/4)');
like($output,   qr/test2/,    '--replicate honors --tables (4/4)');

# #############################################################################
# Issue 96: mk-table-sync: Nibbler infinite loop
# #############################################################################
diag(`/tmp/12345/use -D test < ../../common/t/samples/issue_96.sql`);
sleep 1;
$output = `../mk-table-sync h=127.1,P=12345,D=issue_96,t=t h=127.1,P=12345,D=issue_96,t=t2 --algorithms Nibble --chunk-size 2 --print`;
chomp $output;
is(
   $output,
   "UPDATE `issue_96`.`t2` SET `from_city`='ta' WHERE `package_id`=4 AND `location`='CPR' LIMIT 1;",
   'Sync nibbler infinite loop (issue 96)'
);

# #############################################################################
# Issue 111: Make mk-table-sync require --print or --execute or --dry-run
# #############################################################################

# This test reuses the test.message table created above for issue 22.
$output = `../mk-table-sync h=127.1,P=12345,D=test,t=messages P=12346`;
like($output, qr/Specify at least one of --print, --execute or --dry-run/,
   'Requires --print, --execute or --dry-run');

# #############################################################################
# Issue 262
# #############################################################################
$sb->create_dbs($master_dbh, ['foo']);
$sb->use('master', '-e "create table foo.t1 (i int)"');
$sb->use('master', '-e "SET SQL_LOG_BIN=0; insert into foo.t1 values (1)"');
$sb->use('slave1', '-e "truncate table foo.t1"');
$output = `perl ../mk-table-sync --no-check-slave --print h=127.1,P=12345 -d mysql,foo h=127.1,P=12346 2>&1`;
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
# Test --explain-hosts (issue 293).
# #############################################################################
$output = `perl ../mk-table-sync --explain-hosts localhost,D=foo,t=bar t=baz`;
is($output,
<<EOF
# DSN: D=foo,h=localhost,t=bar
# DSN: D=foo,h=localhost,t=baz
EOF
, '--explain-hosts');

# #############################################################################
# Issue 218: Two NULL column values don't compare properly w/ Stream/GroupBy
# #############################################################################
$sb->create_dbs($master_dbh, [qw(issue218)]);
$sb->use('master', '-e "CREATE TABLE issue218.t1 (i INT)"');
$sb->use('master', '-e "INSERT INTO issue218.t1 VALUES (NULL)"');
qx(../mk-table-sync --no-check-slave --print --database issue218 h=127.1,P=12345 P=12346);
ok(!$?, 'Issue 218: NULL values compare as equal');

# #############################################################################
# Issue 313: Add --ignore-columns (and add tests for --columns).
# #############################################################################
$sb->load_file('master', 'samples/before.sql');
$output = `perl ../mk-table-sync --print h=127.1,P=12345,D=test,t=test3 t=test4`;
# This test changed because the row sql now does ORDER BY key_col (id here)
is($output, <<EOF,
UPDATE `test`.`test4` SET `name`='001' WHERE `id`=1 LIMIT 1;
UPDATE `test`.`test4` SET `name`=51707 WHERE `id`=15034 LIMIT 1;
EOF
  'Baseline for --columns: found differences');

$output = `perl ../mk-table-sync --columns=id --print h=127.1,P=12345,D=test,t=test3 t=test4`;
is($output, "", '--columns id: found no differences');

$output = `perl ../mk-table-sync --ignore-columns name --print h=127.1,P=12345,D=test,t=test3 t=test4`;
is($output, "", '--ignore-columns name: found no differences');

$output = `perl ../mk-table-sync --ignore-columns id --print h=127.1,P=12345,D=test,t=test3 t=test4`;
# This test changed for the same reason as above.
is($output, <<EOF,
UPDATE `test`.`test4` SET `name`='001' WHERE `id`=1 LIMIT 1;
UPDATE `test`.`test4` SET `name`=51707 WHERE `id`=15034 LIMIT 1;
EOF
  '--ignore-columns id: found differences');

$output = `perl ../mk-table-sync --columns name --print h=127.1,P=12345,D=test,t=test3 t=test4`;
# This test changed for the same reason as above.
is($output, <<EOF,
UPDATE `test`.`test4` SET `name`='001' WHERE `id`=1 LIMIT 1;
UPDATE `test`.`test4` SET `name`=51707 WHERE `id`=15034 LIMIT 1;
EOF
  '--columns name: found differences');

# #############################################################################
# Issue 363: lock and rename.
# #############################################################################
$sb->load_file('master', 'samples/before.sql');

$output = `perl ../mk-table-sync --lock-and-rename h=127.1,P=12345 P=12346 2>&1`;
like($output, qr/requires exactly two/,
   '--lock-and-rename error when DSNs do not specify table');

# It's hard to tell exactly which table is which, and the tables are going to be
# "swapped", so we'll put a marker in each table to test the swapping.
`/tmp/12345/use -e "alter table test.test1 comment='test1'"`;

$output = `perl ../mk-table-sync --execute --lock-and-rename h=127.1,P=12345,D=test,t=test1 t=test2 2>&1`;
diag $output if $output;

$output = `/tmp/12345/use -e 'show create table test.test2'`;
like($output, qr/COMMENT='test1'/, '--lock-and-rename worked');

# #############################################################################
# Issue 408: DBD::mysql::st execute failed: Unknown database 'd1' at
# ./mk-table-sync line 2015.
# #############################################################################

# It's not really slave2, we just use slave2's port.
my $dbh2 = $sb->get_dbh_for('slave2');
SKIP: {
   skip 'Cannot connect to second sandbox server', 1
      unless $dbh2;

   $output = `perl ../mk-table-sync --databases test --execute h=127.1,P=12345 h=127.1,P=12347 2>&1`;
   like(
      $output,
      qr/Unknown database 'test'/,
      'Warn about --databases missing on dest host'
   );
};

# #############################################################################
# Issue 391: Add --pid option to mk-table-sync
# #############################################################################
`touch /tmp/mk-table-sync.pid`;
$output = `../mk-table-sync h=127.1,P=12346 --sync-to-master --print --no-check-triggers --pid /tmp/mk-table-sync.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-table-sync.pid already exists},
   'Dies if PID file already exists (issue 391)'
);

`rm -rf /tmp/mk-table-sync.pid`;

# #############################################################################
# Issue 40: mk-table-sync feature: sync to different db
# #############################################################################

# It's not really slave2, we just use slave2's port.
SKIP: {
   skip 'Cannot connect to second sandbox server', 1
      unless $dbh2;

   # master (12345) should have test.test1 from an earlier test.
   $dbh2->do('DROP DATABASE IF EXISTS d2');
   $dbh2->do('CREATE DATABASE d2');
   $dbh2->do('CREATE TABLE d2.test2 (a INT NOT NULL, b char(2) NOT NULL, PRIMARY KEY  (`a`,`b`) )');

   $output = `../mk-table-sync --no-check-slave --execute h=127.1,P=12345,D=test,t=test1  h=127.1,P=12347,D=d2,t=test2 2>&1`;
   is(
      $output,
      '',
      'Sync to different db.tbl (issue 40)'
   );

   $output     = `/tmp/12345/use -e 'SELECT * FROM test.test1'`;
   my $output2 = `/tmp/12347/use -e 'SELECT * FROM d2.test2'`;
   is(
      $output,
      $output2,
      'Original db.tbl matches different db.tbl (issue 40)'
   );
};

# #############################################################################
#  Issue 367: mk-table-sync incorrectly advises --ignore-triggers
# #############################################################################
$sb->load_file('master', 'samples/issue_367.sql');

# Make slave db1.t1 and db2.t1 differ from master.
$slave_dbh->do('INSERT INTO db1.t1 VALUES (9)');
$slave_dbh->do('DELETE FROM db2.t1 WHERE i > 4');

# Replicate checksum of db2.t1.
$output = `../../mk-table-checksum/mk-table-checksum h=127.1,P=12345 --replicate db1.checksum --create-replicate-table --databases db1,db2 2>&1`;
like(
   $output,
   qr/db2\s+t1\s+0\s+127\.1\s+MyISAM\s+5/,
   'Replicated checksums (issue 367)'
);

# Sync db2, which has no triggers, between master and slave using
# --replicate which has entries for both db1 and db2.  db1 has a
# trigger but since we also specify --databases db2, then db1 should
# be ignored.
$output = `../mk-table-sync h=127.1,P=12345  --databases db2 --replicate db1.checksum --execute 2>&1`;
unlike(
   $output,
   qr/Cannot write to table with triggers/,
   "Doesn't warn about trigger on db1 (issue 367)"
);
my $r = $slave_dbh->selectrow_array('SELECT * FROM db2.t1 WHERE i = 5');
is(
   $r,
   '5',
   'Syncs db2, ignores db1 with trigger (issue 367)'
);

# #############################################################################
# Issue 533: mk-table-sync does not work with replicate-do-db
# #############################################################################

# It's not really master1, we just use its port 12348.
diag(`../../sandbox/make_slave 12348`);
my $dbh3 = $sb->get_dbh_for('master1');
SKIP: {
   skip 'Cannot connect to second sandbox slave', 2
      unless $dbh3;

   # This slave is new so it doesn't have the dbs and tbls
   # created above.  We create some so that the current db
   # will change they get checked.  It should stop at something
   # other than onlythisdb.
   $sb->wipe_clean($master_dbh);
   diag(`/tmp/12345/use -e 'CREATE DATABASE test'`);
   diag(`/tmp/12345/use < samples/issue_560.sql`);
   diag(`/tmp/12345/use < samples/issue_533.sql`);

   # Stop the slave, add replicate-do-db to its config, and restart it.
   $dbh3->disconnect();
   diag(`/tmp/12348/stop`);
   diag(`echo "replicate-do-db = onlythisdb" >> /tmp/12348/my.sandbox.cnf`);
   diag(`/tmp/12348/start`);
   $dbh3 = $sb->get_dbh_for('master1');

   # Make master and slave differ.  Because we USE test, this DELETE on
   # the master won't replicate to the slave now that replicate-do-db
   # is set.
   $master_dbh->do('USE test');
   $master_dbh->do('DELETE FROM onlythisdb.t WHERE i = 2');
   my $r = $dbh3->selectall_arrayref('SELECT * FROM onlythisdb.t');
   is_deeply(
      $r,
      [[1],[2],[3]],
      'do-replicate-db is out of sync before sync'
   );

   diag(`../mk-table-sync h=127.1,P=12348 --sync-to-master --execute --no-check-triggers --ignore-databases sakila,mysql --ignore-tables buddy_list 2>&1`);

   $r = $dbh3->selectall_arrayref('SELECT * FROM onlythisdb.t');
   is_deeply(
      $r,
      [[1],[3]],
      'do-replicate-db is in sync after sync'
   );

   $dbh3->disconnect();
   diag(`/tmp/12348/stop`);
   diag(`rm -rf /tmp/12348/`);
};

# #############################################################################
# Issue 86: mk-table-sync: lock level 3
# #############################################################################

$output = `../mk-table-sync --sync-to-master h=127.1,P=12346,D=test,t=t --print  --lock 3 2>&1`;
unlike(
   $output,
   qr/Failed to lock server/,
   '--lock 3 (issue 86)'
);

# #############################################################################
# Issue 410: mk-table-sync doesn't have --float-precision
# #############################################################################

$master_dbh->do('create table test.fl (id int not null primary key, f float(12,10), d double)');
$master_dbh->do('insert into test.fl values (1, 1.0000012, 2.0000012)');
sleep 1;
$slave_dbh->do('update test.fl set d = 2.0000013 where id = 1');

# The columns really are different at this point so we should
# get a REPLACE without using --float-precision.
$output = `../mk-table-sync --sync-to-master h=127.1,P=12346,D=test,t=fl --print 2>&1`;
like(
   $output,
   qr/REPLACE INTO `test`.`fl`\(`d`, `f`, `id`\) VALUES \('2.0000012'/,
   'No --float-precision so double col diff at high precision (issue 410)'
);

# Now use --float-precision to roundoff the differing columns.
# We have 2.0000012
#     vs. 2.0000013, so if we round at 6 places, they should be the same.
$output = `../mk-table-sync --sync-to-master h=127.1,P=12346,D=test,t=fl --print --float-precision 6 2>&1`;
is(
   $output,
   '',
   '--float-precision so no more diff (issue 410)'
);

# #############################################################################
# Issue 616: mk-table-sync inserts NULL values instead of correct values
# #############################################################################
diag(`/tmp/12345/use -D test < ../../common/t/samples/issue_616.sql`);
sleep 1;
`../mk-table-sync --sync-to-master h=127.1,P=12346 --databases issue_616 --execute`;
my $ok_r = [
   [  1, 'from master' ],
   [ 11, 'from master' ],
   [ 21, 'from master' ],
   [ 31, 'from master' ],
   [ 41, 'from master' ],
   [ 51, 'from master' ],
];

$r = $master_dbh->selectall_arrayref('SELECT * FROM issue_616.t ORDER BY id');
is_deeply(
   $r,
   $ok_r,
   'Issue 616 synced on master'
);
      
$r = $slave_dbh->selectall_arrayref('SELECT * FROM issue_616.t ORDER BY id');
is_deeply(
   $r,
   $ok_r,
   'Issue 616 synced on slave'
);

# #############################################################################
# Issue 376: Permit specifying an index for mk-table-sync
# #############################################################################
diag(`/tmp/12345/use -D test < samples/issue_375.sql`);
sleep 1;
$output = `../mk-table-sync --sync-to-master h=127.1,P=12346 -d issue_375 --print -v -v  --chunk-size 50 --chunk-index updated_at`;
like(
   $output,
   qr/FROM `issue_375`.`t` FORCE INDEX \(`updated_at`\) WHERE \(`updated_at` < "2009-09-05 02:38:12"/,
   '--chunk-index',
);

$output = `../mk-table-sync --sync-to-master h=127.1,P=12346 -d issue_375 --print -v -v  --chunk-size 50 --chunk-column updated_at`;
like(
   $output,
   qr/FROM `issue_375`.`t` FORCE INDEX \(`updated_at`\) WHERE \(`updated_at` < "2009-09-05 02:38:12"/,
   '--chunk-column',
);

# #############################################################################
# Issue 627: Results for mk-table-sync --replicate may be incorrect
# #############################################################################
$sb->wipe_clean($master_dbh);  # just for good measure
diag(`/tmp/12345/use < samples/issue_375.sql`);
sleep 1;

# Make the table differ.
# (10, '2009-09-03 14:18:00', 'k'),    -> (10, '2009-09-03 14:18:00', 'z'),
# (100, '2009-09-06 15:01:23', 'cv');  -> (100, '2009-09-06 15:01:23', 'zz');
$slave_dbh->do('UPDATE issue_375.t SET foo="z" WHERE id=10');
$slave_dbh->do('UPDATE issue_375.t SET foo="zz" WHERE id=100');

# Checksum and replicate.
diag(`../../mk-table-checksum/mk-table-checksum --create-replicate-table --replicate issue_375.checksum h=127.1,P=12345 -d issue_375 -t t > /dev/null`);
diag(`../../mk-table-checksum/mk-table-checksum --replicate issue_375.checksum h=127.1,P=12345  --replicate-check 1 > /dev/null`);

# And now sync using the replicated checksum results/differences.
$output = `../mk-table-sync --sync-to-master h=127.1,P=12346 --replicate issue_375.checksum --print`;
is(
   $output,
   "REPLACE INTO `issue_375`.`t`(`foo`, `id`, `updated_at`) VALUES ('k', 10, '2009-09-03 14:18:00');
REPLACE INTO `issue_375`.`t`(`foo`, `id`, `updated_at`) VALUES ('cv', 100, '2009-09-06 15:01:23');
",
   'Simple --replicate'
);

# Note how the columns are out of order (tbl order is: id, updated_at, foo).
# This is issue http://code.google.com/p/maatkit/issues/detail?id=371

# #############################################################################
# Issue 631: mk-table-sync GroupBy and Stream fail
# #############################################################################
diag(`/tmp/12345/use < samples/issue_631.sql`);

$output = `../mk-table-sync h=127.1,P=12345,D=d1,t=t h=127.1,P=12345,D=d2,t=t h=127.1,P=12345,D=d3,t=t --print -v --algorithms GroupBy`;
is(
   $output,
"# Syncing D=d2,P=12345,h=127.1,t=t
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d2`.`t`(`x`) VALUES (1);
#      0       0      1      0 GroupBy   2    d1.t
# Syncing D=d3,P=12345,h=127.1,t=t
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d3`.`t`(`x`) VALUES (1);
INSERT INTO `d3`.`t`(`x`) VALUES (2);
#      0       0      2      0 GroupBy   2    d1.t
",
   'GroupBy can sync issue 631'
);

$output = `../mk-table-sync h=127.1,P=12345,D=d1,t=t h=127.1,P=12345,D=d2,t=t h=127.1,P=12345,D=d3,t=t --print -v --algorithms Stream`;
is(
   $output,
"# Syncing D=d2,P=12345,h=127.1,t=t
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d2`.`t`(`x`) VALUES (1);
#      0       0      1      0 Stream    2    d1.t
# Syncing D=d3,P=12345,h=127.1,t=t
# DELETE REPLACE INSERT UPDATE ALGORITHM EXIT DATABASE.TABLE
INSERT INTO `d3`.`t`(`x`) VALUES (1);
INSERT INTO `d3`.`t`(`x`) VALUES (2);
#      0       0      2      0 Stream    2    d1.t
",
   'Stream can sync issue 631'
);

# #############################################################################
# Done
# #############################################################################
if ( $dbh2 ) {
   $dbh2->disconnect();
   diag(`/tmp/12347/stop`);
   diag(`rm -rf /tmp/12347/`);
}
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
