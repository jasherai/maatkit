#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 14;

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

my $output = `$cmd --watch 'Server:loadavg:1:>:0' -v  --interval 1 --run-time 1s`;
like(
   $output,
   qr/Checking Server:loadavg:1:>:0/,
   'It runs and prints a loadavg for Server:loadavg'
);

# #############################################################################
# Issue 515: Add mk-loadavg --execute-command option
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-test`);
mk_loadavg::main('-F', $cnf, qw(--watch Status:status:Uptime:>:1),
   '--execute-command', 'echo hi > /tmp/mk-loadavg-test',
   qw(--interval 1 --run-time 1));

ok(
   -f '/tmp/mk-loadavg-test',
   '--execute-command'
);

diag(`rm -rf /tmp/mk-loadavg-test`);

# #############################################################################
# Issue 516: Add mk-loadavg metrics for InnoDB status info
# #############################################################################
like(
   output(qw(-F /tmp/12345/my.sandbox.cnf --watch Status:innodb:Innodb_data_fsyncs:>:1 -v --run-time 1 --interval 1)),
   qr/Checking Status:innodb:Innodb_data_fsyncs:>:1\n.+FAIL/,
   'Watch an InnoDB status value'
);

# ###########################################################################
# Issue 391: Add --pid option to all scripts
# ###########################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd --watch 'Server:loadavg:1:>:0' --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;


# #############################################################################
# Issue 622: mk-loadavg requires a database connection
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-test`);
mk_loadavg::main(qw(--watch Server:vmstat:buff:>:0),
   '--execute-command', 'echo hi > /tmp/mk-loadavg-test',
   qw(--interval 1 --run-time 1));

ok(
   -f '/tmp/mk-loadavg-test',
   "Doesn't always need a dbh (issue 622)"
);

diag(`rm -rf /tmp/mk-loadavg-test`);


# #############################################################################
# Issue 621: mk-loadavg doesn't watch vmstat correctly
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-out.txt`);
`$cmd --watch 'Status:status:Uptime:>:1' --interval 1 --run-time 1s --execute-command "echo Ok > /tmp/mk-loadavg-out.txt"`;
chomp($output = `cat /tmp/mk-loadavg-out.txt`);
like(
   $output,
   qr/Ok/,
   'Action triggered when watched item check is true'
);

diag(`rm -rf /tmp/mk-loadavg-out.txt`);

# #############################################################################
# Issue 692: mk-loadavg should reconnect to MySQL
# #############################################################################
my $slave_dbh = $sb->get_dbh_for('slave1');
SKIP: {
   skip 'Cannot connect to sandbox slave', 7 unless $slave_dbh;

   diag(`rm -rf /tmp/mk-loadavg-test`);
   diag(`rm -rf /tmp/mk-loadavg.log`);

   system("../mk-loadavg -F /tmp/12346/my.sandbox.cnf --watch 'Status:status:Uptime:>:9' --verbose --execute-command 'echo hi > /tmp/mk-loadavg-test' --daemonize --log /tmp/mk-loadavg.log --interval 2 --wait 1 --run-time 3");

   sleep 1;
   diag(`/tmp/12346/stop`);
   sleep 1;
   diag(`/tmp/12346/start`);

   # Make sure the sandbox slave is still running.
   $slave_dbh = $sb->get_dbh_for('slave1');
   eval { $slave_dbh->do('start slave'); };
   sleep 2;
   is_deeply(
      $slave_dbh->selectrow_hashref('show slave status')->{Slave_IO_Running},
      'Yes',
      'Sandbox slave IO running'
   );
   is_deeply(
      $slave_dbh->selectrow_hashref('show slave status')->{Slave_SQL_Running},
      'Yes',
      'Sandbox slave SQL running'
   );

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
};

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
