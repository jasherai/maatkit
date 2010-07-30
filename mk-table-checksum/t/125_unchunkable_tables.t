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
   plan tests => 2;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my @args = ('-F', $cnf, 'h=127.1', qw(-t osc.t));

diag(`/tmp/12345/use < $trunk/mk-table-checksum/t/samples/oversize-chunks.sql`);
$dbh->do('alter table osc.t drop index `i`');

ok(
   no_diff(
      sub { mk_table_checksum::main(@args, qw(--chunk-size 10)) },
      "mk-table-checksum/t/samples/unchunkable-table.txt",
   ),
   "Skip unchunkable table"
);

ok(
   no_diff(
      sub { mk_table_checksum::main(@args, qw(--chunk-size 1000)) },
      "mk-table-checksum/t/samples/unchunkable-table-small.txt",
   ),
   "Chunk unchunable table if smaller than chunk size"
);

# #############################################################################
# Done.
# #############################################################################
# $sb->wipe_clean($dbh);
exit;
