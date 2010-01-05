#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

require '../mk-upgrade';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh1 = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

diag(`../../sandbox/start-sandbox master 12347`) unless -d '/tmp/12347';
# Not really slave2, we just use its port.
my $dbh2 = $sb->get_dbh_for('slave2')
   or BAIL_OUT('Cannot connect to second sandbox master');

$sb->load_file('master', 'mk-upgrade/t/samples/001/tables.sql');
$sb->load_file('slave2', 'mk-upgrade/t/samples/001/tables.sql');

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output ) = @_;
   `$cmd > /tmp/mk-upgrade-output.txt`;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat /tmp/mk-upgrade-output.txt > $expected_output`;
   my $retval = system("diff /tmp/mk-upgrade-output.txt $expected_output");
   `rm -rf /tmp/mk-upgrade-output.txt`;
   $retval = $retval >> 8; 
   return !$retval;
}

# Issue 747: Make mk-upgrade rewrite non-SELECT

my $cmd = '../mk-upgrade h=127.1,P=12345 P=12347 -u msandbox -p msandbox --compare results,warnings --zero-query-times --convert-to-select --fingerprints';

my $c1 = $dbh1->selectrow_arrayref('checksum table test.t')->[1];
my $c2 = $dbh2->selectrow_arrayref('checksum table test.t')->[1];

ok(
   $c1 == $c2,
   'Table checksums identical'
);

ok(
   no_diff(
      "$cmd samples/001/non-selects.log",
      'samples/001/non-selects-rewritten.txt'
   ),
   'Rewrite non-SELECT'
);

my $c1_after = $dbh1->selectrow_arrayref('checksum table test.t')->[1];
my $c2_after = $dbh2->selectrow_arrayref('checksum table test.t')->[1];

ok(
   $c1_after == $c1,
   'Table on host1 not changed'
);

ok(
   $c2_after == $c2,
   'Table on host2 not changed'
);

$sb->wipe_clean($dbh1);
$sb->wipe_clean($dbh2);
exit;
