#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-kill/mk-kill";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');


my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-kill/mk-kill -F $cnf -h 127.1";

# #############################################################################
# Test --execute-command action.
# #############################################################################
diag(`rm -rf /tmp/mk-kill-test.txt`);

$output = `$cmd $trunk/common/t/samples/pl/recset001.txt --match-command Query --execute-command 'echo hello > /tmp/mk-kill-test.txt'`;
is(
   $output, 
   '',
   'No output without --print'
);

chomp($output = `cat /tmp/mk-kill-test.txt`),
is(
   $output,
   'hello',
   '--execute-command'
);

diag(`rm -rf /tmp/mk-kill-test.txt`);

SKIP: {
   skip 'Cannot connect to sandbox master', 2 unless $master_dbh;

   system("/tmp/12345/use -e 'select sleep(2)' >/dev/null 2>&1 &");

   $output = `$cmd --match-info 'select sleep' --run-time 2 --print --execute-command 'echo batty > /tmp/mk-kill-test.txt'`;
   like(
      $output,
      qr/KILL .+ select sleep\(2\)/,
      '--print with --execute-command'
   );

   chomp($output = `cat /tmp/mk-kill-test.txt`),
   is(
      $output,
      'batty',
      '--execute-command (online)'
   );
   
   # Let our select sleep(2) go away before other tests are ran.
   sleep 1;
}

diag(`rm -rf /tmp/mk-kill-test.txt`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh) if $master_dbh;
exit;
