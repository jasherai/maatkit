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
use DSNParser;

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --limit 10 $trunk/common/t/samples/";

# #############################################################################
# Issue 173: Make mk-query-digest do collect-and-report cycles
# #############################################################################

# This tests --iterations by checking that its value multiplies --run-for. 
# So if --run-for is 2 and we do 2 iterations, we should run for 4 seconds
# total.
my $pid;
my $output;

`$trunk/mk-query-digest/mk-query-digest --processlist h=127.1,P=12345,u=msandbox,p=msandbox --run-time 2 --iterations 2 --port 12345 --pid /tmp/mk-query-digest.pid --daemonize 1>/dev/null 2>/dev/null`;
chomp($pid = `cat /tmp/mk-query-digest.pid`);
sleep 3;
$output = `ps ax | grep $pid | grep processlist | grep -v grep`;
ok(
   $output,
   'Still running for --iterations (issue 173)'
);

sleep 2;
$output = `ps ax | grep $pid | grep processlist | grep -v grep`;
ok(
   !$output,
   'No longer running for --iterations (issue 173)'
);

# Another implicit test of --iterations checks that on the second
# iteration no queries are reported because the slowlog was read
# entirely by the first iteration.
ok(
   no_diff($run_with . 'slow002.txt --iterations 2   --report-format=query_report,profile --limit 1',
   "mk-query-digest/t/samples/slow002_iters_2.txt"),
   '--iterations'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
