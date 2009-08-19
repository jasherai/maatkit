#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

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

my @hosts = ('h=127.1,P=12345', 'h=127.1,P=12346');

sub output {
   my $output = '';
   open my $output_fh, '>', \$output
      or BAIL_OUT("Cannot capture output to variable: $OS_ERROR");
   select $output_fh;
   eval { mk_upgrade::main(@_); };
   close $output_fh;
   select STDOUT;
   return $EVAL_ERROR ? $EVAL_ERROR : $output;
}

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub test_no_diff {
   my ( $expected_output, @cmd_args ) = @_;
   my $tmp_file = '/tmp/mk-upgrade-test.txt';
   open my $fh, '>', $tmp_file or die "Can't open $tmp_file: $OS_ERROR";
   my $output = normalize(output(@cmd_args));
   print $fh $output;
   close $fh;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat $tmp_file > $expected_output`;
   my $retval = system("diff $tmp_file $expected_output");
   `rm -rf $tmp_file`;
   $retval = $retval >> 8; 
   return !$retval;
}

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
}

sub normalize {
   my ( $output ) = @_;
   # Zero out vals that change.
   $output =~ s/Query_time: (\S+)/Query_time: 0.000000/g;
   $output =~ s/line (\d+)/line 0/g;
   return $output;
}

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
# Test that connection opts inherit.
# #############################################################################
like(
   output('h=127.1,P=12345', 'h=127.1', 'samples/q001.txt'),
   qr/Host2_Query_time/,
   'host2 inherits from host1'
);

like(
   output('h=127.1', 'h=127.1', '--port', '12345', 'samples/q001.txt'),
   qr/Host2_Query_time/,
   'DSNs inherit standard connection options'
);

# #############################################################################
# Test some output.
# #############################################################################
ok(
   test_no_diff('samples/r001.txt', @hosts, 'samples/q001.txt'),
   'Basic output'
);

ok(
   test_no_diff('samples/r001-all-errors.txt', @hosts,
      '--all-errors', 'samples/q001.txt'),
   'Basic output --all-errors'
);

ok(
   test_no_diff('samples/r001-no-errors.txt', @hosts,
      '--no-errors', 'samples/q001.txt'),
   'Basic output --no-errors'
);

ok(
   test_no_diff('samples/r001-no-reasons.txt', @hosts,
      '--no-reasons', 'samples/q001.txt'),
   'Basic output --no-reasons'
);

ok(
   test_no_diff('samples/r001-no-reasons-no-errors.txt', @hosts,
      '--no-reasons', '--no-errors', 'samples/q001.txt'),
   'Basic output --no-reasons --no-errors'
);

ok(
   test_no_diff('samples/r001-no-compare-warnings.txt', @hosts,
      '--no-compare-warnings','samples/q001.txt'),
   'Basic output --no-compare-warnings'
);

ok(
   test_no_diff('samples/r001-no-compare-results.txt', @hosts,
      '--no-compare-results','samples/q001.txt'),
   'Basic output --no-compare-results'
);

# TODO: DSNParser clobbers SQL_MODE so we can't set ONLY_FULL_GROUP_BY.
# print output(@hosts, qw(samples/q002.txt --dump-results));

# #############################################################################
# Test that warnings are cleared after each query.
# #############################################################################

# How to reproduce?

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
