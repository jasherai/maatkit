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
   plan tests => 4;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-loadavg/mk-loadavg -F $cnf -h 127.1";

$output = `$cmd --watch 'Server:loadavg:1:>:0' -v  --interval 1 --run-time 1s`;
like(
   $output,
   qr/Checking Server:loadavg:1:>:0/,
   'It runs and prints a loadavg for Server:loadavg'
);

# #############################################################################
# Issue 516: Add mk-loadavg metrics for InnoDB status info
# #############################################################################
$output = `$cmd --watch "Status:innodb:Innodb_data_fsyncs:>:1" -v --run-time 1 --interval 1`;
like(
   $output,
   qr/Checking Status:innodb:Innodb_data_fsyncs:>:1\n.+FAIL/,
   'Watch an InnoDB status value'
);

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
# Issue 622: mk-loadavg requires a database connection
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-test`);

# Don't use $cmd because it specifies a host.  This tests that
# some watches work when no host info is given.
`$trunk/mk-loadavg/mk-loadavg --watch "Server:vmstat:buff:>:0" --execute-command 'echo hi > /tmp/mk-loadavg-test' --interval 1 --run-time 1`;

ok(
   -f '/tmp/mk-loadavg-test',
   "Doesn't always need a dbh (issue 622)"
);

diag(`rm -rf /tmp/mk-loadavg-test`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
