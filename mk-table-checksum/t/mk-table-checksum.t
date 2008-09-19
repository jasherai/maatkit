#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 72;
use List::Util qw(sum);

diag(`../../sandbox/stop_all`);
diag(`../../sandbox/make_sandbox 12345`);

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "perl ../mk-table-checksum --defaults-file=$cnf -d test -t checksum_test 127.0.0.1";

# Load.
sleep 1 until `/tmp/12345/use -N -e 'select 1' 2>&1` eq "1\n";

# If this fails, you need to build the fnv_64 UDF and copy it to /lib
print `/tmp/12345/use < samples/before.sql`;

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

# Test that it works with locking
$output = `$cmd -kl -f sha1 --checksum -a ACCUM 2>&1`;
like($output, qr/9c1c01dc3ac1445a500251fc34a15d3e75a849df/, 'Locks' );

$output = `/tmp/12345/use -N -e 'select fnv_64(1)' 2>&1`;
is($output + 0, -6320923009900088257, 'FNV_64(1)');

$output = `/tmp/12345/use -N -e 'select fnv_64("hello, world")' 2>&1`;
is($output + 0, 6062351191941526764, 'FNV_64(hello, world)');

$output = `$cmd -f CRC32 --checksum -a ACCUM 2>&1`;
like($output, qr/00000001E9F5DC8E/, 'CRC32 ACCUM' );

$output = `$cmd -f FNV_64 --checksum -a ACCUM 2>&1`;
like($output, qr/DD2CD41DB91F2EAE/, 'FNV_64 ACCUM' );

$output = `$cmd -f CRC32 --checksum -a BIT_XOR 2>&1`;
like($output, qr/83dcefb7/, 'CRC32 BIT_XOR' );

$output = `$cmd -f FNV_64 --checksum -a BIT_XOR 2>&1`;
like($output, qr/a84792031e4ff43f/, 'FNV_64 BIT_XOR' );

$output = `$cmd -f sha1 --checksum -a ACCUM 2>&1`;
like($output, qr/9c1c01dc3ac1445a500251fc34a15d3e75a849df/, 'SHA1 ACCUM' );

# same as sha1(1)
$output = `$cmd -f sha1 --checksum -a BIT_XOR 2>&1`;
like($output, qr/356a192b7913b04c54574d18c28d46e6395428ab/, 'SHA1 BIT_XOR' );

# test that I get the same result with --no-optxor
$output2 = `$cmd -f sha1 --no-optxor --checksum -a BIT_XOR 2>&1`;
is($output, $output2, 'Same result with --no-optxor');

$output = `$cmd --checksum -f MD5 -a ACCUM 2>&1`;
like($output, qr/28c8edde3d61a0411511d3b1866f0636/, 'MD5 ACCUM' );

# same as sha1(1)
$output = `$cmd --checksum -f MD5 -a BIT_XOR 2>&1`;
like($output, qr/c4ca4238a0b923820dcc509a6f75849b/, 'MD5 BIT_XOR' );

# Check --schema
$output = `$cmd --checksum --schema 2>&1`;
like($output, qr/377366820/, 'Checksum with --schema' );

# Check --since
$output = `MKDEBUG=1 $cmd --since '"2008-01-01" - interval 1 day' --explain 2>&1 | grep 2007`;
like($output, qr/2007-12-31/, '--since is calculated as an expression');

# Check --since with --argtest.  The value (current_date) in the --argtest table
# ought to override the --since passed on the command-line.
$output = `$cmd --argtable test.argtest --since '"2008-01-01" - interval 1 day' --explain 2>&1`;
unlike($output, qr/2008-01-01/, 'Argtest overridden');
like($output, qr/`a`>='\d{4}-/, 'Argtest set to something else');

$output = `MKDEBUG=1 $cmd --since 'current_date + interval 1 day' 2>&1`;
like($output, qr/Skipping.*--since/, '--since skips tables');

$output = `$cmd --since 100 --explain`;
like($output, qr/`a`>=100/, '--since adds WHERE clauses');

$output = `$cmd --since current_date 2>&1 | grep HASH`;
unlike($output, qr/HASH\(0x/, '--since does not f*** up table names');

# Check --offset with --modulo
$output = `../mk-table-checksum --databases mysql -C 5 h=127.0.0.1,P=12345 --modulo 7 --offset 'weekday(now())' --tables help_relation 2>&1`;
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

$output  = `$cmd -f sha1 -R test.checksum`;
$output2 = `/tmp/12345/use --skip-column-names -e "select this_crc from test.checksum where tbl='checksum_test'"`;
( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
chomp $output2;
is ( $crc, $output2, 'output matches what was in the table' );

# Ensure chunking works
$output = `$cmd -f sha1 --explain -C 200 -d test -t chunk`;
like($output, qr/test\s+chunk\s+`film_id` < \d+/, 'chunking works');
my $num_chunks = scalar(map { 1 } $output =~ m/^test/gm);
ok($num_chunks >= 5 && $num_chunks < 8, "Found $num_chunks chunks");

# Ensure chunk boundaries are put into test.checksum (bug #1850243)
$output = `perl ../mk-table-checksum -f sha1 --defaults-file=$cnf -d test -t chunk -C 50 -R test.checksum 127.0.0.1`;
$output = `/tmp/12345/use --skip-column-names -e "select boundaries from test.checksum where db='test' and tbl='chunk' and chunk=0"`;
chomp $output;
like ( $output, qr/`film_id` < \d+/, 'chunk boundaries stored right');

# Ensure float-precision is effective
$output = `perl ../mk-table-checksum -f sha1 -a BIT_XOR --defaults-file=$cnf -d test -t fl_test --explain 127.0.0.1`;
unlike($output, qr/ROUND\(`a`/, 'Column is not rounded');
like($output, qr/test/, 'Column is not rounded and I got output');
$output = `perl ../mk-table-checksum -f sha1 --float-precision 3 -a BIT_XOR --defaults-file=$cnf -d test -t fl_test --explain 127.0.0.1`;
like($output, qr/ROUND\(`a`, 3/, 'Column a is rounded');
like($output, qr/ROUND\(`b`, 3/, 'Column b is rounded');
like($output, qr/ISNULL\(`b`\)/, 'Column b is not rounded inside ISNULL');

# Ensure --probability works
$output = `perl ../mk-table-checksum --probability 0 --chunksize 4 127.0.0.1 | grep -v DATABASE`;
chomp $output;
@chunks = $output =~ m/(\d+)\s+127\.0\.0\.1/g;
is(sum(@chunks), 0, 'Nothing with --probability 0!');

diag(`../../sandbox/stop_all`);
diag(`../../sandbox/make_sandbox 12345`);
diag(`../../sandbox/make_slave 12348`);

# Issue 35: mk-table-checksum dies when one server is missing a table
my $create_missing_slave_tbl_cmd
   = "/tmp/12345/use -D mysql -e 'SET SQL_LOG_BIN=0;CREATE TABLE only_on_master(a int);'";
diag(`$create_missing_slave_tbl_cmd`);

$output = `MKDEBUG=1 perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 -d mysql -t only_on_master 2>&1`;
like($output, qr/MyISAM\s+NULL\s+0/, 'Table on master checksummed');
like($output, qr/MyISAM\s+NULL\s+NULL/, 'Missing table on slave checksummed');
like($output, qr/mysql.only_on_master does not exist on slave 127.0.0.1:12348/, 'Debug reports missing slave table');

my $rm_missing_slave_tbl_cmd = "/tmp/12345/use -D mysql -e 'SET SQL_LOG_BIN=0;DROP TABLE only_on_master;'";
diag(`$rm_missing_slave_tbl_cmd`);

# Issue 5: Add ability to checksum table schema instead of data
$cmd = "perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 --schema | awk '{print \$1,\$2,\$7}' | diff ./samples/sample_schema_opt - 2>&1 > /dev/null";
my $ret_val = system($cmd);
cmp_ok($ret_val, '==', 0, 'Only option --schema');

# Remember to add $#opt_combos+1 number of tests to line 6
my @opt_combos = ( # --schema and
   '--algorithm=BIT_XOR',
   '--algorithm=ACCUM',
   '--checksum',
   '--chunksize=1M',
   '--count',
   '--crc',
   '--emptyrepltbl',
   '--float-precision=3',
   '--function=FNV_64',
   '--lock',
   '--optxor',
   '--probability=1',
   '--replcheck=1000',
   '--replicate=checksum_tbl',
   '--since \'"2008-01-01" - interval 1 day\'',
   '--slavelag',
   '--sleep=1000',
   '--noverify',
   '--wait=1000',
   '--where="id > 1000"',
);
# TODO: my pipework here sometimes chokes. I don't know why but random
# runs of this loop will freeze with awk | diff appearing to do nothing.
foreach my $opt_combo ( @opt_combos ) {
   $cmd = "perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 --schema $opt_combo | awk '{print \$1,\$2,\$7}' | diff ./samples/sample_schema_opt - 2>&1 > /dev/null";
   $ret_val = system($cmd);
   cmp_ok($ret_val, '==', 0, "--schema $opt_combo");
}
# I awk the output to just 3 key columns because I found the full
# output is not stable due to the TIME column: occasionally it will
# show 1 instead of 0 and diff barfs. These 3 columns should be stable.

#TODO: it would be great to test --replcheck but I think it's not going to work
#from SHOW PROCESSLIST in the sandboxen, it needs SHOW SLAVE HOSTS.

# Check that --schema does NOT lock by default
$output = `MKDEBUG=1 perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 --schema 2>&1`;
unlike($output, qr/LOCK TABLES /, '--schema does not lock tables by default');

$output = `MKDEBUG=1 perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 --schema --lock 2>&1`;
unlike($output, qr/LOCK TABLES /, '--schema does not lock tables even with --lock');

# Issue 21: --emptyrepltbl doesn't empty if previous runs leave info
diag(`/tmp/12345/use -e 'CREATE DATABASE test'`);
diag(`/tmp/12345/use < samples/checksum_tbl.sql`);

# Run --replication once to populate test.checksum
$cmd = 'perl ../mk-table-checksum h=127.0.0.1,P=12345 --replicate test.checksum | diff ./samples/basic_replicate_output -';
$ret_val = system($cmd);
# Might as well test this while we're at it
cmp_ok($ret_val, '==', 0, 'Basic --replicate works');

# Insert a bogus row into test.checksum
my $repl_row = "INSERT INTO test.checksum VALUES ('foo', 'bar', 0, 'a', 'b', 0, 'c', 0,  NOW())";
diag(`/tmp/12345/use -D test -e "$repl_row"`);
# Run --replicate again which should completely clear test.checksum,
# including our bogus row
`perl ../mk-table-checksum h=127.0.0.1,P=12345 --replicate test.checksum --emptyrepltbl 2>&1 > /dev/null`;
# Make sure bogus row is actually gone
$cmd = "/tmp/12345/use -e \"SELECT db FROM test.checksum WHERE db = 'foo';\"";
$output = `$cmd`;
unlike($output, qr/foo/, '--emptyrepltbl completely empties the table (fixes issue 21)');

# While we're at it, let's test what the doc says about --emptyrepltbl:
# "Ignored if L<"--replicate"> is not specified."
$repl_row = "INSERT INTO test.checksum VALUES ('foo', 'bar', 0, 'a', 'b', 0, 'c', 0,  NOW())";
diag(`/tmp/12345/use -D test -e "$repl_row"`);
`perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 --emptyrepltbl 2>&1 > /dev/null`;
# Now make sure bogus row is still present
$cmd = "/tmp/12345/use -e \"SELECT db FROM test.checksum WHERE db = 'foo';\"";
$output = `$cmd`;
like($output, qr/foo/, '--emptyrepltbl is ignored if --replicate is not specified');

# Test issue 5 + 35: --schema a missing table
diag(`$create_missing_slave_tbl_cmd`);

$output = `MKDEBUG=1 perl ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 -d mysql -t only_on_master --schema 2>&1`;
like($output, qr/MyISAM\s+NULL\s+23678842/, 'Table on master checksummed with --schema');
like($output, qr/MyISAM\s+NULL\s+NULL/, 'Missing table on slave checksummed with --schema');
like($output, qr/mysql.only_on_master does not exist on slave 127.0.0.1:12348/, 'Debug reports missing slave table with --schema');

diag(`$rm_missing_slave_tbl_cmd`); # in case someone adds more tests, and they probably will

# #############################################################################
# Issue 47: TableChunker::range_num broken for very large bigint
# #############################################################################
diag(`/tmp/12345/use -D test < samples/issue_47.sql`);
$output = `/tmp/12345/use -e 'SELECT * FROM test.issue_47'`;
like($output, qr/18446744073709551615/, 'Loaded max unsigned bigint for testing issue 47');
$output = `../mk-table-checksum h=127.0.0.1,P=12345 P=12348 -d test -t issue_47 --chunksize 4 2>&1`;
unlike($output, qr/Chunk size is too small/, 'Unsigned bigint chunks (issue 47)');

# #############################################################################
# Issue 8: Add --force-index parameter to mk-table-checksum and mk-table-sync
# #############################################################################

# This is difficult to test. If it works, it should just work silently.
# That is: there's really no way for us to see if MySQL is indeed using
# the index that we told it to.

$output = `MKDEBUG=1 ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 -d test -t issue_47 -a ACCUM 2>&1 | grep 'SQL for chunk 0:'`;
like($output, qr/SQL for chunk 0:.*FROM `test`\.`issue_47` USE INDEX \(`idx`\) WHERE/, 'Injects correct USE INDEX by default');

$output = `MKDEBUG=1 ../mk-table-checksum h=127.0.0.1,P=12345 P=12348 -d test -t issue_47 -a ACCUM --nouseindex 2>&1 | grep 'SQL for chunk 0:'`;
like($output, qr/SQL for chunk 0:.*FROM `test`\.`issue_47`  WHERE/, 'Does not inject USE INDEX with --nouseindex');

diag(`../../sandbox/stop_all`);
exit;
