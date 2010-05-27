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

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-table-checksum/mk-table-checksum -F $cnf 127.0.0.1";

$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/before.sql');

# Ensure chunking works
$output = `$cmd --function sha1 --explain --chunk-size 200 -d test -t chunk`;
like($output, qr/test\s+chunk\s+`film_id` < '\d+'/, 'chunking works');
my $num_chunks = scalar(map { 1 } $output =~ m/^test/gm);
ok($num_chunks >= 5 && $num_chunks < 8, "Found $num_chunks chunks");

# Ensure chunk boundaries are put into test.checksum (bug #1850243)
$output = `$cmd --function sha1 -d test -t chunk --chunk-size 50 --replicate test.checksum 127.0.0.1`;
$output = `/tmp/12345/use --skip-column-names -e "select boundaries from test.checksum where db='test' and tbl='chunk' and chunk=0"`;
chomp $output;
like ( $output, qr/`film_id` < '\d+'/, 'chunk boundaries stored right');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
