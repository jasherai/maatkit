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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to MySQL';
}
elsif ( !@{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')} ) {
   plan skip_all => 'sakila db not loaded';
}
else {
   plan tests => 24;
}

my $cnf   = '/tmp/12345/my.sandbox.cnf';
my $cmd   = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

use File::Find;
sub get_files {
   my ( $dir ) = @_;
   my @files;
   find sub {
      return if -d;
      push @files, $File::Find::name;
   }, $dir;
   @files = sort @files;
   return \@files;
}

# ###########################################################################
# Test actual dumping.
# ###########################################################################

$output = `$cmd --chunk-size 100 --base-dir $basedir --tab -d sakila -t film --progress`;
my ($tbl, $chunk) = $output =~ m/(\d+) tables,\s+(\d+) chunks/;
is($tbl, 1, 'One table dumped');
ok($chunk >= 5 && $chunk <= 15, 'Got some chunks');
ok(-s "$basedir/sakila/film.000005.txt", 'chunk 5 exists');
ok(-s "$basedir//00_master_data.sql", 'master_data exists');
diag(`rm -rf $basedir`);

# Fixes bug #1851461.
`$mysql -e 'drop database if exists foo'`;
`$mysql -e 'create database foo'`;
`$mysql -e 'create table foo.bar(a int) engine=myisam'`;
`$mysql -e 'insert into foo.bar(a) values(123)'`;
`$mysql -e 'create table foo.mrg(a int) engine=merge union=(foo.bar)'`;
$output = `$cmd --chunk-size 100 --base-dir $basedir --tab -d foo`;
ok(!-f "$basedir/foo/mrg.000000.sql", 'Merge table not dumped by default with --tab');
ok(!-f "$basedir/foo/mrg.000000.txt", 'No tab-delim file found, so no data dumped');

# And again, without --tab
diag(`rm -rf $basedir`);
$output = `$cmd --chunk-size 100 --base-dir $basedir -d foo`;
ok(!-f "$basedir/foo/mrg.000000.sql", 'Merge table not dumped by default');
`$mysql -e 'drop database if exists foo'`;
diag(`rm -rf $basedir`);

# Fixes bug #1850998 (workaround for MySQL bug #29408)
`$mysql < $trunk/mk-parallel-dump/t/samples/bug_29408.sql`;
$output = `$cmd --ignore-engines foo --chunk-size 100 --base-dir $basedir --tab -d mk_parallel_dump_foo 2>&1`;
unlike($output, qr/No database selected/, 'Bug did not affect it');
`$mysql -e 'drop database if exists mk_parallel_dump_foo'`;
diag(`rm -rf $basedir`);

# Make sure subsequent chunks don't have DROP/CREATE in them (fixes bug
# #1863949).
$output = `$cmd --quiet --chunk-size 100 --base-dir $basedir -d sakila -t film`;

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

diag(`rm -rf $basedir`);

# #########################################################################
# Issue 495: mk-parallel-dump: permit to disable resuming behavior
# #########################################################################
diag(`$cmd --base-dir $basedir -d sakila -t film,actor > /dev/null`);
$output = `$cmd --base-dir $basedir -d sakila -t film,actor --no-resume -v 2>&1`;
like(
   $output,
   qr/all\s+\S+\s+0\s+0\s+\-/,
   '--no-resume (no chunks)'
);

diag(`rm -rf $basedir`);
diag(`$cmd --base-dir $basedir -d sakila -t film,actor --chunk-size 100 > /dev/null`);
$output = `$cmd --base-dir $basedir -d sakila -t film,actor --no-resume -v --chunk-size 100 2>&1`;
like(
   $output,
   qr/all\s+\S+\s+0\s+0\s+\-/,
   '--no-resume (with chunks)'
);

# #########################################################################
# Issue 573: 'mk-parallel-dump --progress --ignore-engine MyISAM' Reports
# progress incorrectly
# #########################################################################
# For this issue we'll also test the filters in general, specially
# the engine filters as they were previously treated specially.
# sakila is mostly InnoDB tables so load some MyISAM tables.
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_560.sql`);
diag(`/tmp/12345/use < $trunk/mk-table-sync/t/samples/issue_375.sql`);
diag(`rm -rf $basedir`);

# film_text is the only non-InnoDB table (it's MyISAM).
$output = `$cmd --base-dir $basedir -d sakila --ignore-engines InnoDB --progress`;
like(
   $output,
   qr/1 databases, 1 tables, 1 chunks/,
   '--ignore-engines InnoDB'
);

# Make very sure that it dumped only film_text.
is_deeply(
   get_files($basedir),
   [
      "${basedir}00_master_data.sql",
      "${basedir}sakila/00_film_text.sql",
      "${basedir}sakila/film_text.000000.sql",
   ],
   '--ignore-engines InnoDB dumped files'
);

diag(`rm -rf $basedir`);

$output = `$cmd --base-dir $basedir -d sakila --ignore-engines InnoDB --tab --progress`;
like(
   $output,
   qr/1 databases, 1 tables, 1 chunks/,
   '--ignore-engines InnoDB --tab'
);
is_deeply(
   get_files($basedir),
   [
      "${basedir}00_master_data.sql",
      "${basedir}sakila/00_film_text.sql",
      "${basedir}sakila/film_text.000000.txt",
   ],
   '--ignore-engines InnoDB --tab dumped files'
);

diag(`rm -rf $basedir`);

# Only issue_560.buddy_list is InnoDB so only its size should be used
# to calculate --progress.
$output = `$cmd --base-dir $basedir -d issue_375,issue_560 --ignore-engines MyISAM --progress`;
like(
   $output,
   qr/16\.00k\/16\.00k 100\.00% ETA 00:00/,
   "--progress doesn't count skipped tables (issue 573)"
); 

diag(`rm -rf $basedir`);

# #############################################################################
# Done.
# #############################################################################
exit;
