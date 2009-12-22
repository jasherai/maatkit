#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 1;
}

my $output;

# #############################################################################
# Issue 248: Add --user, --pass, --host, etc to all tools
# #############################################################################
$output = `../mk-query-digest --processlist 127.1,P=12345,u=msandbox,p=msandbox --run-time 1 --port 12345`;
like(
   $output,
   qr/Rank\s+Query ID/,
   'DSN opts inherit from --host, --port, etc. (issue 248)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
