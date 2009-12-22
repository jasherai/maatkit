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
   plan tests => 2;
}

# #############################################################################
# Issue 361: Add a --runfor (or something) option to mk-query-digest
# #############################################################################
`../mk-query-digest --processlist h=127.1,P=12345,u=msandbox,p=msandbox --run-time 3 --port 12345 --log /tmp/mk-query-digest.log --pid /tmp/mk-query-digest.pid --daemonize 1>/dev/null 2>/dev/null`;
chomp(my $pid = `cat /tmp/mk-query-digest.pid`);
sleep 2;
my $output = `ps ax | grep $pid | grep processlist | grep -v grep`;
ok(
   $output,
   'Still running for --run-time (issue 361)'
);

sleep 1;
$output = `ps ax | grep $pid | grep processlist | grep -v grep`;
ok(
   !$output,
   'No longer running for --run-time (issue 361)'
);

diag(`rm -rf /tmp/mk-query-digest.log`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
