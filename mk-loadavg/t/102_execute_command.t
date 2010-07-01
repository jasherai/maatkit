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
   plan tests => 1;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-loadavg/mk-loadavg -F $cnf -h 127.1";

# #############################################################################
# Issue 515: Add mk-loadavg --execute-command option
# #############################################################################
diag(`rm -rf /tmp/mk-loadavg-test`);
`$cmd --watch "Status:status:Uptime:>:1" --execute-command 'echo hi > /tmp/mk-loadavg-test' --interval 1 --run-time 1`;

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
