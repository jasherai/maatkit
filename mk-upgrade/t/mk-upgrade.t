#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../mk-upgrade';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $dbh1 = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $dbh2 = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

$sb->create_dbs($dbh1, [qw(test)]);
$sb->load_file('master', '../../common/t/samples/issue_11.sql');
$dbh1->do('INSERT INTO test.issue_11 VALUES (1,2,3),(2,2,3),(3,1,1),(4,5,0)');

sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
   select $output_fh;
   mk_upgrade::main(@_);
   close $output_fh;
   select STDOUT;
   return $output;
}

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output ) = @_;
   MKDEBUG && diag($cmd);
   `$cmd > /tmp/mk-upgrade_test`;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat /tmp/mk-upgrade_test > $expected_output`;
   my $retval = system("diff /tmp/mk-upgrade_test $expected_output");
   `rm -rf /tmp/mk-upgrade_test`;
   $retval = $retval >> 8;
   return !$retval;
}

my $output = `../mk-upgrade --help`;
like(
   $output,
   qr/--ask-pass/,
   'It runs'
);

my @hosts = ('h=127.1,P=12345', 'h=127.1,P=12346');

print output(@hosts, 'samples/q001.txt');

# TODO: DSNParser clobbers SQL_MODE so we can't set ONLY_FULL_GROUP_BY.
# print output(@hosts, qw(samples/q002.txt --dump-results));

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
