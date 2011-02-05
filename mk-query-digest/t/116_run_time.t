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
   plan tests => 9;
}

my @args;

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
@args = ('--report-format', 'query_report,profile', '--limit', '10');

# --run-time-mode event without a --run-time should result in the same output
# as --run-time-mode clock because the log ts will be effectively ignored.
my $before = output(
   sub { mk_query_digest::main("$trunk/common/t/samples/slow033.txt",
      '--report-format', 'query_report,profile')
   },
);

@args = ('--report-format', 'query_report,profile', '--limit', '10');

my $after = output(
   sub { mk_query_digest::main(@args, "$trunk/common/t/samples/slow033.txt",
      qw(--run-time-mode event))
   },
);

is(
   $before,
   $after,
   "Event run time mode doesn't change analysis"
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, "$trunk/common/t/samples/slow033.txt",
         qw(--run-time-mode event --run-time 1h)) },
      "mk-query-digest/t/samples/slow033-rtm-event-1h.txt"
   ),
   "Run-time mode event 1h"
);

# This is correct because the next event is 1d and 1m after the first.
# So runtime 1d should not include it.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, "$trunk/common/t/samples/slow033.txt",
         qw(--run-time-mode event --run-time 1d)) },
      "mk-query-digest/t/samples/slow033-rtm-event-1h.txt"
   ),
   "Run-time mode event 1d"
);

# Now we'll get the 2nd event but not the 3rd.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, "$trunk/common/t/samples/slow033.txt",
         qw(--run-time-mode event --run-time 25h)) },
      "mk-query-digest/t/samples/slow033-rtm-event-25h.txt"
   ),
   "Run-time mode event 25h"
);

# Run-time interval.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, "$trunk/common/t/samples/slow033.txt",
         qw(--run-time-mode interval --run-time 1d)) },
      "mk-query-digest/t/samples/slow033-rtm-interval-1d.txt"
   ),
   "Run-time mode interval 1d"
);

# This correctly splits these two events:
#   Time: 090727 11:19:30 # User@Host: [SQL_SLAVE] @  []
#   Time: 090727 11:19:31 # User@Host: [SQL_SLAVE] @  []
# The first belongs to the 0-29s interval, the second to the
# 30-60s interval.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, "$trunk/common/t/samples/slow033.txt",
         qw(--run-time-mode interval --run-time 30)) },
      "mk-query-digest/t/samples/slow033-rtm-interval-30s.txt"
   ),
   "Run-time mode interval 30s"
);

# No, contrary to the above, those two events are together because they're
# within the same 30m interval.
ok(
   no_diff(
      sub { mk_query_digest::main(@args, "$trunk/common/t/samples/slow033.txt",
         qw(--run-time-mode interval --run-time 30m)) },
      "mk-query-digest/t/samples/slow033-rtm-interval-30m.txt",
   ),
   "Run-time mode interval 30m"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
