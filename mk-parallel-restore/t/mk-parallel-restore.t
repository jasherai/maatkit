#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 60;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-parallel-restore -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

my $output = `$cmd mk_parallel_restore_foo --dry-run`;
like(
   $output,
   qr/CREATE TABLE bar\(a int\)/,
   'Found the file',
);
like(
   $output,
   qr{1 tables,\s+1 files,\s+1 successes},
   'Counted the work to be done',
);

$output = `$cmd --ignore-tables bar mk_parallel_restore_foo --dry-run`;
unlike( $output, qr/bar/, '--ignore-tables filtered out bar');

$output = `$cmd --ignore-tables mk_parallel_restore_foo.bar mk_parallel_restore_foo --dry-run`;
unlike( $output, qr/bar/, '--ignore-tables filtered out bar again');

# Actually load the file, and make sure it succeeds.
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `$cmd --create-databases mk_parallel_restore_foo`;
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_foo.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_foo.bar');

# Test that the --database parameter doesn't specify the database to use for the
# connection, and that --create-databases creates the database for it (bug #1870415).
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_foo'`;
`$mysql -e 'DROP DATABASE IF EXISTS mk_parallel_restore_bar'`;
$output = `$cmd --database mk_parallel_restore_bar --create-databases mk_parallel_restore_foo`;
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');

# Test that the --defaults-file parameter works (bug #1886866).
# This is implicit in that $cmd specifies --defaults-file
$output = `$cmd --create-databases mk_parallel_restore_foo`;
like($output, qr/1 files,     1 successes,  0 failures/, 'restored');
$output = `$mysql -N -e 'select count(*) from mk_parallel_restore_bar.bar'`;
is($output + 0, 0, 'Loaded mk_parallel_restore_bar.bar');

# #############################################################################
# Issue 31: Make mk-parallel-dump and mk-parallel-restore do biggest-first
# #############################################################################

# Tables in order of size: t4 t1 t3 t2

$output = `$cmd samples/issue_31 --create-databases --dry-run --threads 1 2>&1 | grep 'Dumping data for table'`;
is(
   $output,
"-- Dumping data for table `t4`
-- Dumping data for table `t1`
-- Dumping data for table `t3`
-- Dumping data for table `t2`
",
   "Restores largest tables first by default (issue 31)"
);

# Do it again with > 1 arg to test that it does NOT restore largest first.
# It should restore the tables in the given order.
$output = `$cmd --create-databases --dry-run --threads 1 samples/issue_31/issue_31/t1.000000.sql samples/issue_31/issue_31/t2.000000.sql samples/issue_31/issue_31/t3.000000.sql samples/issue_31/issue_31/t4.000000.sql 2>&1 | grep 'Dumping data for table'`;
is(
   $output,
"-- Dumping data for table `t1`
-- Dumping data for table `t2`
-- Dumping data for table `t3`
-- Dumping data for table `t4`
",
   "Restores tables in given order (issue 31)"
);

# And yet again, but this time test that a given order of tables is
# ignored if --biggest-first is explicitly given
$output = `$cmd --biggest-first --create-databases --dry-run --threads 1 samples/issue_31/issue_31/t1.000000.sql samples/issue_31/issue_31/t2.000000.sql samples/issue_31/issue_31/t3.000000.sql samples/issue_31/issue_31/t4.000000.sql 2>&1 | grep 'Dumping data for table'`;
is(
   $output,
"-- Dumping data for table `t4`
-- Dumping data for table `t1`
-- Dumping data for table `t3`
-- Dumping data for table `t2`
",
   "Given order overriden by explicit --biggest-first (issue 31)"
);

# #############################################################################
# Test --progress.
# #############################################################################
# This is kind of a contrived test, but it's better than nothing.
$output = `$cmd samples/issue_31 --progress --dry-run`;
like($output, qr/done: [\d\.]+[Mk]\/[\d\.]+[Mk]/, 'Reporting progress by bytes');

# #############################################################################
# Issue 30: Add resume functionality to mk-parallel-restore
# #############################################################################
$sb->load_file('master', 'samples/issue_30.sql');
`rm -rf $basedir`;
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25`;
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
$output = `$mysql -e 'SELECT * FROM test.issue_30' | diff samples/issue_30_all_rows.txt -`;
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
$output = `$mysql -e 'SELECT * FROM test.issue_30' | diff samples/issue_30_partial_chunk_2.txt -`;
ok(
   !$output,
   'Resume restored atomic chunks (issue 30)'
);

`rm -rf $basedir`;

# Test that resume doesn't do anything on a tab dump because there's
# no chunks file
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --tab`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test --local --tab $basedir/test/ 2>&1`;
like($output, qr/Cannot resume restore: no chunks file/, 'Does not resume --tab dump (issue 30)');

`rm -rf $basedir/`;

# Test that resume doesn't do anything on non-chunked dump because
# there's only 1 chunk: where 1=1
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 10000`;
$output = `MKDEBUG=1 $cmd --no-atomic-resume -D test $basedir/test/ 2>&1`;
like(
   $output,
   qr/Cannot resume restore: only 1 chunk \(1=1\)/,
   'Does not resume single chunk where 1=1 (issue 30)'
);

`rm -rf $basedir`;

# #############################################################################
# Issue 221: mk-parallel-restore resume functionality broken
# #############################################################################

# Test that resume does not die if the table isn't present.
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25`;
`$mysql -D test -e 'DROP TABLE issue_30'`;
$output = `MKDEBUG=1 $cmd -D test $basedir/test/ 2>&1 | grep Restoring`;
like($output, qr/Restoring from chunk 0 because table `test`.`issue_30` does not exist/, 'Resume does not die when table is not present (issue 221)');

`rm -rf $basedir`;

# #############################################################################
# Issue 57: mk-parallel-restore with --tab doesn't fully replicate 
# #############################################################################

# This test relies on the issue_30 table created somewhere above.

my $slave_dbh = $sb->get_dbh_for('slave1');
SKIP: {
   skip 'Cannot connect to sandbox slave', 10 unless $slave_dbh;

   `../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --tab`;

   # By default a --tab restore should not replicate.
   diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
   $slave_dbh->do('USE test');
   my $res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
   ok(!scalar @$res, 'Slave does not have table before --tab restore');

   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   my $master_pos = $res->[0]->[1];

   `$cmd --tab --replace --local --database test $basedir`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
   ok(!scalar @$res, 'Slave does not have table after --tab restore');

   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');

   # Test that a --tab --bin-log overrides default behavoir
   # and replicates the restore.
   diag(`/tmp/12345/use -e 'SET SQL_LOG_BIN=0; DROP TABLE IF EXISTS test.issue_30'`);
   `$cmd --bin-log --tab --replace --local --database test $basedir`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SELECT * FROM test.issue_30');
   is(scalar @$res, 66, '--tab with --bin-log allows replication');


   # Check that non-tab restores do replicate by default.
   `rm -rf $basedir/`;
   `../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25`;

   diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
   `$cmd $basedir`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SELECT * FROM test.issue_30');
   is(scalar @$res, 66, 'Non-tab restore replicates by default');

   # Make doubly sure that for a restore that defaults to bin-log
   # that --no-bin-log truly prevents binary logging/replication.
   diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   $master_pos = $res->[0]->[1];

   `$cmd --no-bin-log $basedir`;
   sleep 1;

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
   ok(!scalar @$res, 'Non-tab restore does not replicate with --no-bin-log');

   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');

   # Check that triggers are neither restored nor replicated.
   `$cmd ./samples/tbls_with_trig/ --no-bin-log`;
   sleep 1;

   $dbh->do('USE test');
   $res = $dbh->selectall_arrayref('SHOW TRIGGERS');
   is_deeply($res, [], 'Triggers are not restored');

   $slave_dbh->do('USE test');
   $res = $slave_dbh->selectall_arrayref('SHOW TRIGGERS');
   is_deeply($res, [], 'Triggers are not replicated');

   $res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
   is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');
};

# #############################################################################
# Issue 406: Use of uninitialized value in concatenation (.) or string at
# ./mk-parallel-restore line 1808
# #############################################################################

# This test restores a dump of test.issue_30 done in the above SKIP block.
# So if that block was skipped, we need to dump the table ourselves.
`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25` unless $slave_dbh;

$sb->load_file('master', 'samples/issue_30.sql');
$output = `$cmd -D test $basedir 2>&1`;

unlike(
   $output,
   qr/uninitialized value/,
   'No error restoring table that already exists (issue 406)'
);
like(
   $output,
   qr/1 tables,\s+4 files,\s+1 successes,\s+0 failures/,
   'Restoring table that already exists (issue 406)'
);

# #############################################################################
# Issue 534: mk-parallel-restore --threads is being ignored
# #############################################################################
$output = `$cmd --help --threads 32 2>&1`;
like(
   $output,
   qr/--threads\s+32/,
   '--threads overrides /proc/cpuinfo (issue 534)'
);

# ###########################################################################
# Issue 391: Add --pid option to all scripts
# ###########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd -D test $basedir --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
#  Issue 624: mk-parallel-dump --databases does not filter restored databases
# #############################################################################
$dbh->do('DROP DATABASE IF EXISTS issue_624');
$dbh->do('CREATE DATABASE issue_624');
$dbh->do('USE issue_624');

$output = `$cmd samples/issue_624/ -D issue_624 -d d2`;

is_deeply(
   $dbh->selectall_arrayref('SELECT * FROM issue_624.t2'),
   [ [4],[5],[6] ],
   '--databases filters restored dbs (issue 624)'
);

# #############################################################################
# Issue 506: mk-parallel-restore might cause a slave error when checking if
# table exists
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox slave', 4 unless $slave_dbh;

   $sb->load_file('master', 'samples/issue_506.sql');
   sleep 1;

   diag(`rm -rf $basedir`);
   `../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d issue_506 --chunk-size 5`;
   $dbh->do('TRUNCATE TABLE issue_506.t');
   sleep 1;
   $slave_dbh->do('DROP TABLE issue_506.t');

   is_deeply(
      $slave_dbh->selectall_arrayref('show tables from issue_506'),
      [],
      'Table does not exist on slave (issue 506)'
   );

   is(
      $slave_dbh->selectrow_hashref('show slave status')->{Last_Error},
      '',
      'No slave error before restore (issue 506)'
   );

   `$cmd $basedir/issue_506`;

   is(
      $slave_dbh->selectrow_hashref('show slave status')->{Last_Error},
      '',
      'No slave error after restore (issue 506)'
   );

   $slave_dbh->do('stop slave');
   $slave_dbh->do('set global SQL_SLAVE_SKIP_COUNTER=1');
   $slave_dbh->do('start slave');

   is_deeply(
      $slave_dbh->selectrow_hashref('show slave status')->{Last_Error},
      '',
      'No slave error (issue 506)'
   );
};

# #############################################################################
# Issue 507: Does D DSN part require special handling in mk-parallel-restore?
# #############################################################################

# I thought that no special handling was needed but I was wrong.
# The db might not exists (user might be using --create-databases)
# in which case DSN D might try to use an as-of-yet nonexistent db.

`../../mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d issue_506`;
$dbh->do('DROP TABLE IF EXISTS issue_506.t');
$dbh->do('DROP TABLE IF EXISTS issue_624.t');

`$cmd -D issue_624 $basedir/issue_506 2>&1`;

is_deeply(
   $dbh->selectall_arrayref('show tables from issue_624'),
   [['t'],['t2']],
   'Table was restored into -D database'
);

is_deeply(
   $dbh->selectall_arrayref('show tables from issue_506'),
   [],
   'Table was not restored into DSN D database'
);

# #############################################################################
# Issue 625: mk-parallel-restore throws errors for files restored by some
# versions of mysqldump
# #############################################################################
$output = `$cmd --create-databases samples/issue_625`;

like(
   $output,
   qr/0\s+failures,/,
   'Restore older mysqldump, no failure (issue 625)'
);
is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [[1],[2],[3]],
   'Restore older mysqldump, data restored (issue 625)'
);

# #############################################################################
# Issue 300: restore only to empty databases
# #############################################################################
# This test re-uses issue_625 restored above.

$dbh->do('truncate table issue_625.t');
$output = `$cmd --only-empty-databases samples/issue_625`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [],
   'Did not restore non-empty database (issue 300)',
);
like(
   $output,
   qr/database issue_625 is not empty/,
   'Says file was skipped because database is not empty (issue 300)'
);
like(
   $output,
   qr/0\s+files/,
   'Zero files restored (issue 300)'
);

$dbh->do('drop database if exists issue_625');
$output = `$cmd --create-databases --only-empty-databases samples/issue_625`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [[1],[2],[3]],
   '--create-databases --only-empty-databases (issue 300)',
);


# #############################################################################
# Test that --create-databases won't replicate with --no-bin-log.
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox slave', 3 unless $slave_dbh;
   $dbh->do('DROP DATABASE IF EXISTS issue_625');
   sleep 1;

   is_deeply(
      $slave_dbh->selectall_arrayref("show databases like 'issue_625'"),
      [],
      "Database doesn't exist on slave"
   );
  
   my $master_pos = $dbh->selectall_arrayref('SHOW MASTER STATUS')->[0]->[1];

   `$cmd samples/issue_625 --create-databases --no-bin-log`;

   is_deeply(
      $slave_dbh->selectall_arrayref("show databases like 'issue_625'"),
      [],
      "Database still doesn't exist on slave"
   );
   is(
      $dbh->selectall_arrayref('SHOW MASTER STATUS')->[0]->[1],
      $master_pos,
      "Bin log pos unchanged ($master_pos)"
   );
};

# #############################################################################
# Test "pure" restore and attendant options.
# #############################################################################

$output = `$cmd samples/fast_index --dry-run --quiet -t store`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`store`
CREATE TABLE `store` (
  `store_id` tinyint(3) unsigned NOT NULL auto_increment,
  `manager_staff_id` tinyint(3) unsigned NOT NULL,
  `address_id` smallint(5) unsigned NOT NULL,
  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`store_id`),
  UNIQUE KEY `idx_unique_manager` (`manager_staff_id`),
  KEY `idx_fk_address_id` (`address_id`),
  CONSTRAINT `fk_store_staff` FOREIGN KEY (`manager_staff_id`) REFERENCES `staff` (`staff_id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_store_address` FOREIGN KEY (`address_id`) REFERENCES `address` (`address_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8
USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
",
   'Pure restore'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store --no-drop-tables`;
is(
   $output,
"USE `sakila`
CREATE TABLE `store` (
  `store_id` tinyint(3) unsigned NOT NULL auto_increment,
  `manager_staff_id` tinyint(3) unsigned NOT NULL,
  `address_id` smallint(5) unsigned NOT NULL,
  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`store_id`),
  UNIQUE KEY `idx_unique_manager` (`manager_staff_id`),
  KEY `idx_fk_address_id` (`address_id`),
  CONSTRAINT `fk_store_staff` FOREIGN KEY (`manager_staff_id`) REFERENCES `staff` (`staff_id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_store_address` FOREIGN KEY (`address_id`) REFERENCES `address` (`address_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8
USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
",
   '--no-drop-tables'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store --no-create-tables`;
is(
   $output,
"USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
",
   '--no-create-tables'
);

# #############################################################################
# Test --fast-index.
# #############################################################################
$output = `$cmd samples/fast_index --dry-run --quiet -t store --fast-index`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`store`
CREATE TABLE `store` (
  `store_id` tinyint(3) unsigned NOT NULL auto_increment,
  `manager_staff_id` tinyint(3) unsigned NOT NULL,
  `address_id` smallint(5) unsigned NOT NULL,
  `last_update` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`store_id`),
  CONSTRAINT `fk_store_staff` FOREIGN KEY (`manager_staff_id`) REFERENCES `staff` (`staff_id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_store_address` FOREIGN KEY (`address_id`) REFERENCES `address` (`address_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8
USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `store` VALUES (1,1,1,'2006-02-15 11:57:12'),(2,2,2,'2006-02-15 11:57:12');
ALTER TABLE `sakila`.`store` ADD KEY `idx_fk_address_id` (`address_id`), ADD UNIQUE KEY `idx_unique_manager` (`manager_staff_id`)
",
   '--fast-index'
);

# This table should not be affected by --fast-index because it's not InnoDB.
$output = `$cmd samples/fast_index --dry-run --quiet -t store --fast-index -t film_text`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--fast-index on non-InnoDB table'
);

# #############################################################################
# Test stuff like --disable-keys, --unique-checks, etc.
# #############################################################################
$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   'Disables/enables keys by default for MyISAM table'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-disable-keys`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
",
   'Does not disables/enables keys with --no-disable-keys'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-no-auto-value-on-0`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--no-no-auto-value-on-0'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-unique-checks`;
is(
   $output,
"USE `sakila`
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
SET UNIQUE_CHECKS=0
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--no-unique-checks'
);

$output = `$cmd samples/fast_index --dry-run --quiet -t store -t film_text --no-foreign-key-checks`;
is(
   $output,
"USE `sakila`
SET FOREIGN_KEY_CHECKS=0
DROP TABLE IF EXISTS `sakila`.`film_text`
CREATE TABLE `film_text` (
  `film_id` smallint(6) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY  (`film_id`),
  KEY  (`title`),
  FULLTEXT KEY `idx_title_description` (`title`,`description`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8

USE `sakila`
/*!40000 ALTER TABLE `sakila`.`film_text` DISABLE KEYS */
/*!40101 SET SQL_MODE=\"NO_AUTO_VALUE_ON_ZERO\" */
SET FOREIGN_KEY_CHECKS=0
INSERT INTO `film_text` VALUES (1,'ACADEMY DINOSAUR','A Epic Drama of a Feminist And a Mad Scientist who must Battle a Teacher in The Canadian Rockies');
/*!40000 ALTER TABLE `sakila`.`film_text` ENABLE KEYS */
",
   '--no-foreign-key-checks'
);

# " # fix my syntax highlighting because of that ^

# #############################################################################
# Issue 703: mk-parallel-restore cannot create tables with constraints
# #############################################################################
$dbh->do('DROP TABLE IF EXISTS test.store');
`$cmd samples/fast_index/ -D test -t store --no-foreign-key-checks 2>&1`;
is_deeply(
   $dbh->selectall_arrayref("show tables from `test` like 'store'"),
   [['store']],
   'Restore table with foreign key constraints (issue 703)'
);

# #############################################################################
# Done.
# #############################################################################
`rm -rf $basedir/`;
$sb->wipe_clean($dbh);
exit;
