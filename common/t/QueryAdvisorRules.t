#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 8;

use MaatkitTest;
use PodParser;
use QueryAdvisorRules;

# This test should just test that the QueryAdvisor module conforms to the
# expected interface:
#   - It has a get_rules() method that returns a list of hashrefs:
#     ({ID => 'ID', code => $code}, {ID => ..... }, .... )
#   - It has a load_rule_info() method that accepts a list of hashrefs, which
#     we'll use to load rule info from POD.  Our built-in rule module won't
#     store its own rule info.  But plugins supplied by users should.
#   - It has a get_rule_info() method that accepts an ID and returns a hashref:
#     {ID => 'ID', Severity => 'NOTE|WARN|CRIT', Description => '......'}
my $p   = new PodParser();
my $qar = new QueryAdvisorRules(PodParser => $p);

my $rules = $qar->get_rules();
is(
   ref $rules,
   'ARRAY',
   'Returns arrayref of rules'
);

my $rules_ok = 1;
foreach my $rule ( @$rules ) {
   if (    !$rule->{id}
        || !$rule->{code}
        || (ref $rule->{code} ne 'CODE') )
   {
      $rules_ok = 0;
      last;
   }
}
ok(
   $rules_ok,
   'All rules are proper'
);

# Test that we can load rule info from POD.  Make a sample POD file that has a
# single sample rule definition for LIT.001 or something.
$qar->load_rule_info(
   rules    => $rules,
   file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
   section  => 'CHECKS',
);

# We shouldn't be able to load the same rule info twice.
throws_ok(
   sub {
      $qar->load_rule_info(
         rules    => $rules,
         file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
         section  => 'CHECKS',
      );
   },
   qr/Info for rule \S+ already exists and cannot be redefined/,
   'Duplicate rule info is caught',
);

# Test that we can now get a hashref as described above.
is_deeply(
   $qar->get_rule_info('LIT.001'),
   {  id          => 'LIT.001',
      severity    => 'NOTE',
      description => "IP address used as string. The string literal looks like an IP address but is not used inside INET_ATON(). WHERE ip='127.0.0.1' is better as ip=INET_ATON('127.0.0.1') if the column is numeric.",
   },
   'get_rule_info(LIT.001) works',
);

# Test getting a nonexistent rule.
is(
   $qar->get_rule_info('BAR.002'),
   undef,
   "get_rule_info() nonexistent rule"
);

is(
   $qar->get_rule_info(),
   undef,
   "get_rule_info(undef)"
);

# Add a rule for which there is no POD info and test that it's not allowed.
push @$rules, {
   id   => 'FOO.001',
   code => sub { return },
};
$qar->_reset_rule_info();  # else we'll get "cannot redefine rule" error
throws_ok (
   sub {
      $qar->load_rule_info(
         rules    => $rules,
         file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
         section  => 'CHECKS',
      );
   },
   qr/There is no info for rule FOO.001/,
   "Doesn't allow rules without info",
);

pop @$rules;

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
