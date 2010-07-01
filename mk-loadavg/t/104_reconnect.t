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
require "$trunk/mk-loadavg/mk-loadavg";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 5;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-loadavg/mk-loadavg -F $cnf -h 127.1";

# #############################################################################
# Issue 692: mk-loadavg should reconnect to MySQL
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-test`);
diag(`rm -rf /tmp/mk-loadavg.log`);

system("$cmd --watch 'Status:status:Uptime:>:9' --verbose --execute-command 'echo hi > /tmp/mk-loadavg-test' --daemonize --log /tmp/mk-loadavg.log --interval 2 --wait 1 --run-time 3");

sleep 1;
diag(`/tmp/12345/stop >/dev/null`);
sleep 1;
diag(`/tmp/12345/start >/dev/null`);

$dbh = $sb->get_dbh_for('master');
sleep 2;

# 2009-11-13T15:56:25 mk-loadavg started with:
#  --watch Status:status:Uptime:>:9
#  --execute-command echo hi > /tmp/mk-loadavg-test
#  --interval 2
# 2009-11-13T15:56:25 Watching server F=/tmp/12346/my.sandbox.cnf
# 2009-11-13T15:56:25 Checking Status:status:Uptime:>:9
# 2009-11-13T15:56:25 FAIL: 117 > 9
# 2009-11-13T15:56:25 Executing echo hi > /tmp/mk-loadavg-test
# 2009-11-13T15:56:25 Sleeping 2
# 2009-11-13T15:56:27 MySQL not responding; waiting 1 to reconnect
# 2009-11-13T15:56:28 Could not reconnect to MySQL server:
# 2009-11-13T15:56:28 MySQL not responding; waiting 1 to reconnect
# 2009-11-13T15:56:29 Reconnected to MySQL
# 2009-11-13T15:56:29 Checking Status:status:Uptime:>:9
# 2009-11-13T15:56:29 PASS: 0 > 9
# 2009-11-13T15:56:29 Sleeping 2
# 2009-11-13T15:56:31 Done watching server F=/tmp/12346/my.sandbox.cnf
$output = `cat /tmp/mk-loadavg.log`;
like(
   $output,
   qr/FAIL: /,
   'Ran successfully before MySQL went away (issue 692)'
);
like(
   $output,
   qr/MySQL not responding/,
   'Caught that MySQL went away (issue 692)'
);
like(
   $output,
   qr/Reconnected to MySQL/,
   'Reconnected to MySQL (issue 692)'
);
like(
   $output,
   qr/PASS: /,
   'Ran successfully after reconnecting (issue 692)'
);
like(
   $output,
   qr/Done watching/,
   'Terminated normally after restarting (issue 692)'
);

diag(`rm -rf /tmp/mk-loadavg-test`);
diag(`rm -rf /tmp/mk-loadavg.log`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
