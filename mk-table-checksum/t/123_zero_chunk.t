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
my @args = ('-F', $cnf, 'h=127.1', qw(-t sakila.actor --explain --chunk-size 100));

$output = output(
   sub { mk_table_checksum::main(@args) },
);
like(
   $output,
   qr/`actor_id` = 0/,
   "Zero chunk"
);

$output = output(
   sub { mk_table_checksum::main(@args, qw(--no-zero-chunk)) },
);
unlike(
   $output,
   qr/`actor_id` = 0/,
   "No zero chunk"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
