#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

require '../mk-loadavg';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-loadavg -F $cnf ";

my $output = `$cmd --metrics loadavg --info processlist --print-load-avg --run-time 1 --sleep 1`;
like(
   $output,
   qr/loadavg\s+(?:[\d\.])+/,
   'It runs and prints a loadavg for the loadavg metric'
);

# #############################################################################
# Issue 515: Add mk-loadavg --execute-command option
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-test`);
mk_loadavg::main('-F', $cnf, qw(--metrics status:1 --status Uptime),
   '--execute-command', 'echo hi > /tmp/mk-loadavg-test && sleep 2',
   qw(--sleep 0 --run-time 1));
sleep 1;
ok(
   -f '/tmp/mk-loadavg-test',
   '--execute-command'
);

diag(`rm -rf /tmp/mk-loadavg-test`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
