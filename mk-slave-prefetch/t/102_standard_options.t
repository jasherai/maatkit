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
require "$trunk/mk-slave-prefetch/mk-slave-prefetch";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 7;
}

my $output;

diag(`rm -f /tmp/mk-slave-prefetch-sentinel`);

# ###########################################################################
# Check daemonization.
# ###########################################################################
my $cmd = "$trunk/mk-slave-prefetch/mk-slave-prefetch -F /tmp/12346/my.sandbox.cnf --daemonize --pid /tmp/mk-slave-prefetch.pid --print";
diag(`$cmd 1>/dev/null 2>/dev/null`);
$output = `ps -eaf | grep 'mk-slave-prefetch \-F' | grep -v grep`;
like($output, qr/$cmd/, 'It lives daemonized');
ok(-f '/tmp/mk-slave-prefetch.pid', 'PID file created');

my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-prefetch.pid`;
is($output, $pid, 'PID file has correct PID');

# Kill it by testing --stop.
$output = `$trunk/mk-slave-prefetch/mk-slave-prefetch --stop`;
like(
   $output,
   qr{created file /tmp/mk-slave-prefetch-sentinel},
   'Create sentinel file'
);

sleep 1;
$output = `ps -eaf | grep 'mk-slave-prefetch \-F' | grep -v grep`;
is($output, '', 'Stops for sentinel');
ok(! -f '/tmp/mk-slave-prefetch.pid', 'PID file removed');

diag(`rm -f /tmp/mk-slave-prefetch-sentinel`);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `$trunk/mk-slave-prefetch/mk-slave-prefetch -F /tmp/12346/my.sandbox.cnf --print --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;


# #############################################################################
# Done.
# #############################################################################
exit;
