#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../mk-upgrade';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh1 = $sb->get_dbh_for('master');
my $dbh2 = $sb->get_dbh_for('slave2');

if ( !$dbh1 ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$dbh2 ) {
   plan skip_all => 'Cannot connect to second sandbox master';
}
else {
   plan tests => 5;
}

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

my $cmd = '../mk-upgrade h=127.1,P=12345 P=12347 --compare results,warnings --zero-query-times --compare-results-method rows --limit 10';

# This test really deals with,
#   http://code.google.com/p/maatkit/issues/detail?id=754
#   http://bugs.mysql.com/bug.php?id=49634

$dbh2->do('set global query_cache_size=1000000');

my $qc = $dbh2->selectrow_arrayref('show variables like "query_cache_size"')->[1];
ok(
   $qc > 999000,
   'Query size'
);

$qc = $dbh2->selectrow_arrayref('show variables like "query_cache_type"')->[1];
is(
   $qc,
   'ON',
   'Query cache ON'
);


diag(`$cmd samples/001/one-error.log >/dev/null 2>&1`);

ok(
   no_diff(
      "$cmd samples/001/one-error.log",
      'samples/001/one-error.txt',
   ),
   '--clear-warnings',
);

# This produces a similar result to --clear-warnings.  The difference is that
# the script reports that the borked query has both Errors and Warnings.
# This happens because with --clear-warnings the script fails to clear the
# warnings for the borked query (since it has no tables) so it skips the
# CompareWarnings module (it skips any module that fails) thereby negating its
# ability to check/report Warnings.
ok(
   no_diff(
      "$cmd --no-clear-warnings samples/001/one-error.log",
      'samples/001/one-error-no-clear-warnings.txt',
   ),
   '--no-clear-warnings'
);

$dbh2->do('set global query_cache_size=0');
$qc = $dbh2->selectrow_arrayref('show variables like "query_cache_size"')->[1];
ok(
   $qc == 0,
   'Query size'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
