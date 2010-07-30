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

use MaatkitTest;
use Sandbox;
require "$trunk/mk-table-checksum/mk-table-checksum";

my $vp  = new VersionParser();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my @args = ('-F', $cnf, 'h=127.1', qw(-t osc.t --chunk-size 10));

diag(`/tmp/12345/use < $trunk/mk-table-checksum/t/samples/oversize-chunks.sql`);

ok(
   no_diff(
      sub { mk_table_checksum::main(@args) },
      "mk-table-checksum/t/samples/oversize-chunks.txt",
   ),
   "Skip oversize chunk"
);

ok(
   no_diff(
      sub { mk_table_checksum::main(@args, qw(--chunk-size-limit 0)) },
      "mk-table-checksum/t/samples/oversize-chunks-allowed.txt"
   ),
   "Allow oversize chunk"
);

$output = `$trunk/mk-table-checksum/mk-table-checksum -F $cnf h=127.1 --chunk-size-limit 0.999 --chunk-size 100 2>&1`;
like(
   $output,
   qr/chunk-size-limit must be >= 1 or 0 to disable/,
   "Verify --chunk-size-limit size"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
