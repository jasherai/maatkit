#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 10;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../mk-upgrade';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh1 = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

diag(`../../sandbox/make_sandbox 12347`) unless -d '/tmp/12347';
# Not really slave2, we just use its port.
my $dbh2 = $sb->get_dbh_for('slave2')
   or BAIL_OUT('Cannot connect to second sandbox master');

$sb->load_file('master', 'samples/001/tables.sql');
$sb->load_file('slave2', 'samples/001/tables.sql');

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output ) = @_;
   MKDEBUG && diag($cmd);
   `$cmd > /tmp/mk-upgrade-output.txt`;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat /tmp/mk-upgrade-output.txt > $expected_output`;
   my $retval = system("diff /tmp/mk-upgrade-output.txt $expected_output");
   `rm -rf /tmp/mk-upgrade-output.txt`;
   $retval = $retval >> 8; 
   return !$retval;
}

my $cmd = '../mk-upgrade h=127.1,P=12345 P=12347 --compare results,warnings --zero-query-times';

# #############################################################################
# Test that it runs.
# #############################################################################
my $output = `../mk-upgrade --help`;
like(
   $output,
   qr/--ask-pass/,
   'It runs'
);

# #############################################################################
# Test basic runs.
# #############################################################################
ok(
   no_diff(
      "$cmd samples/001/select-one-log.txt",
      'samples/001/select-one-report.txt'
   ),
   'Report for a single query (checksum method)'
);

ok(
   no_diff(
      "$cmd samples/001/select-everyone-log.txt",
      'samples/001/select-everyone-report.txt'
   ),
   'Report for multiple queries (checksum method)'
);

ok(
   no_diff(
      "$cmd samples/001/select-one-log.txt --compare-results-method rows",
      'samples/001/select-one-rows-report.txt'
   ),
   'Report for a single query (rows method)'
);

ok(
   no_diff(
      "$cmd samples/001/select-everyone-log.txt --compare-results-method rows",
      'samples/001/select-everyone-rows-report.txt'
   ),
   'Report for multiple queries (rows method)'
);

ok(
   no_diff(
      "$cmd --reports queries,differences,errors samples/001/select-everyone-log.txt",
      'samples/001/select-everyone-no-stats-report.txt'
   ),
   'Report without statistics'
);

ok(
   no_diff(
      "$cmd --reports differences,errors,statistics samples/001/select-everyone-log.txt",
      'samples/001/select-everyone-no-queries-report.txt'
   ),
   'Report without per-query reports'
);

# #############################################################################
# Test that non-SELECT queries are skipped.
# #############################################################################
ok(
   no_diff(
      "$cmd samples/001/non-selects-log.txt",
      'samples/001/non-selects-report.txt'
   ),
   'Report for non-selects'
);

# #############################################################################
# Test --clear-warnings.
# #############################################################################

# Ideas how to do this?

# #############################################################################
# Issue 391: Add --pid option to all scripts
# #############################################################################
`touch /tmp/mk-script.pid`;
$output = `$cmd samples/001/select-one-log.txt --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
$output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   mk_upgrade::_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
