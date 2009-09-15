#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

require '../mk-loadavg';
require '../../common/Sandbox.pm';
my $dp  = new DSNParser();
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-loadavg -F $cnf ";

sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
   select $output_fh;
   eval { mk_loadavg::main(@_); };
   close $output_fh;
   select STDOUT;
   return $EVAL_ERROR ? $EVAL_ERROR : $output;
}

# ###########################################################################
# Test parse_watch().
# ###########################################################################
my $watch = 'Status:status:Threads_connected:>:16,Processlist:command:Query:time:<:1,Server:vmstat:free:=:0';

is_deeply(
   [ mk_loadavg::parse_watch($watch) ],
   [
      [ 'Status',       'status:Threads_connected:>:16', ],
      [ 'Processlist',  'command:Query:time:<:1',        ],
      [ 'Server',       'vmstat:free:=:0',               ],
   ],
   'parse_watch()'
);

my $output = `$cmd --watch 'Server:loadavg:1:>:0' -v  --sleep 1 --run-time 1s`;
like(
   $output,
   qr/Checking Server:loadavg:1:>:0/,
   'It runs and prints a loadavg for Server:loadavg'
);

# #############################################################################
# Issue 515: Add mk-loadavg --execute-command option
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-test`);
mk_loadavg::main('-F', $cnf, qw(--watch Status:status:Uptime:<:1),
   '--execute-command', 'echo hi > /tmp/mk-loadavg-test && sleep 2',
   qw(--sleep 1 --run-time 1));
sleep 1;
ok(
   -f '/tmp/mk-loadavg-test',
   '--execute-command'
);

diag(`rm -rf /tmp/mk-loadavg-test`);

# #############################################################################
# Issue 516: Add mk-loadavg metrics for InnoDB status info
# #############################################################################
like(
   output(qw(-F /tmp/12345/my.sandbox.cnf --watch Status:innodb:Innodb_data_fsyncs:>:1 -v --run-time 1 --sleep 1)),
   qr/Checking Status:innodb:Innodb_data_fsyncs:>:1\n.+PASS/,
   'Watch an InnoDB status value'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd --watch 'Server:loadavg:1:>:0' --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################

# wipe_clean is causing an error:
#   DBD::mysql::db selectcol_arrayref failed: MySQL server has gone away
#   at ../../common/Sandbox.pm line 142.
# It's somehow due to the issue 515 test and the forked process.
eval { $sb->wipe_clean($dbh); };

exit;
