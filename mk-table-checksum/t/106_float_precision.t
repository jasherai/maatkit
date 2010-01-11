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
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 5;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# Ensure float-precision is effective
$output = `perl ../mk-table-checksum --function sha1 --algorithm BIT_XOR --defaults-file=$cnf -d test -t fl_test --explain 127.0.0.1`;
unlike($output, qr/ROUND\(`a`/, 'Column is not rounded');
like($output, qr/test/, 'Column is not rounded and I got output');
$output = `perl ../mk-table-checksum --function sha1 --float-precision 3 --algorithm BIT_XOR --defaults-file=$cnf -d test -t fl_test --explain 127.0.0.1`;
like($output, qr/ROUND\(`a`, 3/, 'Column a is rounded');
like($output, qr/ROUND\(`b`, 3/, 'Column b is rounded');
like($output, qr/ISNULL\(`b`\)/, 'Column b is not rounded inside ISNULL');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
