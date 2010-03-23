#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use Grants;
use DSNParser;
use Sandbox;
use MaatkitTest;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $gr = new Grants;
isa_ok($gr, 'Grants');

diag(`/tmp/12345/use -u root -e "GRANT USAGE ON *.* TO ''\@'%'"`);
my $anon_dbh = DBI->connect(
   "DBI:mysql:;host=127.0.0.1;port=12345", undef, undef,
   { PrintError => 0, RaiseError => 1 });
ok(!$gr->have_priv($anon_dbh, 'process'), 'Anonymous user does not have PROCESS priv');

diag(`/tmp/12345/use -uroot -umsandbox -e "DROP USER ''\@'%'"`);

ok($gr->have_priv($dbh, 'PROCESS'), 'Normal user does have PROCESS priv');

eval {
   $gr->have_priv($dbh, 'foo');
};
like($EVAL_ERROR, qr/no check for privilege/, 'Dies if privilege has no check');

exit;
