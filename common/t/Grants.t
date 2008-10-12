#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);

require '../Grants.pm';
require '../DSNParser.pm';

my $gr = new Grants;

isa_ok($gr, 'Grants');

diag(`../../sandbox/stop_all`);
diag(`../../sandbox/make_sandbox 12345`);
diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO ''\@'localhost'"`);

my $dbh = DBI->connect(
   "DBI:mysql:;host=127.0.0.1;port=12345", undef, undef,
      { PrintError => 0, RaiseError => 1 });

ok(!$gr->have_priv($dbh, 'process'), 'Anonymous user does not have PROCESS priv');

diag(`/tmp/12345/use -u root -e "DROP USER ''\@'localhost'"`);

my $dp = new DSNParser();
my $dsn = $dp->parse("h=127.0.0.1,P=12345");
$dbh    = $dp->get_dbh($dp->get_cxn_params($dsn), { AutoCommit => 1 });

ok($gr->have_priv($dbh, 'PROCESS'), 'Normal user does have PROCESS priv');

eval {
   $gr->have_priv($dbh, 'foo');
};
like($EVAL_ERROR, qr/no check for privilege/, 'Dies if privilege has no check');

diag(`../../sandbox/stop_all`);
exit;
