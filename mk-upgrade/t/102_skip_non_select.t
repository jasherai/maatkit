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
   plan tests => 1;
}

$sb->load_file('master', 'mk-upgrade/t/samples/001/tables.sql');
$sb->load_file('slave2', 'mk-upgrade/t/samples/001/tables.sql');

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

my $cmd = '../mk-upgrade h=127.1,P=12345,u=msandbox,p=msandbox P=12347 --compare results,warnings --zero-query-times';

# Test that non-SELECT queries are skipped by default.
ok(
   no_diff(
      "$cmd samples/001/non-selects.log",
      'samples/001/non-selects.txt'
   ),
   'Non-SELECT are skipped by default'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
