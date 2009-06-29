#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

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

sub load_file {
   my ($file) = @_;
   open my $fh, "<", $file or die $!;
   my $contents = do { local $/ = undef; <$fh> };
   close $fh;
   return $contents;
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
# Test that host2 inherits from hos1.
# #############################################################################
like(
   output('h=127.1,P=12345', 'h=127.1', 'samples/q001.txt'),
   qr/Execution Results/,
   'host2 inherits from host1'
);

# #############################################################################
# Test some output.
# #############################################################################
$output = output(@hosts, 'samples/q001.txt');
$output =~ s/Query time: (\S+)/Query time: 0/g;
is(
   $output,
   load_file('samples/r001.txt'),
   'Basic output'
);

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
