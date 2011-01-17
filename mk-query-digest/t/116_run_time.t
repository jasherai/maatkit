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
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift
shift @INC;  # Sandbox's unshift
require "$trunk/mk-query-digest/mk-query-digest";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 3;
}

# #############################################################################
# Issue 361: Add a --runfor (or something) option to mk-query-digest
# #############################################################################
`$trunk/mk-query-digest/mk-query-digest --processlist h=127.1,P=12345,u=msandbox,p=msandbox --run-time 3 --port 12345 --log /tmp/mk-query-digest.log --pid /tmp/mk-query-digest.pid --daemonize 1>/dev/null 2>/dev/null`;
chomp(my $pid = `cat /tmp/mk-query-digest.pid`);
sleep 2;
my $output = `ps ax | grep $pid | grep processlist | grep -v grep`;
ok(
   $output,
   'Still running for --run-time (issue 361)'
);

sleep 1;
$output = `ps ax | grep $pid | grep processlist | grep -v grep`;
ok(
   !$output,
   'No longer running for --run-time (issue 361)'
);

diag(`rm -rf /tmp/mk-query-digest.log`);


# #############################################################################
# Issue 1150: Make mk-query-digest --run-time behavior more flexible
# #############################################################################

# --run-time-mode event without a --run-time should result in the same output
# as --run-time-mode clock because the log ts will be effectively ignored.

my $before = output(
   sub { mk_query_digest::main("$trunk/common/t/samples/slow033.txt",
      '--report-format', 'query_report,profile')
   },
);

my $after = output(
   sub { mk_query_digest::main("$trunk/common/t/samples/slow033.txt",
      '--report-format', 'query_report,profile',
      qw(--run-time-mode event))
   },
);

is(
   $before,
   $after,
   "Event run time mode doesn't change analysis"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
