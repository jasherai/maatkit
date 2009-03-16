#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 30;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-parallel-dump -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
SKIP: {
   skip 'Sandbox master does not have the sakila database', 24
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $output = `$cmd --C 100 --basedir /tmp -T --d sakila --t film`;
   my ($tbl, $chunk) = $output =~ m/default:\s+(\d+) tables,\s+(\d+) chunks,\s+\2 successes/;
   is($tbl, 1, 'One table dumped');
   ok($chunk >= 5 && $chunk <= 15, 'Got some chunks');
   ok(-s '/tmp/default/sakila/film.000005.txt.gz', 'chunk 5 exists');
   ok(-s '/tmp/default/00_master_data.sql', 'master_data exists');
   `rm -rf /tmp/default`;

   # Fixes bug #1851461.
   `$mysql -e 'drop database if exists foo'`;
   `$mysql -e 'create database foo'`;
   `$mysql -e 'create table foo.bar(a int) engine=myisam'`;
   `$mysql -e 'insert into foo.bar(a) values(123)'`;
   `$mysql -e 'create table foo.mrg(a int) engine=merge union=(foo.bar)'`;
   $output = `$cmd -C 100 --basedir /tmp -T --d foo`;
   ok(-f '/tmp/default/foo/mrg.000000.sql.gz', 'Merge table was dumped');
   $output = `zgrep 123 /tmp/default/foo/mrg.000000.sql.gz`;
   chomp $output;
   ok(!-f '/tmp/default/foo/mrg.000000.txt.gz',
      'No tab-delim file found, so no data dumped');
   # And again, without --tab
   $output = `$cmd -C 100 --basedir /tmp --d foo`;
   ok(-f '/tmp/default/foo/mrg.000000.sql.gz', 'Merge table was dumped');
   $output = `zgrep 123 /tmp/default/foo/mrg.000000.sql.gz`;
   chomp $output;
   is($output, '', '123 is not in the dumped file, so no data dumped');
   `$mysql -e 'drop database if exists foo'`;
   `rm -rf /tmp/default`;

   # Fixes bug #1850998 (workaround for MySQL bug #29408)
   `$mysql < samples/bug_29408.sql`;
   $output = `$cmd -E foo -C 100 --basedir /tmp -T --d mk_parallel_dump_foo 2>&1`;
   unlike($output, qr/No database selected/, 'Bug did not affect it');
   `$mysql -e 'drop database if exists mk_parallel_dump_foo'`;
   `rm -rf /tmp/default`;

   # Make sure subsequent chunks don't have DROP/CREATE in them (fixes bug
   # #1863949).
   $output = `$cmd -C 100 --no-gzip --basedir /tmp -d sakila -t film 2>&1`;
   ok(-f '/tmp/default/sakila/film.000000.sql', 'first chunk file exists');
   ok(-f '/tmp/default/sakila/film.000001.sql', 'second chunk file exists');
   $output = `grep -i 'DROP TABLE' /tmp/default/sakila/film.000000.sql`;
   like($output, qr/DROP TABLE/i, 'first chunk has DROP TABLE');
   $output = `grep -i 'DROP TABLE' /tmp/default/sakila/film.000001.sql`;
   unlike($output, qr/DROP TABLE/i, 'second chunk has no DROP TABLE');
   $output = `grep -i 'CREATE TABLE' /tmp/default/sakila/film.000000.sql`;
   like($output, qr/CREATE TABLE/i, 'first chunk has CREATE TABLE');
   $output = `grep -i 'CREATE TABLE' /tmp/default/sakila/film.000001.sql`;
   unlike($output, qr/CREATE TABLE/i, 'second chunk has no CREATE TABLE');
   `rm -rf /tmp/default`;

   # But also make sure mysqldump gets the --no-create-info argument, not
   # gzip...! (fixes bug #1866137)
   $output = `$cmd --quiet -C 100 --basedir /tmp -d sakila -t film 2>&1`;
   is($output, '', 'There is no output');
   ok(-f '/tmp/default/sakila/film.000000.sql.gz', 'first chunk file exists');
   ok(-f '/tmp/default/sakila/film.000001.sql.gz', 'second chunk file exists');
   $output = `zgrep -i 'DROP TABLE' /tmp/default/sakila/film.000000.sql.gz`;
   like($output, qr/DROP TABLE/i, 'first chunk has DROP TABLE');
   $output = `zgrep -i 'DROP TABLE' /tmp/default/sakila/film.000001.sql.gz`;
   unlike($output, qr/DROP TABLE/i, 'second chunk has no DROP TABLE');
   $output = `zgrep -i 'INSERT INTO' /tmp/default/sakila/film.000001.sql.gz`;
   like($output,   qr/INSERT INTO/i, 'second chunk does have data, though');
   $output = `zgrep -i 'CREATE TABLE' /tmp/default/sakila/film.000000.sql.gz`;
   like($output, qr/CREATE TABLE/i, 'first chunk has CREATE TABLE');
   $output = `zgrep -i 'CREATE TABLE' /tmp/default/sakila/film.000001.sql.gz`;
   unlike($output, qr/CREATE TABLE/i, 'second chunk has no CREATE TABLE');
   `rm -rf /tmp/default`;


   # ##########################################################################
   # Issue 31: Make mk-parallel-dump and mk-parallel-restore do biggest-first
   ############################################################################
   $output = `MKDEBUG=1 $cmd --basedir /tmp -d sakila 2>&1 | grep -A 6 ' got ' | grep 'Z => ' | awk '{print \$4}' | cut -f1 -d',' | sort --numeric-sort --check --reverse 2>&1`;
   unlike($output, qr/disorder/, 'Tables dumped biggest-first by default');   
   `rm -rf /tmp/default`;
}

# #############################################################################
# Issue 223: mk-parallel-dump includes trig definitions into each chunk file
# #############################################################################
$sb->load_file('master', 'samples/issue_223.sql');
diag(`rm -rf /tmp/default/`);

# Dump table t1 and make sure its trig def is not in any chunk.
diag(`MKDEBUG=1 $cmd --basedir /tmp/ -C 30 -d test 1>/dev/null 2>/dev/null`);
is(
   `zcat /tmp/default/test/t1.000000.sql.gz | grep TRIGGER`,
   '',
   'No trigger def in chunk 0 (issue 223)'
);
is(
   `zcat /tmp/default/test/t1.000001.sql.gz | grep TRIGGER`,
   '',
   'No trigger def in chunk 1 (issue 223)'
);

# Restore t1 and make sure t2 is not affected by the t1 trigger.
diag(`$mysql -e 'TRUNCATE TABLE test.t1'`);
diag(`$mysql -e 'TRUNCATE TABLE test.t2'`);
diag(`../../mk-parallel-restore/mk-parallel-restore -F $cnf -d test /tmp/default/ 1>/dev/null 2>/dev/null`);
$output = $dbh->selectall_arrayref('SELECT * FROM test.t2');
is_deeply(
   $output,
   [],
   'Trigger restored after all table chunks (issue 223)'
);

# And for good measure, check that the trigger actually works.
$dbh->do('INSERT INTO test.t1 VALUES (999)');
$output = $dbh->selectall_arrayref('SELECT * FROM test.t2');
is_deeply(
   $output,
   [ [999] ],
   'Trigger still works after being restored (issue 223)'
);

# #############################################################################
# Issue 275: mk-parallel-dump --chunksize does not work properly with --csv
# #############################################################################

# This test relies on issue_223.sql loaded above which creates test.t1.

# There should be 56 rows total, so -C 28 should make 2 chunks.
# And since the range of vals is 1..999, those chunks will be
# < 500 and >= 500. Furthermore, the top 2 vals are 100 and 999,
# so the 2nd chunk should contain only 999.
diag(`rm -rf /tmp/default/`);
diag(`$cmd --basedir /tmp/ --csv -C 28 -d test -t t1 > /dev/null`);

$output = `gzip -d -c /tmp/default/test/t1.000000.txt.gz | wc -l`;
like($output, qr/55/, 'First chunk of csv dump (issue 275)');

$output = `gzip -d -c /tmp/default/test/t1.000001.txt.gz`;
is($output, "999\n", 'Second chunk of csv dump (issue 275)');

diag(`rm -rf /tmp/default/`);
$sb->wipe_clean($dbh);
exit;
