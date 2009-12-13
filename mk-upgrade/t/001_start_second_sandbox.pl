#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

diag(`../../sandbox/make_sandbox 12347 >/dev/null 2>&1`)
   unless -d '/tmp/12347';

# Not really slave2, we just use its port.
my $dbh2 = $sb->get_dbh_for('slave2');

ok(
   $dbh2,
   'Second sandbox started'
);

exit;
