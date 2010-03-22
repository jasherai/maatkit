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
require "$trunk/mk-upgrade/mk-upgrade";

# This runs immediately if the server is already running, else it starts it.
diag(`$trunk/sandbox/start-sandbox master 12347 >/dev/null`);

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master');
my $dbh2 = $sb->get_dbh_for('slave2');

if ( !$dbh1 ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$dbh2 ) {
   plan skip_all => 'Cannot connect to second sandbox master';
}
else {
   plan tests => 4;
}

$sb->load_file('master', 'mk-upgrade/t/samples/001/tables.sql');
$sb->load_file('slave2', 'mk-upgrade/t/samples/001/tables.sql');

# Issue 747: Make mk-upgrade rewrite non-SELECT

my $cmd = "$trunk/mk-upgrade/mk-upgrade h=127.1,P=12345 P=12347 -u msandbox -p msandbox --compare results,warnings --zero-query-times --convert-to-select --fingerprints";

my $c1 = $dbh1->selectrow_arrayref('checksum table test.t')->[1];
my $c2 = $dbh2->selectrow_arrayref('checksum table test.t')->[1];

ok(
   $c1 == $c2,
   'Table checksums identical'
);

ok(
   no_diff(
      "$cmd $trunk/mk-upgrade/t/samples/001/non-selects.log",
      'mk-upgrade/t/samples/001/non-selects-rewritten.txt'
   ),
   'Rewrite non-SELECT'
);

my $c1_after = $dbh1->selectrow_arrayref('checksum table test.t')->[1];
my $c2_after = $dbh2->selectrow_arrayref('checksum table test.t')->[1];

ok(
   $c1_after == $c1,
   'Table on host1 not changed'
);

ok(
   $c2_after == $c2,
   'Table on host2 not changed'
);

$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
