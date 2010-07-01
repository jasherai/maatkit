#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use List::Util qw(sum);
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

# Ensure --probability works
$output = `$cmd --probability 0 -d test --chunk-size 4 | grep -v DATABASE`;
chomp $output;
my @chunks = $output =~ m/(\d+)\s+127\.0\.0\.1/g;
is(sum(@chunks), 0, 'Nothing with --probability 0!');

# Make sure that it actually checksumed tables and that sum(@chunks)
# isn't zero because no tables were checksumed.
is(
   scalar @chunks,
   6,
   'Checksummed the tables'
);
like(
   $output,
   qr/test\s+argtest\s+0\s+127.0.0.1\s+MyISAM\s+3\s+875b102e/,
   'It actually did something'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
exit;
