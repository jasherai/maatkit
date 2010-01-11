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
   plan tests => 3;
}

my $cnf='/tmp/12345/my.sandbox.cnf';
my ($output, $output2);
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf -d test -t checksum_test 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# Check --offset with --modulo
$output = `../mk-table-checksum --databases mysql --chunk-size 5 h=127.0.0.1,P=12345,u=msandbox,p=msandbox --modulo 7 --offset 'weekday(now())' --tables help_relation 2>&1`;
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

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
