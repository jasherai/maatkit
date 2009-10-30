#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 102;
use List::Util qw(sum);

require '../mk-table-checksum';
require '../../common/Sandbox.pm';
my $vp = new VersionParser();
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');
# $slave_dbh->do('START SLAVE');

eval { $master_dbh->do('DROP FUNCTION test.fnv_64'); };

# If this fails, you need to build the fnv_64 UDF and copy it to /lib
$sb->load_file('master', 'samples/before.sql');

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "perl ../mk-table-checksum --defaults-file=$cnf -d test -t checksum_test 127.0.0.1";

# Test basic functionality with defaults
$output = `$cmd 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');

my ( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
like ( $cnt, qr/1|NULL/, 'One row in the table, or no count' );
if ( $output =~ m/cannot be used; using MD5/ ) {
   # same as md5(md5(1))
   is ( $crc, '28c8edde3d61a0411511d3b1866f0636', 'MD5 is okay' );
}
elsif ( $crc =~ m/^\d+$/ ) {
   is ( $crc, 3036305396, 'CHECKSUM is okay');
}
else {
   # same as sha1(sha1(1))
   is ( $crc, '9c1c01dc3ac1445a500251fc34a15d3e75a849df', 'SHA1 is okay' );
}

# Test DSN value inheritance
$output = `../mk-table-checksum h=127.1 h=127.2,P=12346 --port 12345 --explain-hosts`;
like(
   $output,
   qr/^Server 127.1:\s+P=12345,h=127.1\s+Server 127.2:\s+P=12346,h=127.2/,
   'DSNs inherit values from --port, etc. (issue 248)'
);

# Test that it works with locking
$output = `$cmd --lock --slave-lag --function sha1 --checksum --algorithm ACCUM 2>&1`;
like($output, qr/9c1c01dc3ac1445a500251fc34a15d3e75a849df/, 'Locks' );

SKIP: {
   skip 'MySQL version < 4.1', 10
      unless $vp->version_ge($master_dbh, '4.1.0');

   $output = `/tmp/12345/use -N -e 'select fnv_64(1)' 2>&1`;
   is($output + 0, -6320923009900088257, 'FNV_64(1)');

   $output = `/tmp/12345/use -N -e 'select fnv_64("hello, world")' 2>&1`;
   is($output + 0, 6062351191941526764, 'FNV_64(hello, world)');

   $output = `$cmd --function CRC32 --checksum --algorithm ACCUM 2>&1`;
   like($output, qr/00000001E9F5DC8E/, 'CRC32 ACCUM' );

   $output = `$cmd --function FNV_64 --checksum --algorithm ACCUM 2>&1`;
   like($output, qr/DD2CD41DB91F2EAE/, 'FNV_64 ACCUM' );

   $output = `$cmd --function CRC32 --checksum --algorithm BIT_XOR 2>&1`;
   like($output, qr/83dcefb7/, 'CRC32 BIT_XOR' );

   $output = `$cmd --function FNV_64 --checksum --algorithm BIT_XOR 2>&1`;
   like($output, qr/a84792031e4ff43f/, 'FNV_64 BIT_XOR' );

   $output = `$cmd --function sha1 --checksum --algorithm ACCUM 2>&1`;
   like($output, qr/9c1c01dc3ac1445a500251fc34a15d3e75a849df/, 'SHA1 ACCUM' );

   # same as sha1(1)
   $output = `$cmd --function sha1 --checksum --algorithm BIT_XOR 2>&1`;
   like($output, qr/356a192b7913b04c54574d18c28d46e6395428ab/, 'SHA1 BIT_XOR' );

   # test that I get the same result with --no-optxor
   $output2 = `$cmd --function sha1 --no-optimize-xor --checksum --algorithm BIT_XOR 2>&1`;
   is($output, $output2, 'Same result with --no-optxor');

   # same as sha1(1)
   $output = `$cmd --checksum --function MD5 --algorithm BIT_XOR 2>&1`;
   like($output, qr/c4ca4238a0b923820dcc509a6f75849b/, 'MD5 BIT_XOR' );
};

$output = `$cmd --checksum --function MD5 --algorithm ACCUM 2>&1`;
like($output, qr/28c8edde3d61a0411511d3b1866f0636/, 'MD5 ACCUM' );

# Check --schema
$output = `perl ../mk-table-checksum --tables checksum_test --checksum --schema h=127.1,P=12345 2>&1`;
like($output, qr/2752458186\s+127.1.test2.checksum_test/, 'Checksum test with --schema' );
# Should output the same thing, it only lacks the AUTO_INCREMENT specifier.
like($output, qr/2752458186\s+127.1.test.checksum_test/, 'Checksum 2 test with --schema' );

# Check --since
$output = `MKDEBUG=1 $cmd --since '"2008-01-01" - interval 1 day' --explain 2>&1 | grep 2007`;
like($output, qr/2007-12-31/, '--since is calculated as an expression');

# Check --since with --arg-table. The value in the --arg-table table
# ought to override the --since passed on the command-line.
$output = `$cmd --arg-table test.argtest --since 20 --explain 2>&1`;
unlike($output, qr/`a`>=20/, 'Argtest overridden');
like($output, qr/`a`>=1/, 'Argtest set to something else');

# Make sure that --arg-table table has only legally allowed columns in it
$output = `$cmd --arg-table test.argtest2 2>&1`;
like($output, qr/Column foobar .from test.argtest2/, 'Argtest with bad column');

$output = `MKDEBUG=1 $cmd --since 'current_date + interval 1 day' -t test.blackhole 2>&1`;
like($output, qr/Finished chunk/, '--since does not crash on blackhole tables');

$output = `MKDEBUG=1 $cmd --since 'current_date + interval 1 day' 2>&1`;
like($output, qr/Skipping.*--since/, '--since skips tables');

$output = `$cmd --since 100 --explain`;
like($output, qr/`a`>=100/, '--since adds WHERE clauses');

$output = `$cmd --since current_date 2>&1 | grep HASH`;
unlike($output, qr/HASH\(0x/, '--since does not f*** up table names');

# Check --since with --save-since
$output = `$cmd --arg-table test.argtest --save-since --chunk-size 50 -t test.chunk 2>&1`;
$output2 = `/tmp/12345/use --skip-column-names -e "select since from test.argtest where tbl='chunk'"`;
is($output2 + 0, 1000, '--save-since saved the maxrow');

$output = `$cmd --arg-table test.argtest --save-since --chunk-size 50 -t test.argtest 2>&1`;
$output2 = `/tmp/12345/use --skip-column-names -e "select since from test.argtest where tbl='argtest'"`;
like($output2, qr/^\d{4}-\d\d-\d\d/, '--save-since saved the current timestamp');

# Check --offset with --modulo
$output = `../mk-table-checksum --databases mysql --chunk-size 5 h=127.0.0.1,P=12345 --modulo 7 --offset 'weekday(now())' --tables help_relation 2>&1`;
like($output, qr/^mysql\s+help_relation\s+\d+/m, '--modulo --offset runs');
my @chunks = $output =~ m/help_relation\s+(\d+)/g;
my $chunks = scalar @chunks;
ok($chunks, 'There are several chunks with --modulo');
my %differences;
my $first = shift @chunks;
while ( my $chunk = shift @chunks ) {
   $differences{$chunk - $first} ++;
   $first = $chunk;
}
is($differences{7}, $chunks - 1, 'All chunks are 7 apart');

$output  = `$cmd --function sha1 --replicate test.checksum`;
$output2 = `/tmp/12345/use --skip-column-names -e "select this_crc from test.checksum where tbl='checksum_test'"`;
( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
chomp $output2;
is ( $crc, $output2, 'output matches what was in the table' );

# Ensure chunking works
$output = `$cmd --function sha1 --explain --chunk-size 200 -d test -t chunk`;
like($output, qr/test\s+chunk\s+`film_id` < \d+/, 'chunking works');
my $num_chunks = scalar(map { 1 } $output =~ m/^test/gm);
ok($num_chunks >= 5 && $num_chunks < 8, "Found $num_chunks chunks");

# Ensure chunk boundaries are put into test.checksum (bug #1850243)
$output = `perl ../mk-table-checksum --function sha1 --defaults-file=$cnf -d test -t chunk --chunk-size 50 --replicate test.checksum 127.0.0.1`;
$output = `/tmp/12345/use --skip-column-names -e "select boundaries from test.checksum where db='test' and tbl='chunk' and chunk=0"`;
chomp $output;
like ( $output, qr/`film_id` < \d+/, 'chunk boundaries stored right');

# Ensure float-precision is effective
$output = `perl ../mk-table-checksum --function sha1 --algorithm BIT_XOR --defaults-file=$cnf -d test -t fl_test --explain 127.0.0.1`;
unlike($output, qr/ROUND\(`a`/, 'Column is not rounded');
like($output, qr/test/, 'Column is not rounded and I got output');
$output = `perl ../mk-table-checksum --function sha1 --float-precision 3 --algorithm BIT_XOR --defaults-file=$cnf -d test -t fl_test --explain 127.0.0.1`;
like($output, qr/ROUND\(`a`, 3/, 'Column a is rounded');
like($output, qr/ROUND\(`b`, 3/, 'Column b is rounded');
like($output, qr/ISNULL\(`b`\)/, 'Column b is not rounded inside ISNULL');

# Ensure --probability works
$output = `perl ../mk-table-checksum --probability 0 --chunk-size 4 h=127.0.0.1,P=12345 | grep -v DATABASE`;
chomp $output;
@chunks = $output =~ m/(\d+)\s+127\.0\.0\.1/g;
is(sum(@chunks), 0, 'Nothing with --probability 0!');

# The following tests need a clean server.
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
$sb->create_dbs($master_dbh, [qw(test)]);

# #############################################################################
# Issue 35: mk-table-checksum dies when one server is missing a table
# #############################################################################

# This var is used later in another test.
my $create_missing_slave_tbl_cmd
   = "/tmp/12345/use -D mysql -e 'SET SQL_LOG_BIN=0;CREATE TABLE test.only_on_master(a int);'";
diag(`$create_missing_slave_tbl_cmd`);

$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 -t test.only_on_master 2>&1`;
like($output, qr/MyISAM\s+NULL\s+0/, 'Table on master checksummed');
like($output, qr/MyISAM\s+NULL\s+NULL/, 'Missing table on slave checksummed');
like(
   $output,
   qr/test\.only_on_master does not exist on slave 127.0.0.1:12346/,
   'Warns about missing slave table'
);

# This var is used later in another test.
my $rm_missing_slave_tbl_cmd
   = "/tmp/12345/use -D mysql -e 'SET SQL_LOG_BIN=0;DROP TABLE test.only_on_master;'";
diag(`$rm_missing_slave_tbl_cmd`);

# #############################################################################
# Issue 5: Add ability to checksum table schema instead of data
# #############################################################################

# The following --schema tests are sensitive to what schemas exist on the
# sandbox server. The sample file is for a blank server, i.e. just the mysql
# db and maybe or not the sakila db.
$sb->wipe_clean($master_dbh);

my $awk_slice = "awk '{print \$1,\$2,\$7}'";

$cmd = "perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 --ignore-databases sakila --schema | $awk_slice | diff ./samples/sample_schema_opt - 2>&1 > /dev/null";
my $ret_val = system($cmd);
cmp_ok($ret_val, '==', 0, '--schema basic output');

$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 --schema --quiet`;
is(
   $output,
   '',
   '--schema respects --quiet'
);

$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 --schema --ignore-databases mysql,sakila`;
is(
   $output,
   '',
   '--schema respects --ignore-databases'
);

$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 --schema --ignore-tables users`;
unlike(
   $output,
   qr/users/,
   '--schema respects --ignore-tables'
);

# Remember to add $#opt_combos+1 number of tests to line 6
my @opt_combos = ( # --schema and
   '--algorithm=BIT_XOR',
   '--algorithm=ACCUM',
   '--chunk-size=1M',
   '--count',
   '--crc',
   '--empty-replicate-table',
   '--float-precision=3',
   '--function=FNV_64',
   '--lock',
   '--optimize-xor',
   '--probability=1',
   '--replicate-check=1000',
   '--replicate=checksum_tbl',
   '--resume samples/resume01_partial.txt',
   '--since \'"2008-01-01" - interval 1 day\'',
   '--slave-lag',
   '--sleep=1000',
   '--wait=1000',
   '--where="id > 1000"',
);

foreach my $opt_combo ( @opt_combos ) {
   $output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 --ignore-databases sakila --schema $opt_combo 2>&1`;
   my ($other_opt) = $opt_combo =~ m/^([\w-]+\b)/;
   like(
      $output,
      qr/--schema is not allowed with $other_opt/,
      "--schema is not allowed with $other_opt"
   );
}
# Have to do this one manually be --no-verify is --verify in the
# error output which confuses the regex magic for $other_opt.
$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 --ignore-databases sakila --schema --no-verify 2>&1`;
like(
   $output,
   qr/--schema is not allowed with --verify/,
   "--schema is not allowed with --[no]verify"
);

# Check that --schema does NOT lock by default
$output = `MKDEBUG=1 perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 --schema 2>&1`;
unlike($output, qr/LOCK TABLES /, '--schema does not lock tables by default');

$output = `MKDEBUG=1 perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 --schema --lock 2>&1`;
unlike($output, qr/LOCK TABLES /, '--schema does not lock tables even with --lock');

# #############################################################################
# Issue 21: --empty-replicate-table doesn't empty if previous runs leave info
# #############################################################################

# This test requires that the test db has only the table created by
# issue_21.sql. If there are other tables, the first test below
# will fail because samples/basic_replicate_output will differ.
$sb->wipe_clean($master_dbh);
$sb->create_dbs($master_dbh, ['test']);

$sb->load_file('master', 'samples/checksum_tbl.sql');
$sb->load_file('master', 'samples/issue_21.sql');

# Run --replication once to populate test.checksum
$cmd = 'perl ../mk-table-checksum h=127.0.0.1,P=12345 -d test --replicate test.checksum | diff ./samples/basic_replicate_output -';
$ret_val = system($cmd);
# Might as well test this while we're at it
cmp_ok($ret_val >> 8, '==', 0, 'Basic --replicate works');

# Insert a bogus row into test.checksum
my $repl_row = "INSERT INTO test.checksum VALUES ('foo', 'bar', 0, 'a', 'b', 0, 'c', 0,  NOW())";
diag(`/tmp/12345/use -e "$repl_row"`);
# Run --replicate again which should completely clear test.checksum,
# including our bogus row
`perl ../mk-table-checksum h=127.0.0.1,P=12345 --replicate test.checksum -d test --empty-replicate-table 2>&1 > /dev/null`;
# Make sure bogus row is actually gone
$cmd = "/tmp/12345/use -e \"SELECT db FROM test.checksum WHERE db = 'foo';\"";
$output = `$cmd`;
unlike($output, qr/foo/, '--empty-replicate-table completely empties the table (fixes issue 21)');

# While we're at it, let's test what the doc says about --empty-replicate-table:
# "Ignored if L<"--replicate"> is not specified."
$repl_row = "INSERT INTO test.checksum VALUES ('foo', 'bar', 0, 'a', 'b', 0, 'c', 0,  NOW())";
diag(`/tmp/12345/use -e "$repl_row"`);
`perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 --empty-replicate-table 2>&1 > /dev/null`;
# Now make sure bogus row is still present
$cmd = "/tmp/12345/use -e \"SELECT db FROM test.checksum WHERE db = 'foo';\"";
$output = `$cmd`;
like($output, qr/foo/, '--empty-replicate-table is ignored if --replicate is not specified');
diag(`/tmp/12345/use -D test -e "DELETE FROM checksum WHERE db = 'foo'"`);

# Screw up the data on the slave and make sure --replicate-check works
$slave_dbh->do("update test.checksum set this_crc='' where test.checksum.tbl = 'issue_21'");
$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 -d test --replicate test.checksum --replicate-check 1 2>&1`;
like($output, qr/issue_21/, '--replicate-check works');
cmp_ok($CHILD_ERROR>>8, '==', 1, 'Exit status is correct with --replicate-check failure');

# #############################################################################
# Issue 69: mk-table-checksum should be able to re-checksum things that differ
# #############################################################################

# This test relies on the previous test which checked that --replicate-check works
# and left an inconsistent checksum on columns_priv.
$output = `../mk-table-checksum h=127.1,P=12345 -d test --replicate test.checksum --replicate-check 1 --recheck | diff samples/issue_69.txt -`;
ok(!$output, '--recheck reports inconsistent table like --replicate');

# Now check that --recheck actually caused the inconsistent table to be
# re-checksummed on the master.
$output = 'foo';
$output = `../mk-table-checksum h=127.1,P=12345 --replicate test.checksum --replicate-check 1`;
ok(!$output, '--recheck re-checksummed inconsistent table; it is now consistent');

$master_dbh->do('DROP TABLE test.issue_21');

# #############################################################################
# Issue 36: Add --resume option to mk-table-checksum (1/2)
# #############################################################################

# The following tests rely on a clean test db, that's why we dropped
# test.issue_21 above.

# First re-checksum and replicate using chunks so we can more easily break,
# resume and test it.
`../mk-table-checksum h=127.0.0.1,P=12345 --ignore-databases sakila --replicate test.checksum --empty-replicate-table --chunk-size 100`;

# Make sure the results propagate
sleep 1;

# Now break the results as if that run didn't finish
`/tmp/12345/use -e "DELETE FROM test.checksum WHERE tbl = 'help_relation' AND chunk > 4"`;
`/tmp/12345/use -e "DELETE FROM test.checksum WHERE tbl = 'help_topic' OR tbl = 'host'"`;
`/tmp/12345/use -e "DELETE FROM test.checksum WHERE tbl LIKE 'proc%' OR tbl LIKE 't%' OR tbl = 'user'"`;

# And now test --resume with --replicate
`../mk-table-checksum h=127.0.0.1,P=12345 --ignore-databases sakila --resume-replicate --replicate test.checksum --chunk-size 100 > /tmp/mktc_issue36.txt`;

# We have to chop the output because a simple diff on the whole thing won't
# work well because the TIME column can sometimes change from 0 to 1.
# So, instead, we check that the top part lists the chunks already done,
# and then we simplify the latter lines which should be the
# resumed/not-yet-done chunks.
$output = `head -n 14 /tmp/mktc_issue36.txt | diff samples/resume02_already_done.txt -`;
ok(!$output, 'Resumes with --replicate (1/2)');
$output = `tail -n 19 /tmp/mktc_issue36.txt | awk '{print \$1,\$2,\$3,\$4}' | diff samples/resume02_resumed.txt -`;
ok(!$output, 'Resumes with --replicate (2/2)');

`rm /tmp/mktc_issue36.txt`;

# #############################################################################
# Issue 81: put some data that's too big into the boundaries table
# #############################################################################
diag(`/tmp/12345/use < samples/checksum_tbl_truncated.sql`);
$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 --ignore-databases sakila --empty-replicate-table --replicate test.checksum 2>&1`;
like($output, qr/boundaries/, 'Truncation causes an error');

# Restore the proper checksum table.
diag(`/tmp/12345/use < samples/checksum_tbl.sql`);

# #############################################################################
# Test issue 5 + 35: --schema a missing table
# #############################################################################
diag(`$create_missing_slave_tbl_cmd`);

$output = `perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 -t test.only_on_master --schema 2>&1`;
like($output, qr/MyISAM\s+NULL\s+23678842/, 'Table on master checksummed with --schema');
like($output, qr/MyISAM\s+NULL\s+NULL/, 'Missing table on slave checksummed with --schema');
like($output, qr/test.only_on_master does not exist on slave 127.0.0.1:12346/, 'Debug reports missing slave table with --schema');

diag(`$rm_missing_slave_tbl_cmd`);

# #############################################################################
# Issue 47: TableChunker::range_num broken for very large bigint
# #############################################################################
diag(`/tmp/12345/use -D test < samples/issue_47.sql`);
$output = `/tmp/12345/use -e 'SELECT * FROM test.issue_47'`;
like($output, qr/18446744073709551615/, 'Loaded max unsigned bigint for testing issue 47');
$output = `../mk-table-checksum h=127.0.0.1,P=12345 P=12346 -d test -t issue_47 --chunk-size 4 2>&1`;
unlike($output, qr/Chunk size is too small/, 'Unsigned bigint chunks (issue 47)');

# #############################################################################
# Issue 8: Add --force-index parameter to mk-table-checksum and mk-table-sync
# #############################################################################

# This is difficult to test. If it works, it should just work silently.
# That is: there's really no way for us to see if MySQL is indeed using
# the index that we told it to.

$output = `MKDEBUG=1 ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 -d test -t issue_47 --algorithm ACCUM 2>&1 | grep 'SQL for chunk 0:'`;
like($output, qr/SQL for chunk 0:.*FROM `test`\.`issue_47` (?:FORCE|USE) INDEX \(`idx`\) WHERE/, 'Injects correct USE INDEX by default');

$output = `MKDEBUG=1 ../mk-table-checksum h=127.0.0.1,P=12345 P=12346 -d test -t issue_47 --algorithm ACCUM --no-use-index 2>&1 | grep 'SQL for chunk 0:'`;
like($output, qr/SQL for chunk 0:.*FROM `test`\.`issue_47`  WHERE/, 'Does not inject USE INDEX with --no-use-index');

# #############################################################################
# Issue 36: Add --resume option to mk-table-checksum (2/2)
# #############################################################################

# This tests just one database...
$output = `../mk-table-checksum h=127.0.0.1,P=12345 h=127.1,P=12346 -d test --chunk-size 3 --resume samples/resume01_partial.txt | diff samples/resume01_whole.txt -`;
ok(!$output, 'Resumes checksum of chunked data (1 db)');

# but this tests two.
$output = `../mk-table-checksum h=127.0.0.1,P=12345 h=127.1,P=12346 --ignore-databases sakila --resume samples/resume03_partial.txt | diff samples/resume03_whole.txt -`;
ok(!$output, 'Resumes checksum of non-chunked data (2 dbs)');

# #############################################################################
# Issue 77: mk-table-checksum should be able to create the --replicate table
# #############################################################################

# First check that, like a Klingon, it dies with honor.
`/tmp/12345/use -e 'DROP TABLE test.checksum'`;
$output = `../mk-table-checksum h=127.0.0.1,P=12345 --replicate test.checksum 2>&1`;
like($output, qr/replicate table .+ does not exist/, 'Dies with honor when replication table does not exist');

$output = `../mk-table-checksum h=127.0.0.1,P=12345 --ignore-databases sakila --replicate test.checksum --create-replicate-table`;
like($output, qr/DATABASE\s+TABLE\s+CHUNK/, '--create-replicate-table creates the replicate table');

# #############################################################################
# Issue 94: Enhance mk-table-checksum, add a --ignore-columns option
# #############################################################################
diag(`/tmp/12345/use < samples/issue_94.sql`);
$output = `../mk-table-checksum -d test -t issue_94 h=127.1,P=12345 P=12346 --algorithm ACCUM | awk '{print \$7}'`;
like($output, qr/CHECKSUM\n00000006B6BDB8E6\n00000006B6BDB8E6/, 'Checksum ok with all 3 columns (issue 94 1/2)');

$output = `../mk-table-checksum -d test -t issue_94 h=127.1,P=12345 P=12346 --algorithm ACCUM --ignore-columns c | awk '{print \$7}'`;
like($output, qr/CHECKSUM\n000000066094F8AA\n000000066094F8AA/, 'Checksum ok with ignored column (issue 94 2/2)');

# #############################################################################
# Issue 103: mk-table-checksum doesn't honor --checksum in --schema mode
# #############################################################################
$output = `../mk-table-checksum --checksum h=127.1,P=12345 --schema --ignore-databases sakila`;
unlike($output, qr/DATABASE\s+TABLE/, '--checksum in --schema mode prints terse output');

# #############################################################################
# Issue 121: mk-table-checksum and --since isn't working right on InnoDB tables
# #############################################################################

# Reusing issue_21.sql
$sb->load_file('master', 'samples/issue_21.sql'); 
$output = `../mk-table-checksum --since 'current_date - interval 7 day' h=127.1,P=12345 -t test.issue_21`;
like($output, qr/test\s+issue_21\s+0\s+127\.1\s+InnoDB/, 'InnoDB table is checksummed with temporal --since');

# #############################################################################
# Issue 122: mk-table-checksum doesn't --save-since correctly on empty tables
# #############################################################################

$sb->load_file('master', 'samples/issue_122.sql');
$output = `../mk-table-checksum --arg-table test.argtable --save-since h=127.1,P=12345 -t test.issue_122 --chunk-size 2`;
my $res = $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'");
is_deeply($res, [[undef]], 'Numeric since is not saved when table is empty');

$master_dbh->do("INSERT INTO test.issue_122 VALUES (null,'a'),(null,'b')");
$output = `../mk-table-checksum --arg-table test.argtable --save-since h=127.1,P=12345 -t test.issue_122 --chunk-size 2`;
$res = $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'");
is_deeply($res, [[2]], 'Numeric since is saved when table is not empty');

# Test non-empty table that is chunkable with a temporal --since and
# --save-since to make sure that the current ts gets saved and not the maxval.
$master_dbh->do('UPDATE test.argtable SET since = "current_date - interval 3 day" WHERE db = "test" AND tbl = "issue_122"');
$output = `../mk-table-checksum --arg-table test.argtable --save-since h=127.1,P=12345 -t test.issue_122 --chunk-size 2`;
$res = $master_dbh->selectall_arrayref("SELECT since FROM test.argtable WHERE db='test' AND tbl='issue_122'");
like($res->[0]->[0], qr/^\d{4}-\d{2}-\d{2}(?:.[0-9:]+)?/, 'Temporal since is saved when temporal since is given');

# #############################################################################
# Issue 51: --wait option prevents data from being inserted
# #############################################################################

# This test relies on table issue_94 created somewhere above, which has
# something like:
# mysql> select * from issue_94;
# +----+----+---------+
# | a  | b  | c       |
# +----+----+---------+
# |  1 |  2 | apple   | 
# |  3 |  4 | banana  | 
# |  5 |  6 | kiwi    | 
# |  7 |  8 | orange  | 
# |  9 | 10 | grape   | 
# | 11 | 12 | coconut | 
# +----+----+---------+

$master_dbh->do('DELETE FROM test.checksum');
# Give it something to think about. 
$slave_dbh->do('DELETE FROM test.issue_94 WHERE a > 5');
`perl ../mk-table-checksum --replicate=test.checksum --algorithm=BIT_XOR h=127.1,P=12345 --databases test --tables issue_94 --chunk-size 500000 --wait 900`;
$res = $master_dbh->selectall_arrayref("SELECT * FROM test.checksum");
is($res->[0]->[1], 'issue_94', '--wait does not prevent update to --replicate tbl (issue 51)');

# #############################################################################
# Issue 467: overridable arguments with --arg-table
# #############################################################################

# test.argtable should still exist from a previous test.  We'll re-use it.
$master_dbh->do('ALTER TABLE test.argtable ADD COLUMN (modulo INT, offset INT, `chunk-size` INT)');
$master_dbh->do("TRUNCATE TABLE test.argtable");

# Two different args for two different tables.  Because issue_122 uses
# --chunk-size, it will use the BIT_XOR algo.  And issue_94 uses no opts
# so it will use the CHECKSUM algo.
$master_dbh->do("INSERT INTO test.argtable (db, tbl, since, modulo, offset, `chunk-size`) VALUES ('test', 'issue_122', NULL, 2, 1, 2)");
$master_dbh->do("INSERT INTO test.argtable (db, tbl, since, modulo, offset, `chunk-size`) VALUES ('test', 'issue_94', NULL, NULL, NULL, NULL)");

$master_dbh->do("INSERT INTO test.issue_122 VALUES (3,'c'),(4,'d'),(5,'e'),(6,'f'),(7,'g'),(8,'h'),(9,'i'),(10,'j')");

`perl ../mk-table-checksum h=127.1,P=12345 -d test -t issue_122,issue_94 --arg-table test.argtable > /tmp/mk-table-sync-issue-467-output.txt`;
$output = `diff samples/issue_467.txt /tmp/mk-table-sync-issue-467-output.txt`;
is(
   $output,
   '',
   'chunk-size, modulo and offset in argtable (issue 467)'
);
diag(`rm -rf /tmp/mk-table-sync-issue-467-output.txt`);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-table-checksum h=127.1,P=12345 -d test -t issue_122,issue_94 --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
