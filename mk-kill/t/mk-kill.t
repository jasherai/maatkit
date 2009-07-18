#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 8;

require '../mk-kill';
require '../../common/Sandbox.pm';

sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
   select $output_fh;
   eval { mk_kill::main(@_); };
   close $output_fh;
   select STDOUT;
   return $EVAL_ERROR ? $EVAL_ERROR : $output;
}

# Shell out to a sleep(10) query and try to capture the query.  Backticks don't
# work here.
system("mysql -h127.1 -P12345 -e 'select sleep(10)' >/dev/null&");

my $output = `perl ../mk-kill -P 12345 -h 127.1 --busy-time 1s --print --iterations 20`;

# $output ought to be something like
# 2009-05-27T22:19:40 KILL 5 (Query 1 sec) select sleep(10)
# 2009-05-27T22:19:41 KILL 5 (Query 2 sec) select sleep(10)
# 2009-05-27T22:19:42 KILL 5 (Query 3 sec) select sleep(10)
# 2009-05-27T22:19:43 KILL 5 (Query 4 sec) select sleep(10)
# 2009-05-27T22:19:44 KILL 5 (Query 5 sec) select sleep(10)
# 2009-05-27T22:19:45 KILL 5 (Query 6 sec) select sleep(10)
# 2009-05-27T22:19:46 KILL 5 (Query 7 sec) select sleep(10)
# 2009-05-27T22:19:47 KILL 5 (Query 8 sec) select sleep(10)
# 2009-05-27T22:19:48 KILL 5 (Query 9 sec) select sleep(10)
my @times = $output =~ m/\(Query (\d+) sec\)/g;
ok(@times > 7 && @times < 12, 'There are approximately 9 or 10 captures');


# This is to catch a bad bug where there wasn't any sleep time when --iterations
# was 0, and another bug when --run-time was not respected.  Do it all over
# again, this time with --iterations 0.
system("mysql -h127.1 -P12345 -e 'select sleep(10)' >/dev/null&");
$output = `perl ../mk-kill -P 12345 -h 127.1 --busy-time 1s --print --iterations 0 --run-time 11s`;
@times = $output =~ m/\(Query (\d+) sec\)/g;
ok(@times > 7 && @times < 12, 'Approximately 9 or 10 captures with --iterations 0');

# #############################################################################
# Check that it daemonizes.
# #############################################################################

# There's no hung queries so we'll just make sure it outputs anything,
# its debug stuff in this case.
`../mk-kill -F /tmp/12345/my.sandbox.cnf --print --interval 1s --iterations 2 --pid /tmp/mk-kill.pid --log /tmp/mk-kill.log --daemonize`;
$output = `ps -eaf | grep 'mk-kill \-F'`;
like(
   $output,
   qr/mk-kill -F /,
   'It lives daemonized'
);
ok(
   -f '/tmp/mk-kill.pid',
   'PID file created'
);
ok(
   -f '/tmp/mk-kill.log',
   'Log file created'
);

sleep 2;
ok(
   !-f '/tmp/mk-kill.pid',
   'PID file removed'
);

diag(`rm -rf /tmp/mk-kill.log`);

# #############################################################################
# Test --execute-command action.
# #############################################################################
diag(`rm -rf /tmp/mk-kill-test.txt`);
is(
   output(qw(../../common/t/samples/recset001.txt --match-command Query --execute-command), 'echo hello > /tmp/mk-kill-test.txt'),
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
# #############################################################################
# Done.
# #############################################################################
exit;
