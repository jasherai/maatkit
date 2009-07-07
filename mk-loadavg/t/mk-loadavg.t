#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

require '../mk-loadavg';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
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
# Issue 516: Add mk-loadavg metrics for InnoDB status info
# #############################################################################
like(
   output(qw(-F /tmp/12345/my.sandbox.cnf --metrics innodb:1 --innodb), 'status,Innodb_data_fsyncs', qw(--info uptime --run-time 1 --sleep 1)),
   qr/load average: /,
   'innodb metric'
);

is(
   output(qw(-F /tmp/12345/my.sandbox.cnf --metrics innodb:10000000000 --innodb), 'status,Innodb_data_fsyncs', qw(--info uptime --run-time 1 --sleep 1)),
   '',
   'No info when innodb metric not exceeded'
);

# #############################################################################
# Done.
# #############################################################################

# wipe_clean is causing an error:
#   DBD::mysql::db selectcol_arrayref failed: MySQL server has gone away
#   at ../../common/Sandbox.pm line 142.
# It's somehow due to the issue 515 test and the forked process.
eval { $sb->wipe_clean($dbh); };

exit;
