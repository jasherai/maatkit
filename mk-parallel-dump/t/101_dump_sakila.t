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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 19;
}

# Don't die when mk_parallel_dump::main() forks.
$dbh->{InactiveDestroy} = 1;

my $cnf   = '/tmp/12345/my.sandbox.cnf';
my $cmd   = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --no-gzip ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

# ###########################################################################
# Test actual dumping.
# ###########################################################################

$output = output(
   sub { mk_parallel_dump::main('-F', $cnf, qw(--chunk-size 100 --base-dir),
      $basedir, qw(--tab -d sakila -t film --progress --no-gzip)) }
);
my ($tbl, $chunk) = $output =~ m/(\d+) tables,\s+(\d+) chunks/;
is($tbl, 1, 'One table dumped');
ok($chunk >= 5 && $chunk <= 15, 'Got some chunks');
ok(-s "$basedir/sakila/film.000005.txt", 'chunk 5 exists');
ok(-s "$basedir/00_master_data.sql", 'master_data exists');
diag(`rm -rf $basedir`);

# Fixes bug #1851461.
`$mysql -e 'drop database if exists foo'`;
`$mysql -e 'create database foo'`;
`$mysql -e 'create table foo.bar(a int) engine=myisam'`;
`$mysql -e 'insert into foo.bar(a) values(123)'`;
`$mysql -e 'create table foo.mrg(a int) engine=merge union=(foo.bar)'`;

$output = output(
   sub { mk_parallel_dump::main('-F', $cnf, qw(--chunk-size 100 --base-dir),
      $basedir, qw(--tab -d foo --no-gzip)) }
);
ok(!-f "$basedir/foo/mrg.000000.sql", 'Merge table not dumped by default with --tab');
ok(!-f "$basedir/foo/mrg.000000.txt", 'No tab-delim file found, so no data dumped');

# And again, without --tab
diag(`rm -rf $basedir`);
$output = output(
   sub { mk_parallel_dump::main('-F', $cnf, qw(--chunk-size 100 --base-dir),
      $basedir,  qw(-d foo --no-gzip)) }
);
ok(!-f "$basedir/foo/mrg.000000.sql", 'Merge table not dumped by default');
`$mysql -e 'drop database if exists foo'`;
diag(`rm -rf $basedir`);

# Fixes bug #1850998 (workaround for MySQL bug #29408)
`$mysql < $trunk/mk-parallel-dump/t/samples/bug_29408.sql`;
$output = output(
   sub { mk_parallel_dump::main('-F', $cnf, qw(--ignore-engines foo),
      qw(--chunk-size 100 --base-dir), $basedir,
      qw(--tab -d mk_parallel_dump_foo --no-gzip)) }
);
unlike($output, qr/No database selected/, 'Bug did not affect it');
`$mysql -e 'drop database if exists mk_parallel_dump_foo'`;
diag(`rm -rf $basedir`);

# Make sure subsequent chunks don't have DROP/CREATE in them (fixes bug
# #1863949).
$output = output(
   sub { mk_parallel_dump::main('-F', $cnf, qw(--quiet --chunk-size 100),
      qw(--base-dir), $basedir, qw(-d sakila -t film --no-gzip)) }
);
is($output, '', 'No output with --quiet');

ok(-f "$basedir/sakila/00_film.sql", 'CREATE TABLE file exists');
ok(-f "$basedir/sakila/film.000000.sql", 'First chunk file exists');
ok(-f "$basedir/sakila/film.000001.sql", 'Second chunk file exists');

$output = `grep -i 'DROP TABLE' $basedir/sakila/film.000000.sql`;
is($output, '', 'First chunk does not have DROP TABLE');
$output = `grep -i 'DROP TABLE' $basedir/sakila/film.000001.sql`;
is($output, '', 'Second chunk does not have DROP TABLE');

$output = `grep -i 'CREATE TABLE' $basedir/sakila/00_film.sql`;
like($output, qr/CREATE TABLE/i, 'CREATE TABLE file has CREATE TABLE');
$output = `grep -i 'CREATE TABLE' $basedir/sakila/film.000000.sql`;
is($output, '', 'First chunk does not have CREATE TABLE');
$output = `grep -i 'CREATE TABLE' $basedir/sakila/film.000001.sql`;
is($output, '', 'Second chunk does not have CREATE TABLE');

# ###########################################################################
# Dump, restore and verify sakila database.
# ###########################################################################

$dbh->do('drop database if exists sakila2');
$dbh->do('create database sakila2');
output(
   sub { mk_parallel_dump::main('-F', $cnf, qw(--quiet --chunk-size 1000),
      qw(--base-dir), $basedir, qw(-d sakila)) }
);
$output = `$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf -h 127.1 $basedir -D sakila2 --no-foreign-key-checks 2>&1`;
like(
   $output,
   qr/16 tables,\s+\d+ files,\s+16 successes,\s+0 failures/,
   'Restored sakila'
);

# Checksum the original sakila db and the restored sakila2 db.
diag(`rm -rf /tmp/sakila*-checksum.txt`);
diag(`$trunk/mk-table-checksum/mk-table-checksum --algorithm CHECKSUM -F /tmp/12345/my.sandbox.cnf h=127.1,P=12345 -d sakila | awk '{print \$7}' > /tmp/sakila-checksum.txt 2>&1`);
diag(`$trunk/mk-table-checksum/mk-table-checksum --algorithm CHECKSUM -F /tmp/12345/my.sandbox.cnf h=127.1,P=12345 -d sakila2 | awk '{print \$7}' > /tmp/sakila2-checksum.txt 2>&1`);

$output = `diff /tmp/sakila-checksum.txt /tmp/sakila2-checksum.txt`;
is(
   $output,
   '',
   'Restored sakila checksums'
);

diag(`rm -rf /tmp/sakila*-checksum.txt`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
diag(`rm -rf $basedir`);
exit;
