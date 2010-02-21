#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 7;
use MaatkitTest;

use QueryAdvisorRules;
use PodParser;

# This test should just test that the QueryAdvisor module conforms to the
# expected interface:
#   - It has a get_rules() method that returns a list of hashrefs:
#     ({ID => 'ID', code => $code}, {ID => ..... }, .... )
#   - It has a load_rule_info() method that accepts a list of hashrefs, which
#     we'll use to load rule info from POD.  Our built-in rule module won't
#     store its own rule info.  But plugins supplied by users should.
#   - It has a get_rule_info() method that accepts an ID and returns a hashref:
#     {ID => 'ID', Severity => 'NOTE|WARN|CRIT', Description => '......'}
my $qar = new QueryAdvisorRules();

# TODO: write a test that calls $qar->get_rules().  Check that the result is an
# array, and that each array element is a hashref as described above.

# Test that we can load rule info from POD.  Make a sample POD file that has a
# single sample rule definition for LIT.001 or something.
$qar->load_rule_info(
   $pp->parse_advisor_rule_info(
      "$ENV{MAATKIT_TRUNK}/common/t/samples/POD-rule-LIT.001.pod"));

# We shouldn't be able to load the same rule info twice.
throws_ok (
   sub {
      $qar->load_rule_info(
         $pp->parse_advisor_rule_info(
            "$ENV{MAATKIT_TRUNK}/common/t/samples/POD-rule-LIT.001.pod"));
   },
   qr/Info for rule \S+ already exists, and cannot be redefined/,
   'Duplicate rule info is caught',
);

# Test that we can now get a hashref as described above.
is_deeply(
   $qar->get_rule_info('LIT.001'),
   {  ID          => 'LIT.001',
      Severity    => 'NOTE',
      Description => 'Foo foo apple duck whatever',
   },
   'get_rule_info(LIT.001) works',
);

# #############################################################################
# Done.
# #############################################################################
my $output = '';
{
   local *STDERR;
   open STDERR, '>', \$output;
   $p->_d('Complete test coverage');
}
like(
   $output,
   qr/Complete test coverage/,
   '_d() works'
);
exit;
