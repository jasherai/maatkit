#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 27;

print `./make_repl_sandbox`;
my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "perl ../mk-table-checksum --defaults-file=$cnf -d test -t checksum_test 127.0.0.1";

# Load.
sleep 1 until `/tmp/12345/use -N -e 'select 1' 2>&1` eq "1\n";

# If this fails, you need to build the fnv_64 UDF and copy it to /lib
print `/tmp/12345/use < before.sql`;

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
is($output, '', 'Nothing with --probability 0!');

# Issue 35: mk-table-checksum dies when one server is missing a table
diag('Starting replication sandboxes...');
`../../common/t/make_repl_sandbox`;
`/tmp/12345/use -D mysql -e 'SET SQL_LOG_BIN=0; CREATE TABLE only_on_master (a int);'`;

$cmd = 'perl ../mk-table-checksum h=127.0.0.1,P=12345 h=127.1,P=12348 -d mysql -t only_on_master 2>&1 > /dev/null';
my $ret = system($cmd);
cmp_ok($ret, '==', 0, 'Missing slave tables not reported (fixes issue 35)');

diag('Removing replication sandboxes...');
`../../sandbox/stop_all`;

exit;
