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

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';
$sb->load_file('master', 'mk-table-checksum/t/samples/issue_602.sql');

# #############################################################################
# Issue 602: mk-table-checksum issue with invalid dates
# #############################################################################

$output = output(
   sub {
      mk_table_checksum::main("F=$cnf", qw(-t issue_602.t --chunk-size 5)) },
   undef,
   stderr => 1,
);

like(
   $output,
   qr/^issue_602\s+t\s+2/m,
   "Checksums table despite invalid datetime"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
