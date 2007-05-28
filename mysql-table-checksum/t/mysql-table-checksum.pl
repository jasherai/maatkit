#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 38;

my $opt_file = shift or die "Specify an option file.\n";
my ($output, $output2);
diag("Testing with $opt_file");

# Load.
`mysql --defaults-file=$opt_file < before.sql`;

# Test basic functionality with defaults
$output = `perl ../mysql-table-checksum --defaults-file=$opt_file -d test -t checksum_test 127.0.0.1 2>&1`;

like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');

my ( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
like ( $cnt, qr/2|NULL/, 'There are either two rows in the table, or no count' );
if ( $output =~ m/falling back to MD5/ ) {
   is ( $crc, '68415d6c42e35059e0c30a2bc334b4a5', 'MD5 is okay' );
}
elsif ( $crc =~ m/^\d+$/ ) {
   is ( $crc, 1711838952, 'CHECKSUM is okay');
}
else {
   is ( $crc, 'c590354a59c8c9bec447696046580bc47d83f922', 'SHA1 is okay' );
}

# Test basic functionality with SHA1 hash function
$output = `perl ../mysql-table-checksum -a ACCUM --defaults-file=$opt_file -d test -t checksum_test 127.0.0.1 2>&1`;

like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');

( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
like ( $cnt, qr/2|NULL/, 'There are either two rows in the table, or no count' );
if ( $output =~ m/falling back to MD5/ ) {
   is ( $crc, '68415d6c42e35059e0c30a2bc334b4a5', 'MD5 is okay' );
}
elsif ( $crc =~ m/^\d+$/ ) {
   is ( $crc, 1711838952, 'CHECKSUM is okay');
}
else {
   is ( $crc, 'c590354a59c8c9bec447696046580bc47d83f922', 'SHA1 is okay' );
}

# Test basic functionality with BIT_XOR
$output = `perl ../mysql-table-checksum -a BIT_XOR --defaults-file=$opt_file -d test -t checksum_test 127.0.0.1 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');
( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
like ( $cnt, qr/2|NULL/, 'There are either two rows in the table, or no count' );
if ( $output =~ m/falling back to MD5/ ) {
   is ( $crc, '68415d6c42e35059e0c30a2bc334b4a5', 'MD5 is okay' );
}
elsif ( $crc =~ m/^\d+$/ ) {
   is ( $crc, 1711838952, 'CHECKSUM is okay');
}
elsif ( $output =~ m/falling back to ACCUM/ ) {
   is ( $crc, 'c590354a59c8c9bec447696046580bc47d83f922', 'SHA1/ACCUM is okay');
}
else {
   is ( $crc, '1A942E9F5315FCE7BFE765837F04DE590B0FBE19', 'SHA1/BIT_XOR is okay' );
}

# Test basic functionality with BIT_XOR and MD5
$output = `perl ../mysql-table-checksum -a BIT_XOR -f MD5 --defaults-file=$opt_file -d test -t checksum_test 127.0.0.1 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');
( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
like ( $cnt, qr/2|NULL/, 'There are either two rows in the table, or no count' );
if ( $output =~ m/falling back to ACCUM/ ) {
   is ( $crc, '68415d6c42e35059e0c30a2bc334b4a5', 'MD5/ACCUM is okay' );
}
elsif ( $crc =~ m/^\d+$/ ) {
   is ( $crc, 1711838952, 'CHECKSUM is okay');
}
else {
   is ( $crc, '5BCD1652517DB0F6E33D2813226578F5', 'MD5 is okay' );
}

# Test --replicate functionality
$output = `perl ../mysql-table-checksum -R test.checksum --defaults-file=$opt_file -d test -t checksum_test 127.0.0.1 2>&1`;
my $result = `mysql --defaults-file=$opt_file --skip-column-names -e "select this_crc from test.checksum where tbl='checksum_test'"`;
chomp $result;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');
( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
like ( $cnt, qr/2|NULL/, 'There are either two rows in the table, or no count' );
if ( $output =~ m/falling back to MD5/ ) {
   is ( $crc, '68415d6c42e35059e0c30a2bc334b4a5', 'MD5 is okay' );
}
elsif ( $crc =~ m/^\d+$/ ) {
   is ( $crc, 1711838952, 'CHECKSUM is okay');
}
else {
   is ( $crc, 'c590354a59c8c9bec447696046580bc47d83f922', 'SHA1 is okay' );
}
is ( $crc, $result, 'output matches what was in the table' );

# Test --count functionality
$output = `perl ../mysql-table-checksum --count --defaults-file=$opt_file -d test -t checksum_test 127.0.0.1 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');
( $cnt, $crc ) = $output =~ m/checksum_test *\d+ \S+ \S+ *(\d+|NULL) *(\w+)/;
is ( $cnt, 2, 'There are two rows in the table' );

# Test that two tables with same contents produce same result
$output = `perl ../mysql-table-checksum --defaults-file=$opt_file -d test -t checksum_test,checksum_test_2 127.0.0.1 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');
like($output, qr/ (\d+ [\w]+).*\1/ms,  'There are two identical lines');

# Test that two tables with same contents produce same result with BIT_XOR
$output = `perl ../mysql-table-checksum -a BIT_XOR --defaults-file=$opt_file -d test -t checksum_test,checksum_test_2 127.0.0.1 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');
like($output, qr/ (\d+ [\w]+).*\1/ms,  'There are two identical lines');

# Test that --optxor and --nooptxor produce the same result
$output  = `perl ../mysql-table-checksum -a BIT_XOR --optxor --defaults-file=$opt_file -d test -t checksum_test_2 127.0.0.1 2>&1`;
$output2 = `perl ../mysql-table-checksum -a BIT_XOR --nooptxor --defaults-file=$opt_file -d test -t checksum_test_2 127.0.0.1 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test/, 'The results row is there');
like($output2, qr/^DATABASE/m, 'The header row is there');
like($output2, qr/checksum_test/, 'The results row is there');
is($output, $output2, "The two BIT_XOR methods gave the same results");

# Test chunking
$output = `perl ../mysql-table-checksum -C 2 --defaults-file=$opt_file -d test -t checksum_test_3 127.0.0.1 2>&1`;
like($output, qr/^DATABASE/m, 'The header row is there');
like($output, qr/checksum_test_3 *1 127.0.0.1 (MyISAM|InnoDB) *2/,
   'The first chunked results row is there');
like($output, qr/checksum_test_3 *2 127.0.0.1 (MyISAM|InnoDB) *1/,
   'The second chunked results row is there');
