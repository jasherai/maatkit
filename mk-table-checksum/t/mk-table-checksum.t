#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 20;

my $opt_file = shift || "~/.my.cnf";
my ($output, $output2);
diag("Testing with $opt_file");
my $cmd = "perl ../mk-table-checksum --defaults-file=$opt_file -d test -t checksum_test 127.0.0.1";

# Load.
`mysql --defaults-file=$opt_file < before.sql`;

$output = `mysql -e 'show databases'`;
SKIP: {
   skip 'Sakila not installed', 12 unless $output =~ m/sakila/;

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

   $output = `mysql -e 'select fnv_64(1)' 2>&1`;
   SKIP: {
      skip 'no fnv_64 UDF installed', 2 if $output =~ m/ERROR/;

      $output = `$cmd -f FNV_64 --checksum -a ACCUM 2>&1`;
      like($output, qr/B702F33D8D00F5D8/, 'FNV_64 ACCUM' );

      $output = `$cmd -f FNV_64 --checksum -a BIT_XOR 2>&1`;
      like($output, qr/da8f621ef6d7c3f0/, 'FNV_64 BIT_XOR' );

   }

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
   $output2 = `mysql --defaults-file=$opt_file --skip-column-names -e "select this_crc from test.checksum where tbl='checksum_test'"`;
   ( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
   chomp $output2;
   is ( $crc, $output2, 'output matches what was in the table' );

   # Ensure chunking works
   $output = `$cmd -f sha1 --explain -C 200 -d sakila -t film`;
   like($output, qr/sakila   film  `film_id` < \d+/, 'chunking works');
   my $num_chunks = scalar(map { 1 } $output =~ m/^sakila/gm);
   ok($num_chunks >= 5 && $num_chunks < 8, "Found $num_chunks chunks");

   # Ensure chunk boundaries are put into test.checksum (bug #1850243)
   $output = `perl ../mk-table-checksum -f sha1 --defaults-file=$opt_file -d sakila -t film -C 50 -R test.checksum 127.0.0.1`;
   $output = `mysql --defaults-file=$opt_file --skip-column-names -e "select boundaries from test.checksum where db='sakila' and tbl='film' and chunk=0"`;
   chomp $output;
   like ( $output, qr/`film_id` < \d+/, 'chunk boundaries stored right');

   # Ensure float-precision is effective
   $output = `perl ../mk-table-checksum -f sha1 -a BIT_XOR --defaults-file=$opt_file -d test -t fl_test --explain 127.0.0.1`;
   unlike($output, qr/ROUND\(`a`/, 'Column is not rounded');
   like($output, qr/test/, 'Column is not rounded and I got output');
   $output = `perl ../mk-table-checksum -f sha1 --float-precision 3 -a BIT_XOR --defaults-file=$opt_file -d test -t fl_test --explain 127.0.0.1`;
   like($output, qr/ROUND\(`a`, 3/, 'Column a is rounded');
   like($output, qr/ROUND\(`b`, 3/, 'Column b is rounded');
   like($output, qr/ISNULL\(`b`\)/, 'Column b is not rounded inside ISNULL');

   # Clean up
   `mysql --defaults-file=$opt_file < after.sql`;

}
