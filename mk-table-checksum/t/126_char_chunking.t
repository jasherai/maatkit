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
my @args = ('-F', $cnf, 'h=127.1', qw(-t test.ascii --chunk-column c));

$sb->create_dbs($dbh, ['test']);
$sb->load_file('master', "common/t/samples/char-chunking/ascii.sql", 'test');

ok(
   no_diff(
      sub { mk_table_checksum::main(@args,
         qw(--chunk-size 20 --explain)) },
      "mk-table-checksum/t/samples/char-chunk-ascii-explain.txt",
   ),
   "Char chunk ascii, explain"
);

ok(
   no_diff(
      sub { mk_table_checksum::main(@args,
         qw(--chunk-size 20)) },
      "mk-table-checksum/t/samples/char-chunk-ascii.txt",
   ),
   "Char chunk ascii, chunk size 20"
);

ok(
   no_diff(
      sub { mk_table_checksum::main(@args,
         qw(--chunk-size 20 --chunk-size-limit 3)) },
      "mk-table-checksum/t/samples/char-chunk-ascii-oversize.txt",
   ),
   "Char chunk ascii, chunk size 20, with oversize"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
