#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use constant MKDEBUG => $ENV{MKDEBUG};

# #############################################################################
# First, some basic input-output diffs to make sure that
# the analysis reports are correct.
# #############################################################################

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output ) = @_;
   MKDEBUG && diag($cmd);
   `$cmd > /tmp/mk-memcached_test`;
   # Uncomment this line to update the $expected_output files when there is a
   # fix.
   # `cat /tmp/mk-memcached_test > $expected_output`;
   my $retval = system("diff /tmp/mk-memcached_test $expected_output");
   `rm -f /tmp/mk-memcached_test`;
   $retval = $retval >> 8; 
   return !$retval;
}

my $run_with = '../mk-memcached ../../common/t/samples/';

ok(
   no_diff($run_with.'empty', 'reports/empty_report.txt'),
   'Analysis for empty log'
);

ok(
   no_diff($run_with.'memc_tcpdump001.txt --print --group-by ""', 'reports/001_report-print.txt'),
   'Basic print of events',
);

ok(
   no_diff($run_with.'memc_tcpdump001.txt', 'reports/001_report.txt'),
   'Basic aggregate of events',
);

# #############################################################################
# Done.
# #############################################################################
exit;
