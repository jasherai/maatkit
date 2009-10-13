#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 43;

require '../mk-parallel-dump';
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
   return \@files;
}

# ###########################################################################
# Test chunk_tables().
# ###########################################################################

# We want to make sure that it sets first_tbl_in_db, last_tbl_in_db, and
# last_chunk_in_tbl correctly.
my $q = new Quoter();
my $o = new OptionParser(
   description => 'mk-parallel-dump',
);
$o->get_specs('../mk-parallel-dump');
@ARGV = qw(--no-resume);
$o->get_opts();

my @tbls = (
   {
      tbl        => 't1',
      db         => 'd1',
      tbl_struct => {},
      size       => '12345',
   },
   {
      tbl        => 't2',
      db         => 'd1',
      tbl_struct => {},
      size       => '1234',
   },
   {
      tbl        => 't3',
      db         => 'd1',
      tbl_struct => {},
      size       => '123',
   },
);

my %args = (
   dbh          => 1,  # not needed
   tbls         => \@tbls,
   stat_totals  => {},
   stats_for    => {},
   OptionParser => $o,
   Quoter       => $q,
   TableChunker => 1,  # not needed
);

my $chunks = [
   {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't1',
    W => '1=1',
    Z => '12345',
    first_tbl_in_db => 1,
    last_chunk_in_tbl => 1
   },
   {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't2',
    W => '1=1',
    Z => '1234',
    last_chunk_in_tbl => 1
   },
   {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't3',
    W => '1=1',
    Z => '123',
    last_chunk_in_tbl => 1,
    last_tbl_in_db => 1
   },
];

is_deeply(
   [ mk_parallel_dump::chunk_tables(%args) ],
   $chunks,
   'chunk_tables(), 1 db with 3 tables'
);

# Add another db to the tables.
push @tbls, {
   tbl        => 't1',
   db         => 'd2',
   tbl_struct => {},
   size       => '120',
};
push @$chunks, {
    C => 0,
    D => 'd2',
    E => undef,
    L => '*',
    N => 't1',
    W => '1=1',
    Z => '120',
    last_chunk_in_tbl => 1,
    first_tbl_in_db   => 1,
    last_tbl_in_db    => 1,
};

is_deeply(
   [ mk_parallel_dump::chunk_tables(%args) ],
   $chunks,
   'chunk_tables(), 2 dbs'
);

# Now confuse it by adding another table, t4, from db1.  This can happen if
# t4 is smaller than db2.t1 because the tables are sorted by size.
push @tbls, {
   tbl        => 't4',
   db         => 'd1',
   tbl_struct => {},
   size       => '100',
};
push @$chunks, {
    C => 0,
    D => 'd1',
    E => undef,
    L => '*',
    N => 't4',
    W => '1=1',
    Z => '100',
    last_chunk_in_tbl => 1,
    last_tbl_in_db    => 1,
};
delete $chunks->[2]->{last_tbl_in_db};

is_deeply(
   [ mk_parallel_dump::chunk_tables(%args) ],
   $chunks,
   'chunk_tables(), 2 dbs mixed'
);

# ###########################################################################
# Test actual dumping.
# ###########################################################################
SKIP: {
   skip 'Sandbox master does not have the sakila database', 24
      unless @{$dbh->selectcol_arrayref('SHOW DATABASES LIKE "sakila"')};

   $output = `$cmd --chunk-size 100 --base-dir $basedir --tab -d sakila -t film`;
   my ($tbl, $chunk) = $output =~ m/Final results:\s+(\d+) tables,\s+(\d+) chunks/;
   is($tbl, 1, 'One table dumped');
   ok($chunk >= 5 && $chunk <= 15, 'Got some chunks');
   ok(-s "$basedir/sakila/film.000005.txt", 'chunk 5 exists');
   ok(-s "$basedir/default/00_master_data.sql", 'master_data exists');
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
   `$mysql < samples/bug_29408.sql`;
   $output = `$cmd --ignore-engines foo --chunk-size 100 --base-dir $basedir --tab -d mk_parallel_dump_foo 2>&1`;
   unlike($output, qr/No database selected/, 'Bug did not affect it');
   `$mysql -e 'drop database if exists mk_parallel_dump_foo'`;
   diag(`rm -rf $basedir`);

   # Make sure subsequent chunks don't have DROP/CREATE in them (fixes bug
   # #1863949).
   $output = `$cmd --chunk-size 100 --base-dir $basedir -d sakila -t film 2>&1`;
   ok(-f "$basedir/sakila/film.000000.sql", 'first chunk file exists');
   ok(-f "$basedir/sakila/film.000001.sql", 'second chunk file exists');
   $output = `grep -i 'DROP TABLE' $basedir/sakila/film.000000.sql`;
   like($output, qr/DROP TABLE/i, 'first chunk has DROP TABLE');
   $output = `grep -i 'DROP TABLE' $basedir/sakila/film.000001.sql`;
   unlike($output, qr/DROP TABLE/i, 'second chunk has no DROP TABLE');
   $output = `grep -i 'CREATE TABLE' $basedir/sakila/film.000000.sql`;
   like($output, qr/CREATE TABLE/i, 'first chunk has CREATE TABLE');
   $output = `grep -i 'CREATE TABLE' $basedir/sakila/film.000001.sql`;
   unlike($output, qr/CREATE TABLE/i, 'second chunk has no CREATE TABLE');
   diag(`rm -rf $basedir`);

   # But also make sure mysqldump gets the --no-create-info argument, not
   # gzip...! (fixes bug #1866137)
   $output = `$cmd --quiet --chunk-size 100 --base-dir $basedir -d sakila -t film 2>&1`;
   is($output, '', 'There is no output');
   ok(-f "$basedir/sakila/film.000000.sql", 'first chunk file exists');
   ok(-f "$basedir/sakila/film.000001.sql", 'second chunk file exists');
   $output = `zgrep -i 'DROP TABLE' $basedir/sakila/film.000000.sql`;
   like($output, qr/DROP TABLE/i, 'first chunk has DROP TABLE');
   $output = `zgrep -i 'DROP TABLE' $basedir/sakila/film.000001.sql`;
   unlike($output, qr/DROP TABLE/i, 'second chunk has no DROP TABLE');
   $output = `zgrep -i 'INSERT INTO' $basedir/sakila/film.000001.sql`;
   like($output,   qr/INSERT INTO/i, 'second chunk does have data, though');
   $output = `zgrep -i 'CREATE TABLE' $basedir/sakila/film.000000.sql`;
   like($output, qr/CREATE TABLE/i, 'first chunk has CREATE TABLE');
   $output = `zgrep -i 'CREATE TABLE' $basedir/sakila/film.000001.sql`;
   unlike($output, qr/CREATE TABLE/i, 'second chunk has no CREATE TABLE');
   diag(`rm -rf $basedir`);


   # ##########################################################################
   # Issue 31: Make mk-parallel-dump and mk-parallel-restore do biggest-first
   ############################################################################
   $output = `MKDEBUG=1 $cmd --base-dir $basedir -d sakila 2>&1 | grep -A 6 ' got ' | grep 'Z => ' | awk '{print \$4}' | cut -f1 -d',' | sort --numeric-sort --check --reverse 2>&1`;
   unlike($output, qr/disorder/, 'Tables dumped biggest-first by default');   
   diag(`rm -rf $basedir`);

   # #########################################################################
   # Issue 495: mk-parallel-dump: permit to disable resuming behavior
   # #########################################################################
   diag(`$cmd --base-dir $basedir -d sakila -t film,actor > /dev/null`);
   $output = `$cmd --base-dir $basedir -d sakila -t film,actor --no-resume -v 2>&1`;
   like(
      $output,
      qr/0 skipped,/,
      '--no-resume (no chunks)'
   );

   diag(`rm -rf $basedir`);
   diag(`$cmd --base-dir $basedir -d sakila -t film,actor --chunk-size 100 > /dev/null`);
   $output = `$cmd --base-dir $basedir -d sakila -t film,actor --no-resume -v --chunk-size 100 2>&1`;
   like(
      $output,
      qr/0 skipped,/,
      '--no-resume (with chunks)'
   );

   # #########################################################################
   # Issue 573: 'mk-parallel-dump --progress --ignore-engine MyISAM' Reports
   # progress incorrectly
   # #########################################################################
   # For this issue we'll also test the filters in general, specially
   # the engine filters as they were previously treated specially.
   # sakila is mostly InnoDB tables so load some MyISAM tables.
   diag(`/tmp/12345/use < ../../mk-table-sync/t/samples/issue_560.sql`);
   diag(`/tmp/12345/use < ../../mk-table-sync/t/samples/issue_375.sql`);
   diag(`rm -rf $basedir`);

   # film_text is the only non-InnoDB table (it's MyISAM).
   $output = `$cmd --base-dir $basedir -d sakila --ignore-engines InnoDB 2>&1`;
   like(
      $output,
      qr/^Database sakila:\s+1 tables,/,
      '--ignore-engines InnoDB'
   );
   # Make very sure that it dumped only film_text.
   is_deeply(
      get_files($basedir),
      [
         "${basedir}sakila/film_text.000000.sql",
         "${basedir}default/00_master_data.sql",
      ],
      '--ignore-engines InnoDB dumped files'
   );

   diag(`rm -rf $basedir`);

   $output = `$cmd --base-dir $basedir -d sakila --ignore-engines InnoDB --tab 2>&1`;
   like(
      $output,
      qr/^Database sakila:\s+1 tables,/,
      '--ignore-engines InnoDB --tab'
   );
   is_deeply(
      get_files($basedir),
      [
         "${basedir}sakila/film_text.000000.txt",
         "${basedir}sakila/film_text.000000.sql",
         "${basedir}default/00_master_data.sql",
      ],
      '--ignore-engines InnoDB --tab dumped files'
   );

   diag(`rm -rf $basedir`);

   # Only issue_560.buddy_list is InnoDB so only its size should be used
   # to calculate --progress.
   $output = `$cmd --base-dir $basedir -d issue_375,issue_560 --ignore-engines MyISAM --progress 2>&1 | grep done`;
   like(
      $output,
      qr/^done: 16\.00k\/16\.00k 100\.00% 00:00 remain/,
      "--progress doesn't count skipped tables (issue 573)"
   ); 
};

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 223: mk-parallel-dump includes trig definitions into each chunk file
# #############################################################################

# Triggers are no longer dumped, but we'll keep part of this test to make
# sure triggers really aren't dumped.

$sb->load_file('master', 'samples/issue_223.sql');
diag(`rm -rf $basedir`);

# Dump table t1 and make sure its trig def is not in any chunk.
diag(`MKDEBUG=1 $cmd --base-dir $basedir --chunk-size 30 -d test 1>/dev/null 2>/dev/null`);
is(
   `cat $basedir/test/t1.000000.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 0 (issue 223)'
);
is(
   `cat $basedir/test/t1.000001.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 1 (issue 223)'
);
ok(
   !-f '$basedir/test/t1.000000.trg',
   'No triggers dumped'
);

# #############################################################################
# Issue 275: mk-parallel-dump --chunksize does not work properly with --csv
# #############################################################################

# This test relies on issue_223.sql loaded above which creates test.t1.
# There are 55 rows and we add 1 more (999) for 56 total.  So --chunk-size 28
# should make 2 chunks.  And since the range of vals is 1..999, those chunks
# will be < 500 and >= 500.  Furthermore, the top 2 vals are 100 and 999,
# so the 2nd chunk should contain only 999.
diag(`rm -rf $basedir`);
$dbh->do('insert into test.t1 values (999)');
diag(`$cmd --base-dir $basedir --csv --chunk-size 28 -d test -t t1 > /dev/null`);

$output = `wc -l $basedir/test/t1.000000.txt`;
like($output, qr/^55/, 'First chunk of csv dump (issue 275)');

$output = `cat $basedir/test/t1.000001.txt`;
is($output, "999\n", 'Second chunk of csv dump (issue 275)');

$output = `cat $basedir/test/t1.chunks`;
is($output, "`a` < 500\n`a` >= 500\n", 'Chunks of csv dump (issue 275)');

# #############################################################################
# Issue 170: mk-parallel-dump dies when table-status Data_length is NULL
# #############################################################################
diag(`rm -rf $basedir`);
diag(`cp samples/broken_tbl.frm /tmp/12345/data/test/broken_tbl.frm`);
$output = `$cmd --base-dir $basedir -d test 2>&1`;
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
diag(`rm -rf $basedir`);
$dbh->do('USE test');
$dbh->do('CREATE TABLE `issue 446` (i int)');
$dbh->do('INSERT INTO test.`issue 446` VALUES (1),(2),(3)');

`$cmd --base-dir $basedir --ignore-databases sakila --databases test --tables 'issue 446' 2>&1`;
ok(
   -f "$basedir/test/issue 446.000000.sql",
   'Dumped table with space in name (issue 446)'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd --base-dir $basedir --ignore-databases sakila --databases test --tables 'issue 446' --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
