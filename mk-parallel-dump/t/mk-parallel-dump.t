#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 38;

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

`rm -rf /tmp/default`;
`rm -rf /tmp/sakila`;
`rm -rf /tmp/test`;

SKIP: {
   skip 'Sandbox master does not have the sakila database', 24
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $output = `$cmd --chunk-size 100 --base-dir /tmp --tab -d sakila -t film`;
   my ($tbl, $chunk) = $output =~ m/Final results:\s+(\d+) tables,\s+(\d+) chunks/;
   is($tbl, 1, 'One table dumped');
   ok($chunk >= 5 && $chunk <= 15, 'Got some chunks');
   ok(-s '/tmp/sakila/film.000005.txt', 'chunk 5 exists');
   ok(-s '/tmp/default/00_master_data.sql', 'master_data exists');
   `rm -rf /tmp/default`;

   # Fixes bug #1851461.
   `$mysql -e 'drop database if exists foo'`;
   `$mysql -e 'create database foo'`;
   `$mysql -e 'create table foo.bar(a int) engine=myisam'`;
   `$mysql -e 'insert into foo.bar(a) values(123)'`;
   `$mysql -e 'create table foo.mrg(a int) engine=merge union=(foo.bar)'`;
   $output = `$cmd --chunk-size 100 --base-dir /tmp --tab -d foo`;
   ok(-f '/tmp/foo/mrg.000000.sql', 'Merge table was dumped');
   $output = `zgrep 123 /tmp/foo/mrg.000000.sql`;
   chomp $output;
   ok(!-f '/tmp/foo/mrg.000000.txt',
      'No tab-delim file found, so no data dumped');

   # And again, without --tab
   $output = `$cmd --chunk-size 100 --base-dir /tmp -d foo`;
   ok(-f '/tmp/foo/mrg.000000.sql', 'Merge table was dumped');
   $output = `zgrep 123 /tmp/foo/mrg.000000.sql`;
   chomp $output;
   is($output, '', '123 is not in the dumped file, so no data dumped');
   `$mysql -e 'drop database if exists foo'`;
   `rm -rf /tmp/default`;

   # Fixes bug #1850998 (workaround for MySQL bug #29408)
   `$mysql < samples/bug_29408.sql`;
   $output = `$cmd --ignore-engines foo --chunk-size 100 --base-dir /tmp --tab -d mk_parallel_dump_foo 2>&1`;
   unlike($output, qr/No database selected/, 'Bug did not affect it');
   `$mysql -e 'drop database if exists mk_parallel_dump_foo'`;
   `rm -rf /tmp/default`;

   # Make sure subsequent chunks don't have DROP/CREATE in them (fixes bug
   # #1863949).
   $output = `$cmd --chunk-size 100 --base-dir /tmp -d sakila -t film 2>&1`;
   ok(-f '/tmp/sakila/film.000000.sql', 'first chunk file exists');
   ok(-f '/tmp/sakila/film.000001.sql', 'second chunk file exists');
   $output = `grep -i 'DROP TABLE' /tmp/sakila/film.000000.sql`;
   like($output, qr/DROP TABLE/i, 'first chunk has DROP TABLE');
   $output = `grep -i 'DROP TABLE' /tmp/sakila/film.000001.sql`;
   unlike($output, qr/DROP TABLE/i, 'second chunk has no DROP TABLE');
   $output = `grep -i 'CREATE TABLE' /tmp/sakila/film.000000.sql`;
   like($output, qr/CREATE TABLE/i, 'first chunk has CREATE TABLE');
   $output = `grep -i 'CREATE TABLE' /tmp/sakila/film.000001.sql`;
   unlike($output, qr/CREATE TABLE/i, 'second chunk has no CREATE TABLE');
   `rm -rf /tmp/default`;

   # But also make sure mysqldump gets the --no-create-info argument, not
   # gzip...! (fixes bug #1866137)
   $output = `$cmd --quiet --chunk-size 100 --base-dir /tmp -d sakila -t film 2>&1`;
   is($output, '', 'There is no output');
   ok(-f '/tmp/sakila/film.000000.sql', 'first chunk file exists');
   ok(-f '/tmp/sakila/film.000001.sql', 'second chunk file exists');
   $output = `zgrep -i 'DROP TABLE' /tmp/sakila/film.000000.sql`;
   like($output, qr/DROP TABLE/i, 'first chunk has DROP TABLE');
   $output = `zgrep -i 'DROP TABLE' /tmp/sakila/film.000001.sql`;
   unlike($output, qr/DROP TABLE/i, 'second chunk has no DROP TABLE');
   $output = `zgrep -i 'INSERT INTO' /tmp/sakila/film.000001.sql`;
   like($output,   qr/INSERT INTO/i, 'second chunk does have data, though');
   $output = `zgrep -i 'CREATE TABLE' /tmp/sakila/film.000000.sql`;
   like($output, qr/CREATE TABLE/i, 'first chunk has CREATE TABLE');
   $output = `zgrep -i 'CREATE TABLE' /tmp/sakila/film.000001.sql`;
   unlike($output, qr/CREATE TABLE/i, 'second chunk has no CREATE TABLE');
   `rm -rf /tmp/default`;


   # ##########################################################################
   # Issue 31: Make mk-parallel-dump and mk-parallel-restore do biggest-first
   ############################################################################
   $output = `MKDEBUG=1 $cmd --base-dir /tmp -d sakila 2>&1 | grep -A 6 ' got ' | grep 'Z => ' | awk '{print \$4}' | cut -f1 -d',' | sort --numeric-sort --check --reverse 2>&1`;
   unlike($output, qr/disorder/, 'Tables dumped biggest-first by default');   
   `rm -rf /tmp/default`;
}

# #############################################################################
# Issue 223: mk-parallel-dump includes trig definitions into each chunk file
# #############################################################################

# Triggers are no longer dumped, but we'll keep part of this test to make
# sure triggers really aren't dumped.

$sb->load_file('master', 'samples/issue_223.sql');
diag(`rm -rf /tmp/default/`);

# Dump table t1 and make sure its trig def is not in any chunk.
diag(`MKDEBUG=1 $cmd --base-dir /tmp/ --chunk-size 30 -d test 1>/dev/null 2>/dev/null`);
is(
   `cat /tmp/test/t1.000000.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 0 (issue 223)'
);
is(
   `cat /tmp/test/t1.000001.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 1 (issue 223)'
);
ok(
   !-f '/tmp/test/t1.000000.trg',
   'No triggers dumped'
);

# #############################################################################
# Issue 275: mk-parallel-dump --chunksize does not work properly with --csv
# #############################################################################

# This test relies on issue_223.sql loaded above which creates test.t1.

# There should be 56 rows total, so --chunk-size 28 should make 2 chunks.
# And since the range of vals is 1..999, those chunks will be
# < 500 and >= 500. Furthermore, the top 2 vals are 100 and 999,
# so the 2nd chunk should contain only 999.
diag(`rm -rf /tmp/default/`);
diag(`$cmd --base-dir /tmp/ --csv --chunk-size 28 -d test -t t1 > /dev/null`);

$output = `wc -l /tmp/test/t1.000000.txt`;
like($output, qr/55/, 'First chunk of csv dump (issue 275)');

$output = `wc -l /tmp/test/t1.000001.txt`;
is($output, "999\n", 'Second chunk of csv dump (issue 275)');


# #############################################################################
# Issue 170: mk-parallel-dump dies when table-status Data_length is NULL
# #############################################################################
diag(`rm -rf /tmp/default/`);
diag(`cp samples/broken_tbl.frm /tmp/12345/data/test/broken_tbl.frm`);
$output = `$cmd --base-dir /tmp/ -d test 2>&1`;
like(
   $output,
   qr/\d tables,\s+\d chunks,\s+1 failures/,
   'Runs but does not die on broken table'
);
diag(`rm -rf /tmp/12345/data/test/broken_tbl.frm`);

# #############################################################################
# Issue 534: mk-parallel-restore --threads is being ignored
# #############################################################################
$output = `$cmd --help --threads 32 2>&1`;
like(
   $output,
   qr/--threads\s+32/,
   '--threads overrides /proc/cpuinfo (issue 534)'
);

# #############################################################################
# Issue 446: mk-parallel-dump cannot make filenames for tables with spaces
# in their names
# #############################################################################
diag(`rm -rf /tmp/default`);
$dbh->do('USE test');
$dbh->do('CREATE TABLE `issue 446` (i int)');
$dbh->do('INSERT INTO test.`issue 446` VALUES (1),(2),(3)');

`$cmd --base-dir /tmp/ --ignore-databases sakila --databases test --tables 'issue 446' 2>&1`;
ok(
   -f '/tmp/test/issue 446.000000.sql',
   'Dumped table with space in name (issue 446)'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd --base-dir /tmp/ --ignore-databases sakila --databases test --tables 'issue 446' --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf /tmp/default/`);
$sb->wipe_clean($dbh);
exit;
