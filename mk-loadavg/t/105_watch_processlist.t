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
require "$trunk/mk-loadavg/mk-loadavg";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 6;
}

my $output;
my $sentinel = '/tmp/mk-loadavg-sentinel';
my $log      = '/tmp/mk-loadavg-log';
my $out      = '/tmp/mk-loadavg-out';
my $pid      = '/tmp/mk-loadavg-pid';
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-loadavg/mk-loadavg -F $cnf -h 127.1";

diag(`rm -rf $log $sentinel $pid $out`);
system("$cmd --watch 'Processlist:state:executing:count:>:2' -v --daemonize  --interval 1 --sentinel $sentinel --pid $pid --execute-command 'echo OK >> $out' --log $log");
ok(
   -f $pid && -f $log,
   'mk-loadavg is running'
);

system("/tmp/12345/use -e 'select sleep(5)' >/dev/null 2>&1 &");
sleep 1;
ok(
   !-f $out, 
   'Not enough executing queries yet'
);

system("/tmp/12345/use -e 'select sleep(4)' >/dev/null 2>&1 &");
sleep 1;
ok(
   !-f $out,
   'Still not enough executing queries'
);

system("/tmp/12345/use -e 'select sleep(3)' >/dev/null 2>&1 &");
sleep 1;
chomp($output = `cat $out`);
is(
   $output,
   'OK',
   'Triggered with enough executing queries'
);

diag(`touch $sentinel`);
sleep 1;
diag(`rm -rf $sentinel`);

ok(
   !-f $pid,
   'mk-loadavg has stopped'
);

$output = `grep -A 1 FAIL $log`;
like(
   $output,
   qr/FAIL: 3 > 2\n.+ Executing echo/,
   'Logged check failure and cmd execution'
);

diag(`rm -rf $log $out`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
