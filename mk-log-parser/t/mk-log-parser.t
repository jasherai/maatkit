#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 4;
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent=1;

# Returns true (1) if there's no difference between the
# cmd's output and the expected output.
sub no_diff {
   my ( $cmd, $expected_output ) = @_;
   `$cmd > /tmp/mk-log-parser_test`;
   my $retval = system("diff /tmp/mk-log-parser_test $expected_output 1>/dev/null 2>/dev/null");
   `rm -rf /tmp/mk-log-parser_test`;
   $retval = $retval >> 8;
   return !$retval;
}

my $run_with = '../mk-log-parser ../../common/t/samples/';

ok(
   no_diff($run_with.'slow001.txt', 'samples/slow001_report.txt'),
   'Analysis for slow001'
);
ok(
   no_diff($run_with.'slow002.txt', 'samples/slow002_report.txt'),
   'Analysis for slow002'
);
ok(
   no_diff($run_with.'slow003.txt', 'samples/slow003_report.txt'),
   'Analysis for slow003'
);
ok(
   no_diff($run_with.'slow004.txt', 'samples/slow004_report.txt'),
   'Analysis for slow004'
);
exit;
